import 'package:cloud_firestore/cloud_firestore.dart';
import 'visit.dart';

// Add a TravelSegment class to store the travel mode between visits
class TravelSegment {
  final String originVisitId;
  final String destinationVisitId;
  final String travelMode;

  TravelSegment({
    required this.originVisitId,
    required this.destinationVisitId,
    required this.travelMode,
  });

  Map<String, dynamic> toMap() {
    return {
      'originVisitId': originVisitId,
      'destinationVisitId': destinationVisitId,
      'travelMode': travelMode,
    };
  }

  factory TravelSegment.fromMap(Map<String, dynamic> map) {
    return TravelSegment(
      originVisitId: map['originVisitId'] as String,
      destinationVisitId: map['destinationVisitId'] as String,
      travelMode: map['travelMode'] as String,
    );
  }
}

class TripDay {
  final String id;
  final String tripId;
  final DateTime date;
  final List<Visit> visits;
  final List<TravelSegment> travelSegments; // Added travel segments list
  final String? notes;
  final DateTime? updatedAt;

  TripDay({
    required this.id,
    required this.tripId,
    required this.date,
    this.visits = const [],
    this.travelSegments = const [], // Initialize with empty list
    this.notes,
    this.updatedAt,
  });

  // Create from Firestore document
  factory TripDay.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final List<Visit> visits = [];
    if (data['visits'] != null) {
      for (final visitData in data['visits']) {
        // Explicitly cast the map before passing it
        visits.add(Visit.fromMap(Map<String, dynamic>.from(visitData as Map)));
      }
    }

    // Parse travel segments
    final List<TravelSegment> travelSegments = [];
    if (data['travelSegments'] != null) {
      for (final segmentData in data['travelSegments']) {
        try {
          travelSegments.add(
            TravelSegment.fromMap(
              Map<String, dynamic>.from(segmentData as Map),
            ),
          );
        } catch (e) {
          print('Error parsing travel segment: $e');
        }
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

    return TripDay(
      id: doc.id,
      tripId: data['tripId'],
      date: parseDate(data['date']),
      visits: visits,
      travelSegments: travelSegments, // Include travel segments
      notes: data['notes'],
      updatedAt:
          data['updatedAt'] != null ? parseDate(data['updatedAt']) : null,
    );
  }

  // Create from map
  factory TripDay.fromMap(String id, Map<String, dynamic> map) {
    final List<Visit> visits = [];
    if (map['visits'] != null) {
      for (final visit in map['visits']) {
        try {
          // Safely convert to Map<String, dynamic> with error handling
          if (visit is Map) {
            visits.add(Visit.fromMap(Map<String, dynamic>.from(visit)));
          }
        } catch (e) {
          print('Error parsing visit in TripDay: $e');
        }
      }
    }

    // Parse travel segments
    final List<TravelSegment> travelSegments = [];
    if (map['travelSegments'] != null) {
      for (final segment in map['travelSegments']) {
        try {
          if (segment is Map) {
            travelSegments.add(
              TravelSegment.fromMap(Map<String, dynamic>.from(segment)),
            );
          }
        } catch (e) {
          print('Error parsing travel segment in TripDay: $e');
        }
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

    return TripDay(
      id: id,
      tripId: map['tripId'],
      date: parseDate(map['date']),
      visits: visits,
      travelSegments: travelSegments, // Include travel segments
      notes: map['notes'],
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'date': date.toIso8601String(),
      'visits': visits.map((location) => location.toMap()).toList(),
      'travelSegments':
          travelSegments
              .map((segment) => segment.toMap())
              .toList(), // Include travel segments
      'notes': notes,
      'updatedAt': updatedAt != null ? updatedAt!.toIso8601String() : null,
    };
  }

  // Convert to map for local storage
  Map<String, dynamic> toLocalMap() {
    return {
      'tripId': tripId,
      'date': date.toIso8601String(),
      'visits': visits.map((location) => location.toLocalMap()).toList(),
      'travelSegments':
          travelSegments
              .map((segment) => segment.toMap())
              .toList(), // Include travel segments
      'notes': notes,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Copy with function for updating trip day
  TripDay copyWith({
    List<Visit>? visits,
    List<TravelSegment>? travelSegments, // Add travel segments parameter
    String? notes,
  }) {
    return TripDay(
      id: id,
      tripId: tripId,
      date: date,
      visits: visits ?? this.visits,
      travelSegments:
          travelSegments ?? this.travelSegments, // Include travel segments
      notes: notes ?? this.notes,
      updatedAt: DateTime.now(),
    );
  }

  // Add a convenience method to find a travel segment for specific visits
  TravelSegment? findTravelSegment(
    String originVisitId,
    String destinationVisitId,
  ) {
    try {
      return travelSegments.firstWhere(
        (segment) =>
            segment.originVisitId == originVisitId &&
            segment.destinationVisitId == destinationVisitId,
      );
    } catch (e) {
      // No segment found
      return null;
    }
  }

  // Helper method to add or update a travel segment
  TripDay addOrUpdateTravelSegment(
    String originVisitId,
    String destinationVisitId,
    String travelMode,
  ) {
    // Create a copy of the current travel segments
    final updatedSegments = List<TravelSegment>.from(travelSegments);

    // Try to find and update an existing segment
    final existingIndex = updatedSegments.indexWhere(
      (segment) =>
          segment.originVisitId == originVisitId &&
          segment.destinationVisitId == destinationVisitId,
    );

    if (existingIndex >= 0) {
      // Replace the existing segment
      updatedSegments[existingIndex] = TravelSegment(
        originVisitId: originVisitId,
        destinationVisitId: destinationVisitId,
        travelMode: travelMode,
      );
    } else {
      // Add a new segment
      updatedSegments.add(
        TravelSegment(
          originVisitId: originVisitId,
          destinationVisitId: destinationVisitId,
          travelMode: travelMode,
        ),
      );
    }

    // Return a new TripDay with the updated segments
    return copyWith(travelSegments: updatedSegments);
  }

  // Format day as string (e.g., "Mon, Jan 1")
  String dayLabel(DateTime tripStartDate) {
    return '${_getWeekdayShort(date.weekday)} ${date.day}${_getDayNumberSuffix(date.day)}';
  }

  String _getDayNumberSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  // Get date formatted as "Mon, Jan 1"
  String get dateFormatted {
    return '${_getWeekdayShort(date.weekday)}, ${_getMonthShort(date.month)} ${date.day}';
  }

  // Helper method to get short weekday name
  String _getWeekdayShort(int weekday) {
    const weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday];
  }

  // Helper method to get short month name
  String _getMonthShort(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }
}
