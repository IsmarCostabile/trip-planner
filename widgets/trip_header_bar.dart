import 'package:flutter/material.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/widgets/highlighted_text.dart';
import 'package:trip_planner/widgets/base/overlapping_avatars.dart';
import 'package:trip_planner/widgets/modals/edit_participants_list_modal.dart';

class TripHeaderBar extends StatefulWidget implements PreferredSizeWidget {
  final Trip trip;
  final List<Widget>? actions;

  const TripHeaderBar({super.key, required this.trip, this.actions});

  @override
  State<TripHeaderBar> createState() => _TripHeaderBarState();

  @override
  Size get preferredSize {
    // Adjust height based on title length
    double height = kToolbarHeight;
    if (trip.name.length > 15) {
      height = kToolbarHeight - 4.0;
    }
    if (trip.name.length > 25) {
      height = kToolbarHeight - 8.0;
    }
    return Size.fromHeight(height);
  }
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

    // Scale avatar size based on trip name length for better proportions
    double avatarSize = 38.0;
    if (widget.trip.name.length > 15) {
      avatarSize = 36.0;
    }
    if (widget.trip.name.length > 25) {
      avatarSize = 34.0;
    }

    return OverlappingAvatars(
      participants: widget.trip.participants,
      maxVisibleAvatars: 2,
      avatarSize: avatarSize,
      overlap: 12.0,
      backgroundColor: Colors.grey.shade400,
      clickable: true, // Make it appear clickable
      onTap: () => _showParticipantsModal(context),
    );
  }

  // Method to show the participants management modal
  void _showParticipantsModal(BuildContext context) async {
    final result = await showParticipantsListModal(
      context: context,
      trip: widget.trip,
    );

    if (result == true) {
      // Participant changes were saved, update the cache
      setState(() {
        _cachedParticipantsList = null;
        _cachedParticipantAvatars = null;
      });
      _updateParticipantAvatarsCacheIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripColor = widget.trip.color ?? theme.colorScheme.primary;

    // Ensure cache is built if it's somehow null
    _cachedParticipantAvatars ??= _buildParticipantAvatars();

    // Calculate font size based on text length
    double fontSize = 28.0;
    double topPadding = 4.0;
    double toolbarHeight = kToolbarHeight;

    if (widget.trip.name.length > 15) {
      fontSize = 24.0;
      topPadding = 3.0;
      toolbarHeight = kToolbarHeight - 4.0;
    }
    if (widget.trip.name.length > 25) {
      fontSize = 20.0;
      topPadding = 2.0;
      toolbarHeight = kToolbarHeight - 8.0;
    }

    return AppBar(
      toolbarHeight: toolbarHeight,
      leading: Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          top: topPadding,
        ), // Adjust top padding based on size
        // Use the cached widget here with onTap handler
        child: _cachedParticipantAvatars!,
      ),
      title: Padding(
        padding: EdgeInsets.only(
          top: topPadding - 2.0,
        ), // Adjust vertical alignment to match leading
        child: HighlightedText(
          text: widget.trip.name,
          highlightColor: tripColor,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            color: Colors.black,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      actions: widget.actions,
    );
  }
}
