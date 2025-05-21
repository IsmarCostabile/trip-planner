import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_participant.dart'; // This has InvitationStatus enum
import 'package:trip_planner/views/trip_invitation_page.dart';
import 'package:trip_planner/services/trip_invitation_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/user_data_service.dart';
import 'package:trip_planner/services/trip_data_service.dart';
import 'package:trip_planner/widgets/trip_tile.dart';
import 'package:trip_planner/views/trip_creation_page.dart';
import 'package:trip_planner/widgets/trip_header_bar.dart';
import 'package:trip_planner/auth/auth_service.dart';

class ProfilePage extends StatefulWidget {
  final BuildContext? rootContext;
  const ProfilePage({super.key, this.rootContext});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = false;
  String? _error;
  final user = FirebaseAuth.instance.currentUser;
  String _distanceUnit = 'km';
  String _timeFormat = '24h';
  // Removed _dateFormat state variable
  String? _photoUrl;
  final ImagePicker _imagePicker = ImagePicker();
  List<Trip> _userTrips = [];
  String? _selectedTripId;
  List<Trip> _pendingInvitations = [];
  final TripInvitationService _invitationService = TripInvitationService();

  @override
  void initState() {
    super.initState();
    // Load saved selected trip ID immediately
    _selectedTripId = Hive.box('userBox').get('selectedTripId') as String?;
    _loadProfile();
    // Removed _loadUserTrips() call since it's handled by TripDataService streams
    _loadPendingInvitations();
    _loadPreferencesFromHive();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserDataService>(context, listen: false).loadUserData();
    });
  }

  Future<void> _loadProfile() async {
    if (user == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get();
      if (!mounted) return; // Check if widget is still mounted

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _distanceUnit = data['distanceUnit'] ?? 'km';
          _timeFormat = data['timeFormat'] ?? '24h';
          // Removed loading _dateFormat
          _photoUrl = data['photoURL'] as String?;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return; // Check if widget is still mounted
      setState(() {
        _error = 'Error loading profile: $e';
      });
    }
  }

  // Removed _loadUserTrips method since it's now handled by stream

  Future<void> _loadPendingInvitations() async {
    if (user == null) return;
    try {
      final invitations = await _invitationService.getPendingInvitations();
      if (!mounted) return; // Check if widget is still mounted
      setState(() {
        _pendingInvitations = invitations;
      });
    } catch (e) {
      if (!mounted) return; // Check if widget is still mounted
      print('Error loading invitations: $e');
    }
  }

  Future<void> _loadPreferencesFromHive() async {
    final box = Hive.box('userBox');
    final distanceUnit = box.get('distanceUnit');

    if (!mounted) return; // Check if widget is still mounted

    if (distanceUnit != null &&
        (distanceUnit == 'km' || distanceUnit == 'mi')) {
      setState(() {
        _distanceUnit = distanceUnit;
      });
    }
    final timeFormat = box.get('timeFormat');
    if (timeFormat != null && (timeFormat == '24h' || timeFormat == 'am/pm')) {
      setState(() {
        _timeFormat = timeFormat;
      });
    }
    // Removed loading dateFormat from Hive
    final selectedTripId = box.get('selectedTripId') as String?;
    if (selectedTripId != null) {
      setState(() {
        _selectedTripId = selectedTripId;
      });
    }
  }

  // New method to save a specific preference
  Future<void> _savePreference(String key, String value) async {
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Update in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        key: value,
      }, SetOptions(merge: true));

      // Save in Hive
      final box = Hive.box('userBox');
      await box.put(key, value);

      if (!mounted) return;

      // Show subtle confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$key updated'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error saving preference: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    if (user == null) return;
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    if (!mounted) return;

    // Create a temporary file for immediate display
    final tempFile = File(pickedFile.path);

    // Show the image immediately to improve perceived performance
    setState(() {
      _photoUrl = pickedFile.path; // Temporary local path
      _loading = true;
    });

    try {
      final ref = FirebaseStorage.instance.ref('profilePictures/${user!.uid}');
      await ref.putFile(tempFile);
      final downloadUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'photoURL': downloadUrl,
      }, SetOptions(merge: true));
      await user!.updatePhotoURL(downloadUrl);

      if (!mounted) return;

      setState(() {
        _photoUrl = downloadUrl; // Update with actual download URL
      });

      // Update the UserDataService with the new photo URL
      Provider.of<UserDataService>(
        context,
        listen: false,
      ).updatePhotoUrl(downloadUrl);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));

      // Reset to previous photo if upload failed
      setState(() {
        _photoUrl = user?.photoURL;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  void _navigateToCreateTrip() async {
    // Use rootContext if available, otherwise fallback to local context
    final modalContext = widget.rootContext ?? context;
    // Updated to call TripCreationPage.show
    final result = await TripCreationPage.show(context: modalContext);

    if (result == true && mounted) {
      // No need to call loadUserTrips since we're using streams now
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip created successfully!')),
      );
    }
  }

  void _viewTripInvitation(String tripId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripInvitationPage(tripId: tripId),
      ),
    );

    // Refresh invitations after responding to an invitation
    if (result != null) {
      _loadPendingInvitations();
      // No need to manually reload trips as they're streamed now
    }
  }

  // Confirm and process leaving a trip
  Future<void> _confirmLeaveTrip(Trip trip) async {
    final uid = user!.uid;
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(trip.id);
    final participants = trip.participants;
    if (trip.ownerId == uid) {
      // Owner leaving: assign new owner or delete if none
      final remaining = participants.where((p) => p.uid != uid).toList();
      if (remaining.isNotEmpty) {
        final newOwner = remaining[Random().nextInt(remaining.length)];
        await tripRef.update({
          'participants': remaining.map((p) => p.toMap()).toList(),
          'ownerId': newOwner.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Get the trip data service to delete trip days
        final tripDataService = Provider.of<TripDataService>(
          context,
          listen: false,
        );

        // Delete all trip days before deleting the trip
        await tripDataService.deleteTripDays(trip.id);

        // Then delete the trip document
        await tripRef.delete();
      }
    } else {
      // Participant leaving
      final remaining = participants.where((p) => p.uid != uid).toList();
      await tripRef.update({
        'participants': remaining.map((p) => p.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return; // Check if widget is still mounted

    // Refresh trips list - no need to call loadUserTrips as we have streams
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Left trip "${trip.name}"')));
  }

  @override
  Widget build(BuildContext context) {
    final userDataService = Provider.of<UserDataService>(context);
    final tripDataService = Provider.of<TripDataService>(context);
    final selectedTrip = tripDataService.selectedTrip;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          selectedTrip != null
              ? SliverAppBar(
                floating: true,
                snap: true,
                flexibleSpace: TripHeaderBar(trip: selectedTrip),
              )
              : SliverAppBar(
                floating: true,
                snap: true,
                title: const Text('Profile'),
                backgroundColor: Colors.white,
                centerTitle: true,
              ),
          // Remove the empty SliverToBoxAdapter that's adding extra space
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Profile Section - No Card
                // Adjusted vertical padding to reduce space at the top
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: _getProfileImage(
                                  userDataService,
                                ),
                                child:
                                    _shouldShowDefaultIcon(userDataService)
                                        ? const Icon(Icons.person, size: 40)
                                        : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: IconButton(
                                  onPressed:
                                      _loading ? null : _pickProfileImage,
                                  // Changed icon to edit
                                  icon: const Icon(Icons.edit, size: 20),
                                  style: IconButton.styleFrom(
                                    // Semi-transparent background
                                    backgroundColor: Colors.black.withOpacity(
                                      0.5,
                                    ),
                                    foregroundColor: Colors.white,
                                    // Make it smaller
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(
                                      28,
                                      28,
                                    ), // Adjust size if needed
                                    shape: const CircleBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@${userDataService.username}',
                                  style: const TextStyle(fontSize: 24),
                                ),
                                if (user?.email != null &&
                                    user!.email!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      user!.email!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Error Display - No Card, styled Text
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ),

                // Trip Invitations - Header + List
                if (_pendingInvitations.isNotEmpty) ...[
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Pending Invitations (${_pendingInvitations.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pendingInvitations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final trip = _pendingInvitations[index];
                      final owner = trip.participants.firstWhere(
                        (p) => p.uid == trip.ownerId,
                        orElse:
                            () => TripParticipant(uid: '', username: 'Unknown'),
                      );

                      return ListTile(
                        contentPadding:
                            EdgeInsets.zero, // Remove default padding
                        leading: const Icon(Icons.card_travel),
                        title: Text(trip.name),
                        subtitle: Text('From: @${owner.username}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _viewTripInvitation(trip.id),
                      );
                    },
                  ),
                ],

                // Preferences Section - Header + Cupertino Controls
                const Divider(height: 32),
                const Padding(
                  padding: EdgeInsets.only(
                    bottom: 16.0,
                  ), // Increased bottom padding
                  child: Text(
                    'Preferences',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildPreferenceControl<String>(
                  label: 'Distance',
                  value: _distanceUnit,
                  options: const {
                    'km': Text('Kilometers'),
                    'mi': Text('Miles'),
                  },
                  onChanged:
                      _loading
                          ? null
                          : (value) {
                            if (value != null) {
                              setState(() => _distanceUnit = value);
                              _savePreference('distanceUnit', value);
                            }
                          },
                ),
                const SizedBox(height: 16), // Spacing between controls
                _buildPreferenceControl<String>(
                  label: 'Time',
                  value: _timeFormat,
                  options: const {
                    '24h': Text('24-hour'),
                    'am/pm': Text('AM/PM'),
                  },
                  onChanged:
                      _loading
                          ? null
                          : (value) {
                            if (value != null) {
                              setState(() => _timeFormat = value);
                              _savePreference('timeFormat', value);
                            }
                          },
                ),
                // Removed Date Format preference control

                // Trips Section - Header + List
                const Divider(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Trips',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _navigateToCreateTrip,
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'New Trip',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(),
                    ),
                  ],
                ),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // Set padding to zero, especially top, to remove space above the first item
                  padding: EdgeInsets.only(top: 16),
                  itemCount: tripDataService.userTrips.length,
                  separatorBuilder:
                      (_, __) => const Divider(
                        height: 1,
                        color: Colors.transparent,
                      ), // Keep transparent divider for spacing consistency from TripTile margin
                  itemBuilder: (context, index) {
                    final trip = tripDataService.userTrips[index];
                    final isSelected =
                        trip.id == tripDataService.selectedTripId;
                    // Use a standard ListTile or keep TripTile if it's sufficiently styled
                    return TripTile(
                      trip: trip,
                      isSelected: isSelected,
                      // Removed dateFormat parameter
                      borderColor: trip.color, // Pass trip color here
                      onTripSelected: (selectedTrip) async {
                        final newId = isSelected ? null : selectedTrip.id;
                        await tripDataService.setSelectedTrip(newId);
                        // No need to manually load trip days since we have streams
                      },
                      onTripLeave: _confirmLeaveTrip,
                    );
                  },
                ),

                // Account Section - Header + ListTiles
                const Divider(height: 32),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Account',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign Out'),
                  onTap: () {
                    // Replace direct Firebase Auth call with AuthService call
                    // Import AuthService at the top of the file: import 'package:trip_planner/auth/auth_service.dart';
                    final authService = AuthService();
                    authService.signOut();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () => _confirmDeleteAccount(context),
                ),

                const SizedBox(height: 32), // Bottom padding
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // Method to confirm and process account deletion - Updated to iOS style
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text('Delete Account?'),
            content: const Text(
              'This action cannot be undone. All your data will be permanently deleted. '
              'Are you sure you want to delete your account?',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                isDefaultAction: true,
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(true),
                isDestructiveAction: true,
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() {
        _loading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Delete user data from Firestore
      final batch = FirebaseFirestore.instance.batch();

      // Delete user document
      batch.delete(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
      );

      // Find and handle user's trips
      for (final trip in _userTrips) {
        final tripRef = FirebaseFirestore.instance
            .collection('trips')
            .doc(trip.id);
        if (trip.ownerId == user.uid) {
          // If user is owner and there are other participants, transfer ownership
          final otherParticipants =
              trip.participants.where((p) => p.uid != user.uid).toList();

          if (otherParticipants.isNotEmpty) {
            // Transfer ownership to first participant
            final newOwner = otherParticipants.first;
            batch.update(tripRef, {
              'ownerId': newOwner.uid,
              'participants': otherParticipants.map((p) => p.toMap()).toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            // Delete trip if no other participants
            batch.delete(tripRef);

            // Delete all trip days for this trip
            final tripDaysSnapshot =
                await FirebaseFirestore.instance
                    .collection('tripDays')
                    .where('tripId', isEqualTo: trip.id)
                    .get();

            for (var doc in tripDaysSnapshot.docs) {
              batch.delete(doc.reference);
            }
          }
        } else {
          // If user is just a participant, remove from participants
          final updatedParticipants =
              trip.participants
                  .where((p) => p.uid != user.uid)
                  .map((p) => p.toMap())
                  .toList();

          batch.update(tripRef, {
            'participants': updatedParticipants,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Commit all Firestore changes
      await batch.commit();

      // Delete profile picture from storage if exists
      if (user.photoURL != null && user.photoURL!.contains('firebase')) {
        try {
          await FirebaseStorage.instance
              .ref('profilePictures/${user.uid}')
              .delete();
        } catch (e) {
          // Ignore errors if photo doesn't exist
          print('Error deleting profile photo: $e');
        }
      }

      // Delete the Firebase Auth user
      await user.delete();

      // Clear local storage
      final box = Hive.box('userBox');
      await box.clear();

      // User will be automatically signed out and redirected to auth page
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // Helper method to determine the profile image
  ImageProvider? _getProfileImage(UserDataService userDataService) {
    // Check if we have a local file path (during image upload)
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      if (_photoUrl!.startsWith('/')) {
        // Local file path
        return FileImage(File(_photoUrl!));
      } else {
        // Network URL
        return NetworkImage(_photoUrl!);
      }
    }
    // Try to use the userDataService photoUrl
    else if (userDataService.photoUrl != null &&
        userDataService.photoUrl!.isNotEmpty) {
      return NetworkImage(userDataService.photoUrl!);
    }
    // Finally check the Firebase Auth user's photoURL
    else if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
      return NetworkImage(user!.photoURL!);
    }
    // Return null if no image is available
    return null;
  }

  // Helper method to determine if the default icon should be shown
  bool _shouldShowDefaultIcon(UserDataService userDataService) {
    // Use the state's user variable
    return (userDataService.photoUrl == null ||
            userDataService.photoUrl!.isEmpty) &&
        (_photoUrl == null || _photoUrl!.isEmpty) &&
        (user?.photoURL == null || user!.photoURL!.isEmpty);
  }

  // Helper widget for preference controls
  Widget _buildPreferenceControl<T extends Object>({
    required String label,
    required T value,
    required Map<T, Widget> options,
    required ValueChanged<T?>? onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: CupertinoSlidingSegmentedControl<T>(
              children: options,
              groupValue: value,
              onValueChanged: onChanged ?? (_) {},
              thumbColor: CupertinoColors.systemGrey5,
              backgroundColor: CupertinoColors.systemGrey6,
            ),
          ),
        ),
      ],
    );
  }
}
