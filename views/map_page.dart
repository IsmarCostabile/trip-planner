import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_planner/models/visit.dart';
import 'package:trip_planner/services/places_service.dart';
import 'package:trip_planner/services/polyline_service.dart';
import 'package:trip_planner/services/directions_service.dart'; // Import DirectionsService
import 'package:trip_planner/widgets/day_selector_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/services/user_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  bool _isFetchingPolylines = false;
  String? _currentDayId; // To track changes in selected day
  bool _useSimpleLines = false; // Add flag to track polyline display mode

  // Add subscription for listening to travel mode changes
  StreamSubscription? _travelModeSubscription;

  late DirectionsService _directionsService;
  TripDataService? _tripDataServiceInstance; // Store the instance

  // Add a property to track changes to the trip data
  bool _needsPolylineRefresh = false;

  // Default initial position if no other location is available
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco
    zoom: 1.0,
  );

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();
    // Initialize DirectionsService - ensure PlacesService is initialized beforehand
    // Assuming PlacesService.apiKey is accessible statically after initialization in main.dart
    _directionsService = DirectionsService(apiKey: PlacesService.apiKey);

    // Get the TripDataService instance here
    _tripDataServiceInstance = Provider.of<TripDataService>(
      context,
      listen: false,
    );
    _tripDataServiceInstance?.addListener(_onTripDataChanged);

    // Set up listener for travel mode changes and load preferences
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserPreferences();
      _setupTravelModeListener();
    });
  }

  // Load user preference for map line display type
  void _loadUserPreferences() {
    final userDataService = Provider.of<UserDataService>(
      context,
      listen: false,
    );
    if (userDataService.preferences.containsKey('useSimpleLines')) {
      setState(() {
        _useSimpleLines = userDataService.preferences['useSimpleLines'] as bool;
      });
    }
  }

  @override
  void dispose() {
    // Cancel travel mode change subscription
    _travelModeSubscription?.cancel();

    // Remove listener using the stored instance
    _tripDataServiceInstance?.removeListener(_onTripDataChanged);
    _mapController?.dispose();
    _directionsService.dispose(); // Dispose the http client
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if the selected day has changed and fetch polylines accordingly
    final tripDataService = Provider.of<TripDataService>(context);
    final selectedDay = tripDataService.selectedTripDay;
    if (selectedDay != null && selectedDay.id != _currentDayId) {
      _currentDayId = selectedDay.id;
      // Use a post-frame callback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check if the widget is still mounted
          _fetchAndSetPolylines();
        }
      });
    } else if (selectedDay == null && _currentDayId != null) {
      // Clear polylines if no day is selected anymore
      _currentDayId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _polylines = {};
          });
        }
      });
    }
  }

  Future<void> _fetchAndSetPolylines() async {
    if (!mounted) return; // Check if widget is still in the tree

    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );
    final selectedDay = tripDataService.selectedTripDay;
    final selectedTrip = tripDataService.selectedTrip;

    if (selectedDay == null || selectedTrip == null) {
      setState(() {
        _polylines = {};
        _isFetchingPolylines = false;
      });
      return;
    }

    // Get visits for the day and filter out those without coordinates
    final List<Visit> visits =
        tripDataService
            .getVisitsForDay(selectedDay.id)
            .where((v) => v.location?.coordinates != null)
            .toList();

    // Sort visits by time, just like in the itinerary page
    visits.sort((a, b) => a.visitTime.compareTo(b.visitTime));

    if (visits.length < 2) {
      setState(() {
        _polylines = {}; // Clear polylines if less than 2 visits
        _isFetchingPolylines = false;
      });
      return;
    }

    setState(() {
      _isFetchingPolylines = true;
      _polylines = {}; // Clear existing polylines before fetching new ones
    });

    final List<Future<Polyline?>> polylineFutures = [];

    for (int i = 0; i < visits.length - 1; i++) {
      final Visit originVisit = visits[i];
      final Visit destVisit = visits[i + 1];

      // Ensure locations are not null
      if (originVisit.location == null || destVisit.location == null) continue;

      polylineFutures.add(
        _createPolylineSegment(originVisit, destVisit, selectedTrip.id, i),
      );
    }

    try {
      final List<Polyline?> results = await Future.wait(polylineFutures);
      if (!mounted) return; // Check again after async gap

      final Set<Polyline> validPolylines =
          results.whereType<Polyline>().toSet();

      setState(() {
        _polylines = validPolylines;
        _isFetchingPolylines = false;
      });

      _updateCameraBounds(); // Update bounds after polylines are fetched
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error fetching polylines: $e");
      setState(() {
        _isFetchingPolylines = false;
        // Optionally show an error message to the user
      });
    }
  }

  // Helper to create a single polyline segment
  Future<Polyline?> _createPolylineSegment(
    Visit originVisit,
    Visit destVisit,
    String tripId,
    int index,
  ) async {
    try {
      // Fetch preferred travel mode or default to driving/transit
      String? preferredMode = await _directionsService.getPreferredTravelMode(
        originVisit.location!,
        destVisit.location!,
        tripId: tripId,
        originVisitId: originVisit.id,
        destinationVisitId: destVisit.id,
      );
      String travelMode = preferredMode ?? 'transit';

      List<LatLng> routePoints;

      // Use simple straight lines if enabled, otherwise get complex route
      if (_useSimpleLines) {
        routePoints = PolylineService.createDirectPolyline(
          originVisit.location,
          destVisit.location,
        );
      } else {
        routePoints = await PolylineService.getRoutePolyline(
          originVisit.location,
          destVisit.location,
          travelMode,
          _directionsService,
          tripId: tripId,
          originVisitId: originVisit.id,
          destinationVisitId: destVisit.id,
        );
      }

      if (routePoints.isNotEmpty) {
        return Polyline(
          polylineId: PolylineId('route_$index'),
          points: routePoints,
          color: PolylineService.getTravelModeColor(travelMode),
          width: 4, // Adjust width as needed
        );
      }
    } catch (e) {
      debugPrint("Error creating polyline segment $index: $e");
    }
    return null; // Return null if fetching or creation fails
  }

  void _updateCameraBounds() {
    if (_mapController == null || (!mounted)) return;

    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );
    final selectedDay = tripDataService.selectedTripDay;
    if (selectedDay == null) return;

    final visits = tripDataService.getVisitsForDay(selectedDay.id);
    final markers = _getMarkersForVisits(
      visits,
      null,
      null,
    ); // Get current markers

    if (markers.isEmpty && _polylines.isEmpty) return; // No points to bound

    LatLngBounds bounds;

    if (_polylines.isNotEmpty) {
      bounds = PolylineService.getBoundsForPolylines(_polylines.toList());

      // Manually include marker positions in bounds calculation
      double minLat = bounds.southwest.latitude;
      double minLng = bounds.southwest.longitude;
      double maxLat = bounds.northeast.latitude;
      double maxLng = bounds.northeast.longitude;

      for (final marker in markers) {
        final lat = marker.position.latitude;
        final lng = marker.position.longitude;
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
      bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
    } else if (markers.isNotEmpty) {
      // If only markers, bound them
      bounds = _boundsFromMarkers(markers);
    } else {
      return; // Should not happen if check above works
    }

    // Add padding to the bounds
    final CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(
      bounds,
      50.0,
    ); // 50 pixels padding

    // Animate camera smoothly
    _mapController!.animateCamera(cameraUpdate);
  }

  // Helper to calculate bounds from markers only
  LatLngBounds _boundsFromMarkers(Set<Marker> markers) {
    if (markers.isEmpty)
      return LatLngBounds(
        southwest: _initialPosition.target,
        northeast: _initialPosition.target,
      );
    double? minLat, maxLat, minLng, maxLng;
    for (final marker in markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      minLat = (minLat == null || lat < minLat) ? lat : minLat;
      maxLat = (maxLat == null || lat > maxLat) ? lat : maxLat;
      minLng = (minLng == null || lng < minLng) ? lng : minLng;
      maxLng = (maxLng == null || lng > maxLng) ? lng : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  // Helper function to generate markers (extracted for reuse)
  Set<Marker> _getMarkersForVisits(
    List<Visit> visits,
    double? focusLat,
    double? focusLng,
  ) {
    return visits.where((visit) => visit.location != null).map((visit) {
      // Coordinates are guaranteed non-null here due to the 'where' clause above
      final coords = visit.location!.coordinates;

      final position = LatLng(coords.latitude, coords.longitude);
      return Marker(
        markerId: MarkerId(visit.id),
        position: position,
        infoWindow: InfoWindow(title: visit.location!.name),
        icon:
            (focusLat == coords.latitude && focusLng == coords.longitude)
                ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ) // Highlight focused marker
                : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
      );
    }).toSet();
  }

  // Called when TripDataService notifies listeners
  void _onTripDataChanged() {
    if (!mounted) return;

    // Mark that we need to refresh polylines, but don't do it immediately
    // This avoids refreshing too frequently if multiple changes happen in quick succession
    _needsPolylineRefresh = true;

    // Refresh after a short delay to avoid multiple refreshes for batch changes
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _needsPolylineRefresh) {
        _needsPolylineRefresh = false;
        _fetchAndSetPolylines();
      }
    });
  }

  // Set up listener for real-time travel mode changes from Firestore
  void _setupTravelModeListener() {
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    final selectedTrip = tripDataService.selectedTrip;
    if (selectedTrip == null) return;

    final selectedDay = tripDataService.selectedTripDay;
    if (selectedDay == null) return;

    // Listen to the tripDay document for travel segment changes
    _travelModeSubscription = FirebaseFirestore.instance
        .collection('tripDays')
        .where('tripId', isEqualTo: selectedTrip.id)
        .snapshots()
        .listen((snapshot) {
          // Only refresh if the widget is still mounted
          if (!mounted) return;

          // Check if this update includes our current day
          bool refreshNeeded = false;
          for (final doc in snapshot.docs) {
            if (doc.id == selectedDay.id) {
              refreshNeeded = true;
              break;
            }
          }

          if (refreshNeeded) {
            // Mark for refresh and execute with a small delay
            _needsPolylineRefresh = true;
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && _needsPolylineRefresh) {
                _needsPolylineRefresh = false;
                _fetchAndSetPolylines();
              }
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Ensure AutomaticKeepAliveClientMixin works

    return Consumer<TripDataService>(
      builder: (context, tripDataService, child) {
        // ... (existing loading and error handling) ...
        if (tripDataService.isLoading && tripDataService.selectedTrip == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading Map...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (tripDataService.error != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text('Error loading map: ${tripDataService.error}'),
            ),
          );
        }
        final selectedTrip = tripDataService.selectedTrip;
        if (selectedTrip == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('No Trip Selected')),
            body: const Center(child: Text('Please select a trip.')),
          );
        }
        final tripDays = tripDataService.selectedTripDays;
        // Handle case where trip exists but days haven't loaded yet (or are empty)
        // We can still show the map centered on the destination or initial position

        // Read navigation arguments for focus location (if any)
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final double? focusLat = args?['focusLat'] as double?;
        final double? focusLng = args?['focusLng'] as double?;
        final String? heroTag = args?['heroTag'] as String?;

        // Get visits and markers for the selected day
        final selectedDay = tripDataService.selectedTripDay;
        final List<Visit> visits =
            selectedDay != null
                ? tripDataService.getVisitsForDay(selectedDay.id)
                : <Visit>[];

        // Sort visits by time for consistent ordering with the itinerary page
        if (visits.isNotEmpty) {
          visits.sort((a, b) => a.visitTime.compareTo(b.visitTime));
        }

        final visitMarkers = _getMarkersForVisits(visits, focusLat, focusLng);

        // Determine initial camera position logic (will be adjusted by _updateCameraBounds later)
        CameraPosition initialCameraPosition;
        if (focusLat != null && focusLng != null) {
          initialCameraPosition = CameraPosition(
            target: LatLng(focusLat, focusLng),
            zoom: 15.0, // Zoom in on focused location initially
          );
        } else if (visitMarkers.isNotEmpty) {
          // If markers exist, center on their bounds initially
          final bounds = _boundsFromMarkers(visitMarkers);
          // Calculate center manually
          final centerLat =
              (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
          final centerLng =
              (bounds.southwest.longitude + bounds.northeast.longitude) / 2;
          initialCameraPosition = CameraPosition(
            target: LatLng(centerLat, centerLng),
            zoom: 10.0, // Start with a wider view
          );
        } else if (selectedTrip.destination?.coordinates != null) {
          // Fallback to trip destination
          final coords = selectedTrip.destination!.coordinates;
          initialCameraPosition = CameraPosition(
            target: LatLng(coords.latitude, coords.longitude),
            zoom: 12.0,
          );
        } else {
          // Absolute fallback
          initialCameraPosition = _initialPosition;
        }

        return Scaffold(
          appBar: DaySelectorAppBar(
            trip: selectedTrip,
            tripDays: tripDays,
            selectedDayIndex: tripDataService.selectedDayIndex,
            onDaySelected: (int? newIndex) {
              if (newIndex != null &&
                  newIndex != tripDataService.selectedDayIndex) {
                tripDataService.setSelectedDayIndex(newIndex);
                // Fetching polylines is handled by didChangeDependencies
              }
            },
            actions: [
              // Add toggle button for simple/complex routes
              IconButton(
                icon: Icon(_useSimpleLines ? Icons.timeline : Icons.route),
                tooltip:
                    _useSimpleLines
                        ? 'Show actual routes'
                        : 'Show direct lines',
                onPressed: () {
                  setState(() {
                    _useSimpleLines = !_useSimpleLines;

                    // Save user preference to UserDataService
                    final userDataService = Provider.of<UserDataService>(
                      context,
                      listen: false,
                    );
                    userDataService.updateUserData({
                      'preferences': {
                        ...userDataService.preferences,
                        'useSimpleLines': _useSimpleLines,
                      },
                    });

                    // Refresh polylines when changing mode
                    _fetchAndSetPolylines();
                  });
                },
              ),
            ],
          ),
          body: Stack(
            // Use Stack to overlay loading indicator
            children: [
              // Wrap map view in Hero if tag exists
              heroTag != null
                  ? Hero(
                    tag: heroTag,
                    child: _buildMapView(
                      initialCameraPosition,
                      visitMarkers,
                      _polylines,
                    ),
                  )
                  : _buildMapView(
                    initialCameraPosition,
                    visitMarkers,
                    _polylines,
                  ),

              // Loading indicator overlay
              if (_isFetchingPolylines)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Updated to accept polylines
  Widget _buildMapView(
    CameraPosition cameraPosition,
    Set<Marker> markers,
    Set<Polyline> polylines,
  ) {
    return GoogleMap(
      initialCameraPosition: cameraPosition,
      markers: markers,
      polylines: polylines, // Add polylines here
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: true,
      zoomControlsEnabled: true,
      onMapCreated: (controller) {
        if (!mounted) return;
        _mapController = controller;

        // Initial camera animation after map creation
        // Use a slight delay to ensure layout is complete
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return; // Check mount status again after delay
          if (markers.isNotEmpty || polylines.isNotEmpty) {
            _updateCameraBounds(); // Adjust bounds after map is created and polylines might be ready
          } else {
            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(cameraPosition),
            );
          }
        });
      },
    );
  }
}
