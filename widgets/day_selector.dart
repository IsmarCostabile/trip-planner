import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_day.dart';

const double _dayItemWidth = 45.0;
const double _dayItemHeight = 55.0;

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
  bool _isProgrammaticScroll = false;
  final Map<int, Widget> _dayWidgetCache = {};
  final double _fixedViewportFraction = 0.13;

  int get _totalDaysCount => widget.tripDays.length;

  int get _placeholderDaysCount => 6;
  int get _totalDisplayDaysCount =>
      _totalDaysCount + (_placeholderDaysCount * 2);

  int _realToDisplayIndex(int realIndex) => realIndex + _placeholderDaysCount;
  int _displayToRealIndex(int displayIndex) =>
      displayIndex - _placeholderDaysCount;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _realToDisplayIndex(widget.selectedDayIndex),
      viewportFraction: _fixedViewportFraction,
      keepPage: true,
    );
  }

  @override
  void didUpdateWidget(DaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.trip.id != oldWidget.trip.id) {
      _dayWidgetCache.clear();
    }

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

  DateTime _getDateForDisplayIndex(int displayIndex) {
    final realIndex = _displayToRealIndex(displayIndex);
    return widget.trip.startDate.add(Duration(days: realIndex));
  }

  bool _isRealTripDay(int displayIndex) {
    final realIndex = _displayToRealIndex(displayIndex);
    return realIndex >= 0 && realIndex < widget.tripDays.length;
  }

  void _onDayTapped(int displayIndex) {
    if (_isRealTripDay(displayIndex)) {
      widget.onDaySelected(_displayToRealIndex(displayIndex));
    }
  }

  Widget _buildDayItem(BuildContext context, int displayIndex) {
    final theme = Theme.of(context);
    final isRealTripDay = _isRealTripDay(displayIndex);
    final realIndex = _displayToRealIndex(displayIndex);
    final isSelected = isRealTripDay && realIndex == widget.selectedDayIndex;

    final date = _getDateForDisplayIndex(displayIndex);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayDate = DateTime(date.year, date.month, date.day);
    final isCurrentDay = dayDate.isAtSameMomentAs(today);
    final dayName = DateFormat('E').format(date);
    final dayNumber = DateFormat('d').format(date);

    final tripColor = widget.trip.color ?? theme.colorScheme.primary;
    final selectedColor = tripColor;
    final currentDayColor = Colors.green;

    final dayItemWidget = GestureDetector(
      onTap: () => _onDayTapped(displayIndex),
      child: Opacity(
        opacity: isRealTripDay ? 1.0 : 0.3,
        child: Container(
          width: _dayItemWidth,
          height: _dayItemHeight,
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          margin: const EdgeInsets.symmetric(horizontal: 3.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color:
                  isSelected
                      ? selectedColor
                      : isCurrentDay
                      ? currentDayColor
                      : isRealTripDay
                      ? theme.colorScheme.onSurface.withOpacity(0.7)
                      : theme.colorScheme.onSurface.withOpacity(0.2),
              width: isSelected ? 2.0 : 1.0,
            ),
            color:
                isSelected
                    ? selectedColor.withOpacity(0.1)
                    : Colors.transparent,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
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
                const SizedBox(height: 2),
                Text(
                  dayNumber,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: isSelected ? 14 : 13,
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
        height: _dayItemHeight + 16.0,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        color: Colors.white,
        child: ExcludeSemantics(
          child: PageView.builder(
            controller: _controller,
            itemCount: _totalDisplayDaysCount,
            onPageChanged: (int displayIndex) {
              if (_isProgrammaticScroll) return;
              if (_isRealTripDay(displayIndex)) {
                widget.onDaySelected(_displayToRealIndex(displayIndex));
              } else {
                _isProgrammaticScroll = true;
                final targetPage =
                    displayIndex < _placeholderDaysCount
                        ? _placeholderDaysCount
                        : _placeholderDaysCount + _totalDaysCount - 1;

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
