import 'package:flutter/material.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/widgets/highlighted_text.dart';
import 'package:trip_planner/widgets/base/overlapping_avatars.dart';

class TripHeaderBar extends StatefulWidget implements PreferredSizeWidget {
  final Trip trip;
  final List<Widget>? actions;

  const TripHeaderBar({super.key, required this.trip, this.actions});

  @override
  State<TripHeaderBar> createState() => _TripHeaderBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _TripHeaderBarState extends State<TripHeaderBar> {
  // Cache the participant avatars widget
  Widget? _cachedParticipantAvatars;
  // Store the participant list used to build the cache
  List<TripParticipant>? _cachedParticipantsList;

  @override
  void initState() {
    super.initState();
    _updateParticipantAvatarsCacheIfNeeded();
  }

  @override
  void didUpdateWidget(TripHeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Rebuild avatar cache if participants change
    _updateParticipantAvatarsCacheIfNeeded(oldWidget.trip.participants);
  }

  // Method to build or rebuild the avatar cache if participants changed
  void _updateParticipantAvatarsCacheIfNeeded([
    List<TripParticipant>? oldParticipants,
  ]) {
    // Use identical check for performance if list instance hasn't changed
    if (_cachedParticipantAvatars == null ||
        !identical(widget.trip.participants, _cachedParticipantsList)) {
      // If not identical, do a deep comparison (optional, but safer if list content might change without instance changing)
      // For simplicity, we'll rebuild if the instance is different or null.
      // A more robust check might involve comparing participant UIDs or list length.
      setState(() {
        _cachedParticipantsList = widget.trip.participants;
        _cachedParticipantAvatars = _buildParticipantAvatars();
        // Add debug print to confirm cache rebuild
        debugPrint("Rebuilding participant avatars cache.");
      });
    }
  }

  // Builds the actual OverlappingAvatars widget
  Widget _buildParticipantAvatars() {
    // Add debug print to see when this expensive build happens
    debugPrint("Executing _buildParticipantAvatars()");
    return OverlappingAvatars(
      participants: widget.trip.participants,
      maxVisibleAvatars: 3,
      avatarSize: 42.0,
      overlap: 12.0,
      backgroundColor: Colors.grey.shade400,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripColor = widget.trip.color ?? theme.colorScheme.primary;

    // Ensure cache is built if it's somehow null
    _cachedParticipantAvatars ??= _buildParticipantAvatars();

    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        // Use the cached widget here
        child: _cachedParticipantAvatars!,
      ),
      title: Padding(
        padding: const EdgeInsets.only(bottom: 0.0), // Move title up
        child: HighlightedText(
          text: widget.trip.name,
          highlightColor: tripColor,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 28,
            color: Colors.black,
          ),
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      actions: widget.actions,
    );
  }
}
