import 'package:flutter/material.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/widgets/user_search_field.dart';
import 'package:trip_planner/widgets/base/profile_picture.dart';

class TripParticipantsList extends StatefulWidget {
  final List<TripParticipant> participants;
  final Function(List<TripParticipant>) onParticipantsChanged;
  final String currentUserId;

  const TripParticipantsList({
    super.key,
    required this.participants,
    required this.onParticipantsChanged,
    required this.currentUserId,
  });

  @override
  State<TripParticipantsList> createState() => _TripParticipantsListState();
}

class _TripParticipantsListState extends State<TripParticipantsList> {
  late List<TripParticipant> _participants;

  @override
  void initState() {
    super.initState();
    _participants = List.from(widget.participants);
  }

  void _addParticipant(Map<String, dynamic> userData) {
    // Check if user is already a participant
    final exists = _participants.any((p) => p.uid == userData['uid']);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('@${userData['username']} is already a participant'),
        ),
      );
      return;
    }

    // Current user is trip owner and is auto-accepted
    // Other participants start with pending status until they accept
    final isCurrentUser = userData['uid'] == widget.currentUserId;
    final invitationStatus =
        isCurrentUser ? InvitationStatus.accepted : InvitationStatus.pending;

    // Get the photoURL from the userData
    final String? photoUrl = userData['photoURL'] ?? userData['photoUrl'];

    final newParticipant = TripParticipant(
      uid: userData['uid'],
      username: userData['username'],
      email: userData['email'],
      photoUrl: photoUrl, // Include the photoURL when creating the participant
      invitationStatus: invitationStatus,
    );

    setState(() {
      _participants.add(newParticipant);
    });
    widget.onParticipantsChanged(_participants);
  }

  void _removeParticipant(int index) {
    // Don't allow removing the current user (trip owner)
    if (_participants[index].uid == widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot remove yourself from the trip'),
        ),
      );
      return;
    }

    setState(() {
      _participants.removeAt(index);
    });
    widget.onParticipantsChanged(_participants);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Participants',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        UserSearchField(
          onUserSelected: _addParticipant,
          labelText: 'Add Participant',
          hintText: '@username',
        ),
        const SizedBox(height: 16),
        if (_participants.isNotEmpty) ...[
          const Text(
            'Current Participants:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero, // Remove default padding
              itemCount: _participants.length,
              separatorBuilder:
                  (context, index) => Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.dividerColor.withOpacity(0.3),
                  ),
              itemBuilder: (context, index) {
                final participant = _participants[index];
                final isCurrentUser = participant.uid == widget.currentUserId;
                final invitationStatus =
                    participant.invitationStatus == InvitationStatus.pending
                        ? ' (Invitation pending)'
                        : '';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: ProfilePictureWidget(
                    photoUrl: participant.photoUrl,
                    username: participant.username,
                    size: 40,
                  ),
                  title: Text(
                    '@${participant.username}${isCurrentUser ? ' (You)' : ''}$invitationStatus',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    participant.email ?? '',
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                  trailing:
                      isCurrentUser
                          ? Chip(
                            label: const Text('You'),
                            backgroundColor: Colors.green,
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          )
                          : IconButton(
                            icon: const Icon(Icons.remove_circle),
                            color: Colors.red,
                            onPressed: () => _removeParticipant(index),
                            tooltip: 'Remove participant',
                          ),
                );
              },
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: Text(
                'No participants added yet',
                style: TextStyle(color: theme.textTheme.bodySmall?.color),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
