import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_planner/models/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:trip_planner/services/directions_service.dart'; // Ensure this is the correct import

/// A service class for polyline related utility functions.
class PolylineService {
  // ... getTravelModeColor, getBoundsForPolylines, createDirectPolyline remain the same ...

  /// Decodes an encoded polyline string into a list of LatLng coordinates.
  static List<LatLng> decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];

    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> points = polylinePoints.decodePolyline(encoded);

    return points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  /// Asynchronously fetches route polyline between two locations using DirectionsService.
  /// Uses the detailed polyline from the Directions API result.
  /// Falls back to a direct straight line if the directions request fails or lacks a polyline.
  static Future<List<LatLng>> getRoutePolyline(
    Location? origin,
    Location? destination,
    String travelMode,
    DirectionsService directionsService, { // Pass the service instance
    String? tripId,
    String? originVisitId,
    String? destinationVisitId,
  }) async {
    if (origin?.coordinates == null || destination?.coordinates == null) {
      return []; // Return empty list if coordinates are missing
    }

    try {
      // Request directions from the DirectionsService
      final directionsResult = await directionsService.getDirections(
        origin: origin!,
        destination: destination!,
        travelMode: travelMode,
        tripId: tripId,
        // arrivalTime: null, // Add if needed
      );

      // Check if we got a result and if it has an encoded polyline
      if (directionsResult.polylineEncoded.isNotEmpty) {
        // Decode the polyline string into LatLng points
        final List<LatLng> routePoints = decodePolyline(
          directionsResult.polylineEncoded,
        );
        if (routePoints.isNotEmpty) {
          return routePoints; // Return the detailed route points
        } else {
          debugPrint('PolylineService: Decoded polyline was empty.');
        }
      } else {
        debugPrint(
          'PolylineService: Directions result did not contain an encoded polyline.',
        );
      }

      // Fallback if polyline is missing or decoding failed
      debugPrint('PolylineService: Falling back to direct polyline.');
      return createDirectPolyline(origin, destination);
    } catch (e) {
      debugPrint('Error getting route polyline: $e');
      // Fall back to direct line in case of any error during directions fetching
      return createDirectPolyline(origin, destination);
    }
  }

  /// Creates a simple straight line polyline between two locations.
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

  /// Determines the color of the polyline based on the travel mode.
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
        return Colors.grey; // Default color for unknown modes
    }
  }

  /// Calculates the LatLngBounds that encompass all given polylines.
  static LatLngBounds getBoundsForPolylines(List<Polyline> polylines) {
    if (polylines.isEmpty) {
      // Return a default bounds if no polylines
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

    // Handle case where there might be no points
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
