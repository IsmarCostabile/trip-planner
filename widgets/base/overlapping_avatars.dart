import 'package:flutter/material.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/widgets/base/profile_picture.dart';

/// A widget that displays overlapping profile avatars with a +X indicator
class OverlappingAvatars extends StatelessWidget {
  /// The list of participants to display
  final List<TripParticipant> participants;

  /// Maximum number of avatars to show before using +X indicator
  final int maxVisibleAvatars;

  /// Size of each avatar
  final double avatarSize;

  /// How much each avatar should overlap the previous one (in pixels)
  final double overlap;

  /// Background color for the +X indicator and default avatar color
  final Color? backgroundColor;

  /// Whether to show a clickable style with hover effect
  final bool clickable;

  /// Callback for when the avatars are tapped
  final VoidCallback? onTap;

  const OverlappingAvatars({
    super.key,
    required this.participants,
    this.maxVisibleAvatars = 3,
    this.avatarSize = 32.0,
    this.overlap = 12.0,
    this.backgroundColor,
    this.clickable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBackgroundColor = backgroundColor ?? Colors.grey.shade400;
    const double borderWidth = 2.0;
    // If no participants, return empty container
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate total width based on visible avatars and overlap
    final int visibleCount =
        participants.length > maxVisibleAvatars
            ? maxVisibleAvatars +
                1 // +1 for the +X avatar
            : participants.length;
    // Add borderWidth * 2 for both sides, plus extra padding to prevent clipping
    final double totalWidth =
        avatarSize +
        (visibleCount - 1) * (avatarSize - overlap) +
        borderWidth * 2 +
        8;
    // Add extra height to prevent bottom clipping
    final double totalHeight = avatarSize + borderWidth * 2 + 8;

    // Create the base widget
    Widget avatarStack = Stack(
      alignment: Alignment.topLeft,
      clipBehavior: Clip.none, // Don't clip children
      children: _buildAvatarStack(defaultBackgroundColor, context, borderWidth),
    );

    // Add clickable styling if needed
    if (clickable || onTap != null) {
      avatarStack = InkWell(
        onTap: onTap,
        customBorder: CircleBorder(),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Semantics(
            button: true,
            hint: 'Manage trip participants',
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(avatarSize / 2 + 4),
              ),
              child: avatarStack,
            ),
          ),
        ),
      );
    }

    // Use a container with margin to prevent clipping
    return Container(
      margin: const EdgeInsets.all(2.0),
      width: totalWidth,
      height: totalHeight,
      child: avatarStack,
    );
  }

  List<Widget> _buildAvatarStack(
    Color defaultBackgroundColor,
    BuildContext context,
    double borderWidth,
  ) {
    final List<Widget> avatarWidgets = [];
    final int actualParticipants = participants.length;
    final int visibleParticipants =
        actualParticipants > maxVisibleAvatars
            ? maxVisibleAvatars
            : actualParticipants;

    // Add visible participant avatars
    for (int i = 0; i < visibleParticipants; i++) {
      final participant = participants[i];
      avatarWidgets.add(
        Positioned(
          left: i * (avatarSize - overlap),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: borderWidth,
              ),
            ),
            child: ProfilePictureWidget(
              photoUrl: _getParticipantPhotoUrl(participant),
              username: participant.username,
              size: avatarSize,
              backgroundColor: defaultBackgroundColor,
            ),
          ),
        ),
      );
    }

    // Add +X indicator if there are more participants than shown
    if (actualParticipants > maxVisibleAvatars) {
      final remaining = actualParticipants - maxVisibleAvatars;
      avatarWidgets.add(
        Positioned(
          left: maxVisibleAvatars * (avatarSize - overlap),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: borderWidth,
              ),
            ),
            child: CircleAvatar(
              radius: avatarSize / 2,
              backgroundColor: defaultBackgroundColor,
              child: Text(
                '+$remaining',
                style: TextStyle(
                  fontSize: avatarSize * 0.35,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return avatarWidgets;
  }

  // Helper method to get the correct photo URL from participant
  String? _getParticipantPhotoUrl(TripParticipant participant) {
    // First try photoUrl (lowercase)
    if (participant.photoUrl != null && participant.photoUrl!.isNotEmpty) {
      return participant.photoUrl;
    }

    // Check if there's additional data in extraInfo map
    if (participant is Map<String, dynamic>) {
      final Map<String, dynamic> map = participant as Map<String, dynamic>;
      // Try common keys for Firebase Storage URLs
      if (map['photoURL'] != null && map['photoURL'].toString().isNotEmpty) {
        return map['photoURL'];
      }
      if (map['profilePictureUrl'] != null &&
          map['profilePictureUrl'].toString().isNotEmpty) {
        return map['profilePictureUrl'];
      }
    }

    // No valid URL found
    return null;
  }
}
