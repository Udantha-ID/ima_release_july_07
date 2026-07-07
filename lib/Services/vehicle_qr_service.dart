import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/vehicle_q_model.dart';
import 'package:test_app/app_config.dart';

class VehicleQrService {
  
  // ── Base URL for Vehicle QR API ────────────────────────────────────────────────
  static const String baseUrl = "${AppConfig.baseUrl}/api";

  static const String exploredrive = 'https://srilankaautorentals.com/api';

  static String _friendlyError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'Request timed out. Please check your connection and retry.';
    }
    if (msg.contains('Connection timed out') || msg.contains('errno = 110')) {
      return 'Server is unreachable. Please check your internet connection and try again.';
    }
    if (msg.contains('SocketException') || msg.contains('NetworkException')) {
      return 'No internet connection. Please check your Wi-Fi or mobile data.';
    }
    if (msg.contains('404')) return 'Service not found. Please contact support.';
    if (msg.contains('500')) return 'Server error. Please try again later.';
    return 'Something went wrong. Please try again.';
  }

  static Future<VehicleQrModel> getVehicleDetails(String vehicleNo, {required String preferredName, required String employeeId, required String vehicleNumber}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$exploredrive/vehicle-details/$vehicleNo'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.trim().isEmpty) {
        return VehicleQrModel(status: false, message: 'No response from server.', data: null);
      }

      final Map<String, dynamic> jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return VehicleQrModel.fromJson(jsonData);
      } else {
        return VehicleQrModel(
          status: false,
          message: jsonData['message'] ?? 'Failed to fetch vehicle details',
          data: null,
        );
      }
    } on TimeoutException {
      return VehicleQrModel(
        status: false,
        message: 'Request timed out. Please check your connection and retry.',
        data: null,
      );
    } catch (e) {
      return VehicleQrModel(
        status: false,
        message: _friendlyError(e),
        data: null,
      );
    }
  }

  //NEW API (use this one)
  static Future<VehicleQrModel> getVehicleDetailsWithLog({
    required String employeeId,
    required String preferredName,
    required String vehicleNumber,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/get_vehicle_qr.php");

      final response = await http
          .post(
            uri,
            body: {
              "employee_id": employeeId,
              "preferred_name": preferredName,
              "vehicle_number": vehicleNumber,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.trim().isEmpty) {
        return VehicleQrModel(status: false, message: 'No response from server.', data: null);
      }

      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      return VehicleQrModel.fromJson(jsonData);
    } on TimeoutException {
      return VehicleQrModel(
        status: false,
        message: 'Request timed out. Please check your connection and retry.',
        data: null,
      );
    } catch (e) {
      return VehicleQrModel(
        status: false,
        message: _friendlyError(e),
        data: null,
      );
    }
  }
}
