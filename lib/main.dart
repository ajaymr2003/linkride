import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/no_internet_screen.dart';
import 'services/connectivity_service.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Request Notification Permissions (Crucial for Android 13+)
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // 3. Set Foreground Notification Options
  // This allows notifications to show as popups even when the app is OPEN
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, // Required for heads-up notification
    badge: true,
    sound: true,
  );

  print('🔔 User granted notification permission: ${settings.authorizationStatus}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green, // Matches your LinkRide theme
        useMaterial3: true,
      ),
      // Home uses your NetworkWrapper logic to handle offline states
      home: const NetworkWrapper(child: AuthGate()), 
    );
  }
}

/// A wrapper that listens to connectivity changes and shows a 
/// No Internet screen overlay when the device is offline.
class NetworkWrapper extends StatefulWidget {
  final Widget child;

  const NetworkWrapper({super.key, required this.child});

  @override
  State<NetworkWrapper> createState() => _NetworkWrapperState();
}

class _NetworkWrapperState extends State<NetworkWrapper> {
  late Stream<bool> _connectivityStream;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _connectivityStream = ConnectivityService().onConnectivityChanged;
    _checkInitialConnection();
  }

  Future<void> _checkInitialConnection() async {
    final isOnline = await ConnectivityService().hasInternetConnection();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _connectivityStream,
      initialData: _isOnline,
      builder: (context, snapshot) {
        final bool currentOnlineStatus = snapshot.data ?? true;

        return Stack(
          children: [
            // Layer 1: The actual App logic (AuthGate -> UserDashboard)
            widget.child,

            // Layer 2: The No Internet Popup (Only visible when offline)
            if (!currentOnlineStatus)
              Positioned.fill(
                child: NoInternetScreen(
                  onRetry: () async {
                    // Force a re-check when the user taps OK/Retry
                    await _checkInitialConnection();
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}