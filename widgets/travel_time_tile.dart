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

class TravelTimeTile extends StatefulWidget {
  final String originName;
  final String destinationName;
  final Location? originLocation;
  final Location? destinationLocation;
  final String? travelTime;
  final String? distance;
  final String? travelMode;
  final String? tripId;
  final DateTime? destinationArrivalTime;
  final DateTime? originVisitEndTime;
  final String? originVisitId;
  final String? destinationVisitId;

  const TravelTimeTile({
    super.key,
    required this.originName,
    required this.destinationName,
    this.originLocation,
    this.destinationLocation,
    this.travelTime,
    this.distance,
    this.travelMode = 'transit',
    this.tripId,
    this.destinationArrivalTime,
    this.originVisitEndTime,
    this.originVisitId,
    this.destinationVisitId,
  });

  @override
  State<TravelTimeTile> createState() => _TravelTimeTileState();
}

class _TravelTimeTileState extends State<TravelTimeTile> {
  bool _isLoading = false;
  String? _error;
  String? _travelTime;
  String? _distance;
  DirectionsResult? result;
  String? _actualTravelMode;
  bool _isExpanded = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;
  bool _isNotEnoughTime = false;

  final _userBox = Hive.box('userBox');

  final Map<String, Map<String, String>> _resultsCache = {};

  String _selectedTravelMode = 'driving';

  StreamSubscription? _travelModeSubscription;

  final Map<String, String> _travelModes = {
    'driving': 'Car',
    'transit': 'Transit',
    'walking': 'Foot',
    'bicycling': 'Bike',
  };

  LatLng? _lastOriginCoords;
  LatLng? _lastDestCoords;
  String? _lastTravelMode;
  bool _hasFetchedData = false;

  final Map<String, IconData> _travelModeIcons = {
    'driving': Icons.directions_car,
    'walking': Icons.directions_walk,
    'bicycling': Icons.directions_bike,
    'transit': Icons.directions_transit,
  };

  @override
  void initState() {
    super.initState();

    _loadSavedTravelMode().then((_) {
      if (widget.travelTime != null && widget.distance != null) {
        _travelTime = widget.travelTime;
        _distance = widget.distance;
        _actualTravelMode = widget.travelMode;
        _hasFetchedData = true;
        _storeLastCoordinates();
      } else if (widget.originLocation?.coordinates != null &&
          widget.destinationLocation?.coordinates != null) {
        _storeLastCoordinates();
        _fetchTravelTime();
      }
    });

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
    final currentOriginCoords = widget.originLocation?.coordinates;
    final currentDestCoords = widget.destinationLocation?.coordinates;
    final currentTravelMode = widget.travelMode;

    if (currentOriginCoords == null || currentDestCoords == null) {
      return false;
    }

    if (_lastOriginCoords == null || _lastDestCoords == null) {
      return true;
    }

    return _lastOriginCoords!.latitude != currentOriginCoords.latitude ||
        _lastOriginCoords!.longitude != currentOriginCoords.longitude ||
        _lastDestCoords!.latitude != currentDestCoords.latitude ||
        _lastDestCoords!.longitude != currentDestCoords.longitude ||
        _lastTravelMode != currentTravelMode;
  }

  @override
  void didUpdateWidget(TravelTimeTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool needsRefetch = false;

    if (_coordinatesChanged()) {
      needsRefetch = true;
    } else if (!_hasFetchedData &&
        widget.originLocation?.coordinates != null &&
        widget.destinationLocation?.coordinates != null) {
      if (_coordinatesChanged()) {
        needsRefetch = true;
      } else if (_lastOriginCoords == null && _lastDestCoords == null) {
        needsRefetch = true;
      }
    }

    if (needsRefetch) {
      _retryCount = 0;
      _storeLastCoordinates();
      _fetchTravelTime();
    }
  }

  void _onTravelModeChanged(String newMode) {
    if (newMode != _selectedTravelMode) {
      setState(() {
        _selectedTravelMode = newMode;
        _retryCount = 0;
      });

      _saveTravelModePreference(newMode);

      _fetchTravelTimeWithMode(newMode);

      try {
        final tripDataService = Provider.of<TripDataService>(
          context,
          listen: false,
        );
        Future.delayed(Duration(milliseconds: 100), () {
          tripDataService.forceMapRefresh();
        });
      } catch (e) {
        print('Error notifying map about travel mode change: $e');
      }
    }
  }

  Future<void> _fetchTravelTime() async {
    if (widget.originLocation == null ||
        widget.destinationLocation == null ||
        widget.originLocation?.coordinates == null ||
        widget.destinationLocation?.coordinates == null) {
      setState(() {
        _error = "Missing location coordinates";
      });
      return;
    }

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

      final result = await directionsService.getDirections(
        origin: widget.originLocation!,
        destination: widget.destinationLocation!,
        travelMode: _selectedTravelMode,
        tripId: widget.tripId,
        arrivalTime: widget.destinationArrivalTime,
      );

      if (mounted) {
        setState(() {
          _travelTime = result.duration;
          _distance = result.distance;
          this.result = result;
          _isLoading = false;
          _actualTravelMode = _selectedTravelMode;
          _hasFetchedData = true;
          _storeLastCoordinates();
        });

        _checkIfEnoughTime();

        _storeResultsInMemoryCache(
          _selectedTravelMode,
          result.duration,
          result.distance,
        );
      }
    } catch (e) {
      if (mounted) {
        if (_retryCount < _maxRetries) {
          _retryCount++;
          setState(() {
            _isLoading = false;
          });

          await Future.delayed(const Duration(milliseconds: 500));

          if (widget.travelMode == 'transit') {
            if (mounted) {
              _fetchTravelTimeWithMode('driving');
            }
          } else {
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
        tripId: widget.tripId,
        arrivalTime: widget.destinationArrivalTime,
      );

      if (mounted) {
        setState(() {
          _travelTime = result.duration;
          _distance = result.distance;
          this.result = result;
          _isLoading = false;
          _actualTravelMode = travelMode;
          _hasFetchedData = true;
          _lastTravelMode = travelMode;
          _storeLastCoordinates();
        });

        _checkIfEnoughTime();

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
            _error = 'This travel mode is not available for this route';
          } else {
            _error = 'Could not fetch travel time';
          }
          _isLoading = false;
        });
      }
    }
  }

  String _getTravelModePreferenceKey() {
    String originId = widget.originLocation?.placeId ?? 'unknown';
    String destId = widget.destinationLocation?.placeId ?? 'unknown';

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

  Future<void> _loadSavedTravelMode() async {
    try {
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

      final key = _getTravelModePreferenceKey();
      final savedMode = _userBox.get(key);

      if (savedMode != null && _travelModes.containsKey(savedMode)) {
        if (mounted) {
          setState(() {
            _selectedTravelMode = savedMode;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedTravelMode = widget.travelMode ?? 'driving';
          });
        }
      }
    } catch (e) {
      print('Error loading saved travel mode: $e');

      if (mounted) {
        setState(() {
          _selectedTravelMode = widget.travelMode ?? 'driving';
        });
      }
    }
  }

  Future<void> _saveTravelModePreference(String mode) async {
    final key = _getTravelModePreferenceKey();
    await _userBox.put(key, mode);

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
    }
  }

  String _getLocationsCacheKey() {
    String originId = widget.originLocation?.placeId ?? 'unknown';
    String destId = widget.destinationLocation?.placeId ?? 'unknown';

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

  bool _hasResultsInMemoryCache(String travelMode) {
    final cacheKey = _getLocationsCacheKey();
    return _resultsCache.containsKey(cacheKey) &&
        _resultsCache[cacheKey]?.containsKey(travelMode) == true &&
        _resultsCache[cacheKey]?['duration'] != null &&
        _resultsCache[cacheKey]?['distance'] != null;
  }

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

  Map<String, String>? _getResultsFromMemoryCache(String travelMode) {
    final cacheKey = _getLocationsCacheKey();
    if (_hasResultsInMemoryCache(travelMode)) {
      return _resultsCache[cacheKey];
    }
    return null;
  }

  List<Widget> _buildTransitStepsList(List<Step>? steps) {
    if (steps == null || steps.isEmpty) {
      return [const Text('No transit details available.')];
    }

    return steps
        .map((step) {
          if (step.transitDetails != null) {
            return step.transitDetails!.formattedTransitWidget;
          } else if (step.travelMode.toUpperCase() == 'WALKING') {
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
          return const SizedBox.shrink();
        })
        .toList()
        .cast<Widget>();
  }

  void _checkIfEnoughTime() {
    if (result == null || widget.destinationArrivalTime == null) {
      _isNotEnoughTime = false;
      return;
    }

    try {
      final String durationValue = result!.durationValue;
      final int travelTimeSeconds = int.parse(durationValue);
      final int travelTimeMinutes = travelTimeSeconds ~/ 60;

      DateTime? originVisitEndTime = widget.originVisitEndTime;

      if (originVisitEndTime == null) {
        _isNotEnoughTime = false;
        return;
      }

      int availableTimeMinutes =
          widget.destinationArrivalTime!
              .difference(originVisitEndTime)
              .inMinutes;

      _isNotEnoughTime = travelTimeMinutes > availableTimeMinutes;

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
      final currentContext = context;
      setState(() {
        _selectedTravelMode = newMode;
      });

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

      _fetchTravelTimeWithMode(newMode);
    }
  }

  void _setupTravelModeStream() {
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

      final stream = directionsService.listenToTravelModePreference(
        widget.originLocation!,
        widget.destinationLocation!,
        tripId: widget.tripId!,
        originVisitId: widget.originVisitId,
        destinationVisitId: widget.destinationVisitId,
      );

      _travelModeSubscription = stream.listen(
        (travelMode) {
          if (mounted && travelMode != _selectedTravelMode) {
            setState(() {
              _selectedTravelMode = travelMode;
            });

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
    _travelModeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    IconData travelIcon;

    if (_actualTravelMode == 'transit') {
      travelIcon = Icons.directions_transit;
    } else if (_actualTravelMode == 'walking') {
      travelIcon = Icons.directions_walk;
    } else if (_actualTravelMode == 'bicycling') {
      travelIcon = Icons.directions_bike;
    } else {
      travelIcon = Icons.directions_car;
    }

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

    Widget expandableContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

    String compactTitle = '$travelInfo';

    return BaseListTile(
      title: compactTitle,
      titleTextStyle:
          _isNotEnoughTime && !_isLoading
              ? TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
              : null,
      subtitle: null,
      leading: Icon(travelIcon, size: 24),
      trailing:
          _isLoading
              ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
              : null,
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 0.0,
      ),
      elevation: 1.0,
      isExpandable: true,
      expandableContent: expandableContent,
      initiallyExpanded: _isExpanded,
      onExpansionChanged: (value) {
        setState(() {
          _isExpanded = value;
        });
      },
      dense: true,
      isDismissible: false,
    );
  }
}
