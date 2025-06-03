import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_planner/models/visit.dart';
import 'package:trip_planner/services/places_service.dart';
import 'package:trip_planner/services/polyline_service.dart';
import 'package:trip_planner/services/directions_service.dart';
import 'package:trip_planner/widgets/empty_trip_placeholder.dart';
import 'package:trip_planner/widgets/day_selector_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/services/user_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  bool _isFetchingPolylines = false;
  String? _currentDayId;
  bool _useSimpleLines = false;

  StreamSubscription? _travelModeSubscription;

  late DirectionsService _directionsService;
  TripDataService? _tripDataServiceInstance;

  bool _needsPolylineRefresh = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 1.0,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _directionsService = DirectionsService(apiKey: PlacesService.apiKey);

    _tripDataServiceInstance = Provider.of<TripDataService>(
      context,
      listen: false,
    );
    _tripDataServiceInstance?.addListener(_onTripDataChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserPreferences();
      _setupTravelModeListener();
    });
  }

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
    _travelModeSubscription?.cancel();

    _tripDataServiceInstance?.removeListener(_onTripDataChanged);
    _mapController?.dispose();
    _directionsService.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tripDataService = Provider.of<TripDataService>(context);
    final selectedDay = tripDataService.selectedTripDay;
    if (selectedDay != null && selectedDay.id != _currentDayId) {
      _currentDayId = selectedDay.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchAndSetPolylines();
        }
      });
    } else if (selectedDay == null && _currentDayId != null) {
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
    if (!mounted) return;

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

    final List<Visit> visits =
        tripDataService
            .getVisitsForDay(selectedDay.id)
            .where((v) => v.location?.coordinates != null)
            .toList();

    visits.sort((a, b) => a.visitTime.compareTo(b.visitTime));

    if (visits.length < 2) {
      setState(() {
        _polylines = {};
        _isFetchingPolylines = false;
      });
      return;
    }

    setState(() {
      _isFetchingPolylines = true;
      _polylines = {};
    });

    final List<Future<Polyline?>> polylineFutures = [];

    for (int i = 0; i < visits.length - 1; i++) {
      final Visit originVisit = visits[i];
      final Visit destVisit = visits[i + 1];

      if (originVisit.location == null || destVisit.location == null) continue;

      polylineFutures.add(
        _createPolylineSegment(originVisit, destVisit, selectedTrip.id, i),
      );
    }

    try {
      final List<Polyline?> results = await Future.wait(polylineFutures);
      if (!mounted) return;

      final Set<Polyline> validPolylines =
          results.whereType<Polyline>().toSet();

      setState(() {
        _polylines = validPolylines;
        _isFetchingPolylines = false;
      });

      _updateCameraBounds();
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error fetching polylines: $e");
      setState(() {
        _isFetchingPolylines = false;
      });
    }
  }

  Future<Polyline?> _createPolylineSegment(
    Visit originVisit,
    Visit destVisit,
    String tripId,
    int index,
  ) async {
    try {
      String? preferredMode = await _directionsService.getPreferredTravelMode(
        originVisit.location!,
        destVisit.location!,
        tripId: tripId,
        originVisitId: originVisit.id,
        destinationVisitId: destVisit.id,
      );
      String travelMode = preferredMode ?? 'transit';

      List<LatLng> routePoints;

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
          width: 4,
        );
      }
    } catch (e) {
      debugPrint("Error creating polyline segment $index: $e");
    }
    return null;
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
    final markers = _getMarkersForVisits(visits, null, null);

    if (markers.isEmpty && _polylines.isEmpty) return;

    LatLngBounds bounds;

    if (_polylines.isNotEmpty) {
      bounds = PolylineService.getBoundsForPolylines(_polylines.toList());

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
      bounds = _boundsFromMarkers(markers);
    } else {
      return;
    }

    final CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(
      bounds,
      50.0,
    );

    _mapController!.animateCamera(cameraUpdate);
  }

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

  Set<Marker> _getMarkersForVisits(
    List<Visit> visits,
    double? focusLat,
    double? focusLng,
  ) {
    return visits.where((visit) => visit.location != null).map((visit) {
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
                )
                : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
      );
    }).toSet();
  }

  void _onTripDataChanged() {
    if (!mounted) return;

    _needsPolylineRefresh = true;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _needsPolylineRefresh) {
        _needsPolylineRefresh = false;
        _fetchAndSetPolylines();
      }
    });
  }

  void _setupTravelModeListener() {
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    final selectedTrip = tripDataService.selectedTrip;
    if (selectedTrip == null) return;

    final selectedDay = tripDataService.selectedTripDay;
    if (selectedDay == null) return;

    _travelModeSubscription = FirebaseFirestore.instance
        .collection('tripDays')
        .where('tripId', isEqualTo: selectedTrip.id)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          bool refreshNeeded = false;
          for (final doc in snapshot.docs) {
            if (doc.id == selectedDay.id) {
              refreshNeeded = true;
              break;
            }
          }

          if (refreshNeeded) {
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
    super.build(context);

    return Consumer<TripDataService>(
      builder: (context, tripDataService, child) {
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
            appBar: AppBar(title: const Text('Trip Map')),
            body: const EmptyTripPlaceholder(
              message: 'Ready to explore new destinations?',
              buttonText: 'Plan your next Trip',
              icon: Icons.explore,
            ),
          );
        }
        final tripDays = tripDataService.selectedTripDays;

        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final double? focusLat = args?['focusLat'] as double?;
        final double? focusLng = args?['focusLng'] as double?;
        final String? heroTag = args?['heroTag'] as String?;

        final selectedDay = tripDataService.selectedTripDay;
        final List<Visit> visits =
            selectedDay != null
                ? tripDataService.getVisitsForDay(selectedDay.id)
                : <Visit>[];

        if (visits.isNotEmpty) {
          visits.sort((a, b) => a.visitTime.compareTo(b.visitTime));
        }

        final visitMarkers = _getMarkersForVisits(visits, focusLat, focusLng);

        CameraPosition initialCameraPosition;
        if (focusLat != null && focusLng != null) {
          initialCameraPosition = CameraPosition(
            target: LatLng(focusLat, focusLng),
            zoom: 15.0,
          );
        } else if (visitMarkers.isNotEmpty) {
          final bounds = _boundsFromMarkers(visitMarkers);
          final centerLat =
              (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
          final centerLng =
              (bounds.southwest.longitude + bounds.northeast.longitude) / 2;
          initialCameraPosition = CameraPosition(
            target: LatLng(centerLat, centerLng),
            zoom: 10.0,
          );
        } else if (selectedTrip.destination?.coordinates != null) {
          final coords = selectedTrip.destination!.coordinates;
          initialCameraPosition = CameraPosition(
            target: LatLng(coords.latitude, coords.longitude),
            zoom: 12.0,
          );
        } else {
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
              }
            },
            actions: [
              IconButton(
                icon: Icon(_useSimpleLines ? Icons.timeline : Icons.route),
                tooltip:
                    _useSimpleLines
                        ? 'Show actual routes'
                        : 'Show direct lines',
                onPressed: () {
                  setState(() {
                    _useSimpleLines = !_useSimpleLines;

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

                    _fetchAndSetPolylines();
                  });
                },
              ),
            ],
          ),
          body: Stack(
            children: [
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

  Widget _buildMapView(
    CameraPosition cameraPosition,
    Set<Marker> markers,
    Set<Polyline> polylines,
  ) {
    return GoogleMap(
      initialCameraPosition: cameraPosition,
      markers: markers,
      polylines: polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: true,
      zoomControlsEnabled: true,
      onMapCreated: (controller) {
        if (!mounted) return;
        _mapController = controller;

        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          if (markers.isNotEmpty || polylines.isNotEmpty) {
            _updateCameraBounds();
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
