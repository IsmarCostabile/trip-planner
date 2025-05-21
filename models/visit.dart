import 'package:cloud_firestore/cloud_firestore.dart';
import 'attachment.dart';
import 'location.dart';

class Visit {
  final String id;
  final String locationId; // Reference to Location model
  Location? location; // Actual location object (can be loaded separately)
  final DateTime visitTime;
  final int visitDuration; // Duration in minutes
  final String? notes;
  final double? cost; // Optional cost of the visit
  final List<Attachment> photos;
  final List<Attachment> files;

  Visit({
    required this.id,
    required this.locationId,
    required this.visitTime,
    this.location,
    this.visitDuration = 0,
    this.notes,
    this.cost,
    this.photos = const [],
    this.files = const [],
  });

  factory Visit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final List<Attachment> photos = [];
    if (data['photos'] != null) {
      for (final photo in data['photos']) {
        photos.add(Attachment.fromMap(photo));
      }
    }
    final List<Attachment> files = [];
    if (data['files'] != null) {
      for (final file in data['files']) {
        files.add(Attachment.fromMap(file));
      }
    }

    // Helper function to handle ISO8601 date strings
    DateTime parseDate(dynamic dateValue) {
      try {
        if (dateValue is String) {
          return DateTime.parse(dateValue);
        } else {
          print(
            'Unexpected date format: $dateValue (${dateValue.runtimeType})',
          );
          return DateTime.now(); // Fallback to current date if format is unknown
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
      cost: (data['cost'] as num?)?.toDouble(),
      photos: photos,
      files: files,
    );
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    final List<Attachment> photos = [];
    if (map['photos'] != null) {
      for (final photo in map['photos']) {
        photos.add(Attachment.fromMap(photo));
      }
    }

    final List<Attachment> files = [];
    if (map['files'] != null) {
      for (final file in map['files']) {
        files.add(Attachment.fromMap(file));
      }
    }

    // Parse location data if it exists
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
      location: location, // Add the parsed location
      visitTime: DateTime.parse(map['visitTime']),
      visitDuration: map['visitDuration'] ?? 0,
      notes: map['notes'],
      cost: map['cost'] != null ? (map['cost'] as num).toDouble() : null,
      photos: photos,
      files: files,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Include the ID field when saving to Firestore
      'locationId': locationId,
      'visitTime':
          visitTime
              .toIso8601String(), // Convert DateTime to String instead of Timestamp
      'visitDuration': visitDuration,
      'notes': notes,
      'cost': cost,
      'photos': photos.map((photo) => photo.toMap()).toList(),
      'files': files.map((file) => file.toMap()).toList(),
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
      'cost': cost,
      'photos': photos.map((photo) => photo.toMap()).toList(),
      'files': files.map((file) => file.toMap()).toList(),
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
    List<Attachment>? photos,
    List<Attachment>? files,
  }) {
    return Visit(
      id: id,
      locationId: locationId ?? this.locationId,
      location: location ?? this.location,
      visitTime: visitTime ?? this.visitTime,
      visitDuration: visitDuration ?? this.visitDuration,
      notes: notes ?? this.notes,
      cost: cost ?? this.cost,
      photos: photos ?? this.photos,
      files: files ?? this.files,
    );
  }

  String get formattedVisitTime {
    final hour = visitTime.hour;
    final minute = visitTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hourDisplay = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hourDisplay:$minute $period';
  }

  /// Returns the end time of the visit, calculated from visitTime + visitDuration
  DateTime get visitEndTime => visitTime.add(Duration(minutes: visitDuration));

  /// Returns the end time formatted as a string (e.g. "2:30 PM")
  String get formattedVisitEndTime {
    final endTime = visitEndTime;
    final hour = endTime.hour;
    final minute = endTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hourDisplay = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hourDisplay:$minute $period';
  }
}
