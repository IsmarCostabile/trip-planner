import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_invitation.dart';
import 'package:trip_planner/models/trip_participant.dart';

class TripInvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all invitations for the current user (sent to them)
  Future<List<TripInvitation>> getInvitationsForUser({
    InvitationStatus? status,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      Query query = _firestore
          .collection('tripInvitations')
          .where('inviteeId', isEqualTo: user.uid);

      // Add status filter if provided
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

  // Get invitations sent by the current user
  Future<List<TripInvitation>> getInvitationsSentByUser({
    InvitationStatus? status,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      Query query = _firestore
          .collection('tripInvitations')
          .where('inviterId', isEqualTo: user.uid);

      // Add status filter if provided
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

  // Get pending invitations for the current user
  Future<List<TripInvitation>> getPendingInvitations() async {
    return getInvitationsForUser(status: InvitationStatus.pending);
  }

  // Get trips with pending invitations (for backward compatibility)
  Future<List<Trip>> getTripsWithPendingInvitations() async {
    final pendingInvitations = await getPendingInvitations();
    if (pendingInvitations.isEmpty) return [];

    // Get trip IDs from invitations
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

  // Create a new trip invitation
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
      // Check if an invitation already exists for this user and trip
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

      // If an invitation already exists, don't create a new one
      if (existingInvitations.docs.isNotEmpty) {
        return false;
      }

      // Create a new invitation document
      final invitation = TripInvitation(
        id: '', // Will be assigned by Firestore
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

  // Update an invitation status
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

  // Get a specific invitation by ID
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

  // Check if the user has any pending invitations
  Future<bool> hasAnyPendingInvitations() async {
    final pendingInvitations = await getPendingInvitations();
    return pendingInvitations.isNotEmpty;
  }

  // Get the first pending invitation (for showing immediately after login)
  Future<Trip?> getFirstPendingInvitation() async {
    final pendingInvitations = await getPendingInvitations();
    if (pendingInvitations.isEmpty) return null;

    try {
      // Get the trip for the first pending invitation
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

  // Delete an invitation by ID
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
