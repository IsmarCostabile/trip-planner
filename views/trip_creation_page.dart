import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/models/location.dart';
import 'package:trip_planner/models/trip_destination.dart';
import 'package:trip_planner/services/places_service.dart';
import 'package:trip_planner/services/trip_invitation_service.dart';
import 'package:trip_planner/widgets/trip_participants_list_fixed.dart.bak';
import 'package:google_maps_webservice/places.dart' hide Location;
import 'package:provider/provider.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/widgets/modals/button_tray.dart';
import 'package:intl/intl.dart';

class TripCreationPage extends StatefulWidget {
  const TripCreationPage({super.key});

  static Future<bool?> show({required BuildContext context}) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const TripCreationPage(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<TripCreationPage> createState() => _TripCreationPageState();
}

class _TripCreationPageState extends State<TripCreationPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  final int _totalSteps = 2;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _destinationController = TextEditingController();

  final PlacesService _placesService = PlacesService();
  DateTime? _startDate;
  DateTime? _endDate;
  List<TripParticipant> _participants = [];
  bool _isLoading = false;
  Location? _destination;
  List<PlacesSearchResult> _destinationSuggestions = [];
  bool _searchingDestination = false;
  Color _selectedColor = Colors.blue;

  final List<Color> _colorPalette = [
    const Color(0xFFFBB13C),
    const Color(0xFF1098F7),
    const Color(0xFFFB3640),
    const Color(0xFF0CCE6B),
    const Color(0xFFFF47DA),
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
      photoUrl: user!.photoURL,
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

        final photoURL = data['photoURL'] ?? user!.photoURL;

        setState(() {
          _participants[0] = TripParticipant(
            uid: user!.uid,
            username: username,
            email: user!.email,
            photoUrl: photoURL,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error loading user data for trip creation: $e');
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final theme = Theme.of(context);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          _startDate != null && _endDate != null
              ? DateTimeRange(start: _startDate!, end: _endDate!)
              : null,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
              onPrimary: Colors.white,
              surface: theme.dialogBackgroundColor,
              onSurface: theme.textTheme.bodyLarge?.color,
            ),
            dialogBackgroundColor: theme.dialogBackgroundColor,
            buttonTheme: ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
              colorScheme: theme.colorScheme.copyWith(
                primary: theme.primaryColor,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: theme.primaryColor),
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

      final placeDetailsFutures = predictions
          .where((prediction) => prediction.placeId != null)
          .map(
            (prediction) => _placesService.getPlaceDetails(
              prediction.placeId!,
              context: context,
            ),
          );

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
    if (!_formKey.currentState!.validate()) return;

    final currentContext = context;

    setState(() => _isLoading = true);

    try {
      final tripRef = FirebaseFirestore.instance.collection('trips').doc();
      final tripId = tripRef.id;

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
        'destinations': [initialDestination.toMap()],
        'destination': _destination!.toMap(),
        'color': _selectedColor.value,
      });

      final difference = _endDate!.difference(_startDate!).inDays + 1;
      final batch = FirebaseFirestore.instance.batch();
      for (var i = 0; i < difference; i++) {
        final date = _startDate!.add(Duration(days: i));
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

      if (currentContext.mounted) {
        final tripDataService = Provider.of<TripDataService>(
          currentContext,
          listen: false,
        );
        await tripDataService.setSelectedTrip(tripId);

        Navigator.of(currentContext).pop(true);
      }
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(
          currentContext,
        ).showSnackBar(SnackBar(content: Text('Error creating trip: $e')));
      }
    } finally {
      if (currentContext.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_currentStep == 0) {
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

      if (_currentStep < _totalSteps - 1) {
        setState(() => _currentStep++);
      } else {
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
      case 0:
        return _buildNameDestinationDatesStep();
      case 1:
        return _buildParticipantsStep();
      default:
        return const Center(child: Text('Unknown step'));
    }
  }

  Widget _buildNameDestinationDatesStep() {
    final DateFormat formatter = DateFormat('dd MMM');
    String dateRangeText = 'Select Dates';
    if (_startDate != null && _endDate != null) {
      dateRangeText =
          '${formatter.format(_startDate!)} - ${formatter.format(_endDate!)}';
    }
    final theme = Theme.of(context);
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: theme.dividerColor),
      borderRadius: BorderRadius.circular(8.0),
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
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      children: [
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
        const SizedBox(height: 16),
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
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : null),
          ),
          readOnly: _destination != null,
          onChanged: (value) {
            if (_destination != null) {
              _clearDestination();
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

        if (_destinationSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            decoration: BoxDecoration(
              color: theme.cardColor,
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
            constraints: const BoxConstraints(maxHeight: 200),
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

        const SizedBox(height: 16),
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
            if (_startDate == null || _endDate == null) {
              return 'Please select start and end dates';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
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
        ),
        const SizedBox(height: 16),
        const Text(
          'Choose a color for your trip:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children:
              _colorPalette.map((color) {
                final isSelected = _selectedColor.value == color.value;
                return Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 60,
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

  Widget _buildParticipantsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TripParticipantsListFixed(
        participants: _participants,
        onParticipantsChanged: (participants) {
          setState(() => _participants = participants);
        },
        currentUserId: user?.uid ?? '',
      ),
    );
  }

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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Trip Details & Dates';
      case 1:
        return 'Invite Participants';
      default:
        return 'Create Trip';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getStepTitle()),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom:
              _isLoading && _currentStep == _totalSteps - 1
                  ? const PreferredSize(
                    preferredSize: Size.fromHeight(4.0),
                    child: LinearProgressIndicator(),
                  )
                  : null,
        ),
        body: Form(
          key: _formKey,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: _buildStepContent(),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
