import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Models/gate_pass_summary_record.dart';
import '../Services/staff_gate_pass_service.dart';

class GatePassSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const GatePassSummaryScreen({super.key, required this.user});

  @override
  State<GatePassSummaryScreen> createState() => _GatePassSummaryScreenState();
}

class _GatePassSummaryScreenState extends State<GatePassSummaryScreen> {
  List<GatePassSummaryRecord> _records = [];
  bool   _loading = true;
  String? _error;

  int get _managerId =>
      int.tryParse((widget.user['employee_id'] ??
              widget.user['employeeId'] ?? '').toString()) ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { _loading = true; _error = null; });
      final res = await StaffGatePassService.getManagerGatePassSummary(
          managerId: _managerId);
      if (res['success'] != true) throw Exception(res['message'] ?? 'Failed');
      final raw = List.from(res['records'] ?? []);
      final list = raw
          .map((e) => GatePassSummaryRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.id.compareTo(a.id));
      setState(() {
        _records = list;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF1565C0), strokeWidth: 2),
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
                label: const Text('Retry',
                    style: TextStyle(color: Colors.white)),
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
            Icon(Icons.badge_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No approved gate passes',
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
            // Stats header
            _buildStatsHeader(),
            const SizedBox(height: 14),
            // Cards
            ...List.generate(_records.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildCard(_records[i]),
              );
            }),
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
                const Text('Approved Gate Passes',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54)),
                const SizedBox(height: 2),
                Text('${_records.length} record${_records.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2A3A))),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
  Widget _buildCard(GatePassSummaryRecord r) {
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
          // Header row — avatar + name + approved chip
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
              // Approved chip
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
                _detailRow('Date', _fmtDate(r.gatePassDate)),
                const SizedBox(height: 6),
                _detailRow('Time',
                    '${_fmtTime(r.outTime)}  –  ${_fmtTime(r.returnTime)}'),
                if (r.gatePassCode.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _detailRow('Pass Code', r.gatePassCode),
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
          width: 75,
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

  String _fmtTime(String raw) {
    try {
      final p  = raw.split(':');
      final h  = int.parse(p[0]);
      final m  = int.parse(p[1]);
      final s  = h >= 12 ? 'PM' : 'AM';
      final hr = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '${hr.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $s';
    } catch (_) { return raw; }
  }
}
