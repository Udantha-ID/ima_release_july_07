import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class SrBookingFilter {
  final String type;
  final String fromDate;
  final String toDate;

  const SrBookingFilter({
    required this.type,
    required this.fromDate,
    required this.toDate,
  });

  factory SrBookingFilter.fromJson(Map<String, dynamic>? json) {
    final m = json ?? {};
    return SrBookingFilter(
      type: (m['type'] ?? '').toString(),
      fromDate: (m['from_date'] ?? '').toString(),
      toDate: (m['to_date'] ?? '').toString(),
    );
  }
}

class SrBookingDashboardData {
  final SrBookingFilter filter;
  final int contactFormInquiries;
  final int whatsappBookings;
  final int directEmailBookings;
  final int activeBookingEnquiries;

  const SrBookingDashboardData({
    required this.filter,
    required this.contactFormInquiries,
    required this.whatsappBookings,
    required this.directEmailBookings,
    required this.activeBookingEnquiries,
  });

  factory SrBookingDashboardData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final filterMap = data['filter'] as Map<String, dynamic>?;
    return SrBookingDashboardData(
      filter: SrBookingFilter.fromJson(filterMap),
      contactFormInquiries: _toInt(data['contact_form_inquiries']),
      whatsappBookings: _toInt(data['whatsapp_bookings']),
      directEmailBookings: _toInt(data['direct_email_bookings']),
      activeBookingEnquiries: _toInt(data['active_booking_enquiries']),
    );
  }
}

class SrBookingDashboardService {
  static const String _baseUrl =
      'https://srilankarentacar.com/api/get-booking-dashboard-stats.php';

  /// Optional query keys commonly used by dashboard endpoints, e.g.
  /// `type`, `from_date`, `to_date`. Empty map → plain GET.
  static Future<SrBookingDashboardData> fetch({
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters:
          query == null || query.isEmpty ? null : Map<String, String>.from(query),
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        throw Exception('Server returned ${res.statusCode}');
      }

      if (res.body.trim().isEmpty) {
        throw Exception('Empty response from server');
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;

      if (decoded['success'] != true) {
        throw Exception(decoded['message'] ?? 'Request failed');
      }

      return SrBookingDashboardData.fromJson(decoded);
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on FormatException {
      throw Exception('Invalid response from server.');
    }
  }
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}
