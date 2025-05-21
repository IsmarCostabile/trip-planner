import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_planner/models/visit.dart';
import 'package:trip_planner/views/quicklook_map_page.dart';

class MiniMapView extends StatefulWidget {
  final Visit visit;
  final String mapId;

  const MiniMapView({super.key, required this.visit, required this.mapId});

  @override
  State<MiniMapView> createState() => _MiniMapViewState();
}

class _MiniMapViewState extends State<MiniMapView>
    with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeMarker();
  }

  void _initializeMarker() {
    if (widget.visit.location?.coordinates != null) {
      final marker = Marker(
        markerId: MarkerId(widget.mapId),
        position: LatLng(
          widget.visit.location!.coordinates.latitude,
          widget.visit.location!.coordinates.longitude,
        ),
      );
      _markers.add(marker);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.visit.location?.coordinates == null) {
      return const SizedBox.shrink();
    }

    return Hero(
      tag: widget.mapId,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          height: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  widget.visit.location!.coordinates.latitude,
                  widget.visit.location!.coordinates.longitude,
                ),
                zoom: 15,
              ),
              markers: _markers,
              onTap:
                  (_) => QuickLookMapPage.show(
                    context: context,
                    visit: widget.visit,
                    heroTag: widget.mapId,
                  ),
              onMapCreated: (controller) {
                _mapController = controller;
                controller.setMapStyle(
                  '[{"featureType":"all","elementType":"labels","stylers":[{"visibility":"off"}]}]',
                );
              },
              zoomControlsEnabled: false,
              zoomGesturesEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              liteModeEnabled: true,
            ),
          ),
        ),
      ),
    );
  }
}
