import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:test_app/app_config.dart';

class ApiService {

  // ── Base URL for API ────────────────────────────────────────────────
  static const String baseUrl = "${AppConfig.baseUrl}/api";

  // ── Friendly error mapper ─────────────────────────────────────────────────
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

  // ── Upload leave document ─────────────────────────────────────────────────
  static Future<void> uploadLeaveDocument({
    required int leaveRequestId,
    required File file,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/upload_leave_document.php");
      final req = http.MultipartRequest("POST", uri);
      req.fields["leave_request_id"] = leaveRequestId.toString();
      req.files.add(await http.MultipartFile.fromPath("document", file.path));
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      final bodyStr  = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw Exception('Server error (${streamed.statusCode}).');
      }
      if (bodyStr.trim().isEmpty) {
        throw Exception('No response from server.');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Get profile photo ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProfilePhoto({
    required int employeeId,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/get_profile_photo.php?employee_id=$employeeId");
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      final data  = jsonDecode(res.body);
      final photo = data["photo"];
      if (photo == null) return null;
      return Map<String, dynamic>.from(photo);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Fetch manager leave requests ──────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchManagerLeaveRequests({
    required String managerId,
  }) async {
    try {
      final uri = Uri.parse(
          "$baseUrl/get_manager_leave_requests.php?manager_id=$managerId");
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      final body = json.decode(res.body);
      if (body["success"] != true) {
        throw Exception(body["message"] ?? "Unknown error");
      }
      final List data = body["data"] ?? [];
      return data.map<Map<String, dynamic>>((x) {
        final isSpecial       = x["is_special_request"].toString() == "1";
        final overseeName     = (x["oversee_name"]     ?? "").toString().trim();
        final relieverComment = (x["reliever_comment"] ?? "").toString().trim();
        return {
          "leave_request_id": x["leave_request_id"],
          "employee_id":      x["employee_id"],
          "employeeName":     x["employee_name"] ?? "",
          "position":         x["job_title_name"] ?? "—",
          "employeeId":       x["employee_code"] ?? x["employee_id"],
          "leaveType":        (x["leave_policy_name"] ?? "").toString(),
          "from":             (x["leave_start_date"]  ?? "").toString(),
          "to":               (x["leave_end_date"]    ?? "").toString(),
          "days":             (x["number_of_days"]    ?? "").toString(),
          "reason":           x["reason"] ?? "",
          "coveringOfficer":  (!isSpecial && overseeName.isNotEmpty)
              ? {
                  "name": overseeName,
                  "note": relieverComment.isNotEmpty ? relieverComment : "—",
                }
              : null,
          "attachmentName":   x["attachment_name"],
          "attachmentPath":   x["attachment_path"],
          "is_special_request": x["is_special_request"],
          "status":           x["status"],
          "requested_at":     x["requested_at"],
        };
      }).toList();
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Approve leave ─────────────────────────────────────────────────────────
  static Future<bool> approveLeave({
    required String managerId,
    required int leaveRequestId,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/approve_leave.php");
      final res = await http.post(uri, body: {
        "manager_id":       managerId,
        "leave_request_id": leaveRequestId.toString(),
      }).timeout(const Duration(seconds: 15));

      print("STATUS: ${res.statusCode}");
      print("APPROVE URL: $uri");
      print("APPROVE BODY: ${res.body}");

      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      final body = json.decode(res.body);
      if (body["success"] == true) return true;
      throw Exception(body["message"] ?? "Approve failed");
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      print("Approve Error: $e");
      throw Exception(_friendlyError(e));
    }
  }

  // ── Reject leave ──────────────────────────────────────────────────────────
  static Future<void> rejectLeave({
    required String managerId,
    required int leaveRequestId,
    required String comment,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/reject_leave.php");
      final res = await http.post(uri, body: {
        "manager_id":       managerId,
        "leave_request_id": leaveRequestId.toString(),
        "comment":          comment,
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      final body = json.decode(res.body);
      if (body["success"] != true) {
        throw Exception(body["message"] ?? "Reject failed");
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Fetch employees ───────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchEmployees() async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/get_users.php"),
              headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic> && decoded["data"] is List) {
        return decoded["data"] as List<dynamic>;
      }
      if (decoded is List) return decoded;
      throw Exception("Unexpected response format.");
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/login.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      ).timeout(const Duration(seconds: 15));

      debugPrint("LOGIN URL: $url");
      debugPrint("LOGIN STATUS: ${res.statusCode}");
      debugPrint("LOGIN BODY: '${res.body}'");

      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('Server returned empty response. Please try again.');
      }
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Get leave balance ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLeaveBalance({
    required String employeeId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/get_leave_balance.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"employeeId": employeeId}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server. Please try again.');
      }
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Check leave no-pay preview ────────────────────────────────────────────
  static Future<Map<String, dynamic>> checkLeaveNoPayPreview({
    required String employeeId,
    required int    leavePolicyId,
    required double days,
  }) async {
    try {
      final url = Uri.parse(
        "$baseUrl/check_leave_balance.php"
        "?employee_id=$employeeId&leave_policy_id=$leavePolicyId&days=$days",
      );
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 10));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // ── Apply leave request ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> applyLeaveRequest({
    required String employeeId,
    required int leavePolicyId,
    required String startDate,
    required String endDate,
    required double numberOfDays,
    required String reason,
    String? overseeMemberId,
    required bool isSpecialRequest,
    String? address,
    String? halfDaySession,
    String? managerId,
    int acknowledgeNoPay = 0,
  }) async {
    try {
      final url  = Uri.parse("$baseUrl/apply_leave_request.php");
      final body = {
        "employeeId":      employeeId,
        "leavePolicyId":   leavePolicyId,
        "startDate":       startDate,
        "endDate":         endDate,
        "numberOfDays":    numberOfDays,
        "reason":          reason,
        "overseeMemberId": overseeMemberId ?? "",
        "isSpecialRequest": isSpecialRequest ? 1 : 0,
        "address":         address ?? "",
        "halfDaySession":  halfDaySession ?? "",
        "managerId":       managerId ?? "",
        "acknowledgeNoPay": acknowledgeNoPay,
      };
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      debugPrint("LEAVE APPLY → HTTP ${res.statusCode}: ${res.body}");

      // 5xx = real server crash — throw so caller shows generic error
      if (res.statusCode >= 500) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      // 4xx (overlap/balance/validation) have a JSON body with success+message —
      // return it so the form can show the real reason via the TopBanner.
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      debugPrint("LEAVE APPLY ERROR: $e");
      throw Exception(_friendlyError(e));
    }
  }

  // ── Get manager employee IDs ──────────────────────────────────────────────
  static Future<List<String>> getManagerIds() async {
    try {
      final url = Uri.parse("$baseUrl/get_manager_ids.php");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      if (res.body.trim().isEmpty) return [];
      final decoded = jsonDecode(res.body);
      if (decoded["success"] != true) return [];
      return List<String>.from(decoded["manager_ids"] ?? []);
    } catch (e) {
      debugPrint("getManagerIds failed: $e");
      return []; // fail silently — non-critical
    }
  }

  // ── Get relievers ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getRelievers({
    required String employeeId,
    required String departmentId,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/get_relievers.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({
          "employeeId":   employeeId,
          "departmentId": departmentId,
          "fromDate":     fromDate,
          "toDate":       toDate,
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Get leave managers ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLeaveManagers({
    required String employeeId,
  }) async {
    try {
      // Reuses the same get_default_managers.php endpoint
      final url = Uri.parse(
        "$baseUrl/../vehicle/get_default_managers.php?employee_id=$employeeId",
      );
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Get leave history ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLeaveHistory({
    required String employeeId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/get_leave_history.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"employeeId": employeeId}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server. Please try again.');
      }
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Get recent leave history ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getRecentLeaveHistory({
    required String employeeId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/get_recent_leaves.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"employeeId": employeeId}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Cancel leave request ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> cancelLeaveRequest({
    required String employeeId,
    required int leaveRequestId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/cancel_leave_request.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"employeeId": employeeId, "leaveRequestId": leaveRequestId}),
      ).timeout(const Duration(seconds: 15));

      debugPrint("CANCEL URL: $url");
      debugPrint("CANCEL STATUS: ${res.statusCode}");
      debugPrint("CANCEL BODY: '${res.body}'");

      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server. Please try again.');
      }
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Get reliever requests ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getRelieverRequests({
    required String employeeId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/get_reliever_requests.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"employeeId": employeeId}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Update password ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updatePassword({
    required String email,
    required String newPassword,
    required String recoveryKey,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/create_new_password.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email":        email,
          "newPassword":  newPassword,
          "recovery_key": recoveryKey,
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Forgot password ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
    required String recoveryKey,
    required String newPassword,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/forgot_password.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email":        email,
          "recovery_key": recoveryKey,
          "newPassword":  newPassword,
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Reliever accept ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> relieverAccept({
    required int leaveRequestId,
    required String relieverId,
    required String comment,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/reliever_accept.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "leaveRequestId": leaveRequestId,
          "relieverId":     relieverId,
          "comment":        comment,
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      return jsonDecode(res.body);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Reliever decline ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> relieverDecline({
    required int leaveRequestId,
    required String relieverId,
    required String comment,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/reliever_decline.php");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "leaveRequestId": leaveRequestId,
          "relieverId":     relieverId,
          "comment":        comment,
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}).');
      }
      if (res.body.trim().isEmpty) {
        throw Exception('No response from server.');
      }
      return jsonDecode(res.body);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }
}
