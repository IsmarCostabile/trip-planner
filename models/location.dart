import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class Location {
  final String id;
  final String name;
  final String? description;
  final GeoPoint coordinates;
  final String? address;
  final String? category; // e.g., restaurant, museum, hotel, etc.
  final String? website;
  final String? phoneNumber;
  final Map<String, dynamic>? openingHours;
  final String? photoUrl; // Primary photo URL
  final List<String>? photoUrls; // Support for multiple photos
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String placeId; // Added for Google Places integration

  // In-memory only properties - not stored in Firestore
  final File? localPhoto; // For temporarily storing photo before upload

  Location({
    required this.id,
    required this.name,
    required this.coordinates,
    this.placeId = '', // Make optional with default value
    this.description,
    this.address,
    this.category,
    this.website,
    this.phoneNumber,
    this.openingHours,
    this.photoUrl,
    this.photoUrls,
    this.createdAt,
    this.updatedAt,
    this.localPhoto,
  });

  factory Location.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Location(
      id: doc.id,
      name: data['name'],
      coordinates: data['coordinates'] as GeoPoint,
      placeId: data['placeId'] ?? '', // Added placeId
      description: data['description'],
      address: data['address'],
      category: data['category'],
      website: data['website'],
      phoneNumber: data['phoneNumber'],
      openingHours: data['openingHours'],
      photoUrl: data['photoUrl'],
      photoUrls:
          data['photoUrls'] != null
              ? List<String>.from(data['photoUrls'])
              : null,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
    );
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    // Handle case where id might be null
    String id = map['id'] ?? '';

    // Handle required name field
    String name = map['name'] as String? ?? '';

    // Handle coordinates which is required
    GeoPoint coordinates =
        map['coordinates'] is GeoPoint
            ? map['coordinates']
            : map['coordinates'] == null
            ? const GeoPoint(0, 0) // Provide default coordinates if null
            : GeoPoint(
              (map['coordinates']['latitude'] as num).toDouble(),
              (map['coordinates']['longitude'] as num).toDouble(),
            );

    // Handle placeId which is required
    String placeId = map['placeId'] as String? ?? '';

    // Handle photoUrls
    List<String>? photoUrls;
    if (map['photoUrls'] != null) {
      photoUrls = List<String>.from(map['photoUrls']);
    }

    return Location(
      id: id,
      name: name,
      coordinates: coordinates,
      placeId: placeId,
      description: map['description'] as String?,
      address: map['address'] as String?,
      category: map['category'] as String?,
      website: map['website'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      openingHours: map['openingHours'] as Map<String, dynamic>?,
      photoUrl: map['photoUrl'] as String?,
      photoUrls: photoUrls,
      createdAt:
          map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'coordinates': coordinates,
      'placeId': placeId, // Added placeId
      'description': description,
      'address': address,
      'category': category,
      'website': website,
      'phoneNumber': phoneNumber,
      'openingHours': openingHours,
      'photoUrl': photoUrl,
      'photoUrls': photoUrls,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'name': name,
      'coordinates': {
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
      },
      'placeId': placeId, // Added placeId
      'description': description,
      'address': address,
      'category': category,
      'website': website,
      'phoneNumber': phoneNumber,
      'openingHours': openingHours,
      'photoUrl': photoUrl,
      'photoUrls': photoUrls,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Location copyWith({
    String? name,
    GeoPoint? coordinates,
    String? placeId, // Added placeId
    String? description,
    String? address,
    String? category,
    String? website,
    String? phoneNumber,
    Map<String, dynamic>? openingHours,
    String? photoUrl,
    List<String>? photoUrls,
    File? localPhoto,
  }) {
    return Location(
      id: id,
      name: name ?? this.name,
      coordinates: coordinates ?? this.coordinates,
      placeId: placeId ?? this.placeId, // Added placeId
      description: description ?? this.description,
      address: address ?? this.address,
      category: category ?? this.category,
      website: website ?? this.website,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      openingHours: openingHours ?? this.openingHours,
      photoUrl: photoUrl ?? this.photoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      localPhoto: localPhoto ?? this.localPhoto,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Uploads the location photo to Firebase Storage and returns the download URL
  static Future<String> uploadLocationPhoto({
    required String locationId,
    required File photoFile,
    String fileName = '',
  }) async {
    final storage = FirebaseStorage.instance;
    final String fileNameToUse =
        fileName.isNotEmpty
            ? fileName
            : '${DateTime.now().millisecondsSinceEpoch}_${photoFile.path.split('/').last}';

    // Create reference to the location where the file should be stored
    final storageRef = storage.ref().child(
      'locations/$locationId/$fileNameToUse',
    );

    // Upload the file
    final uploadTask = storageRef.putFile(photoFile);

    // Wait for the upload to complete and get the download URL
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return downloadUrl;
  }

  /// Saves a location to Firestore with its photo uploaded to Storage
  static Future<Location> saveLocationWithPhoto({
    required Location location,
    bool uploadLocalPhoto = true,
  }) async {
    final firestore = FirebaseFirestore.instance;
    String? uploadedPhotoUrl;

    // Upload photo if available
    if (uploadLocalPhoto && location.localPhoto != null) {
      uploadedPhotoUrl = await uploadLocationPhoto(
        locationId: location.id,
        photoFile: location.localPhoto!,
      );
    }

    // Create updated location with the uploaded photo URL
    final updatedLocation = location.copyWith(
      photoUrl: uploadedPhotoUrl ?? location.photoUrl,
      photoUrls:
          uploadedPhotoUrl != null && location.photoUrls == null
              ? [uploadedPhotoUrl]
              : location.photoUrls,
    );

    // Save to Firestore
    final locationRef = firestore.collection('locations').doc(location.id);
    await locationRef.set(updatedLocation.toMap());

    return updatedLocation;
  }

  // Get the main photo URL or the first from the list if available
  String? get mainPhotoUrl =>
      photoUrl ?? (photoUrls?.isNotEmpty == true ? photoUrls!.first : null);
}
