import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Models/vehicle_summary_record.dart';
import '../Services/vehicle_api_service.dart';

class OfficeVehicleSummaryScreen extends StatefulWidget {
  final int managerId;
  const OfficeVehicleSummaryScreen({super.key, required this.managerId});

  @override
  State<OfficeVehicleSummaryScreen> createState() =>
      _OfficeVehicleSummaryScreenState();
}

class _OfficeVehicleSummaryScreenState
    extends State<OfficeVehicleSummaryScreen> {
  List<VehicleSummaryRecord> _records = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { _loading = true; _error = null; });
      final res = await VehicleApiService.getManagerOfficeTransportSummary(
          managerId: widget.managerId);
      if (res['success'] != true) throw Exception(res['message'] ?? 'Failed');
      final list = List.from(res['records'] ?? [])
          .map((e) => VehicleSummaryRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.id.compareTo(a.id));
      setState(() { _records = list; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1565C0), strokeWidth: 2),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No approved office trips',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45)),
            const SizedBox(height: 4),
            const Text('Pull down to refresh',
                style: TextStyle(fontSize: 12, color: Colors.black38)),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFFF5F7FA),
      child: RefreshIndicator(
        color: const Color(0xFF1565C0),
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildStatsHeader(),
            const SizedBox(height: 14),
            ...List.generate(_records.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCard(_records[i]),
            )),
          ],
        ),
      ),
    );
  }

  // ── Stats header ──────────────────────────────────────────────────────────
  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_outline,
                size: 20, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Office Approved Trips',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54)),
                const SizedBox(height: 2),
                Text(
                    '${_records.length} record${_records.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2A3A))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: const Text('Approved',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
  }

  // ── Card ──────────────────────────────────────────────────────────────────
  Widget _buildCard(VehicleSummaryRecord r) {
    final vtrim = r.vehicleType.trim();
    final showType = vtrim.isNotEmpty && vtrim != '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEAF1FF),
                child: Text(
                  _initials(r.employeeName),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1565C0)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.employeeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E2A3A))),
                    const SizedBox(height: 2),
                    Text(r.jobTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7A90),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 11, color: Color(0xFF2E7D32)),
                    SizedBox(width: 3),
                    Text('Approved',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E7D32))),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Details box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _detailRow('Vehicle No', r.vehicleNo),
                if (showType) ...[
                  const SizedBox(height: 6),
                  _detailRow('Vehicle Type', vtrim),
                ],
                const SizedBox(height: 6),
                _detailRow('From', _fmtDate(r.assignedStartAt)),
                const SizedBox(height: 6),
                _detailRow('To', _fmtDate(r.assignedEndAt)),
                if (r.tripCode.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _detailRow('Trip Code', r.tripCode),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 85,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7A90))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2A3A))),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final p = name.trim().split(' ').where((x) => x.isNotEmpty).toList();
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return p.isNotEmpty ? p[0][0].toUpperCase() : '?';
  }

  String _fmtDate(String raw) {
    try { return DateFormat('MMM dd, yyyy').format(DateTime.parse(raw)); }
    catch (_) { return raw; }
  }
}
