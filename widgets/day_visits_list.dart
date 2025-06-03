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
    if (widget.tripDay.id != oldWidget.tripDay.id) {
      _loadVisitsFromService(initialLoad: true);
      setState(() => _expandedStates.clear());
    }
  }

  void _loadVisitsFromService({bool initialLoad = false}) {
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    if (initialLoad && !_initialLoadComplete) {
      setState(() {
        _initialLoadComplete = true;
      });
    }
  }

  String _getTravelTileKey(
    String fromVisitId,
    String toVisitId,
    String fromName,
    String toName,
  ) {
    return 'travel_${fromName}_to_${toName}_${fromVisitId}_${toVisitId}';
  }

  TravelTimeTile _getTravelTimeTile({
    required String fromVisitId,
    required String toVisitId,
    required String fromName,
    required String toName,
    required Location? originLocation,
    required Location? destinationLocation,
    required DateTime destinationArrivalTime,
  }) {
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );
    final visits = tripDataService.getVisitsForDay(widget.tripDay.id);
    final tripDay = tripDataService.findTripDayById(widget.tripDay.id);

    Visit? originVisit;
    for (final visit in visits) {
      if (visit.id == fromVisitId) {
        originVisit = visit;
        break;
      }
    }

    DateTime? originVisitEndTime;
    if (originVisit != null && originVisit.visitDuration > 0) {
      originVisitEndTime = originVisit.visitEndTime;
    }

    String? preferredTravelMode;
    if (tripDay != null) {
      final travelSegment = tripDay.findTravelSegment(fromVisitId, toVisitId);
      if (travelSegment != null) {
        preferredTravelMode = travelSegment.travelMode;
      }
    }

    final timeKey =
        '${destinationArrivalTime.millisecondsSinceEpoch}_${originVisitEndTime?.millisecondsSinceEpoch ?? 0}';
    final keyWithTripId =
        '${fromVisitId}_${toVisitId}_${widget.tripDay.tripId}_$timeKey';
    final tileKey = _getTravelTileKey(fromVisitId, toVisitId, fromName, toName);

    final shouldCreateNewTile =
        !_travelTimeTiles.containsKey(tileKey) ||
        (_travelTimeTiles[tileKey]?.key as PageStorageKey?)?.value !=
            keyWithTripId;

    if (shouldCreateNewTile) {
      _travelTimeTiles[tileKey] = TravelTimeTile(
        key: PageStorageKey(keyWithTripId),
        originName: fromName,
        destinationName: toName,
        originLocation: originLocation,
        destinationLocation: destinationLocation,
        tripId: widget.tripDay.tripId,
        destinationArrivalTime: destinationArrivalTime,
        originVisitEndTime: originVisitEndTime,
        originVisitId: fromVisitId,
        destinationVisitId: toVisitId,
        travelMode: preferredTravelMode,
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
    super.build(context);

    return Selector<TripDataService, List<Visit>>(
      selector: (_, service) {
        final visits = service.getVisitsForDay(widget.tripDay.id);
        final sortedVisits = List<Visit>.from(visits);
        sortedVisits.sort((a, b) => a.visitTime.compareTo(b.visitTime));
        return sortedVisits;
      },
      shouldRebuild: (previous, next) {
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
              itemCount: visits.length * 2 - 1,
              itemBuilder: (context, index) {
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
                } else {
                  final fromVisitIndex = index ~/ 2;
                  final toVisitIndex = fromVisitIndex + 1;

                  final fromVisit = visits[fromVisitIndex];
                  final toVisit = visits[toVisitIndex];

                  final fromName =
                      fromVisit.location?.name ?? 'Previous Location';
                  final toName = toVisit.location?.name ?? 'Next Location';

                  final travelTile = _getTravelTimeTile(
                    fromVisitId: fromVisit.id,
                    toVisitId: toVisit.id,
                    fromName: fromName,
                    toName: toName,
                    originLocation: fromVisit.location,
                    destinationLocation: toVisit.location,
                    destinationArrivalTime: toVisit.visitTime,
                  );

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 50,
                        margin: const EdgeInsets.only(left: 16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 2,
                              height: 50,
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withOpacity(0.5),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.secondary,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
