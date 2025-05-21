import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/services/user_data_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Email & Password Sign In
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Email & Password Sign Up
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
    // Check if username is already taken
    bool isUsernameTaken = await checkUsernameExists(username);
    if (isUsernameTaken) {
      throw FirebaseAuthException(
        code: 'username-already-in-use',
        message: 'The username is already taken. Please choose another one.',
      );
    }

    // Create user with email and password
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Store only email and username in Firestore
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': email,
      'username': username,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  // Check if username exists
  Future<bool> checkUsernameExists(String username) async {
    final querySnapshot =
        await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();

    return querySnapshot.docs.isNotEmpty;
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      // Clear TripDataService cache
      final tripDataService = TripDataService();
      tripDataService.clearCache();

      // Clear UserDataService cache
      final userDataService = UserDataService();
      userDataService.clearCache();

      // Clear Hive user box data
      final userBox = Hive.box('userBox');
      await userBox.clear();

      // Finally, sign out from Firebase Auth
      await _auth.signOut();
    } catch (e) {
      print('Error during sign out: $e');
      // Still attempt to sign out from Firebase Auth even if other cleanup fails
      await _auth.signOut();
    }
  }

  // Auth State Changes
  Stream<User?> get userChanges => _auth.authStateChanges();

  // Get username by user ID
  Future<String?> getUsernameById(String userId) async {
    try {
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();
      return docSnapshot.data()?['username'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Search users by username
  Future<List<Map<String, dynamic>>> searchUsersByUsername(String query) async {
    if (query.isEmpty) return [];

    final querySnapshot =
        await _firestore
            .collection('users')
            .where('username', isGreaterThanOrEqualTo: query)
            .where('username', isLessThan: query + 'z')
            .limit(10)
            .get();

    return querySnapshot.docs
        .map(
          (doc) => {
            'uid': doc.id,
            'username': doc.data()['username'],
            'email': doc.data()['email'],
            'photoURL': doc.data()['photoURL'], // Include photoURL field
          },
        )
        .toList();
  }

  // Get user profile data including photoURL
  Future<Map<String, dynamic>?> getUserProfileData(String userId) async {
    try {
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        return {
          'uid': docSnapshot.id,
          'username': data['username'],
          'email': data['email'],
          'photoURL': data['photoURL'],
        };
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
}
