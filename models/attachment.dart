import 'package:cloud_firestore/cloud_firestore.dart';

enum AttachmentType { photo, document }

class Attachment {
  final String id;
  final String url;
  final String fileName;
  final AttachmentType type;
  final String? description;
  final String? thumbnailUrl; // For images, a smaller version
  final String? mimeType; // e.g., "image/jpeg", "application/pdf"
  final int? size; // File size in bytes

  Attachment({
    required this.id,
    required this.url,
    required this.fileName,
    required this.type,
    this.description,
    this.thumbnailUrl,
    this.mimeType,
    this.size,
  });

  // Create from Firestore document
  factory Attachment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Attachment(
      id: doc.id,
      url: data['url'],
      fileName: data['fileName'] ?? 'Unnamed file',
      type: _typeFromString(data['type'] ?? 'photo'),
      description: data['description'],
      thumbnailUrl: data['thumbnailUrl'],
      mimeType: data['mimeType'],
      size: data['size'],
    );
  }

  // Create from map
  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      id: map['id'],
      url: map['url'],
      fileName: map['fileName'] ?? 'Unnamed file',
      type: _typeFromString(map['type'] ?? 'photo'),
      description: map['description'],
      thumbnailUrl: map['thumbnailUrl'],
      mimeType: map['mimeType'],
      size: map['size'],
    );
  }

  // Convert to map for Firestore and local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'fileName': fileName,
      'type': type.toString().split('.').last,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'mimeType': mimeType,
      'size': size,
    };
  }

  // Copy with function for updating attachment
  Attachment copyWith({
    String? fileName,
    String? description,
    String? thumbnailUrl,
  }) {
    return Attachment(
      id: id,
      url: url,
      fileName: fileName ?? this.fileName,
      type: type,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mimeType: mimeType,
      size: size,
    );
  }

  // Convert string to AttachmentType enum
  static AttachmentType _typeFromString(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'document':
        return AttachmentType.document;
      case 'photo':
      default:
        return AttachmentType.photo;
    }
  }

  // Check if attachment is an image
  bool get isImage => type == AttachmentType.photo;

  // Check if attachment is a document (PDF, etc.)
  bool get isDocument => type == AttachmentType.document;

  // Get file extension from fileName or mimeType
  String get fileExtension {
    // Try to get from fileName first
    if (fileName.contains('.')) {
      return fileName.split('.').last.toLowerCase();
    }

    // Try to get from mimeType
    if (mimeType != null) {
      switch (mimeType) {
        case 'application/pdf':
          return 'pdf';
        case 'image/jpeg':
          return 'jpg';
        case 'image/png':
          return 'png';
        case 'application/vnd.ms-excel':
          return 'xls';
        case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
          return 'xlsx';
        default:
          return '';
      }
    }

    return '';
  }

  // Format file size for display (e.g., "2.5 MB")
  String get formattedSize {
    if (size == null) return '';

    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;

    if (size! >= gb) {
      return '${(size! / gb).toStringAsFixed(1)} GB';
    } else if (size! >= mb) {
      return '${(size! / mb).toStringAsFixed(1)} MB';
    } else if (size! >= kb) {
      return '${(size! / kb).toStringAsFixed(0)} KB';
    } else {
      return '$size bytes';
    }
  }
}
