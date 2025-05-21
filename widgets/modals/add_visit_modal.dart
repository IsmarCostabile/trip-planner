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
// Add missing imports for Provider and TripDataService
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

  /// Helper method to show the modal with consistent styling
  static Future<void> show({
    required BuildContext context,
    required PlacesSearchResult place,
    required Trip trip,
    required TripDay tripDay,
  }) {
    // Get the TripDataService before showing modal
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    return showAppModal(
      context: context,
      builder:
          (modalContext) => ChangeNotifierProvider.value(
            // Changed from Provider.value
            // Provide the same instance but in an isolated context
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

  late TimeOfDay _selectedTime; // Make it late
  int _selectedDuration = 5; // Default duration in minutes

  final uuid = Uuid();

  final int _minuteInterval = 5; // Define interval for reuse

  @override
  void initState() {
    super.initState();
    // Adjust initial time to be a multiple of the interval
    final now = TimeOfDay.now();
    _selectedTime = TimeOfDay(
      hour: now.hour,
      minute: (now.minute ~/ _minuteInterval) * _minuteInterval, // Round down
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<Visit> _createVisit(DateTime visitDateTime) async {
    final visitId = uuid.v4();

    // Create a Location object from place details
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

      // Use Provider to save the visit
      final tripDataService = Provider.of<TripDataService>(
        context,
        listen: false,
      );
      await tripDataService.addVisit(widget.tripDay.id, newVisit);

      // Pop and return success without rebuilding everything
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
    // Replace ListView with Column as BaseModal will handle scrolling
    return Column(
      mainAxisSize:
          MainAxisSize.min, // Prevent Column from expanding unnecessarily
      crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add padding
          child: Text(
            'Select Time:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add padding
          // Use the new TimePickerWidget
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add padding
          child: Text(
            'Select Duration (minutes):',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add padding
          // Use the new DurationSelectorWidget
          child: DurationSelectorWidget(
            initialDurationMinutes: _selectedDuration,
            onDurationChanged: (value) {
              setState(() {
                _selectedDuration = value;
              });
            },
          ),
        ),
        const SizedBox(height: 16), // Add some padding at the bottom
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
        // Remove isScrollable: false to use default scrollable behavior
        // Adjust sizes to better fit the content
        initialChildSize: 0.5, // Slightly larger to accommodate padding/content
        minChildSize: 0.4,
        maxChildSize: 0.7, // Allow slightly more expansion if needed
        footer: _buildFooter(),
        child: _buildContent(),
      ),
    );
  }
}
