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

  Map<String, dynamic> toMap() {
    return {
      'location': location.toMap(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    };
  }

  factory TripDestination.fromMap(Map<String, dynamic> map) {
    return TripDestination(
      location: Location.fromMap(map['location'] as Map<String, dynamic>),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
    );
  }
}
