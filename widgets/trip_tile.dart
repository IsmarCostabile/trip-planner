import 'package:flutter/material.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/widgets/base/base_list_tile.dart';

class TripTile extends StatelessWidget {
  final Trip trip;
  final bool isSelected;
  final Function(Trip trip) onTripSelected;
  final Function(Trip trip) onTripLeave;
  final Color? borderColor;

  const TripTile({
    Key? key,
    required this.trip,
    required this.isSelected,
    required this.onTripSelected,
    required this.onTripLeave,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        border:
            borderColor != null
                ? Border.all(color: borderColor!, width: 1.5)
                : Border.all(color: Colors.grey.shade300, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: BaseListTile(
          title: trip.name,
          subtitle: Text(
            '${_formatDate(trip.startDate)} - ${_formatDate(trip.endDate)}\n'
            '${trip.participants.length} participants',
          ),
          leading: Checkbox(
            value: isSelected,
            onChanged: (_) => onTripSelected(trip),
          ),
          trailing: const Icon(Icons.expand_more),
          onTap: () => onTripSelected(trip),
          elevation: 0,
          margin: EdgeInsets.zero,
          isExpandable: true,
          expandableContent: _buildExpandableContent(context),
          confirmDismiss: (direction) => _confirmDismiss(context),
          onDismissed: () => onTripLeave(trip),
        ),
      ),
    );
  }

  Widget _buildExpandableContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        // Participants section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Participants (${trip.participants.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    trip.participants
                        .map(
                          (participant) => Chip(
                            label: Text(
                              '@${participant.username}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: trip.color!.withOpacity(0.2),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),

        // Destination section
        if (trip.destination != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destination',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trip.destination!.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                if (trip.destination!.address != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      trip.destination!.address!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<bool?> _confirmDismiss(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Leave Trip'),
            content: Text('Are you sure you want to leave "${trip.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onTripLeave(trip);
                },
                child: const Text('Leave'),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().substring(2);
    return '$day/$month/$year';
  }
}
