import 'package:flutter/material.dart';
import 'package:google_maps_webservice/places.dart' hide Location;
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_day.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for GeoPoint
import 'package:trip_planner/models/visit.dart';
import 'package:trip_planner/models/location.dart';
import 'package:uuid/uuid.dart';
import 'package:trip_planner/widgets/base/base_modal.dart';
import 'package:trip_planner/widgets/pickers/time_picker_widget.dart';
import 'package:trip_planner/widgets/pickers/duration_selector_widget.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/widgets/modals/button_tray.dart';

class AddVisitModal extends StatefulWidget {
  final PlacesSearchResult place;
  final Trip trip;
  final TripDay tripDay;

  const AddVisitModal({
    super.key,
    required this.place,
    required this.trip,
    required this.tripDay,
  });

  static Future<void> show({
    required BuildContext context,
    required PlacesSearchResult place,
    required Trip trip,
    required TripDay tripDay,
  }) {
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    return showAppModal(
      context: context,
      builder:
          (modalContext) => ChangeNotifierProvider.value(
            value: tripDataService,
            child: AddVisitModal(place: place, trip: trip, tripDay: tripDay),
          ),
    );
  }

  @override
  State<AddVisitModal> createState() => _AddVisitModalState();
}

class _AddVisitModalState extends State<AddVisitModal> {
  bool _isSaving = false;

  late TimeOfDay _selectedTime;
  int _selectedDuration = 5;

  final uuid = Uuid();

  final int _minuteInterval = 5;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _selectedTime = TimeOfDay(
      hour: now.hour,
      minute: (now.minute ~/ _minuteInterval) * _minuteInterval,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<Visit> _createVisit(DateTime visitDateTime) async {
    final visitId = uuid.v4();

    final location = Location(
      id: widget.place.placeId,
      name: widget.place.name,
      coordinates: GeoPoint(
        widget.place.geometry?.location.lat ?? 0,
        widget.place.geometry?.location.lng ?? 0,
      ),
      placeId: widget.place.placeId,
      address: widget.place.formattedAddress,
    );

    return Visit(
      id: visitId,
      locationId: widget.place.placeId,
      location: location,
      visitTime: visitDateTime,
      visitDuration: _selectedDuration,
    );
  }

  Future<void> _saveVisit() async {
    setState(() => _isSaving = true);

    try {
      final visitDateTime = DateTime(
        widget.tripDay.date.year,
        widget.tripDay.date.month,
        widget.tripDay.date.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final newVisit = await _createVisit(visitDateTime);

      final tripDataService = Provider.of<TripDataService>(
        context,
        listen: false,
      );
      await tripDataService.addVisit(widget.tripDay.id, newVisit);

      Navigator.of(context).pop({'result': 'success', 'visit': newVisit});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding visit: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Select Time:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TimePickerWidget(
            initialTime: _selectedTime,
            minuteInterval: _minuteInterval,
            onTimeChanged: (newTime) {
              setState(() {
                _selectedTime = newTime;
              });
            },
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Select Duration (minutes):',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DurationSelectorWidget(
            initialDurationMinutes: _selectedDuration,
            onDurationChanged: (value) {
              setState(() {
                _selectedDuration = value;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFooter() {
    return ButtonTray(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      secondaryButton: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.red.withOpacity(0.5),
          side: const BorderSide(color: Colors.black),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text('CANCEL'),
      ),
      primaryButton: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.green.withOpacity(0.6),
          side: const BorderSide(color: Colors.black),
        ),
        onPressed: _isSaving ? null : _saveVisit,
        child:
            _isSaving
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Text('ADD TO ITINERARY'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: BaseModal(
        title: 'Add Visit to ${widget.place.name}',
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.7,
        footer: _buildFooter(),
        child: _buildContent(),
      ),
    );
  }
}
