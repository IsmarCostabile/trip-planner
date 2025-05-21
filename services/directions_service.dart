import 'dart:async'; // Add
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Import LatLng
import 'package:http/http.dart' as http;
import 'package:trip_planner/models/location.dart';
import 'package:trip_planner/services/directions_cache_service.dart';
import 'package:trip_planner/models/transit_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // Add missing Provider import

class DirectionsResult {
  final String duration;
  final String distance;
  final String durationValue; // seconds
  final String distanceValue; // meters
  final List<Step> steps;
  final String polylineEncoded; // Add encoded polyline

  DirectionsResult({
    required this.duration,
    required this.distance,
    required this.durationValue,
    required this.distanceValue,
    this.steps = const [],
    required this.polylineEncoded, // Make required
  });

  factory DirectionsResult.fromJson(Map<String, dynamic> json) {
    final routes = json['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      // ...existing error handling...
      debugPrint(
        'DirectionsAPI: No routes found in response: ${json['status']}',
      );
      debugPrint(
        'DirectionsAPI: Error message: ${json['error_message'] ?? 'No error message'}',
      );
      throw Exception('No routes found: ${json['status']}');
    }

    final route = routes[0]; // Get the first route
    final legs = route['legs'] as List?;
    if (legs == null || legs.isEmpty) {
      throw Exception('No route legs found');
    }

    final leg = legs[0];

    // Parse steps if available
    List<Step> steps = [];
    if (leg['steps'] != null) {
      steps =
          (leg['steps'] as List)
              .map((stepJson) => Step.fromJson(stepJson)) // Use Step.fromJson
              .toList();
    }

    // Get the overview polyline
    final overviewPolyline = route['overview_polyline']?['points'] as String?;
    if (overviewPolyline == null || overviewPolyline.isEmpty) {
      debugPrint('DirectionsAPI: Overview polyline not found or empty.');
      // Throw an exception if polyline is missing from API response
      throw Exception('Overview polyline not found in API response');
    }

    return DirectionsResult(
      duration: leg['duration']['text'] as String,
      distance: leg['distance']['text'] as String,
      durationValue: (leg['duration']['value'] ?? 0).toString(),
      distanceValue: (leg['distance']['value'] ?? 0).toString(),
      steps: steps,
      polylineEncoded: overviewPolyline, // Pass the parsed polyline
    );
  }

  // Add toMap method for Firestore serialization
  Map<String, dynamic> toMap() {
    return {
      'duration': duration,
      'distance': distance,
      'durationValue': durationValue,
      'distanceValue': distanceValue,
      // Omit steps for simplicity in cache, reconstruct if needed elsewhere
      'polylineEncoded': polylineEncoded, // *** Ensure polyline is included ***
      // Timestamp is added by CacheService before saving
    };
  }

  // Add fromMap factory for Firestore deserialization
  factory DirectionsResult.fromMap(Map<String, dynamic> map) {
    // Reconstruct steps from cache if they were stored and are needed
    // List<Step> steps = (map['steps'] as List?)
    //     ?.map((stepMap) => Step.fromMap(Map<String, dynamic>.from(stepMap)))
    //     .toList() ?? [];

    return DirectionsResult(
      duration: map['duration'] ?? '',
      distance: map['distance'] ?? '',
      durationValue: map['durationValue'] ?? '0',
      distanceValue: map['distanceValue'] ?? '0',
      // steps: steps, // Assign reconstructed steps if needed
      polylineEncoded:
          map['polylineEncoded'] ?? '', // *** Ensure polyline is retrieved ***
    );
  }
}

class Step {
  final String htmlInstructions;
  final String distance; // text
  final String duration; // text
  final String travelMode;
  final LatLng startLocation;
  final LatLng endLocation;
  final String polylineEncoded; // Polyline for this specific step
  final TransitDetails? transitDetails;

  Step({
    required this.htmlInstructions,
    required this.distance,
    required this.duration,
    required this.travelMode,
    required this.startLocation,
    required this.endLocation,
    required this.polylineEncoded,
    this.transitDetails,
  });

  // Factory to create Step from JSON (API response)
  factory Step.fromJson(Map<String, dynamic> json) {
    final startLoc = json['start_location'];
    final endLoc = json['end_location'];

    TransitDetails? transitDetails;
    if (json['transit_details'] != null) {
      final details = json['transit_details'];
      transitDetails = TransitDetails(
        lineName: details['line']?['short_name'] ?? details['line']?['name'],
        vehicleType: details['vehicle']?['type']?.toString().toUpperCase(),
        departureStop: details['departure_stop']?['name'],
        arrivalStop: details['arrival_stop']?['name'],
        headsign: details['headsign'],
        numStops: details['num_stops'],
        duration: json['duration']?['text'], // Use step duration
      );
    }

    return Step(
      htmlInstructions: json['html_instructions'] ?? '',
      distance: json['distance']?['text'] ?? '',
      duration: json['duration']?['text'] ?? '',
      travelMode: json['travel_mode'] ?? 'UNKNOWN',
      startLocation: LatLng(startLoc?['lat'] ?? 0.0, startLoc?['lng'] ?? 0.0),
      endLocation: LatLng(endLoc?['lat'] ?? 0.0, endLoc?['lng'] ?? 0.0),
      polylineEncoded: json['polyline']?['points'] ?? '',
      transitDetails: transitDetails,
    );
  }

  // Convert to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'htmlInstructions': htmlInstructions,
      'distance': distance,
      'duration': duration,
      'travelMode': travelMode,
      'startLocation': {
        // Store LatLng as map
        'latitude': startLocation.latitude,
        'longitude': startLocation.longitude,
      },
      'endLocation': {
        // Store LatLng as map
        'latitude': endLocation.latitude,
        'longitude': endLocation.longitude,
      },
      'polylineEncoded': polylineEncoded,
      'transitDetails': transitDetails?.toJson(),
    };
  }

  // Create from Firestore map
  factory Step.fromMap(Map<String, dynamic> map) {
    final startLocMap = map['startLocation'] as Map<String, dynamic>?;
    final endLocMap = map['endLocation'] as Map<String, dynamic>?;
    return Step(
      htmlInstructions: map['htmlInstructions'] ?? '',
      distance: map['distance'] ?? '',
      duration: map['duration'] ?? '',
      travelMode: map['travelMode'] ?? 'UNKNOWN',
      startLocation: LatLng(
        // Create LatLng from map
        startLocMap?['latitude'] ?? 0.0,
        startLocMap?['longitude'] ?? 0.0,
      ),
      endLocation: LatLng(
        // Create LatLng from map
        endLocMap?['latitude'] ?? 0.0,
        endLocMap?['longitude'] ?? 0.0,
      ),
      polylineEncoded: map['polylineEncoded'] ?? '',
      transitDetails:
          map['transitDetails'] != null
              ? TransitDetails.fromJson(
                Map<String, dynamic>.from(map['transitDetails']),
              )
              : null,
    );
  }
}

class DirectionsService {
  final String _apiKey;
  final http.Client _httpClient;
  final DirectionsCacheService _cacheService = DirectionsCacheService();

  // Flag to enable/disable caching (enabled by default)
  final bool _useCache;

  // Flag to control verbose debug logs - setting to true temporarily
  final bool _verboseLogging = true;

  DirectionsService({
    required String apiKey,
    http.Client? httpClient,
    bool useCache = true,
  }) : _apiKey = apiKey,
       _httpClient = httpClient ?? http.Client(),
       _useCache = useCache;

  Future<DirectionsResult> getDirections({
    required Location origin,
    required Location destination,
    String travelMode = 'transit',
    String? tripId,
    DateTime? arrivalTime,
  }) async {
    // Try to get from cache first if caching is enabled
    if (_useCache) {
      try {
        final cachedResult = await _cacheService.getDirections(
          origin,
          destination,
          travelMode,
          tripId: tripId,
        );

        if (cachedResult != null) {
          if (_verboseLogging) {
            debugPrint('DirectionsAPI: Using cached result');
          }
          return cachedResult;
        }
      } catch (e) {
        debugPrint('DirectionsAPI: Error retrieving from cache: $e');
      }
    }

    // If not in cache or cache disabled, proceed with API call
    final originParam =
        '${origin.coordinates.latitude},${origin.coordinates.longitude}';
    final destParam =
        '${destination.coordinates.latitude},${destination.coordinates.longitude}';

    // Add current timestamp for time parameters
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final params = {
      'origin': originParam,
      'destination': destParam,
      'mode': travelMode,
      'key': _apiKey,
    };

    // Add transit-specific parameters when using transit mode
    if (travelMode == 'transit') {
      // If arrivalTime is specified, use it to calculate routes that arrive by that time
      // Otherwise use current time as departure time
      if (arrivalTime != null) {
        // Convert DateTime to UNIX timestamp (seconds)
        final arrivalTimestamp = arrivalTime.millisecondsSinceEpoch ~/ 1000;
        params['arrival_time'] = arrivalTimestamp.toString();

        if (_verboseLogging) {
          debugPrint('DirectionsAPI: Using arrival time: $arrivalTime');
        }
      } else {
        params['departure_time'] = now.toString();
      }

      params['transit_mode'] =
          'bus|subway|train|tram'; // Google accepts this format
    }

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      params,
    );

    try {
      if (_verboseLogging) {
        debugPrint(
          'DirectionsAPI: Requesting ${url.toString().replaceAll(_apiKey, 'API_KEY')}',
        );
      }
      final response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        /*  // *** ADD DETAILED LOGGING HERE ***
        if (_verboseLogging) {
          debugPrint('DirectionsAPI: Raw JSON Response:');
          // Use jsonEncode for pretty printing
          JsonEncoder encoder = const JsonEncoder.withIndent('  ');
          String prettyprint = encoder.convert(jsonResponse);
          debugPrint(prettyprint);
        } */
        // *** END LOGGING ***

        // Check for API-level errors
        final status = jsonResponse['status'];
        if (status != 'OK') {
          if (_verboseLogging) {
            debugPrint('DirectionsAPI: Error status: $status');
            debugPrint(
              'DirectionsAPI: Error message: ${jsonResponse['error_message'] ?? 'No error message'}',
            );
          }

          // Special handling for ZERO_RESULTS status
          if (status == 'ZERO_RESULTS') {
            // Check available travel modes
            final availableModes =
                jsonResponse['available_travel_modes'] as List?;
            final String modesMessage =
                availableModes != null && availableModes.isNotEmpty
                    ? 'Available modes: ${availableModes.join(", ")}'
                    : 'No travel modes available';

            if (_verboseLogging) {
              debugPrint(
                'DirectionsAPI: No routes found for $travelMode. $modesMessage',
              );
            }

            throw Exception(
              'No routes found for $travelMode mode. Try another travel mode.',
            );
          }

          throw Exception('Directions API error: $status');
        }

        // *** Potential issue point: Parsing ***
        final result = DirectionsResult.fromJson(jsonResponse);

        // Log the parsed polyline
        if (_verboseLogging) {
          debugPrint(
            'DirectionsAPI: Parsed polylineEncoded length: ${result.polylineEncoded.length}',
          );
        }

        // Store successful result in cache
        if (_useCache) {
          await _cacheService.storeDirections(
            origin,
            destination,
            travelMode,
            result,
            tripId: tripId,
          );
        }

        return result;
      } else {
        if (_verboseLogging) {
          debugPrint('DirectionsAPI: HTTP error: ${response.statusCode}');
          debugPrint('DirectionsAPI: Response body: ${response.body}');
        }
        throw Exception('Failed to load directions: ${response.statusCode}');
      }
    } catch (e) {
      if (_verboseLogging) {
        debugPrint('DirectionsAPI: Exception during request: $e');
      }

      rethrow;
    }
  }

  /// Save user's preferred travel mode for a specific route
  Future<void> savePreferredTravelMode(
    Location origin,
    Location destination,
    String travelMode, {
    required String tripId,
    String? originVisitId,
    String? destinationVisitId,
  }) async {
    // If we have visit IDs, use the new trip day-based approach
    if (originVisitId != null && destinationVisitId != null) {
      await _saveTravelModeInTripDay(
        tripId,
        originVisitId,
        destinationVisitId,
        travelMode,
      );
    } else {
      // Fall back to the old approach for backward compatibility
      await _cacheService.storePreferredTravelMode(
        origin,
        destination,
        travelMode,
        tripId: tripId,
      );
    }
  }

  /// Get user's preferred travel mode for a specific route
  Future<String?> getPreferredTravelMode(
    Location origin,
    Location destination, {
    required String tripId,
    String? originVisitId,
    String? destinationVisitId,
  }) async {
    // If we have visit IDs, use the new trip day-based approach
    if (originVisitId != null && destinationVisitId != null) {
      final mode = await _getTravelModeFromTripDay(
        tripId,
        originVisitId,
        destinationVisitId,
      );
      if (mode != null) {
        return mode;
      }
    }

    // Fall back to the old approach if new approach didn't yield results
    return await _cacheService.getPreferredTravelMode(
      origin,
      destination,
      tripId: tripId,
    );
  }

  /// New method to save travel mode in TripDay
  Future<void> _saveTravelModeInTripDay(
    String tripId,
    String originVisitId,
    String destinationVisitId,
    String travelMode,
  ) async {
    try {
      // Find the trip day that contains these visits
      final firestore = FirebaseFirestore.instance;

      // Query to find the trip day containing the origin visit
      final querySnapshot =
          await firestore
              .collection('tripDays')
              .where('tripId', isEqualTo: tripId)
              .get();

      // Find the trip day that contains both visits
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final visits = data['visits'] as List<dynamic>?;

        if (visits != null) {
          // Check if this trip day contains both visits
          final containsOrigin = visits.any(
            (v) => v is Map && v['id'] == originVisitId,
          );
          final containsDestination = visits.any(
            (v) => v is Map && v['id'] == destinationVisitId,
          );

          if (containsOrigin && containsDestination) {
            // This is the trip day we want to update
            final tripDayId = doc.id;

            // Get current travel segments
            List<Map<String, dynamic>> travelSegments = [];
            if (data.containsKey('travelSegments') &&
                data['travelSegments'] != null) {
              travelSegments = List<Map<String, dynamic>>.from(
                data['travelSegments'] as List,
              );
            }

            // Look for existing segment
            int existingIndex = -1;
            for (int i = 0; i < travelSegments.length; i++) {
              final segment = travelSegments[i];
              if (segment['originVisitId'] == originVisitId &&
                  segment['destinationVisitId'] == destinationVisitId) {
                existingIndex = i;
                break;
              }
            }

            if (existingIndex >= 0) {
              // Update existing segment
              travelSegments[existingIndex] = {
                'originVisitId': originVisitId,
                'destinationVisitId': destinationVisitId,
                'travelMode': travelMode,
              };
            } else {
              // Add new segment
              travelSegments.add({
                'originVisitId': originVisitId,
                'destinationVisitId': destinationVisitId,
                'travelMode': travelMode,
              });
            }

            // Update the trip day with the new travel segments
            await firestore.collection('tripDays').doc(tripDayId).update({
              'travelSegments': travelSegments,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            if (_verboseLogging) {
              debugPrint(
                'DirectionsService: Saved travel mode $travelMode for visits $originVisitId -> $destinationVisitId',
              );
            }

            return;
          }
        }
      }

      if (_verboseLogging) {
        debugPrint(
          'DirectionsService: Could not find trip day containing both visits',
        );
      }
    } catch (e) {
      if (_verboseLogging) {
        debugPrint('DirectionsService: Error saving travel mode: $e');
      }
    }
  }

  /// New method to get travel mode from TripDay
  Future<String?> _getTravelModeFromTripDay(
    String tripId,
    String originVisitId,
    String destinationVisitId,
  ) async {
    try {
      // Find the trip day that contains these visits
      final firestore = FirebaseFirestore.instance;

      // Query to find the trip day containing the origin visit
      final querySnapshot =
          await firestore
              .collection('tripDays')
              .where('tripId', isEqualTo: tripId)
              .get();

      // Find the trip day that contains both visits
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final visits = data['visits'] as List<dynamic>?;

        if (visits != null) {
          // Check if this trip day contains both visits
          final containsOrigin = visits.any(
            (v) => v is Map && v['id'] == originVisitId,
          );
          final containsDestination = visits.any(
            (v) => v is Map && v['id'] == destinationVisitId,
          );

          if (containsOrigin && containsDestination) {
            // Check travel segments
            final travelSegments = data['travelSegments'] as List<dynamic>?;

            if (travelSegments != null) {
              for (final segment in travelSegments) {
                if (segment is Map &&
                    segment['originVisitId'] == originVisitId &&
                    segment['destinationVisitId'] == destinationVisitId) {
                  // Found the travel segment
                  return segment['travelMode'] as String?;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (_verboseLogging) {
        debugPrint('DirectionsService: Error getting travel mode: $e');
      }
    }

    return null;
  }

  /// Get a stream of travel mode preferences for a specific route
  Stream<String> listenToTravelModePreference(
    Location origin,
    Location destination, {
    required String tripId,
    String? originVisitId,
    String? destinationVisitId,
  }) {
    // If we have both visit IDs, set up a stream that combines data from both approaches
    if (originVisitId != null && destinationVisitId != null) {
      // Create a stream controller to combine both sources
      final controller = StreamController<String>.broadcast();

      // Listen to trip day changes first (these have priority)
      final tripDayStream = _listenToTripDayTravelModes(
        tripId,
        originVisitId,
        destinationVisitId,
      );

      // Add trip day stream to our combined stream
      tripDayStream.listen((travelMode) {
        if (!controller.isClosed) controller.add(travelMode);
      });

      // Also listen to the legacy cache service approach as fallback
      final legacyStream = _cacheService.listenToTravelModePreference(
        origin,
        destination,
        tripId: tripId,
      );

      legacyStream.listen((travelMode) {
        // Only add if we don't have better data from trip day
        if (!controller.isClosed) controller.add(travelMode);
      });

      return controller.stream;
    }

    // If we don't have visit IDs, just use the cache service approach
    return _cacheService.listenToTravelModePreference(
      origin,
      destination,
      tripId: tripId,
    );
  }

  /// Listen to travel mode changes in trip days
  Stream<String> _listenToTripDayTravelModes(
    String tripId,
    String originVisitId,
    String destinationVisitId,
  ) {
    final controller = StreamController<String>.broadcast();

    FirebaseFirestore.instance
        .collection('tripDays')
        .where('tripId', isEqualTo: tripId)
        .snapshots()
        .listen(
          (snapshot) {
            // Find trip day with both visits
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final visits = data['visits'] as List<dynamic>?;

              if (visits == null) continue;

              // Check if this trip day contains both visits
              final containsOrigin = visits.any(
                (v) => v is Map && v['id'] == originVisitId,
              );
              final containsDestination = visits.any(
                (v) => v is Map && v['id'] == destinationVisitId,
              );

              if (containsOrigin && containsDestination) {
                // Check travel segments
                final travelSegments = data['travelSegments'] as List<dynamic>?;

                if (travelSegments != null) {
                  for (final segment in travelSegments) {
                    if (segment is Map &&
                        segment['originVisitId'] == originVisitId &&
                        segment['destinationVisitId'] == destinationVisitId &&
                        segment['travelMode'] != null) {
                      // Found the travel segment, add to stream
                      if (!controller.isClosed) {
                        controller.add(segment['travelMode'] as String);
                      }
                      break;
                    }
                  }
                }
              }
            }
          },
          onError: (error) {
            if (_verboseLogging) {
              debugPrint(
                'DirectionsService: Error listening to travel modes: $error',
              );
            }
          },
        );

    return controller.stream;
  }

  /// Clear in-memory cache only
  void clearCache() {
    _cacheService.clearCache();
  }

  /// Clear trip-specific cache data
  Future<void> clearTripCache(String tripId) async {
    await _cacheService.clearTripCache(tripId);
  }

  void dispose() {
    _httpClient.close();
  }
}
