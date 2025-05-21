import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_day.dart';

// Define a fixed width and height for all day items
const double _dayItemWidth = 45.0; // Adjusted uniform width
const double _dayItemHeight = 55.0; // Adjusted uniform height
// Remove centered constants as they are no longer needed
// const double _centeredDayItemWidth = 66.0;
// const double _centeredDayItemHeight = 66.0;

class DaySelector extends StatefulWidget {
  final Trip trip;
  final List<TripDay> tripDays;
  final int selectedDayIndex;
  final ValueChanged<int?> onDaySelected;

  const DaySelector({
    super.key,
    required this.trip,
    required this.tripDays,
    required this.selectedDayIndex,
    required this.onDaySelected,
  });

  @override
  State<DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<DaySelector> {
  late PageController _controller;
  bool _isProgrammaticScroll = false; // Flag to prevent update loops
  // Use a map to cache day widgets to avoid rebuilding them
  final Map<int, Widget> _dayWidgetCache = {};
  // Use a fixed viewportFraction to avoid re-creating controller
  final double _fixedViewportFraction =
      0.13; // Approximately _dayItemWidth / avg screen width

  // Only real trip days
  int get _totalDaysCount => widget.tripDays.length;

  // Add placeholders before and after
  int get _placeholderDaysCount => 6; // Number of placeholder days on each side
  int get _totalDisplayDaysCount =>
      _totalDaysCount + (_placeholderDaysCount * 2);

  // Convert between real index and display index
  int _realToDisplayIndex(int realIndex) => realIndex + _placeholderDaysCount;
  int _displayToRealIndex(int displayIndex) =>
      displayIndex - _placeholderDaysCount;

  @override
  void initState() {
    super.initState();
    // Create controller with fixed viewportFraction, but use the display index
    _controller = PageController(
      initialPage: _realToDisplayIndex(widget.selectedDayIndex),
      viewportFraction: _fixedViewportFraction,
      keepPage: true,
    );
  }

  @override
  void didUpdateWidget(DaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear cache if trip days change
    if (widget.trip.id != oldWidget.trip.id) {
      _dayWidgetCache.clear();
    }

    // If the selectedDayIndex changes, animate the controller
    if (widget.selectedDayIndex != oldWidget.selectedDayIndex &&
        _controller.hasClients) {
      final targetPage = _realToDisplayIndex(widget.selectedDayIndex);
      if (_controller.page?.round() != targetPage) {
        _isProgrammaticScroll = true;
        _controller
            .animateToPage(
              targetPage,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            )
            .then((_) {
              if (mounted) {
                setState(() {
                  _isProgrammaticScroll = false;
                });
              }
            });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dayWidgetCache.clear();
    super.dispose();
  }

  // Get the date for a specific display index (including placeholders)
  DateTime _getDateForDisplayIndex(int displayIndex) {
    final realIndex = _displayToRealIndex(displayIndex);
    return widget.trip.startDate.add(Duration(days: realIndex));
  }

  // Check if a display index represents a real trip day
  bool _isRealTripDay(int displayIndex) {
    final realIndex = _displayToRealIndex(displayIndex);
    return realIndex >= 0 && realIndex < widget.tripDays.length;
  }

  // Handle tapping on a day
  void _onDayTapped(int displayIndex) {
    if (_isRealTripDay(displayIndex)) {
      // Only allow selecting real trip days
      widget.onDaySelected(_displayToRealIndex(displayIndex));
    }
  }

  Widget _buildDayItem(BuildContext context, int displayIndex) {
    final theme = Theme.of(context);
    final isRealTripDay = _isRealTripDay(displayIndex);
    final realIndex = _displayToRealIndex(displayIndex);
    final isSelected = isRealTripDay && realIndex == widget.selectedDayIndex;

    // Get date for this position
    final date = _getDateForDisplayIndex(displayIndex);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayDate = DateTime(date.year, date.month, date.day);
    final isCurrentDay = dayDate.isAtSameMomentAs(today);
    final dayName = DateFormat('E').format(date); // e.g. 'Mon'
    final dayNumber = DateFormat('d').format(date); // e.g. '15'

    // Get the trip color or default to theme colors
    final tripColor = widget.trip.color ?? theme.colorScheme.primary;
    final selectedColor = tripColor;
    final currentDayColor = Colors.green;

    final dayItemWidget = GestureDetector(
      onTap: () => _onDayTapped(displayIndex),
      child: Opacity(
        opacity: isRealTripDay ? 1.0 : 0.3,
        // Replace AnimatedContainer with Container for fixed size
        child: Container(
          // Use fixed width and height
          width: _dayItemWidth,
          height: _dayItemHeight,
          padding: const EdgeInsets.symmetric(
            vertical: 6.0,
            horizontal: 4.0,
          ), // Adjusted padding
          margin: const EdgeInsets.symmetric(
            horizontal: 3.0,
          ), // Adjusted margin
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              10.0,
            ), // Slightly smaller radius
            border: Border.all(
              color:
                  isSelected
                      ? selectedColor
                      : isCurrentDay
                      ? currentDayColor
                      : isRealTripDay
                      ? theme.colorScheme.onSurface.withOpacity(
                        0.7,
                      ) // Slightly less prominent border
                      : theme.colorScheme.onSurface.withOpacity(0.2),
              width: isSelected ? 2.0 : 1.0,
            ),
            // Optional: Add background color change on selection
            color:
                isSelected
                    ? selectedColor.withOpacity(0.1)
                    : Colors.transparent,
          ),
          // Wrap the Column with FittedBox to prevent overflow with larger fonts
          child: FittedBox(
            fit: BoxFit.scaleDown, // Scale down the text if it overflows
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11, // Slightly smaller font
                    color:
                        isSelected
                            ? selectedColor
                            : isCurrentDay
                            ? currentDayColor
                            : isRealTripDay
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurfaceVariant.withOpacity(
                              0.3,
                            ),
                  ),
                ),
                const SizedBox(height: 2), // Add small spacing
                Text(
                  dayNumber,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: isSelected ? 14 : 13, // Adjusted font sizes
                    color:
                        isSelected
                            ? selectedColor
                            : isCurrentDay
                            ? currentDayColor
                            : isRealTripDay
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return dayItemWidget;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        // Adjust height based on the new fixed item height + padding
        height:
            _dayItemHeight +
            16.0, // _dayItemHeight + vertical padding (8.0 * 2)
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        color: Colors.white, // Set to white to match AppBar background
        // Wrap PageView in ExcludeSemantics to prevent excessive semantics processing
        child: ExcludeSemantics(
          child: PageView.builder(
            controller: _controller,
            itemCount: _totalDisplayDaysCount,
            onPageChanged: (int displayIndex) {
              if (_isProgrammaticScroll) return;
              if (_isRealTripDay(displayIndex)) {
                widget.onDaySelected(_displayToRealIndex(displayIndex));
              } else {
                // If scrolling to a placeholder, snap back to the nearest real day
                _isProgrammaticScroll = true;
                final targetPage =
                    displayIndex < _placeholderDaysCount
                        ? _placeholderDaysCount // First real day
                        : _placeholderDaysCount +
                            _totalDaysCount -
                            1; // Last real day

                _controller
                    .animateToPage(
                      targetPage,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                    )
                    .then((_) {
                      if (mounted) {
                        setState(() {
                          _isProgrammaticScroll = false;
                        });
                        // Notify about the real day selection
                        widget.onDaySelected(_displayToRealIndex(targetPage));
                      }
                    });
              }
            },
            physics: const BouncingScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padEnds: true,
            pageSnapping: true,
            itemBuilder:
                (context, index) =>
                    Center(child: _buildDayItem(context, index)),
          ),
        ),
      ),
    );
  }
}
