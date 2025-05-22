import 'package:flutter/material.dart';
import 'package:trip_planner/views/trip_creation_page.dart';

class EmptyTripPlaceholder extends StatelessWidget {
  final String message;
  final String buttonText;
  final IconData icon;

  const EmptyTripPlaceholder({
    super.key,
    this.message = 'No trips selected',
    this.buttonText = 'Plan your next Trip',
    this.icon = Icons.flight_takeoff,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large icon with semi-transparent background
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),

          // Message text
          Text(
            message,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Button to create a new trip
          ElevatedButton.icon(
            onPressed: () async {
              // Navigate to trip creation page
              final created = await TripCreationPage.show(context: context);

              // You can add additional handling here if needed
              if (created == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trip created successfully!')),
                );
              }
            },
            icon: const Icon(Icons.add),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
