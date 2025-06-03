import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_day.dart';
import 'package:trip_planner/models/location.dart';
import 'package:trip_planner/models/visit.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/services/directions_service.dart';
import 'package:trip_planner/services/places_service.dart';
import 'package:trip_planner/services/trip_invitation_service.dart';

class TripDataService extends ChangeNotifier {
  static final TripDataService _instance = TripDataService._internal();
  factory TripDataService() => _instance;
  TripDataService._internal();

  Map<String, Trip> _trips = {};
  Map<String, List<TripDay>> _tripDays = {};

  Map<String, List<Visit>> _visitsCache = {};
  Map<String, Location> _locationsCache = {};

  String? _selectedTripId;
  int _selectedDayIndex = 0;

  final _userBox = Hive.box('userBox');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _tripsSubscription;
  StreamSubscription? _tripDaysSubscription;
  StreamSubscription? _userAuthSubscription;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedTripId => _selectedTripId;
  int get selectedDayIndex => _selectedDayIndex;

  Trip? get selectedTrip =>
      _selectedTripId != null ? _trips[_selectedTripId] : null;

  List<TripDay> get selectedTripDays =>
      _selectedTripId != null ? _tripDays[_selectedTripId] ?? [] : [];

  TripDay? get selectedTripDay {
    final days = selectedTripDays;
    if (days.isEmpty || _selectedDayIndex >= days.length) return null;
    return days[_selectedDayIndex];
  }

  List<Trip> get userTrips => _trips.values.toList();

  List<Visit> getVisitsForDay(String tripDayId) {
    return _visitsCache[tripDayId] ?? [];
  }

  void initialize() {
    _userAuthSubscription = _auth.authStateChanges().listen((user) {
      if (user == null) {
        clearCache();
      } else {
        initSelectedTrip();
        _listenToUserTrips();
      }
    });
  }

  void initSelectedTrip() {
    _selectedTripId = _userBox.get('selectedTripId') as String?;
    if (_selectedTripId != null) {
      _selectedDayIndex =
          _userBox.get('selectedDayIndex_$_selectedTripId', defaultValue: 0)
              as int;
      _listenToTripDays(_selectedTripId!);
    }
    notifyListeners();
  }

  Future<void> setSelectedTrip(String? tripId) async {
    if (_selectedTripId == tripId) return;

    _tripDaysSubscription?.cancel();
    _tripDaysSubscription = null;

    _selectedTripId = tripId;

    if (tripId != null) {
      await _userBox.put('selectedTripId', tripId);
      _selectedDayIndex =
          _userBox.get('selectedDayIndex_$tripId', defaultValue: 0) as int;
      _listenToTripDays(tripId);
    } else {
      await _userBox.delete('selectedTripId');
    }

    notifyListeners();
  }

  Future<void> setSelectedDayIndex(int index) async {
    if (_selectedTripId == null || _selectedDayIndex == index) return;

    final days = selectedTripDays;
    if (index < 0 || index >= days.length) {
      debugPrint(
        "setSelectedDayIndex: Invalid index $index for ${days.length} days",
      );
      return;
    }

    _selectedDayIndex = index;
    await _userBox.put('selectedDayIndex_$_selectedTripId', index);
    notifyListeners();
  }

  void _listenToUserTrips() {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    _tripsSubscription?.cancel();

    _tripsSubscription = _firestore
        .collection('trips')
        .snapshots()
        .listen(
          (snapshot) {
            Map<String, Trip> newTrips = {};

            for (final doc in snapshot.docs) {
              try {
                final trip = Trip.fromFirestore(doc);

                final isOwner = trip.ownerId == user.uid;
                final isAcceptedParticipant = trip.participants.any(
                  (p) =>
                      p.uid == user.uid &&
                      p.invitationStatus == InvitationStatus.accepted,
                );

                if (isOwner || isAcceptedParticipant) {
                  if (_trips.containsKey(trip.id) &&
                      _trips[trip.id]!.tripDays.isNotEmpty) {
                    trip.tripDays = _trips[trip.id]!.tripDays;
                  }
                  newTrips[trip.id] = trip;
                }
              } catch (e) {
                debugPrint('Error parsing trip ${doc.id}: $e');
              }
            }

            _trips = newTrips;
            _isLoading = false;
            _error = null;

            if (_selectedTripId != null &&
                !_trips.containsKey(_selectedTripId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setSelectedTrip(null);
              });
            }

            notifyListeners();
          },
          onError: (e) {
            _isLoading = false;
            _error = 'Error loading trips: $e';
            notifyListeners();
            debugPrint(_error);
          },
        );
  }

  void _listenToTripDays(String tripId) {
    _isLoading = true;
    notifyListeners();

    _tripDaysSubscription?.cancel();

    _tripDaysSubscription = _firestore
        .collection('tripDays')
        .where('tripId', isEqualTo: tripId)
        .orderBy('date')
        .snapshots()
        .listen(
          (snapshot) {
            final tripDays =
                snapshot.docs.map((doc) => TripDay.fromFirestore(doc)).toList()
                  ..sort((a, b) => a.date.compareTo(b.date));

            _tripDays[tripId] = tripDays;

            if (_trips.containsKey(tripId)) {
              _trips[tripId]!.tripDays = tripDays;
            }

            for (final tripDay in tripDays) {
              _visitsCache[tripDay.id] = List.from(tripDay.visits);

              for (final visit in tripDay.visits) {
                if (visit.location != null) {
                  _locationsCache[visit.locationId] = visit.location!;
                }
              }
            }

            if (_selectedTripId == tripId &&
                _selectedDayIndex >= tripDays.length &&
                tripDays.isNotEmpty) {
              _selectedDayIndex = tripDays.length - 1;
              _userBox.put('selectedDayIndex_$tripId', _selectedDayIndex);
            }

            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _isLoading = false;
            _error = 'Error loading trip days: $e';
            notifyListeners();
            debugPrint(_error);
          },
        );
  }

  Future<void> addVisit(String tripDayId, Visit visit) async {
    try {
      final tripDayRef = _firestore.collection('tripDays').doc(tripDayId);
      final docSnapshot = await tripDayRef.get();

      final visitMap = visit.toMap();
      if (visit.location != null) {
        visitMap['location'] = visit.location!.toMap();
        _locationsCache[visit.locationId] = visit.location!;
      }

      if (docSnapshot.exists) {
        await tripDayRef.update({
          'visits': FieldValue.arrayUnion([visitMap]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final tripDay = findTripDayById(tripDayId);
        if (tripDay != null) {
          await tripDayRef.set({
            'tripId': tripDay.tripId,
            'date': Timestamp.fromDate(tripDay.date),
            'visits': [visitMap],
            'notes': tripDay.notes,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      _error = 'Error adding visit: $e';
      debugPrint(_error);
      notifyListeners();
      throw e;
    }
  }

  Future<void> removeVisit(String tripDayId, String visitId) async {
    try {
      final tripDayDoc =
          await _firestore.collection('tripDays').doc(tripDayId).get();
      if (!tripDayDoc.exists) {
        throw Exception('Trip day not found');
      }

      final data = tripDayDoc.data();
      if (data == null || !data.containsKey('visits')) {
        throw Exception('Visits not found in trip day');
      }

      final firestoreVisits = data['visits'] as List<dynamic>;
      Map<String, dynamic>? visitMapToRemove;

      for (final visit in firestoreVisits) {
        if (visit is Map && visit['id'] == visitId) {
          visitMapToRemove = Map<String, dynamic>.from(visit);
          break;
        }
      }

      if (visitMapToRemove == null) {
        throw Exception('Visit not found in trip day');
      }

      final tripDayRef = _firestore.collection('tripDays').doc(tripDayId);
      await tripDayRef.update({
        'visits': FieldValue.arrayRemove([visitMapToRemove]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _error = 'Error removing visit: $e';
      debugPrint(_error);
      notifyListeners();
      throw e;
    }
  }

  Future<void> updateVisit(String tripDayId, Visit updatedVisit) async {
    try {
      final updatedVisitMap = updatedVisit.toMap();
      if (updatedVisit.location != null) {
        updatedVisitMap['location'] = updatedVisit.location!.toMap();
        _locationsCache[updatedVisit.locationId] = updatedVisit.location!;
      }

      await _firestore.runTransaction((transaction) async {
        final tripDayRef = _firestore.collection('tripDays').doc(tripDayId);
        final tripDayDoc = await transaction.get(tripDayRef);

        if (!tripDayDoc.exists) {
          throw Exception('Trip day $tripDayId not found.');
        }

        final data = tripDayDoc.data();
        if (data == null || !data.containsKey('visits')) {
          throw Exception('Visits not found in trip day $tripDayId.');
        }

        List<dynamic> firestoreVisits = List.from(data['visits']);
        List<Map<String, dynamic>> travelSegments = [];

        if (data.containsKey('travelSegments') &&
            data['travelSegments'] != null) {
          travelSegments = List<Map<String, dynamic>>.from(
            data['travelSegments'] as List,
          );
        }

        final oldVisitIndex = firestoreVisits.indexWhere(
          (v) => v is Map && v['id'] == updatedVisit.id,
        );

        if (oldVisitIndex != -1) {
          firestoreVisits.removeAt(oldVisitIndex);
        }

        firestoreVisits.add(updatedVisitMap);

        transaction.update(tripDayRef, {
          'visits': firestoreVisits,
          'travelSegments': travelSegments,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      _error = 'Error updating visit: $e';
      debugPrint(_error);
      notifyListeners();
      throw e;
    }
  }

  TripDay? findTripDayById(String tripDayId) {
    for (final tripDays in _tripDays.values) {
      for (final tripDay in tripDays) {
        if (tripDay.id == tripDayId) {
          return tripDay;
        }
      }
    }
    return null;
  }

  void updateTrip(Trip updatedTrip) {
    if (_trips.containsKey(updatedTrip.id)) {
      if (updatedTrip.tripDays.isEmpty &&
          _trips[updatedTrip.id]!.tripDays.isNotEmpty) {
        updatedTrip.tripDays = _trips[updatedTrip.id]!.tripDays;
      }
      _trips[updatedTrip.id] = updatedTrip;
      notifyListeners();
    }
  }

  void clearCache() {
    _tripsSubscription?.cancel();
    _tripsSubscription = null;
    _tripDaysSubscription?.cancel();
    _tripDaysSubscription = null;

    _trips = {};
    _tripDays = {};
    _visitsCache = {};
    _locationsCache = {};
    _selectedTripId = null;
    _selectedDayIndex = 0;
    _error = null;
    notifyListeners();
  }

  Future<void> deleteTripDays(String tripId) async {
    try {
      final tripDaysSnapshot =
          await _firestore
              .collection('tripDays')
              .where('tripId', isEqualTo: tripId)
              .get();

      final batch = _firestore.batch();
      for (var doc in tripDaysSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint(
        'Deleted ${tripDaysSnapshot.docs.length} trip days for trip $tripId',
      );

      _tripDays.remove(tripId);
      tripDaysSnapshot.docs.forEach((doc) {
        _visitsCache.remove(doc.id);
      });

      if (_trips.containsKey(tripId)) {
        _trips[tripId]!.tripDays = [];
      }

      notifyListeners();
    } catch (e) {
      _error = 'Error deleting trip days: $e';
      debugPrint(_error);
      notifyListeners();
      throw e;
    }
  }

  Future<Location?> getLocationById(String locationId) async {
    if (_locationsCache.containsKey(locationId)) {
      return _locationsCache[locationId];
    }

    try {
      final doc =
          await _firestore.collection('locations').doc(locationId).get();
      if (doc.exists) {
        final location = Location.fromMap(doc.data()!);
        _locationsCache[locationId] = location;
        return location;
      }
    } catch (e) {
      debugPrint('Error fetching location $locationId: $e');
    }
    return null;
  }

  Future<Location> addLocation(Location location) async {
    try {
      final savedLocation = await Location.saveLocationWithPhoto(
        location: location,
        uploadLocalPhoto: location.localPhoto != null,
      );

      _locationsCache[savedLocation.id] = savedLocation;
      return savedLocation;
    } catch (e) {
      _error = 'Error adding location: $e';
      debugPrint(_error);
      notifyListeners();
      throw e;
    }
  }

  Future<Location> updateLocation(Location location) async {
    try {
      final updatedLocation = await Location.saveLocationWithPhoto(
        location: location,
        uploadLocalPhoto: location.localPhoto != null,
      );

      _locationsCache[updatedLocation.id] = updatedLocation;

      for (final trip in _trips.values) {
        final index = trip.savedLocations.indexWhere(
          (loc) => loc.id == location.id,
        );
        if (index >= 0) {
          final updatedLocations = List<Location>.from(trip.savedLocations);
          updatedLocations[index] = updatedLocation;

          await _firestore.collection('trips').doc(trip.id).update({
            'savedLocations': updatedLocations.map((l) => l.toMap()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      notifyListeners();
      return updatedLocation;
    } catch (e) {
      _error = 'Error updating location: $e';
      debugPrint(_error);
      notifyListeners();
      throw e;
    }
  }

  void forceMapRefresh() {
    notifyListeners();
    debugPrint('TripDataService: Forced map refresh');
  }

  @override
  void dispose() {
    _tripsSubscription?.cancel();
    _tripDaysSubscription?.cancel();
    _userAuthSubscription?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    try {
      super.notifyListeners();
    } catch (e) {
      debugPrint('Error in TripDataService.notifyListeners(): $e');
    }
  }
}
