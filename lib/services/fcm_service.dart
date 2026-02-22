import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class FCMService {
  // Your Project ID from the Firebase Console settings
  static const String _projectId = "mainproject-c4112";

  // This gets the temporary "Bearer Token" using your JSON file
  static Future<String> _getAccessToken() async {
    final serviceAccountJson = await rootBundle.loadString('assets/service-account.json');
    final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    
    final client = await clientViaServiceAccount(accountCredentials, scopes);
    return client.credentials.accessToken.data;
  }

  static Future<void> sendPushNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    try {
      final String accessToken = await _getAccessToken();
      final String url = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'high_importance_channel',
                'sound': 'default',
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Success: Notification sent via V1 API");
      } else {
        print("❌ Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("❌ FCM Exception: $e");
    }
  }
}