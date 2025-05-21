import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A reusable widget for displaying profile pictures with fallback initials
class ProfilePictureWidget extends StatelessWidget {
  /// The URL of the profile picture to display
  final String? photoUrl;

  /// The username to extract initials from when no photo is available
  final String? username;

  /// The size (diameter) of the profile picture
  final double size;

  /// Optional border color for the avatar
  final Color? borderColor;

  /// Optional border width (no border if null)
  final double? borderWidth;

  /// Background color when showing initials
  final Color? backgroundColor;

  /// Optional callback when the avatar is tapped
  final VoidCallback? onTap;

  const ProfilePictureWidget({
    super.key,
    this.photoUrl,
    this.username,
    this.size = 36.0,
    this.borderColor,
    this.borderWidth,
    this.backgroundColor,
    this.onTap,
  });

  /// Checks if a URL string is a valid image URL
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      debugPrint(
        'ProfilePictureWidget: URL is null or empty for user: $username',
      );
      return false;
    }

    // Basic URL validation (must be http or https)
    // Firebase Storage URLs should always start with https
    final isValidFormat =
        url.startsWith('http://') || url.startsWith('https://');
    if (!isValidFormat) {
      debugPrint(
        'ProfilePictureWidget: Invalid URL format for user $username: $url',
      );
      return false;
    }

    // For Firebase Storage URLs, additionally check for firebasestorage.googleapis.com
    final isFirebaseStorage = url.contains('firebasestorage.googleapis.com');
    if (isFirebaseStorage) {
      debugPrint(
        'ProfilePictureWidget: Valid Firebase Storage URL for user $username: $url',
      );
    } else {
      debugPrint(
        'ProfilePictureWidget: Valid URL format (non-Firebase) for user $username: $url',
      );
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'ProfilePictureWidget building for user: $username with URL: $photoUrl',
    );

    final hasValidPhoto = _isValidImageUrl(photoUrl);
    final defaultBackgroundColor = backgroundColor ?? Colors.grey.shade400;

    Widget avatarContent;

    if (hasValidPhoto) {
      // Use CachedNetworkImage for caching, error handling and loading indicator
      avatarContent = ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth:
              (size * MediaQuery.of(context).devicePixelRatio).toInt(),
          errorWidget: (context, url, error) {
            debugPrint(
              'ProfilePictureWidget: Error loading image for $username from URL: $photoUrl, Error: $error',
            );
            return Container(
              width: size,
              height: size,
              color: defaultBackgroundColor,
              alignment: Alignment.center,
              child: Text(
                _getInitials(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: size * 0.35,
                ),
              ),
            );
          },
          placeholder:
              (context, url) => Container(
                width: size,
                height: size,
                color: defaultBackgroundColor.withOpacity(0.7),
                alignment: Alignment.center,
                child: SizedBox(
                  width: size * 0.5,
                  height: size * 0.5,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.0,
                    color: Colors.white,
                  ),
                ),
              ),
        ),
      );
    } else {
      // Show initials for invalid or missing photo URL
      debugPrint(
        'ProfilePictureWidget: Using initials fallback for: $username',
      );
      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: defaultBackgroundColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          _getInitials(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: size * 0.35,
          ),
        ),
      );
    }

    // Apply border if specified
    Widget profileWidget = avatarContent;
    if (borderColor != null && borderWidth != null) {
      profileWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth!),
        ),
        child: avatarContent,
      );
    }

    // Add tap functionality if specified
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: profileWidget);
    }

    return profileWidget;
  }

  /// Returns the first letter of the username, or '?' if no username is available
  String _getInitials() {
    if (username == null || username!.isEmpty) return '?';
    return username![0].toUpperCase();
  }
}
