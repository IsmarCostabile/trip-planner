import 'package:flutter/material.dart';
import 'package:google_maps_webservice/places.dart';

class LocationPhotoCarousel extends StatelessWidget {
  final List<Photo> photos;
  final String apiKey;

  const LocationPhotoCarousel({
    super.key,
    required this.photos,
    required this.apiKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
      ), // Add margin on the sides
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: SizedBox(
          height: 200,
          child: PageView.builder(
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              return Image.network(
                'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${photo.photoReference}&key=$apiKey',
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => const Icon(Icons.error),
              );
            },
          ),
        ),
      ),
    );
  }
}
