import 'package:cloud_firestore/cloud_firestore.dart';

enum InvitationStatus { pending, accepted, declined }

class TripParticipant {
  final String uid;
  final String? email;
  final String username;
  final String? photoUrl;
  final InvitationStatus invitationStatus;

  TripParticipant({
    required this.uid,
    this.email,
    required this.username,
    this.photoUrl,
    this.invitationStatus =
        InvitationStatus.accepted, // Owner is automatically accepted
  });

  // Create from Firestore document
  factory TripParticipant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return TripParticipant(
      uid: doc.id,
      username: data?['username'] ?? '',
      email: data?['email'],
      photoUrl: data?['photoURL'] ?? data?['photoUrl'], // Accept both keys
      invitationStatus: _statusFromString(data?['invitationStatus']),
    );
  }

  factory TripParticipant.fromMap(Map<String, dynamic> map) {
    return TripParticipant(
      uid: map['uid'],
      username: map['username'] ?? '',
      email: map['email'],
      photoUrl: map['photoURL'] ?? map['photoUrl'], // Accept both keys
      invitationStatus: _statusFromString(map['invitationStatus']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'photoURL': photoUrl,
      'invitationStatus': invitationStatus.toString().split('.').last,
    };
  }

  TripParticipant copyWith({
    String? username,
    String? email,
    String? photoUrl,
    InvitationStatus? invitationStatus,
  }) {
    return TripParticipant(
      uid: uid,
      username: username ?? this.username,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      invitationStatus: invitationStatus ?? this.invitationStatus,
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
