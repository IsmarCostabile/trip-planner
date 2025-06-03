import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trip_planner/models/location.dart';
import 'package:trip_planner/models/visit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:trip_planner/widgets/base/base_list_tile.dart';
import 'package:trip_planner/widgets/mini_map_view.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/widgets/modals/edit_visit_time_modal.dart';

class VisitTile extends StatelessWidget {
  final Visit visit;
  final Future<bool?> Function(DismissDirection)? confirmDismiss;
  final void Function()? onDismissed;
  final bool initiallyExpanded;
  final void Function(bool)? onExpansionChanged;

  const VisitTile({
    super.key,
    required this.visit,
    this.confirmDismiss,
    this.onDismissed,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours h';
    }
    return '$hours h ${remainingMinutes}m';
  }

  String _formatTimeRange(Visit visit) {
    final startTime = visit.formattedVisitTime;
    if (visit.visitDuration <= 0) {
      return startTime;
    }

    final endTime = visit.formattedVisitEndTime;
    return '$startTime - $endTime (${_formatDuration(visit.visitDuration)})';
  }

  @override
  Widget build(BuildContext context) {
    final locationName = visit.location?.name ?? 'Unknown Location';
    final theme = Theme.of(context);

    final timeSubtitleWidget = GestureDetector(
      onTap: () {
        EditVisitTimeModal.show(
          context: context,
          visit: visit,
          onSave: (DateTime newStartTime, DateTime newEndTime) async {
            final newDuration = newEndTime.difference(newStartTime).inMinutes;

            final adjustedDuration =
                newDuration < 0 ? newDuration + (24 * 60) : newDuration;

            final updatedVisit = visit.copyWith(
              visitTime: newStartTime,
              visitDuration: adjustedDuration,
            );

            try {
              final tripDataService = Provider.of<TripDataService>(
                context,
                listen: false,
              );

              String? tripDayId;
              for (final tripDay in tripDataService.selectedTripDays) {
                if (tripDataService
                    .getVisitsForDay(tripDay.id)
                    .any((v) => v.id == visit.id)) {
                  tripDayId = tripDay.id;
                  break;
                }
              }

              if (tripDayId != null) {
                await tripDataService.updateVisit(tripDayId, updatedVisit);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Visit time updated')),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating visit time: $e')),
                );
              }
            }
          },
        );
      },
      child: Row(
        children: [
          Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                visit.formattedVisitTime,
                style: const TextStyle(color: Colors.black, fontSize: 12),
              ),
            ),
          ),

          if (visit.visitDuration > 0) ...[
            const SizedBox(width: 1),
            Text(' - ', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 1),
            Material(
              elevation: 1,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  visit.formattedVisitEndTime,
                  style: const TextStyle(color: Colors.black, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Text(
              ' (${_formatDuration(visit.visitDuration)})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
    Widget? expandableContent;

    if (visit.notes != null && visit.notes!.isNotEmpty ||
        visit.location?.address != null ||
        (visit.location?.coordinates != null)) {
      expandableContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visit.location?.address != null) ...[
            Text(
              'Address:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(visit.location!.address!),
            const SizedBox(height: 8),
          ],

          if (visit.notes != null && visit.notes!.isNotEmpty) ...[
            Text(
              'Notes:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(visit.notes!),
            const SizedBox(height: 8),
          ],

          if (visit.location?.coordinates != null) ...[
            const SizedBox(height: 12),
            MiniMapView(visit: visit, mapId: 'map_${visit.id}'),
          ],
          const SizedBox(height: 6),
        ],
      );
    }

    final timeDescription = _formatTimeRange(visit);

    return RepaintBoundary(
      child: Semantics(
        label: '$locationName visit',
        value: timeDescription,
        hint: visit.notes != null ? 'Has notes' : null,
        child: BaseListTile(
          title: locationName,
          subtitle: timeSubtitleWidget,
          isExpandable: expandableContent != null,
          expandableContent:
              expandableContent != null
                  ? RepaintBoundary(child: expandableContent)
                  : null,
          onTap:
              expandableContent == null
                  ? () {
                    print('Tapped on visit: ${visit.id}');
                  }
                  : null,
          confirmDismiss: confirmDismiss,
          onDismissed: onDismissed,
          initiallyExpanded: initiallyExpanded,
          onExpansionChanged: onExpansionChanged,
        ),
      ),
    );
  }
}

class VisitListItem extends StatefulWidget {
  final Visit visit;

  const VisitListItem({super.key, required this.visit});

  @override
  State<VisitListItem> createState() => _VisitListItemState();
}

class _VisitListItemState extends State<VisitListItem>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  Location? _locationDetails;
  bool _isLoading = false;
  String? _error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    if (widget.visit.location == null) {
      _fetchLocationDetails();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('locations')
              .doc(widget.visit.locationId)
              .get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _locationDetails = Location.fromFirestore(doc);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Location not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading location: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours h';
    }
    return '$hours h ${remainingMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final visit = widget.visit;
    // Use fetched location details if available, otherwise fallback to visit.location (which might be null)
    final location = _locationDetails ?? visit.location;

    // Add debug logging to help diagnose the issue
    if (kDebugMode) {
      print('VisitListItem build: Location="${location?.name}"');
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time and Duration
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      // Add a single GestureDetector that wraps both time displays
                      GestureDetector(
                        onTap: () {
                          // Show the edit visit time modal with proper callback
                          EditVisitTimeModal.show(
                            context: context,
                            visit: visit,
                            onSave: (
                              DateTime newStartTime,
                              DateTime newEndTime,
                            ) async {
                              // Calculate new duration in minutes
                              final newDuration =
                                  newEndTime.difference(newStartTime).inMinutes;

                              // Handle case where end time is before start time (next day)
                              final adjustedDuration =
                                  newDuration < 0
                                      ? newDuration +
                                          (24 * 60) // Add a day in minutes
                                      : newDuration;

                              // Create updated visit with new time and duration
                              final updatedVisit = visit.copyWith(
                                visitTime: newStartTime,
                                visitDuration: adjustedDuration,
                              );

                              try {
                                // Update visit using TripDataService
                                final tripDataService =
                                    Provider.of<TripDataService>(
                                      context,
                                      listen: false,
                                    );

                                // Get the tripDayId for this visit
                                String? tripDayId;
                                for (final tripDay
                                    in tripDataService.selectedTripDays) {
                                  if (tripDataService
                                      .getVisitsForDay(tripDay.id)
                                      .any((v) => v.id == visit.id)) {
                                    tripDayId = tripDay.id;
                                    break;
                                  }
                                }

                                if (tripDayId != null) {
                                  await tripDataService.updateVisit(
                                    tripDayId,
                                    updatedVisit,
                                  );

                                  // Show success message
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Visit time updated'),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                // Show error message if update fails
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error updating visit time: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              visit.formattedVisitTime,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            if (visit.visitDuration > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(${_formatDuration(visit.visitDuration)}) ',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Show end time if available (part of the same tap interaction)
                      if (visit.visitDuration > 0)
                        GestureDetector(
                          onTap: () {
                            // Show the same edit modal for end time
                            EditVisitTimeModal.show(
                              context: context,
                              visit: visit,
                              onSave: (
                                DateTime newStartTime,
                                DateTime newEndTime,
                              ) async {
                                // Calculate new duration in minutes
                                final newDuration =
                                    newEndTime
                                        .difference(newStartTime)
                                        .inMinutes;

                                // Handle case where end time is before start time (next day)
                                final adjustedDuration =
                                    newDuration < 0
                                        ? newDuration +
                                            (24 * 60) // Add a day in minutes
                                        : newDuration;

                                // Create updated visit with new time and duration
                                final updatedVisit = visit.copyWith(
                                  visitTime: newStartTime,
                                  visitDuration: adjustedDuration,
                                );

                                try {
                                  // Update visit using TripDataService
                                  final tripDataService =
                                      Provider.of<TripDataService>(
                                        context,
                                        listen: false,
                                      );

                                  // Get the tripDayId for this visit
                                  String? tripDayId;
                                  for (final tripDay
                                      in tripDataService.selectedTripDays) {
                                    if (tripDataService
                                        .getVisitsForDay(tripDay.id)
                                        .any((v) => v.id == visit.id)) {
                                      tripDayId = tripDay.id;
                                      break;
                                    }
                                  }

                                  if (tripDayId != null) {
                                    await tripDataService.updateVisit(
                                      tripDayId,
                                      updatedVisit,
                                    );

                                    // Show success message
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Visit time updated'),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  // Show error message if update fails
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error updating visit time: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                          child: Text(
                            'Until ${visit.formattedVisitEndTime}',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Location Name and Loading/Error State
                  if (_isLoading)
                    const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Loading location...',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    )
                  else if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    )
                  else if (location != null)
                    Text(
                      location.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      'Location details not available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),

                  // Address
                  if (location?.address != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      location!.address!,
                      style: TextStyle(color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Notes
                  if (visit.notes != null && visit.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      visit.notes!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
