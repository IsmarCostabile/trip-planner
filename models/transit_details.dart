import 'package:flutter/material.dart';

class TransitDetails {
  final String? lineName; // Bus 766, Metro A, etc.
  final String? vehicleType; // BUS, SUBWAY
  final String? departureStop;
  final String? arrivalStop;
  final String? headsign;
  final int? numStops;
  final String? duration;

  TransitDetails({
    this.lineName,
    this.vehicleType,
    this.departureStop,
    this.arrivalStop,
    this.headsign,
    this.numStops,
    this.duration,
  });

  String get formattedTransitLine {
    if (lineName == null || departureStop == null || arrivalStop == null) {
      return 'Unknown transit';
    }

    final type = vehicleType?.toLowerCase() ?? 'transit';
    final stops = numStops != null ? ' ($numStops stops)' : '';
    final time = duration != null ? ' - $duration' : '';

    return '$type ${lineName!}: $departureStop → $arrivalStop$time$stops';
  }

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
