import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/landing_screen.dart';
import 'screens/no_internet_screen.dart';
import 'services/connectivity_service.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // CHANGE THIS LINE:
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
            // Layer 1: The actual App
            widget.child,

            // Layer 2: The No Internet Popup (Only visible when offline)
            if (!currentOnlineStatus)
              Positioned.fill(
                child: NoInternetScreen(
                  onRetry: () async {
                    // Force a re-check when OK is pressed
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
