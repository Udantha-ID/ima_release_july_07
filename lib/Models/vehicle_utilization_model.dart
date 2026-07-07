class VehicleUtilizationResponse {
  final VehicleUtilizationPeriod period;
  final VehicleUtilizationTotals totals;
  final List<VehicleUtilizationItem> data;

  VehicleUtilizationResponse({
    required this.period,
    required this.totals,
    required this.data,
  });

  factory VehicleUtilizationResponse.fromJson(Map<String, dynamic> json) {
    return VehicleUtilizationResponse(
      period: VehicleUtilizationPeriod.fromJson(
        (json['period'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      totals: VehicleUtilizationTotals.fromJson(
        (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      data: ((json['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => VehicleUtilizationItem.fromJson(
                e.cast<String, dynamic>(),
              ))
          .toList(),
    );
  }
}

class VehicleUtilizationPeriod {
  final String from;
  final String to;
  final int totalDays;

  VehicleUtilizationPeriod({
    required this.from,
    required this.to,
    required this.totalDays,
  });

  factory VehicleUtilizationPeriod.fromJson(Map<String, dynamic> json) {
    return VehicleUtilizationPeriod(
      from: (json['from'] ?? '').toString(),
      to: (json['to'] ?? '').toString(),
      totalDays: _asInt(json['total_days']),
    );
  }

  /// True when API returned a single calendar day (`from` and `to` same, e.g. one-day query).
  bool get isSingleCalendarDay {
    if (from.isEmpty || to.isEmpty) return true;
    return from == to;
  }
}

class VehicleUtilizationTotals {
  final int vehicles;
  final int utilizedVehicles;
  final int notUtilizedVehicles;

  VehicleUtilizationTotals({
    required this.vehicles,
    required this.utilizedVehicles,
    required this.notUtilizedVehicles,
  });

  factory VehicleUtilizationTotals.fromJson(Map<String, dynamic> json) {
    return VehicleUtilizationTotals(
      vehicles: _asInt(json['vehicles']),
      utilizedVehicles: _asInt(json['utilized_vehicles']),
      notUtilizedVehicles: _asInt(json['not_utilized_vehicles']),
    );
  }
}

class VehicleUtilizationItem {
  final int vehicleId;
  final String vehicleNo;
  final String vehicleStatus;
  final String company;
  final int usedDays;
  final int totalDays;
  final double usagePercent;
  final String utilizationStatus;
  final bool isUtilized;

  VehicleUtilizationItem({
    required this.vehicleId,
    required this.vehicleNo,
    required this.vehicleStatus,
    required this.company,
    required this.usedDays,
    required this.totalDays,
    required this.usagePercent,
    required this.utilizationStatus,
    required this.isUtilized,
  });

  factory VehicleUtilizationItem.fromJson(Map<String, dynamic> json) {
    return VehicleUtilizationItem(
      vehicleId: _asInt(json['vehicle_id']),
      vehicleNo: (json['vehicle_no'] ?? '').toString(),
      vehicleStatus: (json['vehicle_status'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
      usedDays: _asInt(json['used_days']),
      totalDays: _asInt(json['total_days']),
      usagePercent: _asDouble(json['usage_percent']),
      utilizationStatus: (json['utilization_status'] ?? '').toString(),
      isUtilized: _asBool(json['is_utilized']),
    );
  }
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

bool _asBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  final s = v.toString().toLowerCase().trim();
  if (s == '1' || s == 'true' || s == 'yes') return true;
  return false;
}
