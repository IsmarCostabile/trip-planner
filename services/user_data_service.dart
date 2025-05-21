import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserDataService extends ChangeNotifier {
  // Singleton pattern
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();

  // User data cache
  Map<String, dynamic>? _userData;
  String? _photoUrl;
  String? _username;
  Map<String, dynamic> _preferences = {};
  bool _isLoading = false;

  // Getters for user data
  Map<String, dynamic>? get userData => _userData;
  String? get photoUrl => _photoUrl;
  String? get username => _username;
  Map<String, dynamic> get preferences => _preferences;
  bool get isLoading => _isLoading;
  bool get isLoaded => _userData != null;

  // Load user data from Firestore
  Future<void> loadUserData({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Return cached data if available and not forcing refresh
    if (_userData != null && !forceRefresh) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (doc.exists) {
        _userData = doc.data();
        _photoUrl = _userData!['photoUrl'];
        _username =
            _userData!['username'] ?? user.email?.split('@')[0] ?? 'User';
        _preferences = _userData!['preferences'] ?? {};
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user data and cache
  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(data);

      // Update cache
      _userData = {...?_userData, ...data};
      if (data.containsKey('photoUrl')) _photoUrl = data['photoUrl'];
      if (data.containsKey('username')) _username = data['username'];
      if (data.containsKey('preferences')) _preferences = data['preferences'];

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating user data: $e');
    }
  }

  // Update photo URL specifically
  Future<void> updatePhotoUrl(String photoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoURL': photoUrl},
      );

      // Update cache
      _userData = {...?_userData, 'photoURL': photoUrl};
      _photoUrl = photoUrl;

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating photo URL: $e');
    }
  }

  // Clear cache on logout
  void clearCache() {
    _userData = null;
    _photoUrl = null;
    _username = null;
    _preferences = {};
    notifyListeners();
  }
}
