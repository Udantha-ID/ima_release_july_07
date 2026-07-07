import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test_app/app_config.dart';

class StaffGatePassService {
  
  // ── Base URL for Staff Gate Pass API ────────────────────────────────
  static const String _baseUrl = "${AppConfig.baseUrl}/gatepass";

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

  static Future<Map<String, dynamic>> getGatePassManagers() async {
    try {
      final url = Uri.parse("$_baseUrl/get_gate_pass_managers.php");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getAllStaff() async {
    try {
      final url = Uri.parse("$_baseUrl/get_all_staff.php");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> createGatePass({
    required int    employeeId,
    required String employeeName,
    required String contactNo,
    required int    managerId,
    required String gatePassDate,
    required String outTime,
    required String returnTime,
    required String reason,
    String?         vehicleNo,
    List<int>?      companionEmployeeIds,
    String?         remark,
  }) async {
    try {
      final url = Uri.parse("$_baseUrl/create_gate_pass.php");
      final res = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept"       : "application/json",
            },
            body: jsonEncode({
              "employee_id"            : employeeId,
              "employee_name"          : employeeName,
              "contact_no"             : contactNo,
              "manager_id"             : managerId,
              "gate_pass_date"         : gatePassDate,
              "out_time"               : outTime,
              "return_time"            : returnTime,
              "reason"                 : reason,
              "vehicle_no"             : vehicleNo ?? "",
              "companion_employee_ids" : companionEmployeeIds ?? [],
              "remark"                 : remark ?? "",
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getGatePassRequests({
    required int employeeId,
  }) async {
    try {
      final url = Uri.parse(
          "$_baseUrl/get_gate_pass_request.php?employee_id=$employeeId");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> cancelGatePassRequest({
    required int id,
    required int employeeId,
  }) async {
    try {
      final url = Uri.parse("$_baseUrl/cancel_gate_pass.php");
      final res = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept"       : "application/json",
            },
            body: jsonEncode({
              "id"          : id,
              "employee_id" : employeeId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> approveGatePassRequest({
    required int id,
    required int managerId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse("$_baseUrl/approve_gate_pass_request.php"),
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({"id": id, "manager_id": managerId}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> rejectGatePassRequest({
    required int    id,
    required int    managerId,
    required String rejectReason,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse("$_baseUrl/reject_gate_pass_request.php"),
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({
              "id"           : id,
              "manager_id"   : managerId,
              "reject_reason": rejectReason,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getManagerGatePassRequests({
    required int managerId,
    String? status,
  }) async {
    try {
      var url = "$_baseUrl/get_manager_gate_pass_request.php?manager_id=$managerId";
      if (status != null) url += "&status=$status";

      final res = await http
          .get(Uri.parse(url), headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> checkOutGatePass({
    required int id,
    required int employeeId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse("$_baseUrl/check_out.php"),
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({"id": id, "employee_id": employeeId}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> checkInGatePass({
    required int id,
    required int employeeId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse("$_baseUrl/check_in.php"),
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({"id": id, "employee_id": employeeId}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> removeGatePassCompanion({
    required int gatePassId,
    required int companionId,
    required int managerId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse("$_baseUrl/remove_gate_pass_companion.php"),
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({
              "gate_pass_id" : gatePassId,
              "companion_id" : companionId,
              "manager_id"   : managerId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getManagerGatePassSummary({
    required int managerId,
  }) async {
    try {
      final url = Uri.parse("$_baseUrl/get_manager_gate_pass_summary.php?manager_id=$managerId");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format.');
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }
}
