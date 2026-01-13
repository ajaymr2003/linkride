import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();

  ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  Future<bool> hasInternetConnection() async {
    try {
      final ConnectivityResult connectivityResult = await _connectivity
          .checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((ConnectivityResult result) {
      return result != ConnectivityResult.none;
    }).distinct();
  }
}
