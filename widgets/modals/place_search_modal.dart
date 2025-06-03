import 'package:flutter/material.dart';
// Hide Location from google_maps_webservice and use prefix
import 'package:google_maps_webservice/places.dart' hide Location;
import 'package:google_maps_webservice/places.dart' as gmw_places;
import 'package:trip_planner/services/places_service.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_day.dart';
// Import custom Location model explicitly
import 'package:trip_planner/models/location.dart';
import 'package:trip_planner/widgets/base/base_modal.dart';
import 'package:trip_planner/widgets/modals/location_preview_modal.dart';
import 'package:trip_planner/widgets/modals/add_visit_modal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class PlaceSearchModal extends StatefulWidget {
  final PlacesService placesService;
  final Function(Location) onPlaceSelected;
  final Trip trip;
  final Function(Trip) onTripUpdated;
  final TripDay? selectedTripDay;

  const PlaceSearchModal({
    super.key,
    required this.placesService,
    required this.onPlaceSelected,
    required this.trip,
    required this.onTripUpdated,
    this.selectedTripDay,
  });

  static Future<void> show({
    required BuildContext context,
    required PlacesService placesService,
    required Trip trip,
    required TripDay selectedTripDay,
    required Function(Location) onPlaceSelected,
    required Function(Trip) onTripUpdated,
  }) async {
    return showAppModal(
      context: context,
      builder:
          (context) => PlaceSearchModal(
            placesService: placesService,
            trip: trip,
            onTripUpdated: onTripUpdated,
            onPlaceSelected: onPlaceSelected,
            selectedTripDay: selectedTripDay,
          ),
    );
  }

  @override
  State<PlaceSearchModal> createState() => _PlaceSearchModalState();
}

class _PlaceSearchModalState extends State<PlaceSearchModal> {
  final _searchController = TextEditingController();
  List<Prediction> _predictions = [];
  bool _isSearching = false;
  bool _loadingTripDays = false;
  bool _isLoading = false;
  List<TripDay> _tripDays = [];
  Timer? _debounce;
  bool _isAddingToDay = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadTripDays();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(_searchController.text);
    });
  }

  Future<void> _loadTripDays() async {
    if (widget.trip.id.isEmpty) return;

    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );
    if (mounted) {
      setState(() {
        _tripDays = tripDataService.selectedTripDays;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      gmw_places.Location? locationBias;
      if (widget.trip.destination != null) {
        locationBias = gmw_places.Location(
          lat: widget.trip.destination!.coordinates.latitude,
          lng: widget.trip.destination!.coordinates.longitude,
        );
      }

      final predictions = await widget.placesService.getPlacePredictions(
        query,
        location: locationBias,
        radius: 50000, // 50km radius around destination
        placeTypes: [
          'restaurant',
          'tourist_attraction',
          'museum',
          'park',
          'point_of_interest',
        ],
        context: context, // Pass context for language
      );

      if (mounted) {
        setState(() {
          _predictions = predictions;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error searching places: $e')));
        });
      }
    }
  }

  Future<void> _handlePlaceDetailsSelection(String placeId) async {
    setState(() => _isSearching = true);
    try {
      final details = await widget.placesService.getPlaceDetails(placeId);
      if (!mounted) return;

      setState(() => _isSearching = false);
      if (details != null) {
        Navigator.of(
          context,
        ).pop({'action': 'showLocationPreview', 'details': details});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addLocationToItinerary(
    String placeId,
    String name,
    String? address,
    GeoPoint coordinates,
  ) async {
    setState(() => _isAddingToDay = true);

    try {
      if (_tripDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No trip days available yet. Please wait for them to load.',
            ),
          ),
        );
        return;
      }

      final tripDay =
          widget.selectedTripDay ??
          (_tripDays.isNotEmpty ? _tripDays.first : null);

      if (tripDay == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No trip day available')));
        return;
      }

      final place = gmw_places.PlacesSearchResult(
        name: name,
        formattedAddress: address ?? '',
        placeId: placeId,
        geometry: gmw_places.Geometry(
          location: gmw_places.Location(
            lat: coordinates.latitude,
            lng: coordinates.longitude,
          ),
        ),
        types: const [],
        reference: '',
      );

      Navigator.of(context).pop({
        'action': 'showAddVisitModal',
        'place': place,
        'tripDay': tripDay,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isAddingToDay = false);
      }
    }
  }

  void _addVisitToDay(TripDay day, PlacesSearchResult place) {
    Navigator.pop(context); // Close search modal first

    AddVisitModal.show(
      context: context,
      place: gmw_places.PlacesSearchResult(
        name: place.name,
        formattedAddress: place.formattedAddress ?? '',
        placeId: place.placeId,
        geometry: gmw_places.Geometry(
          location: gmw_places.Location(
            lat: place.geometry?.location.lat ?? 0,
            lng: place.geometry?.location.lng ?? 0,
          ),
        ),
        types: place.types ?? const [],
        reference: place.reference ?? '',
      ),
      trip: widget.trip,
      tripDay: day,
    );
  }

  // Helper to always get a GeoPoint from location.coordinates
  GeoPoint _toGeoPoint(dynamic coordinates) {
    if (coordinates is GeoPoint) {
      return coordinates;
    } else if (coordinates is Map<String, dynamic>) {
      // Handle map with latitude/longitude keys
      return GeoPoint(
        (coordinates['latitude'] as num).toDouble(),
        (coordinates['longitude'] as num).toDouble(),
      );
    } else if (coordinates != null &&
        coordinates.latitude != null &&
        coordinates.longitude != null) {
      // Handle LatLng or similar
      return GeoPoint(
        (coordinates.latitude as num).toDouble(),
        (coordinates.longitude as num).toDouble(),
      );
    } else {
      throw ArgumentError('Invalid coordinates type: $coordinates');
    }
  }

  Future<void> _addSelectedPlaceToDay(Prediction place, TripDay tripDay) async {
    try {
      setState(() => _isAddingToDay = true);

      // First, get full details of the place
      final placeDetails = await widget.placesService.getPlaceDetails(
        place.placeId ?? '',
      );

      if (placeDetails?.result == null || placeDetails!.result.name.isEmpty) {
        throw Exception('Failed to get place details');
      }

      // Create a Location from the place details
      final location = Location(
        id: placeDetails.result.placeId,
        placeId: placeDetails.result.placeId,
        name: placeDetails.result.name,
        coordinates: GeoPoint(
          placeDetails.result.geometry?.location.lat ?? 0,
          placeDetails.result.geometry?.location.lng ?? 0,
        ),
        address: placeDetails.result.formattedAddress,
        photoUrl:
            placeDetails.result.photos.isNotEmpty
                ? widget.placesService.getPhotoUrl(
                  placeDetails.result.photos.first.photoReference,
                  maxWidth: 800,
                )
                : null,
        photoUrls:
            placeDetails.result.photos
                .map(
                  (photo) => widget.placesService.getPhotoUrl(
                    photo.photoReference,
                    maxWidth: 800,
                  ),
                )
                .toList(),
      );

      // Save location to locations collection
      await Location.saveLocationWithPhoto(
        location: location,
        uploadLocalPhoto: false,
      );

      // Notify callback
      widget.onPlaceSelected(location);

      // ... continue with adding to trip day
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding place: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToDay = false);
      }
    }
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    } else if (_predictions.isNotEmpty) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _predictions.length,
        itemBuilder: (context, index) {
          final prediction = _predictions[index];
          final mainText =
              prediction.structuredFormatting?.mainText ??
              prediction.description ??
              '';
          final secondaryText =
              prediction.structuredFormatting?.secondaryText ?? '';

          return InkWell(
            onTap: () => _handlePlaceDetailsSelection(prediction.placeId ?? ''),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondaryText,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildSavedLocationsList() {
    if (widget.trip.savedLocations.isEmpty ||
        _searchController.text.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Bookmarked Places',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.trip.savedLocations.length,
          itemBuilder: (context, index) {
            final location = widget.trip.savedLocations[index];
            return Dismissible(
              key: Key(location.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Remove Bookmark'),
                        content: Text(
                          'Remove "${location.name}" from bookmarks?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );
                return confirmed ?? false;
              },
              onDismissed: (_) async {
                // Remove from Firestore
                final tripRef = FirebaseFirestore.instance
                    .collection('trips')
                    .doc(widget.trip.id);
                final updatedLocations = List<Location>.from(
                  widget.trip.savedLocations,
                )..removeAt(index);
                await tripRef.update({
                  'savedLocations':
                      updatedLocations.map((l) => l.toMap()).toList(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                // Update local trip object and UI
                setState(() {
                  widget.trip.savedLocations.removeAt(index);
                });
                // Optionally show a snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed "${location.name}" from bookmarks'),
                  ),
                );
                // Notify parent if needed
                widget.onTripUpdated(widget.trip);
              },
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.place, color: Colors.red),
                ),
                title: Text(location.name),
                subtitle:
                    location.address != null
                        ? Text(
                          location.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                        : null,
                trailing: IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.green,
                  ),
                  onPressed:
                      () => _addLocationToItinerary(
                        location.id,
                        location.name,
                        location.address,
                        _toGeoPoint(location.coordinates),
                      ),
                ),
                onTap: () => _handlePlaceDetailsSelection(location.id),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        autofocus: false, // Changed from true to false
        decoration: InputDecoration(
          hintText: 'Search for a place...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _predictions = [];
                      });
                    },
                  )
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseModal(
      isLoading: _loadingTripDays,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      title: 'Search Places',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchField(),
            const SizedBox(height: 8),
            _buildSearchResults(),
            _buildSavedLocationsList(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
