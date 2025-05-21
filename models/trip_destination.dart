import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_planner/models/location.dart';

class TripDestination {
  final Location location;
  final DateTime startDate;
  final DateTime endDate;

  TripDestination({
    required this.location,
    required this.startDate,
    required this.endDate,
  });

  // Convert to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'location': location.toMap(), // Assuming Location has a toMap method
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    };
  }

  // Create from a Map (e.g., from Firestore)
  factory TripDestination.fromMap(Map<String, dynamic> map) {
    return TripDestination(
      location: Location.fromMap(map['location'] as Map<String, dynamic>),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
    );
  }
}
