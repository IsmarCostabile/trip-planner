import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_planner/models/trip_day.dart';
import 'trip_participant.dart';
import 'location.dart';
import 'package:flutter/material.dart'; // Import for Color

class Trip {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final List<TripParticipant> participants;
  final List<Location> savedLocations; // Added field for saved locations
  List<TripDay> tripDays = []; // List of trip days - Made mutable
  final String? description;
  final String? coverImageUrl;
  final String ownerId; // The user who created the trip
  final Location? destination; // Added destination field
  final Color? color; // Added color property

  Trip({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.participants,
    required this.ownerId,
    this.savedLocations = const [], // Added parameter with default empty list
    this.description,
    this.coverImageUrl,
    this.destination, // Added destination parameter
    this.color, // Added color parameter
  });

  // Create from Firestore document
  factory Trip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final List<TripParticipant> participants = [];
    if (data['participants'] != null) {
      for (final participant in data['participants']) {
        try {
          participants.add(
            TripParticipant.fromMap(Map<String, dynamic>.from(participant)),
          );
        } catch (e) {
          print('Error parsing participant: $e');
        }
      }
    }

    final List<Location> savedLocations = [];
    if (data['savedLocations'] != null) {
      final locationsData = data['savedLocations'] as List<dynamic>;
      for (final location in locationsData) {
        try {
          savedLocations.add(
            Location.fromMap(Map<String, dynamic>.from(location)),
          );
        } catch (e) {
          print('Error parsing saved location: $e');
        }
      }
    }

    // Parse destination location if it exists
    Location? destination;
    if (data['destination'] != null) {
      try {
        destination = Location.fromMap(
          Map<String, dynamic>.from(data['destination']),
        );
      } catch (e) {
        print('Error parsing destination: $e');
      }
    }

    // Parse color if it exists
    Color? color;
    if (data['color'] != null) {
      try {
        color = Color(data['color'] as int);
      } catch (e) {
        print('Error parsing color: $e');
      }
    }

    // Helper function to handle different date formats
    DateTime parseDate(dynamic dateValue) {
      try {
        if (dateValue is String) {
          return DateTime.parse(dateValue);
        } else if (dateValue is Timestamp) {
          return dateValue.toDate();
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

    return Trip(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Trip',
      startDate:
          data['startDate'] != null
              ? parseDate(data['startDate'])
              : DateTime.now(),
      endDate:
          data['endDate'] != null ? parseDate(data['endDate']) : DateTime.now(),
      participants: participants,
      savedLocations: savedLocations,
      ownerId: data['ownerId'] as String? ?? '',
      description: data['description'] as String?,
      coverImageUrl: data['coverImageUrl'] as String?,
      destination: destination, // Add destination to constructor
      color: color, // Add color to constructor
    );
  }

  // Create from map (useful for local storage)
  factory Trip.fromMap(String id, Map<String, dynamic> map) {
    final List<TripParticipant> participants = [];
    if (map['participants'] != null) {
      for (final participant in map['participants']) {
        participants.add(
          TripParticipant.fromMap(Map<String, dynamic>.from(participant)),
        );
      }
    }

    final List<Location> savedLocations = [];
    if (map['savedLocations'] != null) {
      for (final location in map['savedLocations']) {
        savedLocations.add(
          Location.fromMap(Map<String, dynamic>.from(location)),
        );
      }
    }

    // Parse destination location if it exists
    Location? destination;
    if (map['destination'] != null) {
      destination = Location.fromMap(
        Map<String, dynamic>.from(map['destination']),
      );
    }

    // Parse color if it exists
    Color? color;
    if (map['color'] != null) {
      try {
        color = Color(map['color'] as int);
      } catch (e) {
        print('Error parsing color: $e');
      }
    }

    // Helper function to handle different date formats
    DateTime parseDate(dynamic dateValue) {
      try {
        if (dateValue is String) {
          return DateTime.parse(dateValue);
        } else if (dateValue is Timestamp) {
          return dateValue.toDate();
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

    return Trip(
      id: id,
      name: map['name'] ?? 'Unnamed Trip',
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      participants: participants,
      savedLocations: savedLocations,
      ownerId: map['ownerId'] ?? '',
      description: map['description'],
      coverImageUrl: map['coverImageUrl'],
      destination: destination, // Add destination to constructor
      color: color, // Add color to constructor
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'participants': participants.map((p) => p.toMap()).toList(),
      'savedLocations': savedLocations.map((l) => l.toMap()).toList(),
      'ownerId': ownerId,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'destination': destination?.toMap(), // Add destination to map
      'color': color?.value, // Add color value to map
    };
  }

  // Convert to map for local storage
  Map<String, dynamic> toLocalMap() {
    return {
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'participants': participants.map((p) => p.toMap()).toList(),
      'savedLocations': savedLocations.map((l) => l.toMap()).toList(),
      'ownerId': ownerId,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'destination': destination?.toMap(), // Add destination to local map
      'color': color?.value, // Add color value to local map
    };
  }

  // Copy with function for updating trip data
  Trip copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    List<TripParticipant>? participants,
    List<Location>? savedLocations,
    String? description,
    String? coverImageUrl,
    DateTime? updatedAt,
    Location? destination, // Add destination to copyWith
    Color? color, // Add color to copyWith
  }) {
    return Trip(
      id: id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      participants: participants ?? this.participants,
      savedLocations: savedLocations ?? this.savedLocations,
      ownerId: ownerId,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      destination:
          destination ?? this.destination, // Add destination to returned Trip
      color: color ?? this.color, // Add color to returned Trip
    );
  }

  // Calculate trip duration in days
  int get durationInDays => endDate.difference(startDate).inDays + 1;

  // Get a list of all dates in the trip
  List<DateTime> get allDates {
    final dates = <DateTime>[];
    for (int i = 0; i < durationInDays; i++) {
      dates.add(startDate.add(Duration(days: i)));
    }
    return dates;
  }
}
