import 'package:flutter/material.dart';
import 'package:google_maps_webservice/places.dart' hide Location;
import 'package:trip_planner/services/places_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_planner/widgets/base/base_modal.dart';
import 'package:google_maps_webservice/places.dart' as gmw;
import 'package:trip_planner/models/trip_day.dart';
import 'package:trip_planner/widgets/location_photo_carousel.dart';
import 'package:trip_planner/widgets/modals/button_tray.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/trip_data_service.dart';

class LocationPreviewModal extends StatefulWidget {
  final PlacesDetailsResponse placeDetails;
  final Trip? trip;
  final Function(Trip updatedTrip)? onLocationSaved;
  final TripDay? selectedTripDay;

  const LocationPreviewModal({
    super.key,
    required this.placeDetails,
    this.trip,
    this.onLocationSaved,
    this.selectedTripDay,
  });

  /// Helper method to show the modal with consistent styling
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required PlacesDetailsResponse placeDetails,
    Trip? trip,
    Function(Trip updatedTrip)? onLocationSaved,
    TripDay? selectedTripDay,
  }) {
    // Get the TripDataService before showing modal
    final tripDataService = Provider.of<TripDataService>(
      context,
      listen: false,
    );

    return showAppModal<Map<String, dynamic>?>(
      context: context,
      builder:
          (modalContext) => ChangeNotifierProvider.value(
            // Provide the same instance but in an isolated context
            value: tripDataService,
            child: LocationPreviewModal(
              placeDetails: placeDetails,
              trip: trip,
              onLocationSaved: onLocationSaved,
              selectedTripDay: selectedTripDay,
            ),
          ),
    );
  }

  @override
  State<LocationPreviewModal> createState() => _LocationPreviewModalState();
}

class _LocationPreviewModalState extends State<LocationPreviewModal> {
  bool _isSaving = false;
  bool _isLocationSaved = false;
  bool _isOpeningHoursExpanded = false; // Add state for expansion

  @override
  void initState() {
    super.initState();
    _checkIfLocationSaved();
  }

  void _checkIfLocationSaved() {
    if (widget.trip != null) {
      setState(() {
        _isLocationSaved = widget.trip!.savedLocations.any(
          (location) => location.placeId == widget.placeDetails.result.placeId,
        );
      });
    }
  }

  Future<void> _toggleSaveLocation() async {
    if (widget.trip == null) return;

    setState(() => _isSaving = true);

    try {
      final tripRef = FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.trip!.id);

      // Get the photo URL if photos are available
      String? photoUrl;
      List<String>? photoUrls;

      if (widget.placeDetails.result.photos.isNotEmpty) {
        // Create a list to store multiple photo URLs
        photoUrls =
            widget.placeDetails.result.photos
                .take(5) // Limit to 5 photos to avoid excessive data
                .map(
                  (photo) =>
                      'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${photo.photoReference}&key=${PlacesService.apiKey}',
                )
                .toList();

        // Set the main photo URL as the first photo
        photoUrl = photoUrls.first;
      }

      final location = Location(
        id: widget.placeDetails.result.placeId,
        placeId: widget.placeDetails.result.placeId,
        name: widget.placeDetails.result.name,
        coordinates: GeoPoint(
          widget.placeDetails.result.geometry?.location.lat ?? 0,
          widget.placeDetails.result.geometry?.location.lng ?? 0,
        ),
        address: widget.placeDetails.result.formattedAddress,
        photoUrl: photoUrl, // Add the primary photo URL
        photoUrls: photoUrls, // Add all photo URLs
      );

      // Check if we need to remove or add the location
      if (_isLocationSaved) {
        // Remove location
        final updatedLocations =
            widget.trip!.savedLocations
                .where((loc) => loc.placeId != location.placeId)
                .toList();

        await tripRef.update({
          'savedLocations': updatedLocations.map((l) => l.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create updated trip model
        final updatedTrip = widget.trip!.copyWith(
          savedLocations: updatedLocations,
          updatedAt: DateTime.now(),
        );

        // Notify parent about the update
        widget.onLocationSaved?.call(updatedTrip);
      } else {
        // Add location - use the saveLocationWithPhoto method
        // We're not uploading a local photo here as we're using URLs from Google Places API
        final savedLocation = await Location.saveLocationWithPhoto(
          location: location,
          uploadLocalPhoto: false, // No local photo to upload in this case
        );

        // Add to trip's saved locations
        final updatedLocations = [
          ...widget.trip!.savedLocations,
          savedLocation,
        ];

        await tripRef.update({
          'savedLocations': updatedLocations.map((l) => l.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create updated trip model
        final updatedTrip = widget.trip!.copyWith(
          savedLocations: updatedLocations,
          updatedAt: DateTime.now(),
        );

        // Notify parent about the update
        widget.onLocationSaved?.call(updatedTrip);
      }

      if (mounted) {
        setState(() {
          _isLocationSaved = !_isLocationSaved;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isLocationSaved
                  ? 'Location saved to bookmarks'
                  : 'Location removed from bookmarks',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving location: $e')));
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) {
        throw 'Could not launch $url';
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open website: $e')));
      }
    }
  }

  Future<void> _launchPhone(BuildContext context, String phone) async {
    try {
      final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\\D'), '')}');
      if (!await canLaunchUrl(uri)) {
        throw 'Could not launch phone call to $phone';
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not make phone call: $e')),
        );
      }
    }
  }

  Future<void> _addToItinerary() async {
    // Ensure selectedTripDay is available
    if (widget.selectedTripDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Could not determine the selected day.'),
        ),
      );
      return;
    }

    // Check trip data
    if (widget.trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Trip data missing.')),
      );
      return;
    }

    final tripDay = widget.selectedTripDay!;
    // final tripData = widget.trip!; // Not needed directly
    final placeDetailsResult = widget.placeDetails.result;

    // Create a place search result from place details
    final place = PlacesSearchResult(
      name: placeDetailsResult.name,
      formattedAddress: placeDetailsResult.formattedAddress ?? '',
      placeId: placeDetailsResult.placeId,
      geometry: gmw.Geometry(
        location: gmw.Location(
          lat: placeDetailsResult.geometry?.location.lat ?? 0,
          lng: placeDetailsResult.geometry?.location.lng ?? 0,
        ),
      ),
      types: placeDetailsResult.types.toList(),
      reference: placeDetailsResult.reference ?? '', // Use null-aware operator
    );

    // Return the data needed to show the AddVisitModal
    Navigator.of(
      context,
    ).pop({'action': 'showAddVisitModal', 'place': place, 'tripDay': tripDay});
  }

  Widget _buildContent() {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Photo carousel
        if (widget.placeDetails.result.photos.isNotEmpty)
          LocationPhotoCarousel(
            photos: widget.placeDetails.result.photos,
            apiKey: PlacesService.apiKey,
          ),
        // Place details
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                // Wrap name and rating in a Row
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween, // Align items
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Align items vertically
                children: [
                  Expanded(
                    // Allow name to take available space
                    child: Text(
                      widget.placeDetails.result.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.placeDetails.result.rating !=
                      null) // Show rating only if available
                    Row(
                      mainAxisSize: MainAxisSize.min, // Take minimum space
                      children: [
                        ...List.generate(5, (index) {
                          final rating = widget.placeDetails.result.rating!;
                          return Icon(
                            Icons.star,
                            color:
                                index < rating
                                    ? Colors.amber
                                    : Colors.grey[300],
                            size: 20,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.placeDetails.result.rating}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.placeDetails.result.formattedAddress ?? '',
                style: const TextStyle(fontSize: 16),
              ),
              if (widget.placeDetails.result.formattedPhoneNumber != null ||
                  widget.placeDetails.result.website != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (widget.placeDetails.result.formattedPhoneNumber != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            // Style the call button
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ), // Adjust padding
                            textStyle: const TextStyle(
                              fontSize: 14,
                            ), // Adjust font size
                          ),
                          onPressed:
                              () => _launchPhone(
                                context,
                                widget
                                    .placeDetails
                                    .result
                                    .formattedPhoneNumber!,
                              ),
                          icon: const Icon(
                            Icons.phone,
                            size: 18,
                          ), // Adjust icon size
                          label: const Text('Call'),
                        ),
                      ),
                    if (widget.placeDetails.result.website != null)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          // Style the website button
                          backgroundColor: Colors.lightBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ), // Adjust padding
                          textStyle: const TextStyle(
                            fontSize: 14,
                          ), // Adjust font size
                        ),
                        onPressed:
                            () => _launchUrl(
                              context,
                              widget.placeDetails.result.website!,
                            ),
                        icon: const Icon(
                          Icons.language,
                          size: 18,
                        ), // Adjust icon size
                        label: const Text('Website'),
                      ),
                  ],
                ),
              ],
              if (widget.placeDetails.result.openingHours?.weekdayText !=
                  null) ...[
                const SizedBox(height: 16),
                InkWell(
                  // Make the header tappable
                  onTap: () {
                    setState(() {
                      _isOpeningHoursExpanded = !_isOpeningHoursExpanded;
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Opening Hours',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        // Add expand/collapse icon
                        _isOpeningHoursExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                    ],
                  ),
                ),
                if (_isOpeningHoursExpanded) ...[
                  // Conditionally show hours
                  const SizedBox(height: 8),
                  ...widget.placeDetails.result.openingHours!.weekdayText.map(
                    (hours) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(hours),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final footer = ButtonTray(
      primaryButton: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.green.withOpacity(0.6),
          side: const BorderSide(color: Colors.black),
        ),
        onPressed: _addToItinerary,
        icon: const Icon(Icons.add),
        label: const Text('VISIT'),
      ),
      secondaryButton: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.amber.withOpacity(0.5),
          side: const BorderSide(color: Colors.black),
        ),
        onPressed: _isSaving ? null : _toggleSaveLocation,
        icon:
            _isSaving
                ? SizedBox(
                  // Removed const
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(
                  _isLocationSaved ? Icons.bookmark : Icons.bookmark_outline,
                ),
        label: Text(_isLocationSaved ? 'SAVED' : 'SAVE'),
      ),
    );

    return BaseModal(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      isScrollable: false,
      footer: footer,
      child: _buildContent(),
    );
  }
}
