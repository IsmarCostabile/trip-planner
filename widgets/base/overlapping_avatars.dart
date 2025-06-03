import 'package:flutter/material.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/widgets/base/profile_picture.dart';

class OverlappingAvatars extends StatelessWidget {
  final List<TripParticipant> participants;
  final int maxVisibleAvatars;
  final double avatarSize;
  final double overlap;
  final Color? backgroundColor;
  final bool clickable;
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
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    final int visibleCount =
        participants.length > maxVisibleAvatars
            ? maxVisibleAvatars + 1
            : participants.length;
    final double totalWidth =
        avatarSize +
        (visibleCount - 1) * (avatarSize - overlap) +
        borderWidth * 2 +
        8;
    final double totalHeight = avatarSize + borderWidth * 2 + 8;

    Widget avatarStack = Stack(
      alignment: Alignment.topLeft,
      clipBehavior: Clip.none,
      children: _buildAvatarStack(defaultBackgroundColor, context, borderWidth),
    );

    if (clickable || onTap != null) {
      avatarStack = InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
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

  String? _getParticipantPhotoUrl(TripParticipant participant) {
    if (participant.photoUrl != null && participant.photoUrl!.isNotEmpty) {
      return participant.photoUrl;
    }

    if (participant is Map<String, dynamic>) {
      final Map<String, dynamic> map = participant as Map<String, dynamic>;
      if (map['photoURL'] != null && map['photoURL'].toString().isNotEmpty) {
        return map['photoURL'];
      }
      if (map['profilePictureUrl'] != null &&
          map['profilePictureUrl'].toString().isNotEmpty) {
        return map['profilePictureUrl'];
      }
    }

    return null;
  }
}
