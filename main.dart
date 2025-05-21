import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/auth_page.dart';
import 'views/map_page.dart';
import 'views/itinerary_page.dart';
import 'views/profile_page.dart';
import 'views/trip_invitation_page.dart';
import 'services/trip_invitation_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trip_planner/services/user_data_service.dart';
import 'package:trip_planner/services/trip_data_service.dart';
// Import Trip model for context.select
import 'package:trip_planner/models/trip.dart';
import 'package:trip_planner/services/directions_service.dart';
import 'package:trip_planner/services/places_service.dart'; // Import PlacesService
import 'package:cupertino_calendar_picker/cupertino_calendar_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await Hive.openBox('userBox');

  // Create trip data service instance first
  final tripDataService = TripDataService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserDataService()),
        // Use the existing instance of TripDataService
        ChangeNotifierProvider.value(value: tripDataService),
        Provider<DirectionsService>(
          create:
              (_) => DirectionsService(
                // Use the same API key from PlacesService
                apiKey: PlacesService.apiKey,
              ),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: const MyApp(),
    ),
  );

  // Initialize TripDataService with streams after runApp
  // This ensures it has access to the provider context if needed
  tripDataService.initialize();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Select only the selectedTrip from TripDataService
    // This ensures MyApp only rebuilds when the selected trip actually changes
    final Trip? selectedTrip = context.select(
      (TripDataService service) => service.selectedTrip,
    );
    // Get color from selected trip, or use default if no trip is selected
    final Color seedColor = selectedTrip?.color ?? Colors.teal;

    // Debug print to see when MaterialApp rebuilds due to theme change
    // print("Rebuilding MaterialApp with seedColor: $seedColor");

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trip Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          // Lock brightness to prevent unintended changes
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const MyHomePage(
              key: ValueKey('MyHomePage'),
              title: 'Trip Planner',
            );
          }
          return const AuthPage();
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 1;

  final TripInvitationService _invitationService = TripInvitationService();
  bool _checkingInvitations = true;

  @override
  void initState() {
    super.initState();
    _checkPendingInvitations();

    // Initialize data services - use initSelectedTrip but we no longer
    // need to call loadUserTrips as that's handled by the stream now
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserDataService>(context, listen: false).loadUserData();
      Provider.of<TripDataService>(context, listen: false).initSelectedTrip();
      // The following line is no longer needed as we use streams now
      // Provider.of<TripDataService>(context, listen: false).loadUserTrips();
    });
  }

  Future<void> _checkPendingInvitations() async {
    setState(() {
      _checkingInvitations = true;
    });

    try {
      final pendingInvitation =
          await _invitationService.getFirstPendingInvitation();

      // If we have a pending invitation, show it
      if (pendingInvitation != null && mounted) {
        // Delay showing the invitation page briefly to allow the main UI to load
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => TripInvitationPage(tripId: pendingInvitation.id),
            ),
          );
        });
      }
    } catch (e) {
      print('Error checking invitations: $e');
    } finally {
      if (mounted) {
        setState(() {
          _checkingInvitations = false;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Define the pages for the IndexedStack
  // Add rootContext parameter to ProfilePage
  static final List<Widget> _pages = <Widget>[
    const MapPage(),
    const ItineraryPage(),
    // Pass the BuildContext from MyHomePage down to ProfilePage
    Builder(builder: (context) => ProfilePage(rootContext: context)),
  ];

  @override
  Widget build(BuildContext context) {
    // Select only the trip color needed for the BottomNavigationBar
    final Color tripColor = context.select(
      (TripDataService service) => service.selectedTrip?.color ?? Colors.teal,
    );

    // If still checking invitations, show loading
    if (_checkingInvitations) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Build the main UI
    return Scaffold(
      body: IndexedStack(
        // Keeps state of inactive tabs
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Itinerary',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped, // Updates _selectedIndex via setState
        type: BottomNavigationBarType.fixed, // Keep labels visible
        fixedColor: tripColor, // Use the selected trip color
      ),
    );
  }
}
