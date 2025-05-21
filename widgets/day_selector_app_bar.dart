import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_day.dart';
import 'package:trip_planner/widgets/highlighted_text.dart';
import 'package:trip_planner/widgets/base/profile_picture.dart';
import 'package:trip_planner/widgets/base/overlapping_avatars.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/widgets/trip_header_bar.dart';
import 'package:trip_planner/widgets/day_selector.dart';

// Define a fixed width for each day item for easier calculation
const double _dayItemWidth = 42.0; // Smaller
const double _dayItemHeight = 58.0; // Smaller
const double _centeredDayItemWidth = 58.0; // Smaller for selected
const double _centeredDayItemHeight = 58.0; // Smaller for selected
// Define number of days to show before and after the trip
const int _extraDaysBefore = 5;
const int _extraDaysAfter = 5;

class DaySelectorAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Trip trip;
  final List<TripDay> tripDays;
  final int selectedDayIndex;
  final ValueChanged<int?> onDaySelected;
  final List<Widget>? actions;
  final bool showDaySelector; // Parameter to control day selector visibility

  const DaySelectorAppBar({
    super.key,
    required this.trip,
    required this.tripDays,
    required this.selectedDayIndex,
    required this.onDaySelected,
    this.actions,
    this.showDaySelector = true, // Default to true
  });

  @override
  State<DaySelectorAppBar> createState() => _DaySelectorAppBarState();

  @override
  Size get preferredSize {
    final double headerHeight = kToolbarHeight;
    // Update daySelectorHeight based on DaySelector's new fixed height
    final double daySelectorHeight =
        55.0 + 16.0; // _dayItemHeight + vertical padding

    return Size.fromHeight(
      headerHeight + (showDaySelector ? daySelectorHeight : 0),
    );
  }
}

class _DaySelectorAppBarState extends State<DaySelectorAppBar> {
  @override
  Widget build(BuildContext context) {
    // Create header bar
    final tripHeaderBar = TripHeaderBar(
      trip: widget.trip,
      actions: widget.actions,
    );

    // Use PreferredSize to create a custom-sized AppBar
    return PreferredSize(
      preferredSize: widget.preferredSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header section
          tripHeaderBar,

          // Day selector section (conditionally included)
          if (widget.showDaySelector)
            SizedBox(
              // Update height to match DaySelector's new height
              height: 55.0 + 16.0, // _dayItemHeight + vertical padding
              child: DaySelector(
                trip: widget.trip,
                tripDays: widget.tripDays,
                selectedDayIndex: widget.selectedDayIndex,
                onDaySelected: widget.onDaySelected,
              ),
            ),
        ],
      ),
    );
  }
}
