import 'dart:async';
import 'package:trip_planner/services/directions_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_planner/models/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

class DirectionsCacheService {
  final Map<String, CachedDirectionResult> _cache = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamController<String>> _travelModeStreamControllers = {};
  final Map<String, StreamSubscription> _travelModeSubscriptions = {};
  static const Duration _inMemoryCacheDuration = Duration(minutes: 30);
  static const Duration _firestoreCacheDuration = Duration(days: 7);

  Future<DirectionsResult?> getDirections(
    Location origin,
    Location destination,
    String travelMode, {
    String? tripId,
  }) async {
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

    final cachedResult = _cache[key];
    if (cachedResult != null) {
      if (DateTime.now().difference(cachedResult.timestamp) <
          _inMemoryCacheDuration) {
        return cachedResult.result;
      } else {
        _cache.remove(key);
      }
    }

    try {
      final sharedDocRef = _firestore.collection('directionsCache').doc(key);

      final sharedDoc = await sharedDocRef.get();
      if (sharedDoc.exists) {
        final data = sharedDoc.data();
        if (data != null) {
          final timestamp = data['timestamp'] as Timestamp;
          if (DateTime.now().difference(timestamp.toDate()) <
              _firestoreCacheDuration) {
            final result = DirectionsResult.fromMap(data);

            _cache[key] = CachedDirectionResult(
              result: result,
              timestamp: timestamp.toDate(),
            );

            return result;
          } else {
            await sharedDocRef.delete();
          }
        }
      }

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
            final timestamp = data['timestamp'] as Timestamp;
            if (DateTime.now().difference(timestamp.toDate()) <
                _firestoreCacheDuration) {
              final result = DirectionsResult.fromMap(data);

              _cache[key] = CachedDirectionResult(
                result: result,
                timestamp: timestamp.toDate(),
              );

              return result;
            } else {
              await tripDocRef.delete();
            }
          }
        }
      }
    } catch (e) {
      print('Error reading from Firestore cache: $e');
    }

    return null;
  }

  Future<void> storeDirections(
    Location origin,
    Location destination,
    String travelMode,
    DirectionsResult result, {
    String? tripId,
  }) async {
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

    _cache[key] = CachedDirectionResult(
      result: result,
      timestamp: DateTime.now(),
    );

    try {
      final dataToStore = result.toMap();

      await _firestore.collection('directionsCache').doc(key).set(dataToStore);

      if (tripId != null) {
        await _firestore
            .collection('trips')
            .doc(tripId)
            .collection('directionsCache')
            .doc(key)
            .set(dataToStore);
      }
    } catch (e) {
      print('Error saving to Firestore cache: $e');
    }
  }

  Future<void> storePreferredTravelMode(
    Location origin,
    Location destination,
    String travelMode, {
    required String tripId,
  }) async {
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

  Future<String?> getPreferredTravelMode(
    Location origin,
    Location destination, {
    required String tripId,
  }) async {
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

  Stream<String> listenToTravelModePreference(
    Location origin,
    Location destination, {
    required String tripId,
  }) {
    final originId =
        origin.placeId.isNotEmpty
            ? origin.placeId
            : '${origin.coordinates?.latitude ?? 0},${origin.coordinates?.longitude ?? 0}';
    final destId =
        destination.placeId.isNotEmpty
            ? destination.placeId
            : '${destination.coordinates?.latitude ?? 0},${destination.coordinates?.longitude ?? 0}';

    final preferenceKey = 'travel_mode_pref_${originId}_to_${destId}';

    if (!_travelModeStreamControllers.containsKey(preferenceKey)) {
      _travelModeStreamControllers[preferenceKey] =
          StreamController<String>.broadcast();

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

  void dispose() {
    for (final subscription in _travelModeSubscriptions.values) {
      subscription.cancel();
    }
    for (final controller in _travelModeStreamControllers.values) {
      controller.close();
    }
    _travelModeStreamControllers.clear();
    _travelModeSubscriptions.clear();
  }

  String _generateKey(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
    String travelMode,
  ) {
    return "${originLat}_${originLng}_${destLat}_${destLng}_${travelMode}";
  }

  void clearCache() {
    _cache.clear();
  }

  Future<void> clearTripCache(String tripId) async {
    if (tripId.isEmpty) return;

    try {
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

        if (prefsSnapshot.docs.length >= 100) {
          await clearTripCache(tripId);
        }
      }

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

        if (cacheSnapshot.docs.length >= 100) {
          await clearTripCache(tripId);
        }
      }
    } catch (e) {
      print('Error clearing trip cache: $e');
    }
  }
}

class CachedDirectionResult {
  final DirectionsResult result;
  final DateTime timestamp;

  CachedDirectionResult({required this.result, required this.timestamp});
}
