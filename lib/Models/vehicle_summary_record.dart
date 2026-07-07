class VehicleSummaryRecord {
  final int    id;
  final String employeeName;
  final String jobTitle;
  final String type;
  final String vehicleNo;
  final String vehicleType;
  final String tripCode;
  final String assignedStartAt;
  final String assignedEndAt;
  final String status;

  const VehicleSummaryRecord({
    required this.id,
    required this.employeeName,
    required this.jobTitle,
    required this.type,
    required this.vehicleNo,
    required this.vehicleType,
    required this.tripCode,
    required this.assignedStartAt,
    required this.assignedEndAt,
    required this.status,
  });

  factory VehicleSummaryRecord.fromJson(Map<String, dynamic> j) =>
      VehicleSummaryRecord(
        id:              int.tryParse((j['id']                 ?? '').toString()) ?? 0,
        employeeName:    (j['employee_name']    ?? '').toString(),
        jobTitle:        (j['job_title']        ?? '').toString(),
        type:            (j['type']             ?? '').toString(),
        vehicleNo:       (j['vehicle_no']       ?? '').toString(),
        vehicleType:     (j['vehicle_type']     ?? '').toString(),
        tripCode:        (j['trip_code']        ?? '').toString(),
        assignedStartAt: (j['assigned_start_at'] ?? '').toString(),
        assignedEndAt:   (j['assigned_end_at']   ?? '').toString(),
        status:          (j['status']           ?? '').toString(),
      );
}
