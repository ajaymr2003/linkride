import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();

  ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  /// Checks if the device is currently connected to any network (Wifi or Mobile)
  Future<bool> hasInternetConnection() async {
    try {
      // The library now returns a List of ConnectivityResult
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      
      // If any of the results in the list are NOT 'none', we have a connection
      return results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Listens to changes in connectivity status
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((List<ConnectivityResult> results) {
      // Return true if the list contains any active connection
      return results.any((result) => result != ConnectivityResult.none);
    }).distinct();
  }
}