import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trip_planner/models/visit.dart';
import 'package:trip_planner/widgets/base/base_modal.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/user_data_service.dart';
import 'package:trip_planner/services/trip_data_service.dart';

class EditVisitTimeModal extends StatefulWidget {
  final Visit visit;
  final Function(DateTime newStartTime, DateTime newEndTime) onSave;

  const EditVisitTimeModal({
    super.key,
    required this.visit,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required Visit visit,
    required Function(DateTime newStartTime, DateTime newEndTime) onSave,
  }) async {
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    return showAppModal(
      context: context,
      builder:
          (context) => ChangeNotifierProvider.value(
            value: tripDataService,
            child: EditVisitTimeModal(visit: visit, onSave: onSave),
          ),
    );
  }

  @override
  State<EditVisitTimeModal> createState() => _EditVisitTimeModalState();
}

class _EditVisitTimeModalState extends State<EditVisitTimeModal> {
  late DateTime _selectedStartTime;
  late DateTime _selectedEndTime;
  late bool _use24HourFormat;

  @override
  void initState() {
    super.initState();
    _selectedStartTime = widget.visit.visitTime;
    _selectedEndTime = widget.visit.visitEndTime;

    if (_selectedEndTime.isBefore(_selectedStartTime) ||
        _selectedEndTime.isAtSameMomentAs(_selectedStartTime)) {
      _selectedEndTime = _selectedStartTime.add(const Duration(minutes: 1));
    }

    _loadTimeFormatPreference();
  }

  void _loadTimeFormatPreference() {
    final box = Hive.box('userBox');
    final timeFormat = box.get('timeFormat', defaultValue: '24h');
    _use24HourFormat = timeFormat == '24h';
  }

  DateTime _combineDateAndTime(DateTime datePart, DateTime timePart) {
    return DateTime(
      datePart.year,
      datePart.month,
      datePart.day,
      timePart.hour,
      timePart.minute,
    );
  }

  Widget _buildTimePicker({
    required DateTime initialTime,
    required ValueChanged<DateTime> onTimeChanged,
    required bool use24HourFormat,
    required ThemeData theme,
  }) {
    return SizedBox(
      height: 120,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: initialTime,
        use24hFormat: use24HourFormat,
        onDateTimeChanged: onTimeChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userDataService = Provider.of<UserDataService>(context);
    final userPreferences = userDataService.preferences;
    final userTimeFormat = userPreferences['timeFormat'] ?? 'unknown';

    if (userTimeFormat != 'unknown') {
      _use24HourFormat = userTimeFormat == '24h';
    }

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          final startTimeChanged = _selectedStartTime != widget.visit.visitTime;
          final endTimeChanged = _selectedEndTime != widget.visit.visitEndTime;

          if (startTimeChanged || endTimeChanged) {
            if (_selectedEndTime.isBefore(_selectedStartTime)) {
              if (_selectedEndTime.day != _selectedStartTime.day) {
                _saveChanges();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('End time cannot be before start time.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } else {
              _saveChanges();
            }
          }
        }
      },
      child: BaseModal(
        initialChildSize: 0.35,
        minChildSize: 0.3,
        maxChildSize: 0.4,
        title: 'Edit Visit Time',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('Start', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        _buildTimePicker(
                          initialTime: _selectedStartTime,
                          onTimeChanged: (newTime) {
                            setState(() {
                              final newStartTime = _combineDateAndTime(
                                widget.visit.visitTime,
                                newTime,
                              );
                              _selectedStartTime = newStartTime;

                              if (_selectedEndTime.isBefore(
                                newStartTime.add(const Duration(minutes: 1)),
                              )) {
                                _selectedEndTime = newStartTime.add(
                                  const Duration(minutes: 1),
                                );
                              }
                            });
                          },
                          use24HourFormat: _use24HourFormat,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        Text('End', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 120,
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            initialDateTime: _selectedEndTime,
                            minimumDate: _selectedStartTime.add(
                              const Duration(minutes: 1),
                            ),
                            use24hFormat: _use24HourFormat,
                            onDateTimeChanged: (newTime) {
                              setState(() {
                                DateTime combinedTime = _combineDateAndTime(
                                  widget.visit.visitEndTime,
                                  newTime,
                                );

                                final minEndTime = _selectedStartTime.add(
                                  const Duration(minutes: 1),
                                );
                                if (combinedTime.isBefore(minEndTime)) {
                                  combinedTime = minEndTime;
                                }

                                _selectedEndTime = combinedTime;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveChanges() {
    widget.onSave(_selectedStartTime, _selectedEndTime);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final tripDataService = Provider.of<TripDataService>(
          context,
          listen: false,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          tripDataService.notifyListeners();
        });
      } catch (e) {
        debugPrint('Error notifying listeners: $e');
      }
    });
  }
}
