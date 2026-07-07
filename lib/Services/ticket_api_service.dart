import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test_app/app_config.dart';

class TicketApiService {

  // ── Base URL for Ticket API ────────────────────────────────────────────────
  static const String baseUrl = "${AppConfig.baseUrl}/tickets";

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

  static Future<List<String>> getItAgentIds() async {
    try {
      final url = Uri.parse("$baseUrl/get_it_agent_ids.php");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) return [];
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) return [];
      return List<String>.from(
          (decoded["agent_ids"] as List? ?? []).map((e) => e.toString()));
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getPlatforms() async {
    try {
      final url = Uri.parse("$baseUrl/get_platforms.php");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to load platforms");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getCommonIssues({required int platformId}) async {
    try {
      final url = Uri.parse("$baseUrl/get_common_issues.php?platform_id=$platformId");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to load issues");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> createTicket({
    required String employeeId,
    required int    platformId,
    int?            commonIssueId,
    required String title,
    required String description,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/create_ticket.php");
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({
              "employee_id"     : employeeId,
              "platform_id"     : platformId,
              "common_issue_id" : commonIssueId,
              "title"           : title,
              "description"     : description,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to create ticket");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getMyTickets({required String employeeId}) async {
    try {
      final url = Uri.parse("$baseUrl/get_my_tickets.php?employee_id=$employeeId");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to load tickets");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getAgentTickets({String? status}) async {
    try {
      final query = (status != null && status.isNotEmpty) ? "?status=$status" : "";
      final url = Uri.parse("$baseUrl/get_agent_tickets.php$query");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to load tickets");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getTicketDetail({required int ticketId}) async {
    try {
      final url = Uri.parse("$baseUrl/get_ticket_detail.php?ticket_id=$ticketId");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to load ticket detail");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getTicketMessages({required int ticketId}) async {
    try {
      final url = Uri.parse("$baseUrl/get_ticket_messages.php?ticket_id=$ticketId");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to load messages");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> sendTicketMessage({
    required int    ticketId,
    required String senderType,
    required String senderId,
    required String message,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/send_ticket_message.php");
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({
              "ticket_id"   : ticketId,
              "sender_type" : senderType,
              "sender_id"   : senderId,
              "message"     : message,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to send message");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> resolveTicket({
    required int    ticketId,
    required String agentId,
    String?         resolutionNote,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/resolve_ticket.php");
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({
              "ticket_id"       : ticketId,
              "agent_id"        : agentId,
              "resolution_note" : resolutionNote ?? "",
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to resolve ticket");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> cancelTicket({
    required int    ticketId,
    required String employeeId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/cancel_ticket.php");
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({
              "ticket_id"   : ticketId,
              "employee_id" : int.tryParse(employeeId) ?? 0,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = Map<String, dynamic>.from(jsonDecode(res.body));
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to cancel ticket");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> markMessagesRead({
    required int    ticketId,
    required String readerType,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/mark_messages_read.php");
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({"ticket_id": ticketId, "reader_type": readerType}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }
}
