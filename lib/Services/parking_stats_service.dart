import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ParkingStats {
  final int totalParkedVehicles;
  final int totalCompletedParking;
  final int activeParkingCount;
  final int totalBookings;
  final int revenue;
  final String revenueType;

  const ParkingStats({
    required this.totalParkedVehicles,
    required this.totalCompletedParking,
    required this.activeParkingCount,
    required this.totalBookings,
    required this.revenue,
    required this.revenueType,
  });

  factory ParkingStats.fromJson(Map<String, dynamic> json) => ParkingStats(
        totalParkedVehicles: _toInt(json['total_parked_vehicles']),
        totalCompletedParking: _toInt(json['total_completed_parking']),
        activeParkingCount: _toInt(json['active_parking_count']),
        totalBookings: _toInt(json['total_bookings']),
        revenue: _toInt(json['revenue']),
        revenueType: (json['revenue_type'] ?? '').toString(),
      );
}

class ParkingHandover {
  final int? handoverById;
  final String? handoverByName;
  final String? handoverDatetime;
  final int cashHandover;

  const ParkingHandover({
    this.handoverById,
    this.handoverByName,
    this.handoverDatetime,
    required this.cashHandover,
  });

  bool get hasHandover =>
      handoverById != null ||
      (handoverByName != null && handoverByName!.isNotEmpty);

  factory ParkingHandover.fromJson(Map<String, dynamic> json) => ParkingHandover(
        handoverById: json['handover_by_id'] != null
            ? int.tryParse(json['handover_by_id'].toString())
            : null,
        handoverByName: json['handover_by_name']?.toString(),
        handoverDatetime: json['handover_datetime']?.toString(),
        cashHandover: _toInt(json['cash_handover']),
      );
}

class ParkingDashboardData {
  final String startDate;
  final String endDate;
  final String? revenueMonth;
  final String revenueYear;
  final ParkingStats stats;
  final ParkingHandover handover;

  const ParkingDashboardData({
    required this.startDate,
    required this.endDate,
    this.revenueMonth,
    required this.revenueYear,
    required this.stats,
    required this.handover,
  });

  factory ParkingDashboardData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final dateFilter = data['date_filter'] as Map<String, dynamic>? ?? {};
    final revenueFilter = data['revenue_filter'] as Map<String, dynamic>? ?? {};
    return ParkingDashboardData(
      startDate: (dateFilter['start_date'] ?? '').toString(),
      endDate: (dateFilter['end_date'] ?? '').toString(),
      revenueMonth: revenueFilter['month']?.toString(),
      revenueYear: (revenueFilter['year'] ?? '').toString(),
      stats: ParkingStats.fromJson(data['stats'] as Map<String, dynamic>? ?? {}),
      handover: ParkingHandover.fromJson(data['handover'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class ParkingStatsService {

  //static const String _baseUrl = 'https://airportparking.lk/api/api_list_bookings.php';
  static const String _baseUrl = 'https://airportparking.lk/api/api_list_bookings.php';

  static Future<ParkingDashboardData> fetchDashboard({
    String? startDate,
    String? endDate,
    String? year,
    String? month,
  }) async {
    final params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (year != null) params['year'] = year;
    if (month != null) params['month'] = month;

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params.isEmpty ? null : params);

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

      return ParkingDashboardData.fromJson(decoded);
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on FormatException {
      throw Exception('Invalid response from server.');
    }
  }

  static String formatApiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}
