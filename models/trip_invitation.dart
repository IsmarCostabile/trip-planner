import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_planner/models/trip_participant.dart';

class TripInvitation {
  final String id;
  final String tripId;
  final String tripName;
  final String inviterId;
  final String inviterName;
  final String inviteeId;
  final String inviteeName;
  final DateTime createdAt;
  final InvitationStatus status;
  final String? message;

  TripInvitation({
    required this.id,
    required this.tripId,
    required this.tripName,
    required this.inviterId,
    required this.inviterName,
    required this.inviteeId,
    required this.inviteeName,
    required this.createdAt,
    this.status = InvitationStatus.pending,
    this.message,
  });

  // Create from Firestore document
  factory TripInvitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

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

    return TripInvitation(
      id: doc.id,
      tripId: data['tripId'] ?? '',
      tripName: data['tripName'] ?? 'Unnamed Trip',
      inviterId: data['inviterId'] ?? '',
      inviterName: data['inviterName'] ?? '',
      inviteeId: data['inviteeId'] ?? '',
      inviteeName: data['inviteeName'] ?? '',
      createdAt:
          data['createdAt'] != null
              ? parseDate(data['createdAt'])
              : DateTime.now(),
      status: _statusFromString(data['status']),
      message: data['message'],
    );
  }

  factory TripInvitation.fromMap(String id, Map<String, dynamic> map) {
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

    return TripInvitation(
      id: id,
      tripId: map['tripId'] ?? '',
      tripName: map['tripName'] ?? 'Unnamed Trip',
      inviterId: map['inviterId'] ?? '',
      inviterName: map['inviterName'] ?? '',
      inviteeId: map['inviteeId'] ?? '',
      inviteeName: map['inviteeName'] ?? '',
      createdAt:
          map['createdAt'] != null
              ? parseDate(map['createdAt'])
              : DateTime.now(),
      status: _statusFromString(map['status']),
      message: map['message'],
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'tripName': tripName,
      'inviterId': inviterId,
      'inviterName': inviterName,
      'inviteeId': inviteeId,
      'inviteeName': inviteeName,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'message': message,
    };
  }

  TripInvitation copyWith({
    String? tripId,
    String? tripName,
    String? inviterId,
    String? inviterName,
    String? inviteeId,
    String? inviteeName,
    DateTime? createdAt,
    InvitationStatus? status,
    String? message,
  }) {
    return TripInvitation(
      id: id,
      tripId: tripId ?? this.tripId,
      tripName: tripName ?? this.tripName,
      inviterId: inviterId ?? this.inviterId,
      inviterName: inviterName ?? this.inviterName,
      inviteeId: inviteeId ?? this.inviteeId,
      inviteeName: inviteeName ?? this.inviteeName,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  static InvitationStatus _statusFromString(String? status) {
    if (status == null) return InvitationStatus.pending;

    switch (status.toLowerCase()) {
      case 'accepted':
        return InvitationStatus.accepted;
      case 'declined':
        return InvitationStatus.declined;
      case 'pending':
      default:
        return InvitationStatus.pending;
    }
  }
}
