import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TimePickerWidget extends StatefulWidget {
  final TimeOfDay initialTime;
  final int minuteInterval;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const TimePickerWidget({
    super.key,
    required this.initialTime,
    this.minuteInterval = 1,
    required this.onTimeChanged,
  });

  @override
  State<TimePickerWidget> createState() => _TimePickerWidgetState();
}

class _TimePickerWidgetState extends State<TimePickerWidget> {
  late Duration _currentTimerDuration;

  @override
  void initState() {
    super.initState();
    _currentTimerDuration = Duration(
      hours: widget.initialTime.hour,
      minutes: widget.initialTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: CupertinoTimerPicker(
        mode: CupertinoTimerPickerMode.hm,
        initialTimerDuration: _currentTimerDuration,
        minuteInterval: widget.minuteInterval,
        onTimerDurationChanged: (Duration newDuration) {
          // Update internal state for the picker itself
          setState(() {
            _currentTimerDuration = newDuration;
          });
          // Notify the parent widget
          widget.onTimeChanged(
            TimeOfDay(
              hour: newDuration.inHours % 24,
              minute: newDuration.inMinutes % 60,
            ),
          );
        },
      ),
    );
  }
}
