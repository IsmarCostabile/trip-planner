import 'package:flutter/material.dart';

class TransitDetails {
  final String? lineName; // e.g., "Bus 100", "Metro A"
  final String? vehicleType; // e.g., "BUS", "SUBWAY"
  final String? departureStop;
  final String? arrivalStop;
  final String? headsign; // Direction or destination of the vehicle
  final int? numStops; // Number of stops
  final String? duration; // Duration of this transit segment

  TransitDetails({
    this.lineName,
    this.vehicleType,
    this.departureStop,
    this.arrivalStop,
    this.headsign,
    this.numStops,
    this.duration,
  });

  /// Creates a formatted string representation of the transit line details
  String get formattedTransitLine {
    if (lineName == null || departureStop == null || arrivalStop == null) {
      return 'Unknown transit';
    }

    final type = vehicleType?.toLowerCase() ?? 'transit';
    final stops = numStops != null ? ' ($numStops stops)' : '';
    final time = duration != null ? ' - $duration' : '';

    return '$type ${lineName!}: $departureStop → $arrivalStop$time$stops';
  }

  /// Get the appropriate icon for this transit mode
  IconData get icon {
    final type = vehicleType?.toLowerCase() ?? '';

    switch (type) {
      case 'bus':
        return Icons.directions_bus;
      case 'subway':
      case 'metro':
        return Icons.subway;
      case 'train':
        return Icons.train;
      case 'tram':
        return Icons.tram;
      case 'ferry':
        return Icons.directions_boat;
      case 'walk':
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.directions_transit;
    }
  }

  /// Format the transit details into a rich text span with icon
  Widget get formattedTransitWidget {
    if (lineName == null || departureStop == null || arrivalStop == null) {
      return const Text('Unknown transit');
    }

    final stops = numStops != null ? ' ($numStops stops)' : '';
    final time = duration != null ? ' - $duration' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black),
                children: [
                  TextSpan(
                    text: lineName!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ': $departureStop → $arrivalStop'),
                  TextSpan(
                    text: time,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  TextSpan(
                    text: stops,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Creates a TransitDetails object from a JSON map
  factory TransitDetails.fromJson(Map<String, dynamic> json) {
    return TransitDetails(
      lineName: json['line']?['short_name'] ?? json['line']?['name'],
      vehicleType: json['vehicle']?['type']?.toString().toUpperCase(),
      departureStop: json['departure_stop']?['name'],
      arrivalStop: json['arrival_stop']?['name'],
      headsign: json['headsign'],
      numStops: json['num_stops'],
      duration: json['duration']?['text'],
    );
  }

  /// Converts the TransitDetails object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'line': {'name': lineName},
      'vehicle': {'type': vehicleType},
      'departure_stop': {'name': departureStop},
      'arrival_stop': {'name': arrivalStop},
      'headsign': headsign,
      'num_stops': numStops,
      'duration': {'text': duration},
    };
  }
}
