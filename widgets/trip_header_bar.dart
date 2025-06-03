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
  Widget? _cachedParticipantAvatars;
  List<TripParticipant>? _cachedParticipantsList;

  @override
  void initState() {
    super.initState();
    _updateParticipantAvatarsCacheIfNeeded();
  }

  @override
  void didUpdateWidget(TripHeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    _updateParticipantAvatarsCacheIfNeeded(oldWidget.trip.participants);
  }

  void _updateParticipantAvatarsCacheIfNeeded([
    List<TripParticipant>? oldParticipants,
  ]) {
    if (_cachedParticipantAvatars == null ||
        !identical(widget.trip.participants, _cachedParticipantsList)) {
      setState(() {
        _cachedParticipantsList = widget.trip.participants;
        _cachedParticipantAvatars = _buildParticipantAvatars();
        debugPrint("Rebuilding participant avatars cache.");
      });
    }
  }

  Widget _buildParticipantAvatars() {
    debugPrint("Executing _buildParticipantAvatars()");

    double avatarSize = 38.0;
    if (widget.trip.name.length > 15) {
      avatarSize = 36.0;
    }
    if (widget.trip.name.length > 25) {
      avatarSize = 34.0;
    }

    return OverlappingAvatars(
      participants: widget.trip.participants,
      maxVisibleAvatars: 1,
      avatarSize: avatarSize,
      overlap: 12.0,
      backgroundColor: Colors.grey.shade400,
      clickable: true,
      onTap: () => _showParticipantsModal(context),
    );
  }

  void _showParticipantsModal(BuildContext context) async {
    final result = await showParticipantsListModal(
      context: context,
      trip: widget.trip,
    );

    if (result == true) {
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

    _cachedParticipantAvatars ??= _buildParticipantAvatars();

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
        padding: EdgeInsets.only(left: 16.0, top: topPadding),
        child: _cachedParticipantAvatars!,
      ),
      title: Padding(
        padding: EdgeInsets.only(top: topPadding - 2.0),
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
