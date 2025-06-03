import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/places_service.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/widgets/day_visits_list.dart';
import 'package:trip_planner/widgets/empty_trip_placeholder.dart';
import 'package:trip_planner/widgets/modals/place_search_modal.dart';
import 'package:trip_planner/widgets/modals/location_preview_modal.dart';
import 'package:trip_planner/widgets/modals/add_visit_modal.dart';
import 'package:trip_planner/widgets/modals/edit_participants_list_modal.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_day.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:trip_planner/widgets/base/base_modal.dart';
import 'package:trip_planner/widgets/day_selector.dart';
import 'package:trip_planner/widgets/base/overlapping_avatars.dart';
import 'package:trip_planner/widgets/highlighted_text.dart';

class ItineraryPage extends StatefulWidget {
  const ItineraryPage({super.key});

  @override
  State<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage>
    with AutomaticKeepAliveClientMixin {
  final PlacesService _placesService = PlacesService();
  late PageController _pageController;
  bool _isProgrammaticScroll = false;
  final Set<String> _initializedPages = {};
  final Map<String, Widget> _pageCache = {};
  int _lastTripUpdateTimestamp = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(keepPage: true, viewportFraction: 0.999);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripDataService = Provider.of<TripDataService>(
        context,
        listen: false,
      );
      if (!tripDataService.isLoading &&
          tripDataService.selectedTripDays.isNotEmpty &&
          _pageController.hasClients) {
        _pageController.jumpToPage(tripDataService.selectedDayIndex);
        if (tripDataService.selectedTripDays.isNotEmpty) {
          _initializedPages.add(
            tripDataService
                .selectedTripDays[tripDataService.selectedDayIndex]
                .id,
          );
        }
      }

      tripDataService.addListener(_onTripDataChanged);
    });
  }

  void _onTripDataChanged() {
    if (!mounted) return;

    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

    if (currentTimestamp - _lastTripUpdateTimestamp < 100) return;

    _lastTripUpdateTimestamp = currentTimestamp;

    if (mounted) {
      try {
        setState(() {
          _pageCache.clear();
        });
      } catch (e) {
        debugPrint('Error updating page cache: $e');
      }
    }
  }

  @override
  void dispose() {
    try {
      final tripDataService = Provider.of<TripDataService>(
        context,
        listen: false,
      );
      tripDataService.removeListener(_onTripDataChanged);
    } catch (e) {
      debugPrint('Error removing listener: $e');
    }

    _pageController.dispose();
    _pageCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tripDataService = Provider.of<TripDataService>(context);
    final theme = Theme.of(context);

    if (tripDataService.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Itinerary...')),
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (tripDataService.error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              tripDataService.error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final selectedTrip = tripDataService.selectedTrip;
    if (selectedTrip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Itinerary')),
        body: const EmptyTripPlaceholder(
          message: 'Ready to plan your adventure?',
          buttonText: 'Plan your next Trip',
          icon: Icons.map,
        ),
      );
    }

    final tripDays = tripDataService.selectedTripDays;
    final bool showDaySelector = tripDays.length <= 20;
    final tripColor = selectedTrip.color ?? theme.colorScheme.primary;

    if (tripDays.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(selectedTrip.name)),
        body: EmptyTripPlaceholder(
          message: 'This trip has no planned days yet.',
          buttonText: 'Add your first day',
          icon: Icons.calendar_today,
        ),
        floatingActionButton: _buildAddPlaceButton(tripDataService),
      );
    }

    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.round();
      final targetPage = tripDataService.selectedDayIndex;
      if (currentPage != targetPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients && !_isProgrammaticScroll) {
            _isProgrammaticScroll = true;
            _pageController
                .animateToPage(
                  targetPage,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                )
                .whenComplete(() {
                  if (mounted) {
                    setState(() {
                      _isProgrammaticScroll = false;
                    });
                  }
                });
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 1.0,
              toolbarHeight:
                  selectedTrip.name.length > 25
                      ? kToolbarHeight - 8.0
                      : selectedTrip.name.length > 15
                      ? kToolbarHeight - 4.0
                      : kToolbarHeight,
              leading: Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  top:
                      selectedTrip.name.length > 25
                          ? 2.0
                          : selectedTrip.name.length > 15
                          ? 3.0
                          : 4.0,
                ),
                child: OverlappingAvatars(
                  participants: selectedTrip.participants,
                  maxVisibleAvatars: 1,
                  avatarSize:
                      selectedTrip.name.length > 25
                          ? 34.0
                          : selectedTrip.name.length > 15
                          ? 36.0
                          : 38.0,
                  overlap: 12.0,
                  backgroundColor: Colors.grey.shade400,
                  clickable: true,
                  onTap: () => _handleAvatarsTap(context, selectedTrip),
                ),
              ),
              title: Padding(
                padding: EdgeInsets.only(
                  top:
                      selectedTrip.name.length > 25
                          ? 0.0
                          : selectedTrip.name.length > 15
                          ? 1.0
                          : 2.0,
                ),
                child: HighlightedText(
                  text: selectedTrip.name,
                  highlightColor: tripColor,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:
                        selectedTrip.name.length > 25
                            ? 20.0
                            : selectedTrip.name.length > 15
                            ? 24.0
                            : 28.0,
                    color: Colors.black,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              centerTitle: true,
              actions: null,
              bottom:
                  showDaySelector
                      ? PreferredSize(
                        preferredSize: const Size.fromHeight(55.0 + 16.0),
                        child: DaySelector(
                          trip: selectedTrip,
                          tripDays: tripDays,
                          selectedDayIndex: tripDataService.selectedDayIndex,
                          onDaySelected: (int? newIndex) {
                            if (newIndex != null) {
                              tripDataService.setSelectedDayIndex(newIndex);
                            }
                          },
                        ),
                      )
                      : null,
            ),
          ];
        },
        body: Column(
          children: [
            Expanded(
              child: Consumer<TripDataService>(
                builder:
                    (
                      context,
                      service,
                      child,
                    ) => NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollEndNotification) {
                          if (_pageController.page?.round() !=
                              tripDataService.selectedDayIndex) {
                            setState(() {
                              final currentDayId =
                                  tripDays[_pageController.page!.round()].id;
                              _pageCache.removeWhere(
                                (key, value) => key != currentDayId,
                              );
                            });
                          }
                        }
                        return false;
                      },
                      child: Semantics(
                        container: true,
                        label: 'Day itinerary view',
                        explicitChildNodes: true,
                        onScrollLeft: () {
                          if (tripDataService.selectedDayIndex > 0) {
                            tripDataService.setSelectedDayIndex(
                              tripDataService.selectedDayIndex - 1,
                            );
                          }
                        },
                        onScrollRight: () {
                          if (tripDataService.selectedDayIndex <
                              tripDays.length - 1) {
                            tripDataService.setSelectedDayIndex(
                              tripDataService.selectedDayIndex + 1,
                            );
                          }
                        },
                        child: RepaintBoundary(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: tripDays.length,
                            onPageChanged: (int newPage) {
                              if (_isProgrammaticScroll) return;
                              tripDataService.setSelectedDayIndex(newPage);
                            },
                            physics: const PageScrollPhysics(),
                            allowImplicitScrolling: false,
                            pageSnapping: true,
                            key: const PageStorageKey('itinerary_page_view'),
                            itemBuilder: (context, index) {
                              final tripDay = tripDays[index];
                              final tripDayId = tripDay.id;

                              if (!_initializedPages.contains(tripDayId)) {
                                _initializedPages.add(tripDayId);
                              }

                              if (!_pageCache.containsKey(tripDayId)) {
                                _pageCache[tripDayId] = _buildDayPage(
                                  tripDay,
                                  selectedTrip,
                                );
                              }

                              return _pageCache[tripDayId]!;
                            },
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildAddPlaceButton(tripDataService),
    );
  }

  Widget _buildDayPage(TripDay tripDay, Trip selectedTrip) {
    if (!mounted) {
      return const SizedBox.shrink();
    }

    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );
    final visits = tripDataService.getVisitsForDay(tripDay.id);

    final visitsHash = visits.fold(
      '',
      (prev, visit) =>
          '$prev${visit.id}:${visit.visitTime.millisecondsSinceEpoch}:${visit.visitDuration}',
    );

    return RepaintBoundary(
      child: KeepAlivePage(
        key: ValueKey('keep_alive_${tripDay.id}_$visitsHash'),
        child: DayVisitsList(
          key: ValueKey('day_list_${tripDay.id}_$visitsHash'),
          tripDay: tripDay,
          onRefresh: () async {
            final tripDataService = Provider.of<TripDataService>(
              context,
              listen: false,
            );
            tripDataService.forceMapRefresh();
            return Future.delayed(const Duration(milliseconds: 300));
          },
        ),
      ),
    );
  }

  Widget _buildAddPlaceButton(TripDataService tripDataService) {
    return FloatingActionButton(
      onPressed: _showPlaceSearchModal,
      shape: CircleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2.0,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      tooltip: 'Add Place to Itinerary',
      child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
    );
  }

  Future<void> _showPlaceSearchModal() async {
    final selectedTrip =
        Provider.of<TripDataService>(context, listen: false).selectedTrip;
    final tripDays =
        Provider.of<TripDataService>(context, listen: false).selectedTripDays;

    if (selectedTrip == null || tripDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add place: No trip or days available.'),
        ),
      );
      return;
    }

    final selectedTripDay =
        tripDays[Provider.of<TripDataService>(
          context,
          listen: false,
        ).selectedDayIndex];

    final result = await showAppModal<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => PlaceSearchModal(
            placesService: _placesService,
            trip: selectedTrip,
            onTripUpdated: (updatedTrip) {
              Provider.of<TripDataService>(
                context,
                listen: false,
              ).updateTrip(updatedTrip);
            },
            onPlaceSelected: (_) {},
            selectedTripDay: selectedTripDay,
          ),
    );

    if (result != null && mounted) {
      if (result['action'] == 'showLocationPreview') {
        _showLocationPreviewModal(
          result['details'],
          selectedTrip,
          selectedTripDay,
        );
      } else if (result['action'] == 'showAddVisitModal') {
        _showAddVisitModal(result['place'], selectedTrip, result['tripDay']);
      }
    }
  }

  Future<void> _showLocationPreviewModal(
    PlacesDetailsResponse details,
    Trip trip,
    TripDay selectedTripDay,
  ) async {
    if (!mounted) return;

    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    final result = await showAppModal<Map<String, dynamic>>(
      context: context,
      builder:
          (modalContext) => ChangeNotifierProvider.value(
            value: tripDataService,
            child: LocationPreviewModal(
              placeDetails: details,
              trip: trip,
              onLocationSaved: (updatedTrip) {
                tripDataService.updateTrip(updatedTrip);
              },
              selectedTripDay: selectedTripDay,
            ),
          ),
    );

    if (result != null && mounted && result['action'] == 'showAddVisitModal') {
      final currentSelectedTrip =
          Provider.of<TripDataService>(context, listen: false).selectedTrip;
      if (currentSelectedTrip != null) {
        _showAddVisitModal(
          result['place'],
          currentSelectedTrip,
          result['tripDay'],
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No selected trip found.')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _pageCache.clear();
      });
    }
  }

  Future<void> _showAddVisitModal(
    PlacesSearchResult place,
    Trip trip,
    TripDay tripDay,
  ) async {
    if (!mounted) return;

    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    await showAppModal(
      context: context,
      builder:
          (modalContext) => ChangeNotifierProvider.value(
            value: tripDataService,
            child: AddVisitModal(place: place, trip: trip, tripDay: tripDay),
          ),
    );

    if (mounted) {
      setState(() {
        _pageCache.clear();
      });

      tripDataService.forceMapRefresh();
    }
  }

  Future<void> _showParticipantsModal(BuildContext context, Trip trip) async {
    if (!mounted) return;

    await showParticipantsListModal(context: context, trip: trip);
  }

  void _handleAvatarsTap(BuildContext context, Trip trip) {
    showParticipantsListModal(context: context, trip: trip);
  }
}

class KeepAlivePage extends StatefulWidget {
  final Widget child;

  const KeepAlivePage({Key? key, required this.child}) : super(key: key);

  @override
  _KeepAlivePageState createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
