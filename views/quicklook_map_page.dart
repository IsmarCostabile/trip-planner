import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_planner/models/location.dart';
import 'package:trip_planner/models/visit.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/trip_data_service.dart';

class QuickLookMapPage extends StatefulWidget {
  final Visit? visit;
  final Location? location;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String heroTag;

  const QuickLookMapPage({
    super.key,
    this.visit,
    this.location,
    this.latitude,
    this.longitude,
    this.locationName,
    required this.heroTag,
  }) : assert(
         (visit != null) ||
             (location != null) ||
             (latitude != null && longitude != null),
         'Either visit, location, or latitude/longitude pair must be provided',
       );

  @override
  State<QuickLookMapPage> createState() => _QuickLookMapPageState();

  static Future<void> show({
    required BuildContext context,
    Visit? visit,
    Location? location,
    double? latitude,
    double? longitude,
    String? locationName,
    required String heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => QuickLookMapPage(
              visit: visit,
              location: location,
              latitude: latitude,
              longitude: longitude,
              locationName: locationName,
              heroTag: heroTag,
            ),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _QuickLookMapPageState extends State<QuickLookMapPage>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  bool _mapCreated = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  LatLng get _mapCoordinates {
    if (widget.visit?.location?.coordinates != null) {
      final coords = widget.visit!.location!.coordinates;
      return LatLng(coords.latitude, coords.longitude);
    } else if (widget.location?.coordinates != null) {
      final coords = widget.location!.coordinates;
      return LatLng(coords.latitude, coords.longitude);
    } else if (widget.latitude != null && widget.longitude != null) {
      return LatLng(widget.latitude!, widget.longitude!);
    }
    return const LatLng(37.7749, -122.4194);
  }

  String get _locationName {
    if (widget.locationName != null) {
      return widget.locationName!;
    } else if (widget.visit?.location?.name != null) {
      return widget.visit!.location!.name;
    } else if (widget.location?.name != null) {
      return widget.location!.name;
    }
    return 'Location';
  }

  Set<Marker> _createMarkers(BuildContext context) {
    final Set<Marker> markers = {};
    final latLng = _mapCoordinates;

    markers.add(
      Marker(
        markerId: const MarkerId('focus'),
        position: latLng,
        infoWindow: InfoWindow(title: _locationName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    if (widget.visit != null) {
      final tripDataService = Provider.of<TripDataService>(
        context,
        listen: false,
      );
      final visits = tripDataService.getVisitsForDay(
        tripDataService.selectedTripDay?.id ?? '',
      );

      for (final visit in visits) {
        if (visit.id == widget.visit!.id) continue;

        if (visit.location?.coordinates != null) {
          markers.add(
            Marker(
              markerId: MarkerId(visit.id),
              position: LatLng(
                visit.location!.coordinates.latitude,
                visit.location!.coordinates.longitude,
              ),
              infoWindow: InfoWindow(title: visit.location!.name),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          );
        }
      }
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_locationName),
        backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [Hero(tag: widget.heroTag, child: _buildMapView(context))],
      ),
    );
  }

  Widget _buildMapView(BuildContext context) {
    final latLng = _mapCoordinates;
    final cameraPosition = CameraPosition(target: latLng, zoom: 15.0);

    return GoogleMap(
      initialCameraPosition: cameraPosition,
      markers: _createMarkers(context),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: true,
      zoomControlsEnabled: true,
      onMapCreated: (controller) {
        _mapController = controller;

        if (!_mapCreated) {
          _mapCreated = true;
          Future.delayed(const Duration(milliseconds: 300), () {
            controller.animateCamera(
              CameraUpdate.newCameraPosition(cameraPosition),
            );
          });
        }
      },
    );
  }
}
