import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math'; // Import for min function

class DurationSelectorWidget extends StatefulWidget {
  final int initialDurationMinutes;
  final ValueChanged<int> onDurationChanged;
  final int minuteInterval;

  const DurationSelectorWidget({
    super.key,
    required this.initialDurationMinutes,
    required this.onDurationChanged,
    this.minuteInterval = 1,
  });

  @override
  State<DurationSelectorWidget> createState() => _DurationSelectorWidgetState();
}

class _DurationSelectorWidgetState extends State<DurationSelectorWidget> {
  final List<Map<String, dynamic>> _durationOptions = [
    {'minutes': 5, 'label': '5 min'},
    {'minutes': 10, 'label': '10 min'},
    {'minutes': 15, 'label': '15 min'},
    {'minutes': 30, 'label': '30 min'},
    {'minutes': 45, 'label': '45 min'},
    {'minutes': 60, 'label': '1 hour'},
    {'minutes': 90, 'label': '1h 30min'},
    {'minutes': 120, 'label': '2 hours'},
    {'minutes': 150, 'label': '2h 30min'},
    {'minutes': 180, 'label': '3 hours'},
    {'minutes': 150, 'label': '3h 30min'},
    {'minutes': 180, 'label': '4 hours'},
    {'minutes': 210, 'label': '4h 30min'},
    {'minutes': 240, 'label': '5 hours'},
    {'minutes': 270, 'label': '5h 30min'},
    {'minutes': 300, 'label': '6 hours'},
  ];

  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _findNearestIndex(widget.initialDurationMinutes);
  }

  int _findNearestIndex(int initialMinutes) {
    int closestIndex = 0;
    int minDifference =
        (initialMinutes - (_durationOptions[0]['minutes'] as int)).abs();

    for (int i = 1; i < _durationOptions.length; i++) {
      int difference =
          (initialMinutes - (_durationOptions[i]['minutes'] as int)).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestIndex = i;
      } else if (difference == minDifference) {}
    }
    if (initialMinutes < (_durationOptions.first['minutes'] as int)) return 0;
    if (initialMinutes > (_durationOptions.last['minutes'] as int))
      return _durationOptions.length - 1;

    return closestIndex;
  }

  @override
  void didUpdateWidget(DurationSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDurationMinutes != oldWidget.initialDurationMinutes) {
      int newIndex = _findNearestIndex(widget.initialDurationMinutes);
      if (newIndex != _selectedIndex) {
        setState(() {
          _selectedIndex = newIndex;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              _durationOptions.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, dynamic> option = entry.value;
                bool isSelected = index == _selectedIndex;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor:
                          isSelected ? Colors.green.withOpacity(0.2) : null,
                      side: BorderSide(
                        color: isSelected ? Colors.green : Colors.black,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                      widget.onDurationChanged(option['minutes'] as int);
                    },
                    child: Text(option['label'] as String),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}
