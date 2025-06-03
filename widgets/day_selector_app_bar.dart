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

const double _dayItemWidth = 42.0;
const double _dayItemHeight = 58.0;
const double _centeredDayItemWidth = 58.0;
const double _centeredDayItemHeight = 58.0;
const int _extraDaysBefore = 5;
const int _extraDaysAfter = 5;

class DaySelectorAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Trip trip;
  final List<TripDay> tripDays;
  final int selectedDayIndex;
  final ValueChanged<int?> onDaySelected;
  final List<Widget>? actions;
  final bool showDaySelector;

  const DaySelectorAppBar({
    super.key,
    required this.trip,
    required this.tripDays,
    required this.selectedDayIndex,
    required this.onDaySelected,
    this.actions,
    this.showDaySelector = true,
  });

  @override
  State<DaySelectorAppBar> createState() => _DaySelectorAppBarState();

  @override
  Size get preferredSize {
    final double headerHeight = kToolbarHeight;
    final double daySelectorHeight = 55.0 + 16.0;

    return Size.fromHeight(
      headerHeight + (showDaySelector ? daySelectorHeight : 0),
    );
  }
}

class _DaySelectorAppBarState extends State<DaySelectorAppBar> {
  @override
  Widget build(BuildContext context) {
    final tripHeaderBar = TripHeaderBar(
      trip: widget.trip,
      actions: widget.actions,
    );

    return PreferredSize(
      preferredSize: widget.preferredSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tripHeaderBar,
          if (widget.showDaySelector)
            SizedBox(
              height: 55.0 + 16.0,
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
