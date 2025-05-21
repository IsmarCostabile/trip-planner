import 'package:flutter/material.dart' hide Step; // Hide Material Step
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/models/location.dart';
import 'package:trip_planner/services/directions_service.dart';
import 'package:trip_planner/services/trip_data_service.dart'; // Add missing import
import 'package:trip_planner/widgets/base/base_list_tile.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trip_planner/services/directions_service.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'dart:async'; // Add import for StreamSubscription

/// A widget that displays travel time information between two locations
class TravelTimeTile extends StatefulWidget {
  final String originName;
  final String destinationName;
  final Location? originLocation;
  final Location? destinationLocation;
  final String? travelTime; // Optional pre-calculated time
  final String? distance; // Optional pre-calculated distance
  final String? travelMode; // Optional travel mode to use
  final String? tripId; // Add trip ID to allow trip-level storage
  final DateTime? destinationArrivalTime; // Add arrival time parameter
  final DateTime? originVisitEndTime; // Add origin visit's end time
  final String? originVisitId; // Add origin visit ID
  final String? destinationVisitId; // Add destination visit ID

  const TravelTimeTile({
    super.key,
    required this.originName,
    required this.destinationName,
    this.originLocation,
    this.destinationLocation,
    this.travelTime,
    this.distance,
    this.travelMode = 'transit', // Default to transit
    this.tripId, // Add optional tripId parameter
    this.destinationArrivalTime, // Add optional arrival time parameter
    this.originVisitEndTime, // Add optional origin visit end time
    this.originVisitId, // Add optional origin visit ID
    this.destinationVisitId, // Add optional destination visit ID
  });

  @override
  State<TravelTimeTile> createState() => _TravelTimeTileState();
}

class _TravelTimeTileState extends State<TravelTimeTile> {
  bool _isLoading = false;
  String? _error;
  String? _travelTime;
  String? _distance;
  DirectionsResult?
  result; // Add this field to store the full directions result
  String?
  _actualTravelMode; // The mode that was actually used (may fall back from transit to driving)
  bool _isExpanded = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;
  bool _isNotEnoughTime =
      false; // Added to track if there's not enough time between visits

  // Hive box to store travel mode preferences
  final _userBox = Hive.box('userBox');

  // In-memory cache for travel time results for each mode to avoid repeated API lookups
  final Map<String, Map<String, String>> _resultsCache = {};

  // Current selected travel mode for the segmented control
  String _selectedTravelMode = 'driving';

  // Stream subscription for travel mode updates
  StreamSubscription? _travelModeSubscription;

  // Define available travel modes for the segmented control
  final Map<String, String> _travelModes = {
    'driving': 'Car',
    'transit': 'Transit',
    'walking': 'Foot',
    'bicycling': 'Bike',
  };

  // Store the last coordinate information to avoid unnecessary API calls
  LatLng? _lastOriginCoords;
  LatLng? _lastDestCoords;
  String? _lastTravelMode;
  bool _hasFetchedData = false;

  // Define travel mode icons for the travel mode selection dialog
  final Map<String, IconData> _travelModeIcons = {
    'driving': Icons.directions_car,
    'walking': Icons.directions_walk,
    'bicycling': Icons.directions_bike,
    'transit': Icons.directions_transit,
  };

  @override
  void initState() {
    super.initState();

    // Load the saved travel mode preference if it exists
    _loadSavedTravelMode().then((_) {
      // After loading the travel mode, check if we need to fetch travel time
      if (widget.travelTime != null && widget.distance != null) {
        _travelTime = widget.travelTime;
        _distance = widget.distance;
        _actualTravelMode = widget.travelMode;
        _hasFetchedData = true; // Mark as having data
        _storeLastCoordinates(); // Store the coordinates associated with this pre-provided data
      }
      // Otherwise, if we have locations with coordinates, initiate fetch
      else if (widget.originLocation?.coordinates != null &&
          widget.destinationLocation?.coordinates != null) {
        // Store initial coordinates *before* fetching
        _storeLastCoordinates();
        _fetchTravelTime();
      } else {
        // Handle case where initial locations/coordinates are missing
        // Don't set error here, let the build method handle 'No travel data available'
        // _error = "Missing location coordinates";
      }
    });

    // Set up stream for travel mode preferences if we have the necessary data
    _setupTravelModeStream();
  }

  void _storeLastCoordinates() {
    _lastOriginCoords =
        widget.originLocation?.coordinates != null
            ? LatLng(
              widget.originLocation!.coordinates.latitude,
              widget.originLocation!.coordinates.longitude,
            )
            : null;
    _lastDestCoords =
        widget.destinationLocation?.coordinates != null
            ? LatLng(
              widget.destinationLocation!.coordinates.latitude,
              widget.destinationLocation!.coordinates.longitude,
            )
            : null;
    _lastTravelMode = widget.travelMode;
  }

  bool _coordinatesChanged() {
    // Check if current coordinates are available
    final currentOriginCoords = widget.originLocation?.coordinates;
    final currentDestCoords = widget.destinationLocation?.coordinates;
    final currentTravelMode = widget.travelMode;

    // If current coordinates are missing, we can't compare or fetch, so no change detected
    if (currentOriginCoords == null || currentDestCoords == null) {
      return false;
    }

    // If last stored coordinates are missing (e.g., first time with valid coords),
    // it counts as a change *if* we haven't fetched data yet.
    // This check is implicitly handled in didUpdateWidget's logic.
    if (_lastOriginCoords == null || _lastDestCoords == null) {
      // If we haven't fetched, and now have coords, it's a change.
      // If we *have* fetched, but somehow lost _lastCoords, treat as change to be safe.
      return true;
    }

    // Compare actual coordinate values and the *requested* travel mode
    return _lastOriginCoords!.latitude != currentOriginCoords.latitude ||
        _lastOriginCoords!.longitude != currentOriginCoords.longitude ||
        _lastDestCoords!.latitude != currentDestCoords.latitude ||
        _lastDestCoords!.longitude != currentDestCoords.longitude ||
        _lastTravelMode != currentTravelMode; // Compare against requested mode
  }

  @override
  void didUpdateWidget(TravelTimeTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool needsRefetch = false;

    // Scenario 1: Coordinates or travel mode changed compared to the last known state
    if (_coordinatesChanged()) {
      needsRefetch = true;
    }
    // Scenario 2: We didn't have data/coordinates before, but now we do
    else if (!_hasFetchedData &&
        widget.originLocation?.coordinates != null &&
        widget.destinationLocation?.coordinates != null) {
      // Check if the coordinates are different from the last attempt (even if it failed)
      if (_coordinatesChanged()) {
        needsRefetch = true;
      } else if (_lastOriginCoords == null && _lastDestCoords == null) {
        // Or if we never even had coordinates stored before
        needsRefetch = true;
      }
    }

    if (needsRefetch) {
      _retryCount = 0; // Reset retry count for the new fetch attempt
      // Store the *new* coordinates/mode we are about to fetch for *before* fetching
      _storeLastCoordinates();
      _fetchTravelTime();
    }
  }

  // Method to handle travel mode changes from the segmented control
  void _onTravelModeChanged(String newMode) {
    // Only refetch if the mode actually changed
    if (newMode != _selectedTravelMode) {
      setState(() {
        _selectedTravelMode = newMode;
        _retryCount = 0; // Reset retry count for the new travel mode
      });

      // Save the selected travel mode preference
      _saveTravelModePreference(newMode);

      // Skip the cache and fetch with the new mode directly
      _fetchTravelTimeWithMode(newMode);

      // Force refresh the map by explicitly telling the TripDataService to refresh
      try {
        final tripDataService = Provider.of<TripDataService>(
          context,
          listen: false,
        );
        // Add a small delay to ensure the travel mode is saved first
        Future.delayed(Duration(milliseconds: 100), () {
          tripDataService.forceMapRefresh();
        });
      } catch (e) {
        print('Error notifying map about travel mode change: $e');
      }
    }
  }

  Future<void> _fetchTravelTime() async {
    // Skip if we don't have both locations with coordinates
    if (widget.originLocation == null ||
        widget.destinationLocation == null ||
        widget.originLocation?.coordinates == null ||
        widget.destinationLocation?.coordinates == null) {
      setState(() {
        _error = "Missing location coordinates";
      });
      return;
    }

    // Check in-memory cache first
    if (_hasResultsInMemoryCache(_selectedTravelMode)) {
      final cachedResults = _getResultsFromMemoryCache(_selectedTravelMode);
      if (cachedResults != null) {
        setState(() {
          _travelTime = cachedResults['duration'];
          _distance = cachedResults['distance'];
          _isLoading = false;
          _actualTravelMode = _selectedTravelMode;
          _hasFetchedData = true;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final directionsService = Provider.of<DirectionsService>(
        context,
        listen: false,
      );

      // Use the selected travel mode from the segmented control instead of widget.travelMode
      final result = await directionsService.getDirections(
        origin: widget.originLocation!,
        destination: widget.destinationLocation!,
        travelMode: _selectedTravelMode,
        tripId: widget.tripId, // Pass trip ID for trip-level caching
        arrivalTime:
            widget
                .destinationArrivalTime, // Pass the arrival time for more accurate routing
      );

      if (mounted) {
        setState(() {
          _travelTime = result.duration;
          _distance = result.distance;
          this.result = result; // Store the full directions result
          _isLoading = false;
          _actualTravelMode = _selectedTravelMode; // Use selected mode
          _hasFetchedData = true;
          _storeLastCoordinates(); // Store the coordinates we just fetched for
        });

        // Check if there's enough time between the visits
        _checkIfEnoughTime();

        // Store in our in-memory cache
        _storeResultsInMemoryCache(
          _selectedTravelMode,
          result.duration,
          result.distance,
        );
      }
    } catch (e) {
      if (mounted) {
        if (_retryCount < _maxRetries) {
          // If transit mode fails, try with driving mode
          _retryCount++;
          setState(() {
            _isLoading = false;
          });

          // Short delay before retry
          await Future.delayed(const Duration(milliseconds: 500));

          if (widget.travelMode == 'transit') {
            // Try with driving mode as fallback
            if (mounted) {
              _fetchTravelTimeWithMode('driving');
            }
          } else {
            // Try with transit mode as fallback
            if (mounted) {
              _fetchTravelTimeWithMode('transit');
            }
          }
        } else {
          setState(() {
            _error = 'Could not fetch travel time';
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _fetchTravelTimeWithMode(String travelMode) async {
    if (!mounted) return;

    // Check in-memory cache first
    if (_hasResultsInMemoryCache(travelMode)) {
      final cachedResults = _getResultsFromMemoryCache(travelMode);
      if (cachedResults != null) {
        setState(() {
          _travelTime = cachedResults['duration'];
          _distance = cachedResults['distance'];
          _isLoading = false;
          _actualTravelMode = travelMode;
          _hasFetchedData = true;
        });

        // Check if there's enough time with the cached data
        _checkIfEnoughTime();
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final directionsService = Provider.of<DirectionsService>(
        context,
        listen: false,
      );

      final result = await directionsService.getDirections(
        origin: widget.originLocation!,
        destination: widget.destinationLocation!,
        travelMode: travelMode,
        tripId: widget.tripId, // Pass trip ID for trip-level caching
        arrivalTime:
            widget
                .destinationArrivalTime, // Pass the arrival time for more accurate routing
      );

      if (mounted) {
        setState(() {
          _travelTime = result.duration;
          _distance = result.distance;
          this.result = result; // Store the full directions result
          _isLoading = false;
          _actualTravelMode = travelMode;
          _hasFetchedData = true;
          // Update the last requested travel mode
          _lastTravelMode = travelMode;
          _storeLastCoordinates();
        });

        // Check if there's enough time between visits with the new travel mode
        _checkIfEnoughTime();

        // Store in our in-memory cache
        _storeResultsInMemoryCache(
          travelMode,
          result.duration,
          result.distance,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('No routes found for $travelMode mode')) {
            // Handle ZERO_RESULTS with user-friendly message
            _error = 'This travel mode is not available for this route';
          } else {
            _error = 'Could not fetch travel time';
          }
          _isLoading = false;
        });
      }
    }
  }

  // Generate a unique key for storing travel mode preference based on origin and destination
  String _getTravelModePreferenceKey() {
    // We use the place IDs if available as they are more stable than coordinates
    String originId = widget.originLocation?.placeId ?? 'unknown';
    String destId = widget.destinationLocation?.placeId ?? 'unknown';

    // If place IDs aren't available, fall back to coordinate-based keys
    if (originId == 'unknown' && widget.originLocation?.coordinates != null) {
      originId =
          '${widget.originLocation!.coordinates.latitude},${widget.originLocation!.coordinates.longitude}';
    }

    if (destId == 'unknown' &&
        widget.destinationLocation?.coordinates != null) {
      destId =
          '${widget.destinationLocation!.coordinates.latitude},${widget.destinationLocation!.coordinates.longitude}';
    }

    return 'travel_mode_pref_${originId}_to_${destId}';
  }

  // Load the previously saved travel mode preference from Firestore (with Hive fallback)
  Future<void> _loadSavedTravelMode() async {
    try {
      // Try to load from Firestore first (if trip ID is available)
      if (widget.tripId != null &&
          widget.originLocation != null &&
          widget.destinationLocation != null) {
        final directionsService = Provider.of<DirectionsService>(
          context,
          listen: false,
        );

        final savedMode = await directionsService.getPreferredTravelMode(
          widget.originLocation!,
          widget.destinationLocation!,
          tripId: widget.tripId!,
        );

        if (savedMode != null && _travelModes.containsKey(savedMode)) {
          if (mounted) {
            setState(() {
              _selectedTravelMode = savedMode;
            });
          }
          return;
        }
      }

      // Fall back to Hive if Firestore failed or returned no data
      final key = _getTravelModePreferenceKey();
      final savedMode = _userBox.get(key);

      if (savedMode != null && _travelModes.containsKey(savedMode)) {
        if (mounted) {
          setState(() {
            _selectedTravelMode = savedMode;
          });
        }
      } else {
        // If no saved mode anywhere, use the one provided by the widget or default to driving
        if (mounted) {
          setState(() {
            _selectedTravelMode = widget.travelMode ?? 'driving';
          });
        }
      }
    } catch (e) {
      print('Error loading saved travel mode: $e');

      // Fall back to widget-provided mode or default
      if (mounted) {
        setState(() {
          _selectedTravelMode = widget.travelMode ?? 'driving';
        });
      }
    }
  }

  // Save the selected travel mode preference to both Firestore and Hive
  Future<void> _saveTravelModePreference(String mode) async {
    // Save to Hive for quick local access (as fallback)
    final key = _getTravelModePreferenceKey();
    await _userBox.put(key, mode);

    // Also save to Firestore if we have trip ID and location data
    try {
      if (widget.tripId != null &&
          widget.originLocation != null &&
          widget.destinationLocation != null) {
        final directionsService = Provider.of<DirectionsService>(
          context,
          listen: false,
        );

        await directionsService.savePreferredTravelMode(
          widget.originLocation!,
          widget.destinationLocation!,
          mode,
          tripId: widget.tripId!,
        );
      }
    } catch (e) {
      print('Error saving travel mode to Firestore: $e');
      // Continue because we already saved to Hive as a backup
    }
  }

  // Generate a unique cache key for the current origin-destination pair
  String _getLocationsCacheKey() {
    // We use the place IDs if available as they are more stable than coordinates
    String originId = widget.originLocation?.placeId ?? 'unknown';
    String destId = widget.destinationLocation?.placeId ?? 'unknown';

    // If place IDs aren't available, fall back to coordinate-based keys
    if (originId == 'unknown' && widget.originLocation?.coordinates != null) {
      originId =
          '${widget.originLocation!.coordinates.latitude},${widget.originLocation!.coordinates.longitude}';
    }

    if (destId == 'unknown' &&
        widget.destinationLocation?.coordinates != null) {
      destId =
          '${widget.destinationLocation!.coordinates.latitude},${widget.destinationLocation!.coordinates.longitude}';
    }

    return '${originId}_to_${destId}';
  }

  // Check if we have already fetched results for this mode and location pair
  bool _hasResultsInMemoryCache(String travelMode) {
    final cacheKey = _getLocationsCacheKey();
    return _resultsCache.containsKey(cacheKey) &&
        _resultsCache[cacheKey]?.containsKey(travelMode) == true &&
        _resultsCache[cacheKey]?['duration'] != null &&
        _resultsCache[cacheKey]?['distance'] != null;
  }

  // Store results in memory cache
  void _storeResultsInMemoryCache(
    String travelMode,
    String duration,
    String distance,
  ) {
    final cacheKey = _getLocationsCacheKey();
    if (!_resultsCache.containsKey(cacheKey)) {
      _resultsCache[cacheKey] = {};
    }
    _resultsCache[cacheKey]!['travelMode'] = travelMode;
    _resultsCache[cacheKey]!['duration'] = duration;
    _resultsCache[cacheKey]!['distance'] = distance;
  }

  // Get results from memory cache
  Map<String, String>? _getResultsFromMemoryCache(String travelMode) {
    final cacheKey = _getLocationsCacheKey();
    if (_hasResultsInMemoryCache(travelMode)) {
      return _resultsCache[cacheKey];
    }
    return null;
  }

  // NEW: Helper method to build the list of transit step widgets
  List<Widget> _buildTransitStepsList(List<Step>? steps) {
    if (steps == null || steps.isEmpty) {
      return [const Text('No transit details available.')];
    }

    // Explicitly cast the result of map().toList() to List<Widget>
    return steps
        .map((step) {
          if (step.transitDetails != null) {
            // Use the formatted widget for transit segments
            return step.transitDetails!.formattedTransitWidget;
          } else if (step.travelMode.toUpperCase() == 'WALKING') {
            // Format walking segments with icon
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                        ),
                        children: [
                          const TextSpan(text: 'Walk'),
                          TextSpan(text: ': ${step.distance}'),
                          TextSpan(
                            text: ' - ${step.duration}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // Optionally handle other step types if needed
          return const SizedBox.shrink(); // Hide steps that aren't transit or walking
        })
        .toList()
        .cast<Widget>(); // Added .cast<Widget>()
  }

  // Check if there's enough time between visits
  void _checkIfEnoughTime() {
    // We can only check if there's both a result with duration and the destination arrival time
    if (result == null || widget.destinationArrivalTime == null) {
      _isNotEnoughTime = false;
      return;
    }

    try {
      // Get travel time in seconds
      final String durationValue = result!.durationValue;
      final int travelTimeSeconds = int.parse(durationValue);
      final int travelTimeMinutes = travelTimeSeconds ~/ 60;

      // We need the previous visit's end time
      // Since that's not directly passed in the widget, we need to derive it from
      // the originLocation or use a heuristic based on the destination arrival time

      // For this implementation, we'll add a parameter to the TravelTimeTile
      // that represents the origin visit's end time

      // In the meantime, we can assume we need to check if travel time exceeds
      // the gap between visits

      // If originVisitEndTime is provided, use it; otherwise try to make a smart guess
      DateTime? originVisitEndTime = widget.originVisitEndTime;

      if (originVisitEndTime == null) {
        // No origin visit end time provided, we can't make an accurate determination
        _isNotEnoughTime = false;
        return;
      }

      // Calculate time available between visits in minutes
      int availableTimeMinutes =
          widget.destinationArrivalTime!
              .difference(originVisitEndTime)
              .inMinutes;

      // If travel time is greater than available time, flag it
      _isNotEnoughTime = travelTimeMinutes > availableTimeMinutes;

      // Debug
      if (_isNotEnoughTime) {
        print(
          'Not enough time: Travel takes $travelTimeMinutes minutes, but only $availableTimeMinutes minutes available',
        );
        print('Origin visit ends: $originVisitEndTime');
        print('Destination visit starts: ${widget.destinationArrivalTime}');
      }
    } catch (e) {
      print('Error calculating if enough time: $e');
      _isNotEnoughTime = false;
    }
  }

  Future<void> _selectTravelMode() async {
    final String? newMode = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children:
                _travelModeIcons.keys.map((mode) {
                  return ListTile(
                    leading: Icon(
                      _travelModeIcons[mode],
                      color:
                          _selectedTravelMode == mode
                              ? Theme.of(context).colorScheme.primary
                              : null,
                    ),
                    title: Text(
                      mode[0].toUpperCase() + mode.substring(1),
                      style: TextStyle(
                        fontWeight:
                            _selectedTravelMode == mode
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, mode),
                  );
                }).toList(),
          ),
        );
      },
    );

    if (newMode != null && newMode != _selectedTravelMode) {
      // Use a local variable for context safety if needed
      final currentContext = context;
      setState(() {
        _selectedTravelMode = newMode;
      });

      // Save the preference
      if (widget.originLocation != null &&
          widget.destinationLocation != null &&
          widget.tripId != null) {
        try {
          final directionsService = Provider.of<DirectionsService>(
            context,
            listen: false,
          );

          await directionsService.savePreferredTravelMode(
            widget.originLocation!,
            widget.destinationLocation!,
            newMode,
            tripId: widget.tripId!,
            originVisitId: widget.originVisitId,
            destinationVisitId: widget.destinationVisitId,
          );

          // Notify TripDataService to update the map
          if (currentContext.mounted) {
            final tripDataService = Provider.of<TripDataService>(
              currentContext,
              listen: false,
            );
            tripDataService.notifyListeners();
          }
        } catch (e) {
          print('Error saving travel mode preference: $e');
        }
      }

      // Re-fetch directions for this tile's display
      _fetchTravelTimeWithMode(newMode);
    }
  }

  // Set up a stream to listen for real-time travel mode preference changes
  void _setupTravelModeStream() {
    // We need trip ID, origin & destination locations, and visit IDs to set up the stream
    if (widget.tripId == null ||
        widget.originLocation == null ||
        widget.destinationLocation == null) {
      return;
    }

    try {
      final directionsService = Provider.of<DirectionsService>(
        context,
        listen: false,
      );

      // Create a stream that listens for travel mode changes
      final stream = directionsService.listenToTravelModePreference(
        widget.originLocation!,
        widget.destinationLocation!,
        tripId: widget.tripId!,
        originVisitId: widget.originVisitId,
        destinationVisitId: widget.destinationVisitId,
      );

      // Subscribe to the stream
      _travelModeSubscription = stream.listen(
        (travelMode) {
          // Only update if the mode actually changed
          if (mounted && travelMode != _selectedTravelMode) {
            setState(() {
              _selectedTravelMode = travelMode;
            });

            // Fetch travel time with the new mode
            _fetchTravelTimeWithMode(travelMode);
          }
        },
        onError: (error) {
          print('Error from travel mode stream: $error');
        },
      );
    } catch (e) {
      print('Error setting up travel mode stream: $e');
    }
  }

  @override
  void dispose() {
    // Cancel the travel mode stream subscription
    _travelModeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get basic travel info for compact display
    String travelInfo;
    if (_isLoading) {
      travelInfo = 'Calculating route...';
    } else if (_error != null) {
      travelInfo = _error!;
    } else if (_travelTime != null && _distance != null) {
      travelInfo = '$_travelTime ($_distance)';
    } else {
      travelInfo = 'No travel data available';
    }

    // Choose the appropriate icon based on actual travel mode
    IconData travelIcon;

    if (_actualTravelMode == 'transit') {
      travelIcon = Icons.directions_transit;
    } else if (_actualTravelMode == 'walking') {
      travelIcon = Icons.directions_walk;
    } else if (_actualTravelMode == 'bicycling') {
      travelIcon = Icons.directions_bike;
    } else {
      // Default to driving
      travelIcon = Icons.directions_car;
    }

    // Create map of travel mode icons for segmented control
    final Map<String, Widget> travelModeIcons = {
      'driving': const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.directions_car, size: 22),
      ),
      'transit': const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.directions_transit, size: 22),
      ),
      'walking': const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.directions_walk, size: 22),
      ),
      'bicycling': const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.directions_bike, size: 22),
      ),
    };

    // Create expandable content with full details and segmented control
    Widget expandableContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show transit details if available and transit mode is selected
        if (_actualTravelMode == 'transit' &&
            _travelTime != null &&
            !_isLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transit Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                // Use the new helper method to build the list
                ..._buildTransitStepsList(result?.steps),
                const SizedBox(height: 12),
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Total Time: $_travelTime',
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
          ),

        // Warning message when there's not enough time
        if (_isNotEnoughTime && !_isLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You may not have enough time to reach the next visit with this mode of transportation.',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Transport Method:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(
              width: double.infinity,
              child: CupertinoSegmentedControl<String>(
                padding: const EdgeInsets.symmetric(vertical: 8),
                borderColor: Theme.of(context).primaryColor,
                selectedColor: Theme.of(context).primaryColor,
                unselectedColor: Colors.white,
                groupValue: _selectedTravelMode,
                onValueChanged: _onTravelModeChanged,
                children: travelModeIcons,
              ),
            ),
          ],
        ),
      ],
    );

    // Single-line compact title with appropriate icon
    String compactTitle = '$travelInfo';

    return BaseListTile(
      title: compactTitle,
      titleTextStyle:
          _isNotEnoughTime && !_isLoading
              ? TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ) // Red text when not enough time
              : null, // Default text style when time is sufficient
      subtitle: null, // No subtitle in compact mode
      leading: Icon(travelIcon, size: 24), // Use travel mode icon
      trailing:
          _isLoading
              ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
              : null,
      // Very small vertical margin
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      // Minimal content padding
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 0.0,
      ),
      elevation: 1.0, // Flat appearance
      isExpandable: true, // Make it expandable
      expandableContent:
          expandableContent, // Add the details in expandable content
      initiallyExpanded: _isExpanded,
      onExpansionChanged: (value) {
        setState(() {
          _isExpanded = value;
        });
      },
      dense: true, // Use dense mode for minimum height
      isDismissible: false, // Disable dismissal for travel time tiles
    );
  }
}
