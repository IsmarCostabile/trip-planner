import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_planner/models/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:trip_planner/services/directions_service.dart';

class PolylineService {
  static List<LatLng> decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];

    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> points = polylinePoints.decodePolyline(encoded);

    return points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  static Future<List<LatLng>> getRoutePolyline(
    Location? origin,
    Location? destination,
    String travelMode,
    DirectionsService directionsService, {
    String? tripId,
    String? originVisitId,
    String? destinationVisitId,
  }) async {
    if (origin?.coordinates == null || destination?.coordinates == null) {
      return [];
    }

    try {
      final directionsResult = await directionsService.getDirections(
        origin: origin!,
        destination: destination!,
        travelMode: travelMode,
        tripId: tripId,
      );

      if (directionsResult.polylineEncoded.isNotEmpty) {
        final List<LatLng> routePoints = decodePolyline(
          directionsResult.polylineEncoded,
        );
        if (routePoints.isNotEmpty) {
          return routePoints;
        } else {
          debugPrint('PolylineService: Decoded polyline was empty.');
        }
      } else {
        debugPrint(
          'PolylineService: Directions result did not contain an encoded polyline.',
        );
      }

      debugPrint('PolylineService: Falling back to direct polyline.');
      return createDirectPolyline(origin, destination);
    } catch (e) {
      debugPrint('Error getting route polyline: $e');
      return createDirectPolyline(origin, destination);
    }
  }

  static List<LatLng> createDirectPolyline(
    Location? origin,
    Location? destination,
  ) {
    if (origin?.coordinates == null || destination?.coordinates == null) {
      return [];
    }
    return [
      LatLng(origin!.coordinates.latitude, origin.coordinates.longitude),
      LatLng(
        destination!.coordinates.latitude,
        destination.coordinates.longitude,
      ),
    ];
  }

  static Color getTravelModeColor(String travelMode) {
    switch (travelMode.toLowerCase()) {
      case 'driving':
        return Colors.blue;
      case 'walking':
        return Colors.green;
      case 'bicycling':
        return Colors.orange;
      case 'transit':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  static LatLngBounds getBoundsForPolylines(List<Polyline> polylines) {
    if (polylines.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(1, 1),
      );
    }

    double? minLat, maxLat, minLng, maxLng;

    for (final polyline in polylines) {
      for (final point in polyline.points) {
        if (minLat == null || point.latitude < minLat) {
          minLat = point.latitude;
        }
        if (maxLat == null || point.latitude > maxLat) {
          maxLat = point.latitude;
        }
        if (minLng == null || point.longitude < minLng) {
          minLng = point.longitude;
        }
        if (maxLng == null || point.longitude > maxLng) {
          maxLng = point.longitude;
        }
      }
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(1, 1),
      );
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
