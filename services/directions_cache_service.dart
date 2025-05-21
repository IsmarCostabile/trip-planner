import 'dart:async'; // Add import for StreamSubscription and StreamController
import 'package:trip_planner/services/directions_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_planner/models/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // Add missing Provider import

/// A service that caches direction results to reduce API calls
class DirectionsCacheService {
  // In-memory cache for direction results
  // Key format: "${originLat}_${originLng}_${destLat}_${destLng}_${travelMode}"
  final Map<String, CachedDirectionResult> _cache = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controllers for travel mode preferences
  final Map<String, StreamController<String>> _travelModeStreamControllers = {};
  final Map<String, StreamSubscription> _travelModeSubscriptions = {};

  // Cache expiration duration (30 minutes for in-memory, 7 days for Firestore)
  static const Duration _inMemoryCacheDuration = Duration(minutes: 30);
  static const Duration _firestoreCacheDuration = Duration(days: 7);

  /// Get cached directions if available and not expired
  /// Checks in-memory cache first, then Firestore
  Future<DirectionsResult?> getDirections(
    Location origin,
    Location destination,
    String travelMode, {
    String? tripId,
  }) async {
    // Skip if coordinates are null
    if (origin.coordinates == null || destination.coordinates == null) {
      return null;
    }

    final originLat = origin.coordinates!.latitude;
    final originLng = origin.coordinates!.longitude;
    final destLat = destination.coordinates!.latitude;
    final destLng = destination.coordinates!.longitude;

    final key = _generateKey(
      originLat,
      originLng,
      destLat,
      destLng,
      travelMode,
    );

    // Check in-memory cache first
    final cachedResult = _cache[key];
    if (cachedResult != null) {
      // Check if cache is still valid
      if (DateTime.now().difference(cachedResult.timestamp) <
          _inMemoryCacheDuration) {
        return cachedResult.result;
      } else {
        // Remove expired cache entry
        _cache.remove(key);
      }
    }

    // If not in memory cache or expired, try Firestore
    try {
      // Try to read from shared collection first (no trip ID required)
      final sharedDocRef = _firestore.collection('directionsCache').doc(key);

      final sharedDoc = await sharedDocRef.get();
      if (sharedDoc.exists) {
        final data = sharedDoc.data();
        if (data != null) {
          // Check if Firestore cache is expired
          final timestamp = data['timestamp'] as Timestamp;
          if (DateTime.now().difference(timestamp.toDate()) <
              _firestoreCacheDuration) {
            // Convert Firestore data to DirectionsResult
            final result = DirectionsResult.fromMap(data);

            // Store in memory cache to avoid future Firestore reads
            _cache[key] = CachedDirectionResult(
              result: result,
              timestamp: timestamp.toDate(),
            );

            return result;
          } else {
            // Delete expired cache entry
            await sharedDocRef.delete();
          }
        }
      }

      // If no shared cache and tripId is provided, try trip-specific cache
      if (tripId != null) {
        final tripDocRef = _firestore
            .collection('trips')
            .doc(tripId)
            .collection('directionsCache')
            .doc(key);

        final tripDoc = await tripDocRef.get();
        if (tripDoc.exists) {
          final data = tripDoc.data();
          if (data != null) {
            // Check if Firestore cache is expired
            final timestamp = data['timestamp'] as Timestamp;
            if (DateTime.now().difference(timestamp.toDate()) <
                _firestoreCacheDuration) {
              // Convert Firestore data to DirectionsResult
              final result = DirectionsResult.fromMap(data);

              // Store in memory cache to avoid future Firestore reads
              _cache[key] = CachedDirectionResult(
                result: result,
                timestamp: timestamp.toDate(),
              );

              return result;
            } else {
              // Delete expired cache entry
              await tripDocRef.delete();
            }
          }
        }
      }
    } catch (e) {
      // If Firestore read fails, just continue without the cached data
      print('Error reading from Firestore cache: $e');
    }

    return null;
  }

  /// Store directions result in both in-memory cache and Firestore
  Future<void> storeDirections(
    Location origin,
    Location destination,
    String travelMode,
    DirectionsResult result, {
    String? tripId,
  }) async {
    // Skip if coordinates are null
    if (origin.coordinates == null || destination.coordinates == null) {
      return;
    }

    final originLat = origin.coordinates!.latitude;
    final originLng = origin.coordinates!.longitude;
    final destLat = destination.coordinates!.latitude;
    final destLng = destination.coordinates!.longitude;

    final key = _generateKey(
      originLat,
      originLng,
      destLat,
      destLng,
      travelMode,
    );

    // Store in memory cache
    _cache[key] = CachedDirectionResult(
      result: result,
      timestamp: DateTime.now(),
    );

    try {
      // Create a map for Firestore storage
      final dataToStore = result.toMap();

      // Always store in shared collection for reuse across trips
      await _firestore.collection('directionsCache').doc(key).set(dataToStore);

      // If tripId is provided, also store in trip-specific collection
      if (tripId != null) {
        await _firestore
            .collection('trips')
            .doc(tripId)
            .collection('directionsCache')
            .doc(key)
            .set(dataToStore);
      }
    } catch (e) {
      // If Firestore write fails, we still have the in-memory cache
      print('Error saving to Firestore cache: $e');
    }
  }

  /// Store travel mode preference for a specific route in a trip
  Future<void> storePreferredTravelMode(
    Location origin,
    Location destination,
    String travelMode, {
    required String tripId,
  }) async {
    // Skip if coordinates are null or tripId missing
    if (origin.coordinates == null ||
        destination.coordinates == null ||
        tripId.isEmpty) {
      return;
    }

    try {
      final originId =
          origin.placeId.isNotEmpty
              ? origin.placeId
              : '${origin.coordinates!.latitude},${origin.coordinates!.longitude}';
      final destId =
          destination.placeId.isNotEmpty
              ? destination.placeId
              : '${destination.coordinates!.latitude},${destination.coordinates!.longitude}';

      final preferenceKey = 'travel_mode_pref_${originId}_to_${destId}';

      // Store the preference at trip level
      await _firestore
          .collection('trips')
          .doc(tripId)
          .collection('travelPreferences')
          .doc(preferenceKey)
          .set({
            'travelMode': travelMode,
            'originId': originId,
            'destinationId': destId,
            'originName': origin.name,
            'destinationName': destination.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error storing preferred travel mode: $e');
    }
  }

  /// Get travel mode preference for a specific route in a trip
  Future<String?> getPreferredTravelMode(
    Location origin,
    Location destination, {
    required String tripId,
  }) async {
    // Skip if coordinates are null or tripId missing
    if (origin.coordinates == null ||
        destination.coordinates == null ||
        tripId.isEmpty) {
      return null;
    }

    try {
      final originId =
          origin.placeId.isNotEmpty
              ? origin.placeId
              : '${origin.coordinates!.latitude},${origin.coordinates!.longitude}';
      final destId =
          destination.placeId.isNotEmpty
              ? destination.placeId
              : '${destination.coordinates!.latitude},${destination.coordinates!.longitude}';

      final preferenceKey = 'travel_mode_pref_${originId}_to_${destId}';

      final doc =
          await _firestore
              .collection('trips')
              .doc(tripId)
              .collection('travelPreferences')
              .doc(preferenceKey)
              .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          return data['travelMode'] as String?;
        }
      }
    } catch (e) {
      print('Error getting preferred travel mode: $e');
    }

    return null;
  }

  /// Get a stream of travel mode preferences for a specific route
  Stream<String> listenToTravelModePreference(
    Location origin,
    Location destination, {
    required String tripId,
  }) {
    // Create a key for this origin-destination pair
    final originId =
        origin.placeId.isNotEmpty
            ? origin.placeId
            : '${origin.coordinates?.latitude ?? 0},${origin.coordinates?.longitude ?? 0}';
    final destId =
        destination.placeId.isNotEmpty
            ? destination.placeId
            : '${destination.coordinates?.latitude ?? 0},${destination.coordinates?.longitude ?? 0}';

    final preferenceKey = 'travel_mode_pref_${originId}_to_${destId}';

    // Check if a controller already exists for this key
    if (!_travelModeStreamControllers.containsKey(preferenceKey)) {
      // Create a new controller
      _travelModeStreamControllers[preferenceKey] =
          StreamController<String>.broadcast();

      // Subscribe to Firestore updates
      _travelModeSubscriptions[preferenceKey] = _firestore
          .collection('trips')
          .doc(tripId)
          .collection('travelPreferences')
          .doc(preferenceKey)
          .snapshots()
          .listen(
            (snapshot) {
              if (snapshot.exists && snapshot.data() != null) {
                final travelMode = snapshot.data()!['travelMode'] as String?;
                if (travelMode != null) {
                  _travelModeStreamControllers[preferenceKey]!.add(travelMode);
                }
              }
            },
            onError: (error) {
              print('Error listening to travel mode preferences: $error');
            },
          );
    }

    return _travelModeStreamControllers[preferenceKey]!.stream;
  }

  /// Dispose of resources
  void dispose() {
    // Cancel all subscriptions and close all controllers
    for (final subscription in _travelModeSubscriptions.values) {
      subscription.cancel();
    }
    for (final controller in _travelModeStreamControllers.values) {
      controller.close();
    }
    _travelModeStreamControllers.clear();
    _travelModeSubscriptions.clear();
  }

  /// Generate a unique cache key based on locations and travel mode
  String _generateKey(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
    String travelMode,
  ) {
    return "${originLat}_${originLng}_${destLat}_${destLng}_${travelMode}";
  }

  /// Clear in-memory cache
  void clearCache() {
    _cache.clear();
  }

  /// Clear trip-specific cache data
  Future<void> clearTripCache(String tripId) async {
    if (tripId.isEmpty) return;

    try {
      // Clear travel preferences
      final prefsSnapshot =
          await _firestore
              .collection('trips')
              .doc(tripId)
              .collection('travelPreferences')
              .limit(100)
              .get();

      if (prefsSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in prefsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // If there are more documents, recursively clear them
        if (prefsSnapshot.docs.length >= 100) {
          await clearTripCache(tripId);
        }
      }

      // Clear directions cache
      final cacheSnapshot =
          await _firestore
              .collection('trips')
              .doc(tripId)
              .collection('directionsCache')
              .limit(100)
              .get();

      if (cacheSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in cacheSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // If there are more documents, recursively clear them
        if (cacheSnapshot.docs.length >= 100) {
          await clearTripCache(tripId);
        }
      }
    } catch (e) {
      print('Error clearing trip cache: $e');
    }
  }
}

/// Class to store a cached result with its timestamp
class CachedDirectionResult {
  final DirectionsResult result;
  final DateTime timestamp;

  CachedDirectionResult({required this.result, required this.timestamp});
}
