import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_webservice/places.dart';

class PlacesService {
  static const _apiKey = 'GOOGLE_MAPS_API_KEY_HERE';
  static String get apiKey => _apiKey;
  final places = GoogleMapsPlaces(apiKey: _apiKey);

  String _getCurrentLanguage(BuildContext? context) {
    if (context != null) {
      final locale = Localizations.localeOf(context);
      return locale.languageCode;
    }
    return WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  }

  Future<List<PlacesSearchResult>> searchNearby(
    double latitude,
    double longitude, {
    String? keyword,
    int radius = 1500,
    BuildContext? context,
  }) async {
    try {
      final location = Location(lat: latitude, lng: longitude);
      final response = await places.searchNearbyWithRankBy(
        location,
        "distance",
        keyword: keyword,
        language: _getCurrentLanguage(context),
      );

      if (response.status == "OK") {
        return response.results;
      } else {
        debugPrint("Places API Error: ${response.errorMessage}");
        return [];
      }
    } catch (e) {
      debugPrint("Error searching places: $e");
      return [];
    }
  }

  Future<List<Prediction>> getPlaceSuggestions(
    String query, {
    Location? location,
    BuildContext? context,
  }) async {
    try {
      if (query.isEmpty) return [];

      debugPrint(
        'Fetching predictions for query: $query${location != null ? ' near ${location.lat},${location.lng}' : ''}',
      );

      final response = await places.autocomplete(
        query,
        language: _getCurrentLanguage(context),
        components: [],
        location: location,
        radius: null,
        types: ['locality', 'country', 'administrative_area_level_1'],
        strictbounds: false,
      );

      debugPrint('Places API Response Status: ${response.status}');
      if (response.status == "OK") {
        debugPrint('Received ${response.predictions.length} predictions');
        return response.predictions;
      } else {
        debugPrint(
          "Places API Error: ${response.errorMessage ?? 'Unknown error'}",
        );
        debugPrint("Status: ${response.status}");
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint("Error getting place suggestions: $e");
      debugPrint("Stack trace: $stackTrace");
      return [];
    }
  }

  Future<PlacesDetailsResponse?> getPlaceDetails(
    String placeId, {
    BuildContext? context,
  }) async {
    try {
      final response = await places.getDetailsByPlaceId(
        placeId,
        language: _getCurrentLanguage(context),
        fields: [
          'name',
          'formatted_address',
          'geometry',
          'photo',
          'place_id',
          'type',
          'rating',
          'website',
          'formatted_phone_number',
          'opening_hours',
        ],
      );

      if (response.status == "OK") {
        return response;
      } else {
        debugPrint("Places API Error: ${response.errorMessage}");
        return null;
      }
    } catch (e) {
      debugPrint("Error getting place details: $e");
      return null;
    }
  }

  Future<List<PlacesSearchResult>> searchPlaces(
    String query, {
    BuildContext? context,
  }) async {
    try {
      if (query.isEmpty) return [];

      debugPrint('Searching places for query: $query');

      final response = await places.searchByText(
        query,
        language: _getCurrentLanguage(context),
      );

      if (response.status == "OK") {
        debugPrint('Received ${response.results.length} places');
        return response.results;
      } else {
        debugPrint(
          "Places API Error: ${response.errorMessage ?? 'Unknown error'}",
        );
        debugPrint("Status: ${response.status}");
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint("Error searching places: $e");
      debugPrint("Stack trace: $stackTrace");
      return [];
    }
  }

  Future<List<PlacesSearchResult>> searchPlacesNearby(
    String query,
    GeoPoint location, {
    int radius = 50000,
    BuildContext? context,
  }) async {
    try {
      if (query.isEmpty) return [];

      debugPrint(
        'Searching places near ${location.latitude},${location.longitude} for query: $query',
      );

      final response = await places.searchNearbyWithRadius(
        Location(lat: location.latitude, lng: location.longitude),
        radius,
        keyword: query,
        language: _getCurrentLanguage(context),
      );

      if (response.status == "OK") {
        debugPrint('Received ${response.results.length} nearby places');
        return response.results;
      } else {
        debugPrint(
          "Places API Error: ${response.errorMessage ?? 'Unknown error'}",
        );
        debugPrint("Status: ${response.status}");
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint("Error searching nearby places: $e");
      debugPrint("Stack trace: $stackTrace");
      return [];
    }
  }

  String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=$_apiKey';
  }

  Future<List<Prediction>> getPlacePredictions(
    String query, {
    Location? location,
    int? radius,
    List<String>? placeTypes,
    BuildContext? context,
  }) async {
    try {
      if (query.isEmpty) return [];

      debugPrint(
        'Fetching place predictions for query: $query${location != null ? ' near ${location.lat},${location.lng}' : ''}',
      );

      final response = await places.autocomplete(
        query,
        language: _getCurrentLanguage(context),
        components: [],
        location: location,
        radius: radius,
        types: placeTypes ?? ['establishment'],
        strictbounds: location != null,
      );

      debugPrint('Places API Response Status: ${response.status}');
      if (response.status == "OK") {
        debugPrint('Received ${response.predictions.length} predictions');
        return response.predictions;
      } else {
        debugPrint(
          "Places API Error: ${response.errorMessage ?? 'Unknown error'}",
        );
        debugPrint("Status: ${response.status}");
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint("Error getting place predictions: $e");
      debugPrint("Stack trace: $stackTrace");
      return [];
    }
  }

  void dispose() {
    places.dispose();
  }
}
