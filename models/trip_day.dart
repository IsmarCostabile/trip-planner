import 'package:cloud_firestore/cloud_firestore.dart';
import 'visit.dart';

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
  final List<TravelSegment> travelSegments;
  final String? notes;
  final DateTime? updatedAt;

  TripDay({
    required this.id,
    required this.tripId,
    required this.date,
    this.visits = const [],
    this.travelSegments = const [],
    this.notes,
    this.updatedAt,
  });

  factory TripDay.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final List<Visit> visits = [];
    if (data['visits'] != null) {
      for (final visitData in data['visits']) {
        // Explicitly cast the map before passing it
        visits.add(Visit.fromMap(Map<String, dynamic>.from(visitData as Map)));
      }
    }

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
          return DateTime.now();
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
      travelSegments: travelSegments,
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
          return DateTime.now();
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
      travelSegments: travelSegments,
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
          travelSegments.map((segment) => segment.toMap()).toList(),
      'notes': notes,
      'updatedAt': updatedAt != null ? updatedAt!.toIso8601String() : null,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'tripId': tripId,
      'date': date.toIso8601String(),
      'visits': visits.map((location) => location.toLocalMap()).toList(),
      'travelSegments':
          travelSegments.map((segment) => segment.toMap()).toList(),
      'notes': notes,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  TripDay copyWith({
    List<Visit>? visits,
    List<TravelSegment>? travelSegments,
    String? notes,
  }) {
    return TripDay(
      id: id,
      tripId: tripId,
      date: date,
      visits: visits ?? this.visits,
      travelSegments: travelSegments ?? this.travelSegments,
      notes: notes ?? this.notes,
      updatedAt: DateTime.now(),
    );
  }

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
      return null;
    }
  }

  TripDay addOrUpdateTravelSegment(
    String originVisitId,
    String destinationVisitId,
    String travelMode,
  ) {
    final updatedSegments = List<TravelSegment>.from(travelSegments);

    final existingIndex = updatedSegments.indexWhere(
      (segment) =>
          segment.originVisitId == originVisitId &&
          segment.destinationVisitId == destinationVisitId,
    );

    if (existingIndex >= 0) {
      updatedSegments[existingIndex] = TravelSegment(
        originVisitId: originVisitId,
        destinationVisitId: destinationVisitId,
        travelMode: travelMode,
      );
    } else {
      updatedSegments.add(
        TravelSegment(
          originVisitId: originVisitId,
          destinationVisitId: destinationVisitId,
          travelMode: travelMode,
        ),
      );
    }

    return copyWith(travelSegments: updatedSegments);
  }

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

  String get dateFormatted {
    return '${_getWeekdayShort(date.weekday)}, ${_getMonthShort(date.month)} ${date.day}';
  }

  String _getWeekdayShort(int weekday) {
    const weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday];
  }

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
