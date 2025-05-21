import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:trip_planner/models/trip_day.dart';
import 'package:trip_planner/models/visit.dart';
import 'package:trip_planner/models/location.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/widgets/visit_tile.dart';
import 'package:trip_planner/widgets/travel_time_tile.dart';
import 'package:trip_planner/services/directions_service.dart';

class DayVisitsList extends StatefulWidget {
  final TripDay tripDay;
  final Future<void> Function() onRefresh;

  const DayVisitsList({
    super.key,
    required this.tripDay,
    required this.onRefresh,
  });

  @override
  State<DayVisitsList> createState() => _DayVisitsListState();
}

class _DayVisitsListState extends State<DayVisitsList>
    with AutomaticKeepAliveClientMixin {
  bool _initialLoadComplete = false;
  final Map<String, bool> _expandedStates = {};

  // Instance cache for travel time tiles
  final Map<String, TravelTimeTile> _travelTimeTiles = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadVisitsFromService(initialLoad: true);
  }

  @override
  void didUpdateWidget(DayVisitsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload visits if the tripDay ID changes - this prevents unnecessary reloading
    if (widget.tripDay.id != oldWidget.tripDay.id) {
      _loadVisitsFromService(initialLoad: true);
      // Only clear expanded states if we're looking at a different day
      setState(() => _expandedStates.clear());
    }
  }

  void _loadVisitsFromService({bool initialLoad = false}) {
    // Get visits from the TripDataService
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    // Only set state on initial load to avoid unnecessary rebuilds
    if (initialLoad && !_initialLoadComplete) {
      setState(() {
        _initialLoadComplete = true;
      });
    }
  }

  // Create a stable key for travel time tiles that persists across day changes
  String _getTravelTileKey(
    String fromVisitId,
    String toVisitId,
    String fromName,
    String toName,
  ) {
    // Use location names in the key to ensure stable references even if visit IDs change
    // This allows us to reuse travel time tiles for the same locations
    return 'travel_${fromName}_to_${toName}_${fromVisitId}_${toVisitId}';
  }

  // Get or create a travel time tile to avoid unnecessary rebuilds
  TravelTimeTile _getTravelTimeTile({
    required String fromVisitId,
    required String toVisitId,
    required String fromName,
    required String toName,
    required Location? originLocation,
    required Location? destinationLocation,
    required DateTime destinationArrivalTime,
  }) {
    // Find the origin visit to get its end time
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );
    final visits = tripDataService.getVisitsForDay(widget.tripDay.id);
    final tripDay = tripDataService.findTripDayById(widget.tripDay.id);

    // Find the origin visit by ID
    Visit? originVisit;
    for (final visit in visits) {
      if (visit.id == fromVisitId) {
        originVisit = visit;
        break;
      }
    }

    // Calculate the origin visit's end time
    DateTime? originVisitEndTime;
    if (originVisit != null && originVisit.visitDuration > 0) {
      originVisitEndTime = originVisit.visitEndTime;
    }

    // Check if there's a saved travel mode preference
    String? preferredTravelMode;
    if (tripDay != null) {
      final travelSegment = tripDay.findTravelSegment(fromVisitId, toVisitId);
      if (travelSegment != null) {
        preferredTravelMode = travelSegment.travelMode;
      }
    }

    // Generate a unique key that includes the trip ID and time information to ensure proper rebuilds
    final timeKey =
        '${destinationArrivalTime.millisecondsSinceEpoch}_${originVisitEndTime?.millisecondsSinceEpoch ?? 0}';
    final keyWithTripId =
        '${fromVisitId}_${toVisitId}_${widget.tripDay.tripId}_$timeKey';
    final tileKey = _getTravelTileKey(fromVisitId, toVisitId, fromName, toName);

    // We'll force recreate the tile in certain conditions to ensure fresh data
    final shouldCreateNewTile =
        !_travelTimeTiles.containsKey(tileKey) ||
        // Recreate if the trip changed or time info changed
        (_travelTimeTiles[tileKey]?.key as PageStorageKey?)?.value !=
            keyWithTripId;

    if (shouldCreateNewTile) {
      // Create a new tile with updated key and data
      _travelTimeTiles[tileKey] = TravelTimeTile(
        key: PageStorageKey(keyWithTripId),
        originName: fromName,
        destinationName: toName,
        originLocation: originLocation,
        destinationLocation: destinationLocation,
        tripId: widget.tripDay.tripId,
        destinationArrivalTime: destinationArrivalTime,
        originVisitEndTime:
            originVisitEndTime, // Pass the origin visit's end time
        originVisitId:
            fromVisitId, // Pass origin visit ID for stable travel preferences
        destinationVisitId:
            toVisitId, // Pass destination visit ID for stable travel preferences
        travelMode:
            preferredTravelMode, // Use the saved preference if available
      );
    }

    return _travelTimeTiles[tileKey]!;
  }

  Future<bool> _confirmDismiss(Visit visit) async {
    final location = visit.location?.name ?? 'this visit';

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Visit'),
            content: Text(
              'Are you sure you want to delete your visit to $location?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'DELETE',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteVisit(Visit visit) async {
    try {
      final tripDataService = Provider.of<TripDataService>(
        context,
        listen: false,
      );
      await tripDataService.removeVisit(widget.tripDay.id, visit.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting visit: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin

    return Selector<TripDataService, List<Visit>>(
      // Only rebuild when the list of visits for this specific day changes
      selector: (_, service) {
        // Get visits and sort them by start time
        final visits = service.getVisitsForDay(widget.tripDay.id);
        // Create a copy of the list to avoid modifying the original
        final sortedVisits = List<Visit>.from(visits);
        // Sort by visit time (ascending)
        sortedVisits.sort((a, b) => a.visitTime.compareTo(b.visitTime));
        return sortedVisits;
      },
      shouldRebuild: (previous, next) {
        // Check if the list actually changed to avoid unnecessary rebuilds
        if (previous.length != next.length) return true;
        for (int i = 0; i < previous.length; i++) {
          if (previous[i].id != next[i].id) return true;
        }
        return false;
      },
      builder: (context, visits, _) {
        if (visits.isEmpty) {
          return RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: Semantics(
              label: 'Empty day visits list',
              hint: 'Pull to refresh',
              child: ListView(
                // Use the TripDay's ID only for the key - more stable
                key: PageStorageKey('visits_list_${widget.tripDay.id}'),
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      'No visits planned for this day yet.\nAdd a place to get started!',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: Semantics(
            label: 'Day visits list',
            hint: 'Pull to refresh. Swipe visits left to delete.',
            child: ListView.builder(
              key: PageStorageKey('visits_list_${widget.tripDay.id}'),
              padding: const EdgeInsets.only(bottom: 80),
              // Calculate total items: visits + travel times between visits
              itemCount: visits.length * 2 - 1,
              itemBuilder: (context, index) {
                // If index is even, it's a visit
                if (index % 2 == 0) {
                  final visitIndex = index ~/ 2;
                  final visit = visits[visitIndex];

                  return Semantics(
                    sortKey: OrdinalSortKey(index.toDouble()),
                    child: VisitTile(
                      key: ValueKey('visit_${visit.id}'),
                      visit: visit,
                      confirmDismiss: (_) => _confirmDismiss(visit),
                      onDismissed: () => _deleteVisit(visit),
                      initiallyExpanded: _expandedStates[visit.id] ?? false,
                      onExpansionChanged: (expanded) {
                        setState(() => _expandedStates[visit.id] = expanded);
                      },
                    ),
                  );
                }
                // If index is odd, it's a travel time tile
                else {
                  // Calculate which visits this travel time is between
                  final fromVisitIndex = index ~/ 2;
                  final toVisitIndex = fromVisitIndex + 1;

                  final fromVisit = visits[fromVisitIndex];
                  final toVisit = visits[toVisitIndex];

                  final fromName =
                      fromVisit.location?.name ?? 'Previous Location';
                  final toName = toVisit.location?.name ?? 'Next Location';

                  // Get a cached travel time tile if it exists, or create a new one
                  final travelTile = _getTravelTimeTile(
                    fromVisitId: fromVisit.id,
                    toVisitId: toVisit.id,
                    fromName: fromName,
                    toName: toName,
                    originLocation: fromVisit.location,
                    destinationLocation: toVisit.location,
                    destinationArrivalTime:
                        toVisit
                            .visitTime, // Pass the destination visit's time as arrival time
                  );

                  // Create a row with connector line + travel tile
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Connector line with dot in the middle
                      Container(
                        width: 40,
                        height: 50, // Reduced height from 80 to 50
                        margin: const EdgeInsets.only(left: 16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Vertical line
                            Container(
                              width: 2,
                              height: 50, // Reduced height to match parent
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withOpacity(0.5),
                            ),
                            // Center dot
                            Container(
                              width: 8, // Reduced dot size from 10 to 8
                              height: 8, // Reduced dot size from 10 to 8
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.secondary,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width:
                                      1.5, // Reduced border width from 2 to 1.5
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Travel time tile - use the cached instance
                      Expanded(child: travelTile),
                    ],
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }
}
