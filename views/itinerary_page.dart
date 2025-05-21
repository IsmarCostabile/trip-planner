import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/places_service.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/widgets/day_visits_list.dart';
// Remove DaySelectorAppBar import if no longer needed directly
// import 'package:trip_planner/widgets/day_selector_app_bar.dart';
import 'package:trip_planner/widgets/modals/place_search_modal.dart';
import 'package:trip_planner/widgets/modals/location_preview_modal.dart';
import 'package:trip_planner/widgets/modals/add_visit_modal.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_day.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:trip_planner/widgets/base/base_modal.dart';
import 'package:trip_planner/widgets/day_selector.dart'; // Import DaySelector
import 'package:trip_planner/widgets/base/overlapping_avatars.dart'; // Import for avatars
import 'package:trip_planner/widgets/highlighted_text.dart'; // Import for title

class ItineraryPage extends StatefulWidget {
  const ItineraryPage({super.key});

  @override
  State<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage>
    with AutomaticKeepAliveClientMixin {
  final PlacesService _placesService = PlacesService();
  // PageController to manage swiping between days
  late PageController _pageController;
  bool _isProgrammaticScroll = false; // Flag to prevent update loops
  // Keep track of pages that have been viewed to optimize loading
  final Set<String> _initializedPages = {};
  // Cache for day content widgets to prevent rebuilding
  final Map<String, Widget> _pageCache = {};
  // Add this to track the last time trip data was updated
  int _lastTripUpdateTimestamp = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Initialize with keepAlive and viewportFraction for smoother scrolling
    // Adding viewportFraction slightly less than 1.0 helps with performance
    _pageController = PageController(
      keepPage: true,
      viewportFraction:
          0.999, // Slight offset prevents some Flutter rendering issues
    );

    // Initialize the controller with the current selected day index after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripDataService = Provider.of<TripDataService>(
        context,
        listen: false,
      );
      if (!tripDataService.isLoading &&
          tripDataService.selectedTripDays.isNotEmpty &&
          _pageController.hasClients) {
        // Jump directly without animation on initial load
        _pageController.jumpToPage(tripDataService.selectedDayIndex);
        // Mark this page as initialized
        if (tripDataService.selectedTripDays.isNotEmpty) {
          _initializedPages.add(
            tripDataService
                .selectedTripDays[tripDataService.selectedDayIndex]
                .id,
          );
        }
      }

      // Add listener to tripDataService to detect changes
      tripDataService.addListener(_onTripDataChanged);
    });
  }

  // Add this method to handle trip data changes
  void _onTripDataChanged() {
    // Skip if widget is no longer mounted to avoid lifecycle exceptions
    if (!mounted) return;

    // Get current timestamp
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

    // If this update is within 100ms of the last one, ignore it to prevent excessive rebuilds
    if (currentTimestamp - _lastTripUpdateTimestamp < 100) return;

    // Mark the timestamp
    _lastTripUpdateTimestamp = currentTimestamp;

    // Clear cache to force rebuild - only if still mounted
    // Use a safe setState pattern to avoid lifecycle errors
    if (mounted) {
      // Check if this context is still valid before calling setState
      try {
        setState(() {
          _pageCache.clear();
        });
      } catch (e) {
        // Log error but don't crash if setState fails due to timing issues
        debugPrint('Error updating page cache: $e');
      }
    }
  }

  @override
  void dispose() {
    // Safely remove listener when disposing
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
    final theme = Theme.of(context); // Get theme

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
        body: const Center(child: Text('No trip selected or data available.')),
      );
    }

    final tripDays = tripDataService.selectedTripDays;
    final bool showDaySelector = tripDays.length <= 20;
    final tripColor = selectedTrip.color ?? theme.colorScheme.primary;

    if (tripDays.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(selectedTrip.name)),
        body: const Center(child: Text('This trip has no planned days yet.')),
        floatingActionButton: _buildAddPlaceButton(tripDataService),
      );
    }

    // Synchronize PageController when selectedDayIndex changes externally
    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.round();
      final targetPage = tripDataService.selectedDayIndex;
      if (currentPage != targetPage) {
        // Use a post frame callback to avoid triggering build during build
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
      // Replace body with NestedScrollView
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              // Configuration for hiding on scroll
              floating:
                  true, // Makes the app bar reappear as soon as you scroll up
              snap:
                  true, // Snaps the app bar into view when scrolling up slightly
              pinned: false, // Does not stay visible when scrolled down
              backgroundColor: Colors.white,
              foregroundColor:
                  Colors.black, // Adjust icon/text colors if needed
              elevation: 1.0, // Optional: Add a slight shadow
              // Leading: Participant Avatars (extracted from TripHeaderBar logic)
              leading: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: OverlappingAvatars(
                  participants: selectedTrip.participants,
                  maxVisibleAvatars: 3,
                  avatarSize: 42.0,
                  overlap: 12.0,
                  backgroundColor: Colors.grey.shade400,
                ),
              ),
              // Title: Trip Name (extracted from TripHeaderBar logic)
              title: Padding(
                padding: const EdgeInsets.only(
                  bottom: 0.0,
                ), // Adjust padding if needed
                child: HighlightedText(
                  text: selectedTrip.name,
                  highlightColor: tripColor,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28, // Slightly smaller for SliverAppBar
                    color: Colors.black,
                  ),
                ),
              ),
              centerTitle: true,
              // Actions: Pass any actions if needed (assuming null for now)
              actions: null, // Replace with actual actions if required
              // Bottom: DaySelector (conditionally shown)
              bottom:
                  showDaySelector
                      ? PreferredSize(
                        // Update height to match DaySelector's new height
                        preferredSize: const Size.fromHeight(
                          55.0 + 16.0,
                        ), // _dayItemHeight + vertical padding
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
                      : null, // No bottom if day selector is hidden
            ),
          ];
        },
        // Body: The PageView
        body: Column(
          // Keep the Column structure if needed, otherwise just the Expanded PageView
          children: [
            Expanded(
              child: Consumer<TripDataService>(
                builder:
                    (
                      context,
                      service,
                      child,
                    ) => NotificationListener<ScrollNotification>(
                      // Add a scroll listener to track scrolling state
                      onNotification: (notification) {
                        // If scroll ends, clear cache to ensure fresh data
                        if (notification is ScrollEndNotification) {
                          // Only rebuild if scrolling has actually changed the page
                          if (_pageController.page?.round() !=
                              tripDataService.selectedDayIndex) {
                            setState(() {
                              // Clear just the cache of pages that aren't visible
                              final currentDayId =
                                  tripDays[_pageController.page!.round()].id;
                              _pageCache.removeWhere(
                                (key, value) => key != currentDayId,
                              );
                            });
                          }
                        }
                        return false; // Return false for NestedScrollView compatibility
                      },
                      child: Semantics(
                        container: true,
                        label: 'Day itinerary view',
                        explicitChildNodes:
                            true, // Explicitly handle child semantics
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
                            // Ensure physics allows NestedScrollView to handle scroll
                            physics: const PageScrollPhysics(),
                            allowImplicitScrolling: false,
                            pageSnapping: true,
                            key: const PageStorageKey('itinerary_page_view'),
                            itemBuilder: (context, index) {
                              final tripDay = tripDays[index];
                              final tripDayId = tripDay.id;

                              // Check if we need to mark as initialized
                              if (!_initializedPages.contains(tripDayId)) {
                                _initializedPages.add(tripDayId);
                              }

                              // Check if we already have this page in cache
                              if (!_pageCache.containsKey(tripDayId)) {
                                // Create a new cached widget for this day
                                _pageCache[tripDayId] = _buildDayPage(
                                  tripDay,
                                  selectedTrip,
                                );
                              }

                              // Use cached page for better performance
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

  // Create a separate method to build day pages to make caching more explicit
  Widget _buildDayPage(TripDay tripDay, Trip selectedTrip) {
    // Safety check for context
    if (!mounted) {
      return const SizedBox.shrink(); // Return empty widget if context is invalid
    }

    // Get key that incorporates both tripDay.id and a content hash based on visits
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );
    final visits = tripDataService.getVisitsForDay(tripDay.id);

    // Build visit hash for cache invalidation
    final visitsHash = visits.fold(
      '',
      (prev, visit) =>
          '$prev${visit.id}:${visit.visitTime.millisecondsSinceEpoch}:${visit.visitDuration}',
    );

    return RepaintBoundary(
      child: KeepAlivePage(
        key: ValueKey(
          'keep_alive_${tripDay.id}_$visitsHash',
        ), // Add a key that changes when visits change
        child: DayVisitsList(
          key: ValueKey('day_list_${tripDay.id}_$visitsHash'),
          tripDay: tripDay,
          onRefresh: () async {
            // Force map refresh instead of calling loadTripDays which is now handled by streams
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
      backgroundColor: Colors.white, // Set the inside of the button to white
      elevation: 0, // Remove shadow to prevent darkening
      tooltip: 'Add Place to Itinerary',
      child: Icon(
        Icons.add,
        color: Theme.of(context).colorScheme.primary,
      ), // Adjust icon color for contrast
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

    // Show the search modal and wait for a result
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

    // Handle the result based on the action requested
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

    // Get the TripDataService instance *before* the async gap of showAppModal
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    final result = await showAppModal<Map<String, dynamic>>(
      context: context,
      builder:
          (modalContext) => ChangeNotifierProvider.value(
            // Changed from Provider.value
            value: tripDataService, // Use the instance fetched before the await
            child: LocationPreviewModal(
              placeDetails: details,
              trip: trip,
              onLocationSaved: (updatedTrip) {
                // Use the provided service instance directly if needed, or re-fetch
                // Using the instance passed via .value is generally safe here
                tripDataService.updateTrip(updatedTrip);
              },
              selectedTripDay: selectedTripDay,
            ),
          ),
    );

    // Handle the result if needed
    if (result != null && mounted && result['action'] == 'showAddVisitModal') {
      // Ensure selectedTrip is not null before proceeding
      final currentSelectedTrip =
          Provider.of<TripDataService>(context, listen: false).selectedTrip;
      if (currentSelectedTrip != null) {
        _showAddVisitModal(
          result['place'],
          currentSelectedTrip,
          result['tripDay'],
        );
      } else {
        // Handle error: selected trip is null
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No selected trip found.')),
        );
      }
    }

    // Clear cache when modal is closed to ensure fresh data
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

    // Get the TripDataService instance *before* the async gap of showAppModal
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    await showAppModal(
      context: context,
      builder:
          (modalContext) => ChangeNotifierProvider.value(
            // Changed from Provider.value
            value: tripDataService, // Use the instance fetched before the await
            child: AddVisitModal(place: place, trip: trip, tripDay: tripDay),
          ),
    );

    // Refresh data after closing the modal
    if (mounted) {
      // Clear cache to ensure fresh data is shown
      setState(() {
        _pageCache.clear();
      });

      // Force map refresh instead of calling loadTripDays
      tripDataService.forceMapRefresh();
    }
  }
}

// Helper widget to ensure pages stay alive in the PageView
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
