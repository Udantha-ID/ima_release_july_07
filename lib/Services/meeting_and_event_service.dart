import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:test_app/app_config.dart';

class MeetingAndEventService {

  static const String baseUrl = "${AppConfig.baseUrl}/meetings";

  // Get All Staff API (use this in CreateEventScreen)
  static Future<Map<String, dynamic>> getAllStaff() async {
    final url = Uri.parse("$baseUrl/get_all_staff.php");

    final res = await http.get(
      url,
      headers: {"Accept": "application/json"},
    ).timeout(const Duration(seconds: 12));

    if (res.body.trim().isEmpty) throw Exception("EMPTY response");

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Invalid JSON format");
    return decoded;
  }

  // Get all meetings/events API
  static Future<List<Map<String, dynamic>>> getAllMeetings() async {
    final url = Uri.parse("$baseUrl/get_all_meetings.php");

    final res = await http.get(
      url,
      headers: {"Accept": "application/json"},
    ).timeout(const Duration(seconds: 15));

    if (res.body.trim().isEmpty) throw Exception("EMPTY response");
    if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}: ${res.body}");

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Invalid JSON format");
    if (decoded["success"] != true) {
      throw Exception(decoded["message"]?.toString() ?? "Failed to fetch meetings");
    }

    final rawList = decoded["data"];
    if (rawList is! List) return [];
    return rawList.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Get meetings split by created vs invited (Feature 4A)
  static Future<Map<String, dynamic>> getMyMeetings({required String employeeId}) async {
    final url = Uri.parse("$baseUrl/get_my_meetings.php?employee_id=$employeeId");

    final res = await http.get(
      url,
      headers: {"Accept": "application/json"},
    ).timeout(const Duration(seconds: 15));

    if (res.body.trim().isEmpty) throw Exception("EMPTY response");
    if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}: ${res.body}");

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Invalid JSON format");
    if (decoded["success"] != true) {
      throw Exception(decoded["message"]?.toString() ?? "Failed to fetch meetings");
    }
    return decoded;
  }

  // Cancel a meeting (sets status = 'cancelled', record stays visible)
  static Future<Map<String, dynamic>> cancelMeeting({
    required int meetingId,
    required String employeeId,
  }) async {
    final url = Uri.parse("$baseUrl/cancel_meeting.php");

    final res = await http.post(
      url,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"meeting_id": meetingId, "employee_id": employeeId}),
    ).timeout(const Duration(seconds: 15));

    if (res.body.trim().isEmpty) throw Exception("EMPTY response");
    if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}: ${res.body}");

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Invalid JSON format");
    return decoded;
  }

  // Soft-delete a meeting (Feature 4B)
  static Future<Map<String, dynamic>> deleteMeeting({
    required int meetingId,
    required String employeeId,
  }) async {
    final url = Uri.parse("$baseUrl/delete_meeting.php");

    final res = await http.post(
      url,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"meeting_id": meetingId, "employee_id": employeeId}),
    ).timeout(const Duration(seconds: 15));

    if (res.body.trim().isEmpty) throw Exception("EMPTY response");
    if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}: ${res.body}");

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Invalid JSON format");
    return decoded;
  }

  // Create meeting/event API
  static Future<Map<String, dynamic>> createMeeting({
    required String type,
    required String title,
    required String description,
    required String meetingDate,
    required String startTime,
    required String endTime,
    required String locationType,
    required String location,
    required List<String> membersIds,
    required int createdBy,
    String status = "scheduled",
    String responseStatus = "{}",
    String attachments = "[]",
  }) async {
    final url = Uri.parse("$baseUrl/create_event.php");
    final normalizedMemberIds = membersIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final autoResponseStatusMap = <String, String>{
      for (final id in normalizedMemberIds) id: "pending",
    };
    final resolvedResponseStatus =
        responseStatus.trim().isEmpty || responseStatus.trim() == "{}"
            ? jsonEncode(autoResponseStatusMap)
            : responseStatus;

    final res = await http.post(
      url,
      headers: {"Accept": "application/json"},
      body: {
        "type": type,
        "title": title,
        "description": description,
        "meeting_date": meetingDate,
        "start_time": startTime,
        "end_time": endTime,
        "location_type": locationType,
        "location": location,
        "members_ids": jsonEncode(normalizedMemberIds),
        "status": status,
        "created_by": createdBy.toString(),
        "user_id": createdBy.toString(),
        "response_status": resolvedResponseStatus,
        "attachments": attachments,
      },
    ).timeout(const Duration(seconds: 15));

    if (res.body.trim().isEmpty) throw Exception("EMPTY response");
    if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}: ${res.body}");

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw Exception("Invalid JSON response: ${res.body}");
    }
    if (decoded is! Map<String, dynamic>) throw Exception("Unexpected response format");
    return decoded;
  }

  // Create meeting with PDF attachment via multipart (Feature 2)
  static Future<Map<String, dynamic>> createMeetingWithAttachment({
    required String type,
    required String title,
    required String description,
    required String meetingDate,
    required String startTime,
    required String endTime,
    required String locationType,
    required String location,
    required List<String> membersIds,
    required int createdBy,
    required File attachmentFile,
    required String attachmentName,
    String status = "scheduled",
    String responseStatus = "{}",
  }) async {
    final url = Uri.parse("$baseUrl/create_event.php");
    final normalizedMemberIds = membersIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final autoResponseStatusMap = <String, String>{
      for (final id in normalizedMemberIds) id: "pending",
    };
    final resolvedResponseStatus =
        responseStatus.trim().isEmpty || responseStatus.trim() == "{}"
            ? jsonEncode(autoResponseStatusMap)
            : responseStatus;

    final request = http.MultipartRequest("POST", url);
    request.headers["Accept"] = "application/json";
    request.fields.addAll({
      "type": type,
      "title": title,
      "description": description,
      "meeting_date": meetingDate,
      "start_time": startTime,
      "end_time": endTime,
      "location_type": locationType,
      "location": location,
      "members_ids": jsonEncode(normalizedMemberIds),
      "status": status,
      "created_by": createdBy.toString(),
      "user_id": createdBy.toString(),
      "response_status": resolvedResponseStatus,
      "attachments": "[]",
    });
    request.files.add(await http.MultipartFile.fromPath(
      "attachment",
      attachmentFile.path,
      filename: attachmentName,
    ));

    final streamedRes = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamedRes);

    if (res.body.trim().isEmpty) throw Exception("EMPTY response");
    if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}: ${res.body}");

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw Exception("Invalid JSON response: ${res.body}");
    }
    if (decoded is! Map<String, dynamic>) throw Exception("Unexpected response format");
    return decoded;
  }

}
