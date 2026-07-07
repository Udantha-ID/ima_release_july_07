import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Services/staff_gate_pass_service.dart';
import '../Services/api_service.dart';
import '../Leaves/top_banner.dart';
import '../ui/dialogs/gate_pass_approve_dialog.dart';
import '../ui/dialogs/gate_pass_reject_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _Companion {
  final int    id;
  final String name;
  final String jobTitle;

  const _Companion({required this.id, required this.name, required this.jobTitle});

  factory _Companion.fromJson(Map<String, dynamic> j) => _Companion(
        id:       int.tryParse((j['employee_id'] ?? '').toString()) ?? 0,
        name:     (j['name']      ?? '').toString().trim(),
        jobTitle: (j['job_title'] ?? '').toString().trim(),
      );
}

class _PendingRequest {
  final int              id;
  final int              employeeId;
  final String           employeeName;
  final String           jobTitle;
  final String           contactNo;
  final String           gatePassDate;
  final String           outTime;
  final String           returnTime;
  final String           reason;
  final String?          vehicleNo;
  List<_Companion>       companions; // mutable — manager can remove
  final String?          remark;
  final String           createdAt;

  _PendingRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.jobTitle,
    required this.contactNo,
    required this.gatePassDate,
    required this.outTime,
    required this.returnTime,
    required this.reason,
    this.vehicleNo,
    required this.companions,
    this.remark,
    required this.createdAt,
  });

  factory _PendingRequest.fromJson(Map<String, dynamic> j) {
    final raw = j['companions'] as List? ?? [];
    return _PendingRequest(
      id:           int.tryParse((j['id']          ?? '').toString()) ?? 0,
      employeeId:   int.tryParse((j['employee_id'] ?? '').toString()) ?? 0,
      employeeName: (j['employee_name'] ?? '').toString(),
      jobTitle:     (j['job_title']     ?? '').toString(),
      contactNo:    (j['contact_no']    ?? '').toString(),
      gatePassDate: (j['gate_pass_date']?? '').toString(),
      outTime:      (j['out_time']      ?? '').toString(),
      returnTime:   (j['return_time']   ?? '').toString(),
      reason:       (j['reason']        ?? '').toString(),
      vehicleNo:    j['vehicle_no']?.toString(),
      companions:   raw.map((c) => _Companion.fromJson(c as Map<String, dynamic>)).toList(),
      remark:       j['remark']?.toString(),
      createdAt:    (j['created_at']    ?? '').toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ManagerGatePassScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ManagerGatePassScreen({super.key, required this.user});

  @override
  State<ManagerGatePassScreen> createState() => _ManagerGatePassScreenState();
}

class _ManagerGatePassScreenState extends State<ManagerGatePassScreen> {
  List<_PendingRequest> _requests    = [];
  bool                  _loading     = true;
  String?               _error;
  int?                  _processingId;

  final Map<int, Future<Map<String, dynamic>?>> _photoCache = {};

  Future<Map<String, dynamic>?> _getPhoto(int id) =>
      _photoCache.putIfAbsent(id, () => ApiService.getProfilePhoto(employeeId: id));

  int get _managerId =>
      int.tryParse((widget.user['employee_id'] ?? widget.user['employeeId'] ?? '').toString()) ?? 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      setState(() { _loading = true; _error = null; });
      final res = await StaffGatePassService.getManagerGatePassRequests(
        managerId: _managerId, status: 'PENDING');
      if (res['success'] != true) throw Exception(res['message'] ?? 'Failed to load');
      final raw = List.from(res['requests'] ?? []);
      setState(() {
        _requests = raw.map((e) => _PendingRequest.fromJson(e as Map<String, dynamic>)).toList();
        _loading  = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _approve(_PendingRequest req) async {
    await showGatePassApproveDialog(
      context:      context,
      employeeName: req.employeeName,
      gatePassDate: _fmtDate(req.gatePassDate),
      outTime:      _fmtTime(req.outTime),
      returnTime:   _fmtTime(req.returnTime),
      onApprove: () async {
        setState(() => _processingId = req.id);
        try {
          final res = await StaffGatePassService.approveGatePassRequest(
              id: req.id, managerId: _managerId);
          if (res['success'] == true) {
            setState(() => _requests.removeWhere((r) => r.id == req.id));
            if (mounted) TopBanner.show(context,
                title: 'Approved',
                message: 'Gate pass approved — ${res['gate_pass_code'] ?? ''}',
                icon: Icons.check_circle, isSuccess: true);
          } else {
            if (mounted) TopBanner.show(context,
                title: 'Failed',
                message: (res['message'] ?? 'Could not approve').toString(),
                icon: Icons.error_outline, isError: true);
          }
        } catch (e) {
          if (mounted) TopBanner.show(context,
              title: 'Error', message: e.toString(),
              icon: Icons.error_outline, isError: true);
        } finally {
          if (mounted) setState(() => _processingId = null);
        }
      },
    );
  }

  Future<void> _reject(_PendingRequest req) async {
    await showGatePassRejectDialog(
      context:      context,
      employeeName: req.employeeName,
      onReject: (reason) async {
        setState(() => _processingId = req.id);
        try {
          final res = await StaffGatePassService.rejectGatePassRequest(
              id: req.id, managerId: _managerId, rejectReason: reason);
          if (res['success'] == true) {
            setState(() => _requests.removeWhere((r) => r.id == req.id));
            if (mounted) TopBanner.show(context,
                title: 'Rejected', message: 'Gate pass request rejected.',
                icon: Icons.cancel);
          } else {
            if (mounted) TopBanner.show(context,
                title: 'Failed',
                message: (res['message'] ?? 'Could not reject').toString(),
                icon: Icons.error_outline, isError: true);
          }
        } catch (e) {
          if (mounted) TopBanner.show(context,
              title: 'Error', message: e.toString(),
              icon: Icons.error_outline, isError: true);
        } finally {
          if (mounted) setState(() => _processingId = null);
        }
      },
    );
  }

  // ── Open companions sheet ─────────────────────────────────────────────────
  void _openCompanionsSheet(_PendingRequest req) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CompanionsSheet(
        gatePassId: req.id,
        managerId:  _managerId,
        companions: List.from(req.companions),
        getPhoto:   _getPhoto,
        onUpdated:  (updatedList) {
          // Reflect removal in the parent card without full reload
          setState(() {
            req.companions = updatedList;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1565C0), strokeWidth: 2));
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
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No pending requests',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black45)),
            const SizedBox(height: 6),
            const Text('All gate pass requests have been processed.',
                style: TextStyle(fontSize: 13, color: Colors.black38)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF1565C0),
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (ctx, i) {
          final req = _requests[i];
          return _GatePassCard(
            req:              req,
            isProcessing:     _processingId == req.id,
            getPhoto:         _getPhoto,
            onApprove:        () => _approve(req),
            onReject:         () => _reject(req),
            onViewCompanions: () => _openCompanionsSheet(req),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card widget
// ─────────────────────────────────────────────────────────────────────────────

class _GatePassCard extends StatelessWidget {
  final _PendingRequest req;
  final bool isProcessing;
  final Future<Map<String, dynamic>?> Function(int) getPhoto;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewCompanions;

  const _GatePassCard({
    required this.req,
    required this.isProcessing,
    required this.getPhoto,
    required this.onApprove,
    required this.onReject,
    required this.onViewCompanions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ───────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: req.employeeId > 0 ? getPhoto(req.employeeId) : Future.value(null),
                builder: (_, snap) {
                  final url = (snap.data?['fileUrl'] ?? '').toString().trim();
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFFEAF1FF),
                      child: SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.blue, backgroundColor: Colors.white, strokeWidth: 2)),
                    );
                  }
                  if (url.isNotEmpty) {
                    return CircleAvatar(radius: 22,
                        backgroundColor: const Color(0xFFEAF1FF),
                        backgroundImage: NetworkImage(url));
                  }
                  return const CircleAvatar(radius: 22,
                      backgroundColor: Color(0xFFEAF1FF),
                      child: Icon(Icons.person, color: Color(0xFF1E88E5)));
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.employeeName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900,
                            fontSize: 13.5, color: Color(0xFF1E2A3A))),
                    const SizedBox(height: 2),
                    Text(req.jobTitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF6B7A90),
                            fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFFE08A)),
                ),
                child: const Text('PENDING',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900,
                        color: Color(0xFF8A5A00), letterSpacing: 0.3)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Details box ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _detailRow('Date',    _fmtDate(req.gatePassDate)),
                const SizedBox(height: 8),
                _detailRow('Time',    '${_fmtTime(req.outTime)}  →  ${_fmtTime(req.returnTime)}'),
                const SizedBox(height: 8),
                _detailRow('Contact', req.contactNo),
                const SizedBox(height: 8),
                _detailRow('Reason',  req.reason),
                if (req.vehicleNo != null && req.vehicleNo!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _detailRow('Vehicle', req.vehicleNo!),
                ],
              ],
            ),
          ),

          // ── Companions — tappable row opens sheet ─────────────────────────
          if (req.companions.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onViewCompanions,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDE6F8)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      height: 36,
                      width: _avatarStackWidth(req.companions.length),
                      child: Stack(
                        children: [
                          for (int i = 0; i < req.companions.length.clamp(0, 3); i++)
                            Positioned(
                              left: i * 24.0,
                              child: _avatarCircle(
                                  req.companions[i].id, req.companions[i].name, i, getPhoto),
                            ),
                          if (req.companions.length > 3)
                            Positioned(
                              left: 3 * 24.0,
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                ),
                                child: Center(
                                  child: Text('+${req.companions.length - 3}',
                                      style: const TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF475569))),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        req.companions.length == 1
                            ? req.companions.first.name
                            : '${req.companions.length} people going',
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.black38),
                  ],
                ),
              ),
            ),
          ],

          // ── Remark ────────────────────────────────────────────────────────
          if (req.remark != null && req.remark!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.comment_outlined, size: 14, color: Colors.black45),
                  const SizedBox(width: 6),
                  Expanded(child: Text(req.remark!,
                      style: const TextStyle(fontSize: 12, color: Colors.black54))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          Text(
            'Applied on: ${_fmtDateTime(req.createdAt)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7A90)),
          ),

          const SizedBox(height: 12),

          // ── Action buttons ────────────────────────────────────────────────
          isProcessing
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(
                        color: Color(0xFF1565C0), strokeWidth: 2),
                  ),
                )
              : Row(
                  children: [
                    Expanded(child: _gradientBtn('Reject',
                        [const Color(0xFFD10A0A), const Color(0xFF5B0000)], onReject)),
                    const SizedBox(width: 12),
                    Expanded(child: _gradientBtn('Approve',
                        [const Color(0xFF2E7D32), const Color(0xFF1B5E20)], onApprove)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 75,
          child: Text(label,
              style: const TextStyle(fontSize: 11.5,
                  fontWeight: FontWeight.w700, color: Color(0xFF6B7A90))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(value,
                style: const TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w900, color: Color(0xFF1E2A3A)),
                overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }

  Widget _gradientBtn(String label, List<Color> colors, VoidCallback onTap) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }

  double _avatarStackWidth(int count) => (count.clamp(0, 4) * 24.0) + 12;
}

// ─────────────────────────────────────────────────────────────────────────────
// Companions bottom sheet — stateful so remove updates live
// ─────────────────────────────────────────────────────────────────────────────

class _CompanionsSheet extends StatefulWidget {
  final int                                      gatePassId;
  final int                                      managerId;
  final List<_Companion>                         companions;
  final Future<Map<String, dynamic>?> Function(int) getPhoto;
  final void Function(List<_Companion>)          onUpdated;

  const _CompanionsSheet({
    required this.gatePassId,
    required this.managerId,
    required this.companions,
    required this.getPhoto,
    required this.onUpdated,
  });

  @override
  State<_CompanionsSheet> createState() => _CompanionsSheetState();
}

class _CompanionsSheetState extends State<_CompanionsSheet> {
  late List<_Companion> _companions;
  int? _removingId;

  @override
  void initState() {
    super.initState();
    _companions = List.from(widget.companions);
  }

  Future<void> _remove(_Companion c) async {
    // Confirm
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        final dialogW =
            (MediaQuery.of(ctx).size.width * 0.90).clamp(280.0, 420.0);
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                  color: Colors.black.withValues(alpha: 0.15)),
            ),
            Center(
              child: Dialog(
                insetPadding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: SizedBox(
                  width: dialogW,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title row ─────────────────────────────────
                        Row(
                          children: [
                            const Icon(Icons.person_remove_outlined,
                                color: Colors.redAccent),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text('Remove Member',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              icon: const Icon(Icons.close),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'This action cannot be undone.',
                          style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5),
                        ),
                        const SizedBox(height: 14),
                        // ── Member name box ────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFF),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: const Color(0xFFE1E6EF)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 16, color: Color(0xFF6B7A90)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(c.name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E2A3A))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Buttons ────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black54,
                                  side: const BorderSide(
                                      color: Color(0xFFC4C4C4), width: 1.2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD10A0A),
                                      Color(0xFF5B0000)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    elevation: 0,
                                  ),
                                  child: const Text('Remove',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() => _removingId = c.id);

    try {
      final res = await StaffGatePassService.removeGatePassCompanion(
        gatePassId:  widget.gatePassId,
        companionId: c.id,
        managerId:   widget.managerId,
      );

      if (res['success'] == true) {
        setState(() {
          _companions.removeWhere((x) => x.id == c.id);
        });
        widget.onUpdated(_companions);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${c.name} removed'),
            backgroundColor: const Color(0xFF1565C0),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }

        // Close sheet if no companions left
        if (_companions.isEmpty && mounted) Navigator.pop(context);

      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res['message'] ?? 'Could not remove'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Handle ─────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // ── Title ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.group_outlined, color: Color(0xFF1565C0), size: 20),
                const SizedBox(width: 8),
                Text('Going With (${_companions.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                // Hint
                const Text('Tap  ✕  to remove',
                    style: TextStyle(fontSize: 11, color: Colors.black38)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),

          // ── List ───────────────────────────────────────────────────────
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _companions.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72, endIndent: 20),
            itemBuilder: (_, i) {
              final c           = _companions[i];
              final isRemoving  = _removingId == c.id;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [

                    // Avatar
                    FutureBuilder<Map<String, dynamic>?>(
                      future: c.id > 0 ? widget.getPhoto(c.id) : Future.value(null),
                      builder: (_, snap) {
                        final url = (snap.data?['fileUrl'] ?? '').toString().trim();
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const CircleAvatar(
                            radius: 22, backgroundColor: Color(0xFFEAF1FF),
                            child: SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF1565C0), strokeWidth: 1.5)),
                          );
                        }
                        if (url.isNotEmpty) {
                          return CircleAvatar(radius: 22,
                              backgroundColor: const Color(0xFFEAF1FF),
                              backgroundImage: NetworkImage(url));
                        }
                        final parts = c.name.trim().split(' ')
                            .where((p) => p.isNotEmpty).toList();
                        final initials = parts.length >= 2
                            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                            : (parts.isNotEmpty ? parts[0][0].toUpperCase() : '?');
                        return CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF1565C0),
                          child: Text(initials,
                              style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w800, color: Colors.white)),
                        );
                      },
                    ),

                    const SizedBox(width: 14),

                    // Name + job title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: const TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w700, color: Color(0xFF1E2A3A))),
                          if (c.jobTitle.isNotEmpty)
                            Text(c.jobTitle,
                                style: const TextStyle(fontSize: 12,
                                    color: Color(0xFF6B7A90), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),

                    // Remove button
                    isRemoving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.redAccent))
                        : GestureDetector(
                            onTap: () => _remove(c),
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFFFCDD2)),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: Colors.redAccent),
                            ),
                          ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _avatarCircle(int id, String name, int index,
    Future<Map<String, dynamic>?> Function(int) getPhoto) {
  const colors = [
    Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100),
  ];
  final parts    = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  final initials = parts.length >= 2
      ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
      : (parts.isNotEmpty ? parts[0][0].toUpperCase() : '?');

  return FutureBuilder<Map<String, dynamic>?>(
    future: id > 0 ? getPhoto(id) : Future.value(null),
    builder: (_, snap) {
      final url = (snap.data?['fileUrl'] ?? '').toString().trim();
      return Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: url.isEmpty ? colors[index % colors.length] : null,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          image: url.isNotEmpty
              ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
              : null,
        ),
        child: url.isEmpty
            ? Center(child: Text(initials,
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w800, color: Colors.white)))
            : null,
      );
    },
  );
}

String _fmtDate(String raw) {
  try { return DateFormat('MMM dd, yyyy').format(DateTime.parse(raw)); }
  catch (_) { return raw; }
}

String _fmtTime(String raw) {
  try {
    final p = raw.split(':');
    final h = int.parse(p[0]), m = int.parse(p[1]);
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour   = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${hour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix';
  } catch (_) { return raw; }
}

String _fmtDateTime(String raw) {
  try { return DateFormat('MMM dd, yyyy  hh:mm a').format(DateTime.parse(raw)); }
  catch (_) { return raw; }
}