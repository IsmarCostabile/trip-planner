import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_invitation.dart';
import 'package:trip_planner/models/trip_participant.dart';

class TripInvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<TripInvitation>> getInvitationsForUser({
    InvitationStatus? status,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      Query query = _firestore
          .collection('tripInvitations')
          .where('inviteeId', isEqualTo: user.uid);

      if (status != null) {
        query = query.where(
          'status',
          isEqualTo: status.toString().split('.').last,
        );
      }

      final invitationsSnapshot = await query.get();

      return invitationsSnapshot.docs
          .map((doc) => TripInvitation.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting trip invitations: $e');
      return [];
    }
  }

  Future<List<TripInvitation>> getInvitationsSentByUser({
    InvitationStatus? status,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      Query query = _firestore
          .collection('tripInvitations')
          .where('inviterId', isEqualTo: user.uid);

      if (status != null) {
        query = query.where(
          'status',
          isEqualTo: status.toString().split('.').last,
        );
      }

      final invitationsSnapshot = await query.get();

      return invitationsSnapshot.docs
          .map((doc) => TripInvitation.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting sent invitations: $e');
      return [];
    }
  }

  Future<List<TripInvitation>> getPendingInvitations() async {
    return getInvitationsForUser(status: InvitationStatus.pending);
  }

  Future<List<Trip>> getTripsWithPendingInvitations() async {
    final pendingInvitations = await getPendingInvitations();
    if (pendingInvitations.isEmpty) return [];

    final tripIds =
        pendingInvitations.map((inv) => inv.tripId).toSet().toList();

    try {
      final trips = <Trip>[];
      for (final tripId in tripIds) {
        final tripDoc = await _firestore.collection('trips').doc(tripId).get();
        if (tripDoc.exists) {
          trips.add(Trip.fromFirestore(tripDoc));
        }
      }
      return trips;
    } catch (e) {
      debugPrint('Error getting trips for invitations: $e');
      return [];
    }
  }

  Future<bool> createInvitation({
    required String tripId,
    required String tripName,
    required String inviteeId,
    required String inviteeName,
    String? message,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final existingInvitations =
          await _firestore
              .collection('tripInvitations')
              .where('tripId', isEqualTo: tripId)
              .where('inviteeId', isEqualTo: inviteeId)
              .where(
                'status',
                isEqualTo: InvitationStatus.pending.toString().split('.').last,
              )
              .get();

      if (existingInvitations.docs.isNotEmpty) {
        return false;
      }

      final invitation = TripInvitation(
        id: '',
        tripId: tripId,
        tripName: tripName,
        inviterId: user.uid,
        inviterName: user.displayName ?? 'Unknown',
        inviteeId: inviteeId,
        inviteeName: inviteeName,
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
        message: message,
      );

      await _firestore.collection('tripInvitations').add(invitation.toMap());
      return true;
    } catch (e) {
      debugPrint('Error creating invitation: $e');
      return false;
    }
  }

  Future<bool> updateInvitationStatus(
    String invitationId,
    InvitationStatus status,
  ) async {
    try {
      await _firestore.collection('tripInvitations').doc(invitationId).update({
        'status': status.toString().split('.').last,
      });
      return true;
    } catch (e) {
      debugPrint('Error updating invitation status: $e');
      return false;
    }
  }

  Future<TripInvitation?> getInvitationById(String invitationId) async {
    try {
      final doc =
          await _firestore
              .collection('tripInvitations')
              .doc(invitationId)
              .get();
      if (doc.exists) {
        return TripInvitation.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting invitation: $e');
      return null;
    }
  }

  Future<bool> hasAnyPendingInvitations() async {
    final pendingInvitations = await getPendingInvitations();
    return pendingInvitations.isNotEmpty;
  }

  Future<Trip?> getFirstPendingInvitation() async {
    final pendingInvitations = await getPendingInvitations();
    if (pendingInvitations.isEmpty) return null;

    try {
      final tripDoc =
          await _firestore
              .collection('trips')
              .doc(pendingInvitations.first.tripId)
              .get();

      if (tripDoc.exists) {
        return Trip.fromFirestore(tripDoc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting first pending invitation trip: $e');
      return null;
    }
  }

  Future<bool> deleteInvitation(String invitationId) async {
    try {
      await _firestore.collection('tripInvitations').doc(invitationId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting invitation: $e');
      return false;
    }
  }
}
