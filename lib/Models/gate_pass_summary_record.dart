class GatePassSummaryRecord {
  final int    id;
  final String employeeName;
  final String jobTitle;
  final String gatePassDate;
  final String outTime;
  final String returnTime;
  final String gatePassCode;

  const GatePassSummaryRecord({
    required this.id,
    required this.employeeName,
    required this.jobTitle,
    required this.gatePassDate,
    required this.outTime,
    required this.returnTime,
    required this.gatePassCode,
  });

  factory GatePassSummaryRecord.fromJson(Map<String, dynamic> j) =>
      GatePassSummaryRecord(
        id:           int.tryParse((j['id']             ?? '').toString()) ?? 0,
        employeeName: (j['employee_name']  ?? '').toString(),
        jobTitle:     (j['job_title']      ?? '').toString(),
        gatePassDate: (j['gate_pass_date'] ?? '').toString(),
        outTime:      (j['out_time']       ?? '').toString(),
        returnTime:   (j['return_time']    ?? '').toString(),
        gatePassCode: (j['gate_pass_code'] ?? '').toString(),
      );
}
