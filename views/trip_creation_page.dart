import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/models/location.dart';
import 'package:trip_planner/models/trip_destination.dart';
import 'package:trip_planner/services/places_service.dart';
import 'package:trip_planner/services/trip_invitation_service.dart';
import 'package:trip_planner/widgets/trip_participants_list.dart';
import 'package:google_maps_webservice/places.dart' hide Location;
import 'package:provider/provider.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/widgets/modals/button_tray.dart';
import 'package:intl/intl.dart';

// Renamed class
class TripCreationPage extends StatefulWidget {
  const TripCreationPage({super.key});

  // Updated show method to navigate to a full page
  static Future<bool?> show({required BuildContext context}) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const TripCreationPage(),
        fullscreenDialog: true, // Present as a full-screen dialog
      ),
    );
  }

  @override
  // Renamed state class
  State<TripCreationPage> createState() => _TripCreationPageState();
}

// Renamed state class
class _TripCreationPageState extends State<TripCreationPage> {
  // ... existing state variables ...
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  // Updated total steps since we're combining description and color selection with the first step
  final int _totalSteps = 2; // Combined details step + Participants

  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _destinationController = TextEditingController();

  // State
  final PlacesService _placesService = PlacesService();
  DateTime? _startDate;
  DateTime? _endDate;
  List<TripParticipant> _participants = [];
  bool _isLoading = false;
  Location? _destination;
  List<PlacesSearchResult> _destinationSuggestions = [];
  bool _searchingDestination = false;
  Color _selectedColor = Colors.blue; // Default color

  // Updated color palette to use custom CSS HEX colors
  final List<Color> _colorPalette = [
    const Color(0xFFFBB13C), // Hunyadi Yellow
    const Color(0xFF1098F7), // Dodger Blue
    const Color(0xFFFB3640), // Imperial Red
    const Color(0xFF0CCE6B), // Emerald
    const Color(0xFFFF47DA), // Purple Pizzazz
  ];

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    if (user == null) return;
    final initialUsername = user!.email?.split('@')[0] ?? 'Me';
    final currentUserParticipant = TripParticipant(
      uid: user!.uid,
      username: initialUsername,
      email: user!.email,
      photoUrl: user!.photoURL, // Include photoURL from Firebase Auth
    );
    if (!mounted) return;
    setState(() {
      _participants = [currentUserParticipant];
    });

    try {
      final userData =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get();
      if (userData.exists && mounted) {
        final data = userData.data()!;
        final username =
            data['username']?.isNotEmpty == true
                ? data['username']
                : initialUsername;

        // Get photoURL from Firestore (which may be more up-to-date than Auth)
        final photoURL = data['photoURL'] ?? user!.photoURL;

        setState(() {
          _participants[0] = TripParticipant(
            uid: user!.uid,
            username: username,
            email: user!.email,
            photoUrl: photoURL, // Include the photoURL
          );
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error loading user data for trip creation: $e');
      }
    }
  }

  // Updated to use showDateRangePicker with custom theme
  Future<void> _selectDateRange(BuildContext context) async {
    final theme = Theme.of(context); // Get current theme
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          _startDate != null && _endDate != null
              ? DateTimeRange(start: _startDate!, end: _endDate!)
              : null,
      firstDate: DateTime.now().subtract(
        const Duration(days: 1),
      ), // Allow today
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      // Add builder for theming
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            // Customize date picker theme here
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor, // Use app's primary color
              onPrimary: Colors.white, // Text on primary color
              surface: theme.dialogBackgroundColor, // Background
              onSurface: theme.textTheme.bodyLarge?.color, // Text color
            ),
            dialogBackgroundColor: theme.dialogBackgroundColor,
            buttonTheme: ButtonThemeData(
              textTheme:
                  ButtonTextTheme.primary, // Use primary color for buttons
              colorScheme: theme.colorScheme.copyWith(
                primary: theme.primaryColor,
              ),
            ),
            // Optional: Customize text button style if needed
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.primaryColor, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // Removed _selectStartDate and _selectEndDate

  Future<void> _searchDestinations(String query) async {
    if (query.isEmpty) {
      setState(() => _destinationSuggestions = []);
      return;
    }
    setState(() => _searchingDestination = true);
    try {
      final predictions = await _placesService.getPlaceSuggestions(
        query,
        context: context,
      );
      if (!mounted) return;

      // Convert predictions to list of Futures first
      final placeDetailsFutures = predictions
          .where((prediction) => prediction.placeId != null)
          .map(
            (prediction) => _placesService.getPlaceDetails(
              prediction.placeId!,
              context: context,
            ),
          );

      // Wait for all futures to complete
      final placeDetailsResults = await Future.wait(placeDetailsFutures);

      if (mounted) {
        setState(() {
          _destinationSuggestions =
              placeDetailsResults
                  .where((details) => details != null)
                  .map(
                    (details) => PlacesSearchResult(
                      placeId: details!.result.placeId,
                      name: details.result.name,
                      formattedAddress: details.result.formattedAddress,
                      geometry: details.result.geometry,
                      reference:
                          details.result.reference ?? details.result.placeId,
                    ),
                  )
                  .toList();
          _searchingDestination = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searchingDestination = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching: $e')));
      }
    }
  }

  void _selectDestination(PlacesSearchResult place) {
    setState(() {
      _destination = Location(
        id: place.placeId,
        name: place.name,
        placeId: place.placeId,
        address: place.formattedAddress,
        coordinates: GeoPoint(
          place.geometry?.location.lat ?? 0,
          place.geometry?.location.lng ?? 0,
        ),
      );
      _destinationController.text = place.name;
      _destinationSuggestions = [];
    });
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
  }

  void _clearDestination() {
    setState(() {
      _destination = null;
      _destinationController.text = '';
      _destinationSuggestions = [];
    });
  }

  Future<void> _saveTrip() async {
    // Final validation before saving
    if (!_formKey.currentState!.validate()) return;
    // Date validation moved to step 0 check in _nextStep
    // Destination validation moved to step 0 check in _nextStep

    // Capture context before async operations
    final currentContext = context;

    setState(() => _isLoading = true);

    try {
      final tripRef = FirebaseFirestore.instance.collection('trips').doc();
      final tripId = tripRef.id;

      // Create the initial TripDestination from the selected destination and dates
      final initialDestination = TripDestination(
        location: _destination!,
        startDate: _startDate!,
        endDate: _endDate!,
      );

      await tripRef.set({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'participants': _participants.map((p) => p.toMap()).toList(),
        'ownerId': user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Save the initial destination in the new 'destinations' list
        'destinations': [initialDestination.toMap()],
        // Keep legacy destination for potential backward compatibility (optional)
        'destination': _destination!.toMap(),
        'color': _selectedColor.value, // Add color to Firestore document
      });

      final difference = _endDate!.difference(_startDate!).inDays + 1;
      final batch = FirebaseFirestore.instance.batch();
      for (var i = 0; i < difference; i++) {
        final date = _startDate!.add(Duration(days: i));
        // Use a more robust ID generation for trip days
        final tripDayRef =
            FirebaseFirestore.instance.collection('tripDays').doc();
        batch.set(tripDayRef, {
          'tripId': tripId,
          'date': Timestamp.fromDate(date),
          'visits': [],
          'notes': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Create invitations for participants who are not the owner
      final invitationService = TripInvitationService();
      final nonOwnerParticipants =
          _participants.where((p) => p.uid != user!.uid).toList();

      for (final participant in nonOwnerParticipants) {
        await invitationService.createInvitation(
          tripId: tripId,
          tripName: _nameController.text,
          inviteeId: participant.uid,
          inviteeName: participant.username,
          message: 'You\'ve been invited to join this trip!',
        );
      }

      // Refresh user trips in the service
      // Use currentContext.mounted check
      if (currentContext.mounted) {
        final tripDataService = Provider.of<TripDataService>(
          currentContext, // Use captured context
          listen: false,
        );
        await tripDataService.setSelectedTrip(
          tripId,
        ); // Automatically select the new trip
        // No need to call loadUserTrips as we're using streams now

        // Pop using the captured context
        Navigator.of(currentContext).pop(true); // Return true for success
      }
    } catch (e) {
      // Use currentContext.mounted check
      if (currentContext.mounted) {
        ScaffoldMessenger.of(
          currentContext, // Use captured context
        ).showSnackBar(SnackBar(content: Text('Error creating trip: $e')));
      }
    } finally {
      // Use currentContext.mounted check
      if (currentContext.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextStep() {
    // Validate current step before proceeding
    if (_formKey.currentState!.validate()) {
      // Specific validation for steps
      if (_currentStep == 0) {
        // Combined Name/Dest/Dates step
        if (_destination == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a destination')),
          );
          return;
        }
        if (_startDate == null || _endDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select start and end dates')),
          );
          return;
        }
      }
      // Removed validation for step 1 (Dates)

      if (_currentStep < _totalSteps - 1) {
        setState(() => _currentStep++);
      } else {
        // Last step, trigger save
        _saveTrip();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: // Name, Destination & Dates
        return _buildNameDestinationDatesStep();
      // case 1: // Dates - REMOVED
      case 1: // Participants (was 4)
        return _buildParticipantsStep();
      default:
        return const Center(child: Text('Unknown step'));
    }
  }

  Widget _buildNameDestinationDatesStep() {
    final DateFormat formatter = DateFormat(
      'dd MMM',
    ); // Changed format slightly
    String dateRangeText = 'Select Dates';
    if (_startDate != null && _endDate != null) {
      dateRangeText =
          '${formatter.format(_startDate!)} - ${formatter.format(_endDate!)}';
    }
    final theme = Theme.of(context);
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: theme.dividerColor),
      borderRadius: BorderRadius.circular(8.0), // Consistent border radius
    );
    final focusedInputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: theme.primaryColor, width: 2.0),
      borderRadius: BorderRadius.circular(8.0),
    );
    final errorInputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
      borderRadius: BorderRadius.circular(8.0),
    );

    return ListView(
      // Use ListView for scrollability within the step
      padding: const EdgeInsets.all(16), // Use consistent padding
      shrinkWrap: true,
      children: [
        // Trip Name Field
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Trip Name *',
            hintText: 'e.g., Summer Vacation',
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusedInputBorder,
            prefixIcon: const Icon(Icons.airplane_ticket_outlined),
          ),
          validator:
              (value) => (value == null || value.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 16), // Consistent spacing
        // Destination Field
        TextFormField(
          controller: _destinationController,
          decoration: InputDecoration(
            labelText: 'Destination *',
            hintText: 'Search for a city or place',
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusedInputBorder,
            errorBorder: errorInputBorder,
            focusedErrorBorder: errorInputBorder,
            prefixIcon: const Icon(Icons.location_pin),
            suffixIcon:
                _destination != null
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear destination',
                      onPressed: _clearDestination,
                    )
                    : (_searchingDestination
                        ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20, // Consistent size
                            height: 20, // Consistent size
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : null),
          ),
          readOnly: _destination != null, // Prevent editing after selection
          onChanged: (value) {
            if (_destination != null) {
              _clearDestination(); // Clear if user types again
            }
            _searchDestinations(value);
          },
          validator: (value) {
            if (_destination == null && (value == null || value.isEmpty)) {
              return 'Please select a destination';
            }
            return null;
          },
        ),

        // Destination Suggestions (if any)
        if (_destinationSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            decoration: BoxDecoration(
              color: theme.cardColor, // Use card color for background
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(
              maxHeight: 200, // Limit suggestion list height
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _destinationSuggestions.length,
              itemBuilder: (context, index) {
                final place = _destinationSuggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(place.name),
                  subtitle: Text(
                    place.formattedAddress ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectDestination(place),
                );
              },
            ),
          ),

        const SizedBox(height: 16), // Consistent spacing
        // Date Range Field (using TextFormField for consistent style)
        TextFormField(
          readOnly: true,
          controller: TextEditingController(text: dateRangeText),
          decoration: InputDecoration(
            labelText: 'Dates *',
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusedInputBorder,
            errorBorder: errorInputBorder,
            focusedErrorBorder: errorInputBorder,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          onTap: () => _selectDateRange(context),
          validator: (_) {
            // Validate dates are selected
            if (_startDate == null || _endDate == null) {
              return 'Please select start and end dates';
            }
            return null;
          },
        ),
        const SizedBox(height: 16), // Consistent spacing
        // Description Field
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description (Optional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            prefixIcon: Icon(Icons.description),
            hintText: 'Add some details about your trip...',
          ),
          maxLines: 4,
          // No validator needed as it's optional
        ),
        const SizedBox(height: 16), // Consistent spacing
        // Color Selection
        const Text(
          'Choose a color for your trip:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        // Updated color picker layout for better alignment
        Wrap(
          alignment: WrapAlignment.center, // Center align the color picker
          spacing: 8, // Increased spacing for better visual appeal
          runSpacing: 8, // Consistent spacing between rows
          children:
              _colorPalette.map((color) {
                final isSelected = _selectedColor.value == color.value;
                return Container(
                  constraints: const BoxConstraints(
                    maxWidth: 300,
                  ), // Limit to 5 per row
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 60, // Slightly larger for better visibility
                      height: 60,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                isSelected
                                    ? color.withOpacity(0.8)
                                    : Colors.black.withOpacity(0.2),
                            blurRadius: isSelected ? 10 : 5,
                            spreadRadius: isSelected ? 3 : 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  // Removed _buildDatesStep()

  Widget _buildParticipantsStep() {
    // Ensure the list is scrollable if it gets long
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TripParticipantsList(
        participants: _participants,
        onParticipantsChanged: (participants) {
          setState(() => _participants = participants);
        },
        currentUserId: user?.uid ?? '',
      ),
    );
  }

  // Footer remains similar but Cancel button pops the page
  Widget _buildFooter() {
    return ButtonTray(
      padding: const EdgeInsets.all(16),
      primaryButton: ElevatedButton(
        onPressed: _isLoading ? null : _nextStep,
        child:
            _isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Text(
                  _currentStep == _totalSteps - 1 ? 'CREATE TRIP' : 'NEXT',
                ),
      ),
      secondaryButton:
          _currentStep > 0
              ? TextButton(
                onPressed: _isLoading ? null : _previousStep,
                child: const Text('BACK'),
              )
              : TextButton(
                // Updated onPressed for Cancel
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Trip Details & Dates'; // Updated title
      // case 1: // REMOVED
      case 1:
        return 'Invite Participants';
      default:
        return 'Create Trip';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Scaffold for the full page structure
    return GestureDetector(
      onTap:
          () =>
              FocusScope.of(context).unfocus(), // Close keyboard on tap outside
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getStepTitle()),
          leading: IconButton(
            icon: const Icon(Icons.close),
            // Use pop to close the page
            onPressed: () => Navigator.of(context).pop(),
          ),
          // Optional: Add progress indicator to AppBar during final save
          bottom:
              _isLoading && _currentStep == _totalSteps - 1
                  ? const PreferredSize(
                    preferredSize: Size.fromHeight(4.0),
                    child: LinearProgressIndicator(),
                  )
                  : null,
        ),
        // Use Form widget to enable validation across steps
        body: Form(
          key: _formKey,
          child: Column(
            // Use Column to place content and footer
            children: [
              Expanded(
                // Make the step content take available space
                child: Padding(
                  // Add padding around the step content
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: _buildStepContent(),
                ),
              ),
              // Place the footer at the bottom
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
