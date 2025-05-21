import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/services/trip_invitation_service.dart';
import 'package:trip_planner/widgets/base/base_modal.dart';
import 'package:trip_planner/widgets/trip_participants_list.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditParticipantsListModal extends StatefulWidget {
  final Trip trip;

  const EditParticipantsListModal({super.key, required this.trip});

  @override
  State<EditParticipantsListModal> createState() =>
      _EditParticipantsListModalState();
}

class _EditParticipantsListModalState extends State<EditParticipantsListModal> {
  late List<TripParticipant> _participants;
  final TripInvitationService _invitationService = TripInvitationService();
  String? _error;
  bool _isSaving = false;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _participants = List.from(widget.trip.participants);
  }

  // Method to update participants and save changes
  Future<void> _updateParticipants(
    List<TripParticipant> updatedParticipants,
  ) async {
    setState(() {
      _participants = updatedParticipants;
    });
  }

  // Method to save changes to the trip
  Future<void> _saveChanges() async {
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // Get the trip data service
      final tripDataService = Provider.of<TripDataService>(
        context,
        listen: false,
      );

      // Create a copy of the trip with updated participants
      final updatedTrip = widget.trip.copyWith(participants: _participants);

      // Update the trip in the database
      tripDataService.updateTrip(updatedTrip);

      // Process any pending invitations
      final newParticipants =
          _participants
              .where(
                (p) => !widget.trip.participants.any((op) => op.uid == p.uid),
              )
              .toList();

      for (final participant in newParticipants) {
        // Skip current user or already accepted participants
        if (participant.uid == user!.uid ||
            participant.invitationStatus == InvitationStatus.accepted) {
          continue;
        }

        // Create an invitation for the new participant
        await _invitationService.createInvitation(
          tripId: widget.trip.id,
          tripName: widget.trip.name,
          inviteeId: participant.uid,
          inviteeName: participant.username,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Pop with success result
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error updating participants: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseModal(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      isScrollable:
          false, // Keep this false to let inner components handle scrolling
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Trip Participants',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Participants List - Set a specific height to avoid layout issues
            Expanded(
              child: TripParticipantsList(
                participants: _participants,
                onParticipantsChanged: _updateParticipants,
                currentUserId: user?.uid ?? '',
              ),
            ),

            // Save button
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child:
                    _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to show the participants management modal
Future<bool?> showParticipantsListModal({
  required BuildContext context,
  required Trip trip,
}) {
  return showAppModal<bool>(
    context: context,
    initialChildSize: 0.85, // Start a bit larger to avoid scrolling issues
    minChildSize: 0.6,
    maxChildSize: 0.95,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => EditParticipantsListModal(trip: trip),
  );
}
