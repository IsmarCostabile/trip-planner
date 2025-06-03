import 'package:cloud_firestore/cloud_firestore.dart';
import 'location.dart';

class Visit {
  final String id;
  final String locationId;
  Location? location;
  final DateTime visitTime;
  final int visitDuration;
  final String? notes;

  Visit({
    required this.id,
    required this.locationId,
    required this.visitTime,
    this.location,
    this.visitDuration = 0,
    this.notes,
  });

  factory Visit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseDate(dynamic dateValue) {
      try {
        if (dateValue is String) {
          return DateTime.parse(dateValue);
        } else {
          print(
            'Unexpected date format: $dateValue (${dateValue.runtimeType})',
          );
          return DateTime.now();
        }
      } catch (e) {
        print('Error parsing date: $dateValue - $e');
        return DateTime.now();
      }
    }

    return Visit(
      id: doc.id,
      locationId: data['locationId'],
      visitTime: parseDate(data['visitTime']),
      visitDuration: data['visitDuration'] ?? 0,
      notes: data['notes'],
    );
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    Location? location;
    if (map['location'] != null) {
      try {
        location = Location.fromMap(Map<String, dynamic>.from(map['location']));
      } catch (e) {
        print('Error parsing location in Visit: $e');
      }
    }

    return Visit(
      id: map['id'] ?? '',
      locationId: map['locationId'] ?? '',
      location: location,
      visitTime: DateTime.parse(map['visitTime']),
      visitDuration: map['visitDuration'] ?? 0,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'locationId': locationId,
      'visitTime': visitTime.toIso8601String(),
      'visitDuration': visitDuration,
      'notes': notes,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'locationId': locationId,
      'location': location?.toLocalMap(),
      'visitTime': visitTime.toIso8601String(),
      'visitDuration': visitDuration,
      'notes': notes,
    };
  }

  Visit copyWith({
    String? locationId,
    Location? location,
    DateTime? visitTime,
    int? visitDuration,
    String? notes,
    double? rating,
    double? cost,
    String? costCurrency,
  }) {
    return Visit(
      id: id,
      locationId: locationId ?? this.locationId,
      location: location ?? this.location,
      visitTime: visitTime ?? this.visitTime,
      visitDuration: visitDuration ?? this.visitDuration,
      notes: notes ?? this.notes,
    );
  }

  String get formattedVisitTime {
    final hour = visitTime.hour;
    final minute = visitTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hourDisplay = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hourDisplay:$minute $period';
  }

  DateTime get visitEndTime => visitTime.add(Duration(minutes: visitDuration));

  String get formattedVisitEndTime {
    final endTime = visitEndTime;
    final hour = endTime.hour;
    final minute = endTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hourDisplay = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hourDisplay:$minute $period';
  }
}
