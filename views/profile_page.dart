import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_invitation.dart';
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
  String? _photoUrl;
  final ImagePicker _imagePicker = ImagePicker();
  List<Trip> _userTrips = [];
  String? _selectedTripId;
  List<TripInvitation> _pendingInvitations = [];
  final TripInvitationService _invitationService = TripInvitationService();

  @override
  void initState() {
    super.initState();
    _selectedTripId = Hive.box('userBox').get('selectedTripId') as String?;
    _loadProfile();
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
      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _distanceUnit = data['distanceUnit'] ?? 'km';
          _timeFormat = data['timeFormat'] ?? '24h';
          _photoUrl = data['photoURL'] as String?;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading profile: $e';
      });
    }
  }

  Future<void> _loadPendingInvitations() async {
    if (user == null) return;
    try {
      final invitations = await _invitationService.getPendingInvitations();
      if (!mounted) return;
      setState(() {
        _pendingInvitations = invitations;
      });
    } catch (e) {
      if (!mounted) return;
      print('Error loading invitations: $e');
    }
  }

  Future<void> _loadPreferencesFromHive() async {
    final box = Hive.box('userBox');
    final distanceUnit = box.get('distanceUnit');

    if (!mounted) return;

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
    final selectedTripId = box.get('selectedTripId') as String?;
    if (selectedTripId != null) {
      setState(() {
        _selectedTripId = selectedTripId;
      });
    }
  }

  Future<void> _savePreference(String key, String value) async {
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        key: value,
      }, SetOptions(merge: true));

      final box = Hive.box('userBox');
      await box.put(key, value);

      if (!mounted) return;

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

    final tempFile = File(pickedFile.path);

    setState(() {
      _photoUrl = pickedFile.path;
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
        _photoUrl = downloadUrl;
      });

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
    final modalContext = widget.rootContext ?? context;
    final result = await TripCreationPage.show(context: modalContext);

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip created successfully!')),
      );
    }
  }

  void _viewTripInvitationDetail(String invitationId) async {
    try {
      final invitation = await _invitationService.getInvitationById(
        invitationId,
      );
      if (invitation == null || !mounted) return;

      final tripDoc =
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(invitation.tripId)
              .get();

      if (!tripDoc.exists || !mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripInvitationPage(tripId: invitation.tripId),
        ),
      );

      if (result != null) {
        _loadPendingInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading invitation: $e')));
      }
    }
  }

  Future<void> _confirmLeaveTrip(Trip trip) async {
    final uid = user!.uid;
    final tripRef = FirebaseFirestore.instance.collection('trips').doc(trip.id);
    final participants = trip.participants;
    if (trip.ownerId == uid) {
      final remaining = participants.where((p) => p.uid != uid).toList();
      if (remaining.isNotEmpty) {
        final newOwner = remaining[Random().nextInt(remaining.length)];
        await tripRef.update({
          'participants': remaining.map((p) => p.toMap()).toList(),
          'ownerId': newOwner.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final tripDataService = Provider.of<TripDataService>(
          context,
          listen: false,
        );

        await tripDataService.deleteTripDays(trip.id);

        await tripRef.delete();
      }
    } else {
      final remaining = participants.where((p) => p.uid != uid).toList();
      await tripRef.update({
        'participants': remaining.map((p) => p.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;

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
                title: const Text('Your Profile'),
                backgroundColor: Colors.white,
                centerTitle: true,
              ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
                                  icon: const Icon(Icons.edit, size: 20),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black.withOpacity(
                                      0.5,
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(28, 28),
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

                if (_pendingInvitations.isNotEmpty) ...[
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pending Invitations (${_pendingInvitations.length})',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pendingInvitations.length,
                    padding: EdgeInsets.zero,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final invitation = _pendingInvitations[index];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.card_travel),
                        title: Text(invitation.tripName),
                        subtitle: Text('From: @${invitation.inviterName}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _viewTripInvitationDetail(invitation.id),
                      );
                    },
                  ),
                ],

                const Divider(height: 32),
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
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
                const SizedBox(height: 16),
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
                  padding: EdgeInsets.only(top: 16),
                  itemCount: tripDataService.userTrips.length,
                  separatorBuilder:
                      (_, __) =>
                          const Divider(height: 1, color: Colors.transparent),
                  itemBuilder: (context, index) {
                    final trip = tripDataService.userTrips[index];
                    final isSelected =
                        trip.id == tripDataService.selectedTripId;
                    return TripTile(
                      trip: trip,
                      isSelected: isSelected,
                      borderColor: trip.color,
                      onTripSelected: (selectedTrip) async {
                        final newId = isSelected ? null : selectedTrip.id;
                        await tripDataService.setSelectedTrip(newId);
                      },
                      onTripLeave: _confirmLeaveTrip,
                    );
                  },
                ),

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

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

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

      final batch = FirebaseFirestore.instance.batch();

      batch.delete(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
      );

      for (final trip in _userTrips) {
        final tripRef = FirebaseFirestore.instance
            .collection('trips')
            .doc(trip.id);
        if (trip.ownerId == user.uid) {
          final otherParticipants =
              trip.participants.where((p) => p.uid != user.uid).toList();

          if (otherParticipants.isNotEmpty) {
            final newOwner = otherParticipants.first;
            batch.update(tripRef, {
              'ownerId': newOwner.uid,
              'participants': otherParticipants.map((p) => p.toMap()).toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            batch.delete(tripRef);

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

      await batch.commit();

      if (user.photoURL != null && user.photoURL!.contains('firebase')) {
        try {
          await FirebaseStorage.instance
              .ref('profilePictures/${user.uid}')
              .delete();
        } catch (e) {
          print('Error deleting profile photo: $e');
        }
      }

      await user.delete();

      final box = Hive.box('userBox');
      await box.clear();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  ImageProvider? _getProfileImage(UserDataService userDataService) {
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      if (_photoUrl!.startsWith('/')) {
        return FileImage(File(_photoUrl!));
      } else {
        return NetworkImage(_photoUrl!);
      }
    } else if (userDataService.photoUrl != null &&
        userDataService.photoUrl!.isNotEmpty) {
      return NetworkImage(userDataService.photoUrl!);
    } else if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
      return NetworkImage(user!.photoURL!);
    }
    return null;
  }

  bool _shouldShowDefaultIcon(UserDataService userDataService) {
    return (userDataService.photoUrl == null ||
            userDataService.photoUrl!.isEmpty) &&
        (_photoUrl == null || _photoUrl!.isEmpty) &&
        (user?.photoURL == null || user!.photoURL!.isEmpty);
  }

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
