import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/no_internet_screen.dart';
import 'services/connectivity_service.dart';
import 'screens/auth/auth_gate.dart';
import 'services/ride_cleanup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Setup Notifications
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const NetworkWrapper(child: AuthGate()), 
    );
  }
}

class NetworkWrapper extends StatefulWidget {
  final Widget child;
  const NetworkWrapper({super.key, required this.child});
  @override
  State<NetworkWrapper> createState() => _NetworkWrapperState();
}

class _NetworkWrapperState extends State<NetworkWrapper> {
  late Stream<bool> _connectivityStream;
  bool _isOnline = true;
  bool _isCheckingInitialStatus = true; 

  @override
  void initState() {
    super.initState();
    _connectivityStream = ConnectivityService().onConnectivityChanged;
    _checkInitialConnection();
  }

  Future<void> _checkInitialConnection() async {
    final isOnline = await ConnectivityService().hasInternetConnection();
    
    if (isOnline) {
      // Run cleanup safely in the background
      _runStartupCleanup();
    }

    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        _isCheckingInitialStatus = false; 
      });
    }
  }

  // Safe wrapper for the cleanup service
  Future<void> _runStartupCleanup() async {
    try {
      await RideCleanupService.globalRideCleanup();
    } catch (e) {
      debugPrint("Startup Cleanup Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingInitialStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<bool>(
      stream: _connectivityStream,
      initialData: _isOnline,
      builder: (context, snapshot) {
        final bool currentOnlineStatus = snapshot.data ?? _isOnline;

        // If internet just came back, trigger cleanup
        if (currentOnlineStatus == true) {
          _runStartupCleanup();
        }

        return Stack(
          children: [
            widget.child,
            if (!currentOnlineStatus)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: NoInternetScreen(
                    onRetry: () async { await _checkInitialConnection(); },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}