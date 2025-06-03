import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/models/trip_participant.dart';
import 'package:trip_planner/models/trip_invitation.dart';
import 'package:trip_planner/services/trip_invitation_service.dart';

class TripInvitationPage extends StatefulWidget {
  final String tripId;

  const TripInvitationPage({super.key, required this.tripId});

  @override
  State<TripInvitationPage> createState() => _TripInvitationPageState();
}

class _TripInvitationPageState extends State<TripInvitationPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Trip? _trip;
  TripInvitation? _invitation;
  String? _error;
  final user = FirebaseAuth.instance.currentUser;
  final TripInvitationService _invitationService = TripInvitationService();

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
  }

  Future<void> _loadTripDetails() async {
    if (user == null) {
      setState(() {
        _error = 'User not logged in';
        _isLoading = false;
      });
      return;
    }

    try {
      final invitationsSnapshot =
          await FirebaseFirestore.instance
              .collection('tripInvitations')
              .where('tripId', isEqualTo: widget.tripId)
              .where('inviteeId', isEqualTo: user!.uid)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      final tripDoc =
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(widget.tripId)
              .get();

      if (!tripDoc.exists) {
        setState(() {
          _error = 'Trip not found';
          _isLoading = false;
        });
        return;
      }

      if (invitationsSnapshot.docs.isNotEmpty) {
        _invitation = TripInvitation.fromFirestore(
          invitationsSnapshot.docs.first,
        );
      }

      setState(() {
        _trip = Trip.fromFirestore(tripDoc);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading trip details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _respondToInvitation(bool accept) async {
    if (_trip == null || _invitation == null || user == null || _isProcessing)
      return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (accept) {
        final tripRef = FirebaseFirestore.instance
            .collection('trips')
            .doc(_trip!.id);

        final tripDoc = await tripRef.get();
        if (!tripDoc.exists) {
          throw Exception('Trip no longer exists');
        }

        final data = tripDoc.data()!;
        final participants = List<Map<String, dynamic>>.from(
          data['participants'] ?? [],
        );

        final existingIndex = participants.indexWhere(
          (p) => p['uid'] == user!.uid,
        );

        final participant = {
          'uid': user!.uid,
          'username': user!.displayName ?? user!.email?.split('@')[0] ?? 'User',
          'email': user!.email,
          'photoURL': user!.photoURL,
          'invitationStatus': 'accepted',
        };

        if (existingIndex >= 0) {
          participants[existingIndex] = participant;
        } else {
          participants.add(participant);
        }

        await tripRef.update({
          'participants': participants,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final deleteSuccess = await _invitationService.deleteInvitation(
        _invitation!.id,
      );

      if (!deleteSuccess) {
        debugPrint('Warning: Failed to delete invitation ${_invitation!.id}');
      }

      if (mounted) {
        if (accept) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip invitation accepted!')),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip invitation declined')),
          );
          Navigator.of(context).pop(false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error processing invitation: $e';
          _isProcessing = false;
        });
      }
    } finally {
      if (mounted && _isProcessing) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _formatParticipants(
    List<TripParticipant> participants,
    int maxToShow,
  ) {
    if (participants.isEmpty) {
      return 'No participants yet';
    }
    final displayNames =
        participants.take(maxToShow).map((p) => '@${p.username}').toList();
    final remainingCount = participants.length - maxToShow;

    String result = displayNames.join(', ');
    if (remainingCount > 0) {
      result += ', ... +$remainingCount more';
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Invitation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Invitation')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Invitation')),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final participantsString = _formatParticipants(_trip!.participants, 2);
    final destinationName = _trip!.destination?.name ?? 'No destination set';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Invitation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade200, Colors.purple.shade200],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              const SizedBox(height: 30),
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _trip!.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              destinationName,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_outlined, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              participantsString,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 30.0),
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _respondToInvitation(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'DECLINE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _respondToInvitation(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'ACCEPT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
