import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_participant.dart';

class TripInvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Find pending trip invitations for the current user
  Future<List<Trip>> getPendingInvitations() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Get all trips to check for pending invitations
      final tripsSnapshot = await _firestore.collection('trips').get();

      // Filter trips where current user is a participant with pending status
      final pendingTrips =
          tripsSnapshot.docs.map((doc) => Trip.fromFirestore(doc)).where((
            trip,
          ) {
            // Find the current user in participants list
            final userParticipant = trip.participants.firstWhere(
              (participant) => participant.uid == user.uid,
              // Return null if user is not a participant
              orElse:
                  () => TripParticipant(
                    uid: '',
                    username: '',
                    invitationStatus: InvitationStatus.accepted,
                  ),
            );

            // Return true if the user is a participant and invitation is pending
            return userParticipant.uid.isNotEmpty &&
                userParticipant.invitationStatus == InvitationStatus.pending;
          }).toList();

      return pendingTrips;
    } catch (e) {
      print('Error getting trip invitations: $e');
      return [];
    }
  }

  // Check if the user has any pending invitations
  Future<bool> hasAnyPendingInvitations() async {
    final pendingInvitations = await getPendingInvitations();
    return pendingInvitations.isNotEmpty;
  }

  // Get the first pending invitation (for showing immediately after login)
  Future<Trip?> getFirstPendingInvitation() async {
    final pendingInvitations = await getPendingInvitations();
    if (pendingInvitations.isEmpty) return null;

    // Return the most recent invitation (based on username)
    pendingInvitations.sort(
      (a, b) => a.participants.first.username.compareTo(
        b.participants.first.username,
      ),
    );
    return pendingInvitations.first;
  }
}
