import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> isOnWifi() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet);
  } catch (_) {
    return true;
  }
}
