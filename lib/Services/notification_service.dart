import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class NotificationService {
  // Derived from ApiService.baseUrl so both always point to the same host.
  // ApiService.baseUrl ends in "/api"; we replace that segment with "/notifications".
  static String get _baseUrl {
    final api = ApiService.baseUrl;
    return '${api.substring(0, api.lastIndexOf('/'))}/notifications';
  }

  static Future<void> saveFcmToken({
    required String employeeId,
    required String fcmToken,
  }) async {
    try {
      debugPrint("FCM: saving token for employee $employeeId");
      debugPrint("FCM: token = $fcmToken");
      final url = Uri.parse("$_baseUrl/save_fcm_token.php");
      debugPrint("FCM: POST $url");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"employeeId": employeeId, "fcmToken": fcmToken}),
      ).timeout(const Duration(seconds: 15));
      debugPrint("FCM token save → HTTP ${res.statusCode}: ${res.body}");
    } catch (e) {
      debugPrint("FCM token save failed: $e");
    }
  }
}
