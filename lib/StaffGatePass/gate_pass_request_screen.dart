import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Services/staff_gate_pass_service.dart';
import '../Services/api_service.dart';
import '../ui/dialogs/gate_pass_dialogs.dart';
import '../Leaves/top_banner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _Companion {
  final int    id;
  final String name;
  const _Companion({required this.id, required this.name});
  factory _Companion.fromJson(Map<String, dynamic> j) => _Companion(
        id:   int.tryParse((j['employee_id'] ?? '').toString()) ?? 0,
        name: (j['name'] ?? '').toString().trim(),
      );
}

class _GatePassRequest {
  final int              id;
  final String           employeeName;
  final String           managerName;
  final String           gatePassDate;
  final String           outTime;
  final String           returnTime;
  final String           reason;
  final String?          vehicleNo;
  final List<_Companion> companions;
  final String?          gatePassCode;
  final String           status;
  final String?          rejectReason;
  final String?          managerComment;
  final String?          remark;
  final String?          checkedOutAt;
  final String?          checkedInAt;
  final String           createdAt;

  const _GatePassRequest({
    required this.id,
    required this.employeeName,
    required this.managerName,
    required this.gatePassDate,
    required this.outTime,
    required this.returnTime,
    required this.reason,
    this.vehicleNo,
    required this.companions,
    this.gatePassCode,
    required this.status,
    this.rejectReason,
    this.managerComment,
    this.remark,
    this.checkedOutAt,
    this.checkedInAt,
    required this.createdAt,
  });

  factory _GatePassRequest.fromJson(Map<String, dynamic> j) {
    final raw = j['companions'] as List? ?? [];
    return _GatePassRequest(
      id:             int.tryParse((j['id'] ?? '').toString()) ?? 0,
      employeeName:   (j['employee_name']  ?? '').toString(),
      managerName:    (j['manager_name']   ?? '').toString(),
      gatePassDate:   (j['gate_pass_date'] ?? '').toString(),
      outTime:        (j['out_time']       ?? '').toString(),
      returnTime:     (j['return_time']    ?? '').toString(),
      reason:         (j['reason']         ?? '').toString(),
      vehicleNo:      j['vehicle_no']?.toString(),
      companions:     raw.map((c) => _Companion.fromJson(c as Map<String, dynamic>)).toList(),
      gatePassCode:   j['gate_pass_code']?.toString(),
      status:         (j['status']         ?? 'PENDING').toString(),
      rejectReason:   j['reject_reason']?.toString(),
      managerComment: j['manager_comment']?.toString(),
      remark:         j['remark']?.toString(),
      checkedOutAt:   j['checked_out_at']?.toString(),
      checkedInAt:    j['checked_in_at']?.toString(),
      createdAt:      (j['created_at']     ?? '').toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class GatePassRequestScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const GatePassRequestScreen({super.key, required this.user});

  @override
  State<GatePassRequestScreen> createState() => _GatePassRequestScreenState();
}

class _GatePassRequestScreenState extends State<GatePassRequestScreen> {
  int                    _tab           = 0;
  List<_GatePassRequest> _all           = [];
  bool                   _loading       = true;
  String?                _error;
  int?                   _deletingId;
  int?                   _checkingOutId;
  int?                   _checkingInId;
  final Map<int, Future<Map<String, dynamic>?>> _photoCache = {};

  static const _tabLabels   = ['Pending', 'Approved', 'Checked Out', 'Completed', 'Rejected'];
  static const _tabStatuses = ['PENDING', 'APPROVED', 'CHECKED_OUT', 'COMPLETED', 'REJECTED'];

  List<_GatePassRequest> get _filtered =>
      _all.where((r) => r.status == _tabStatuses[_tab]).toList();

  Future<Map<String, dynamic>?> _getPhoto(int id) =>
      _photoCache.putIfAbsent(id, () => ApiService.getProfilePhoto(employeeId: id));

  @override
  void initState() { super.initState(); _load(); }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    try {
      setState(() { _loading = true; _error = null; });
      final empId = (widget.user['employee_id'] ?? widget.user['employeeId'] ?? '').toString();
      final res   = await StaffGatePassService.getGatePassRequests(employeeId: int.parse(empId));
      if (res['success'] != true) throw Exception(res['message'] ?? 'Failed to load');
      final raw = List.from(res['requests'] ?? []);
      setState(() {
        _all     = raw.map((e) => _GatePassRequest.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _delete(_GatePassRequest req) async {
    final ok = await showGatePassCancelDialog(
      context:      context,
      gatePassCode: req.gatePassCode,
    );
    if (ok != true) return;

    setState(() => _deletingId = req.id);
    try {
      final empId = (widget.user['employee_id'] ?? widget.user['employeeId'] ?? '').toString();
      final res   = await StaffGatePassService.cancelGatePassRequest(
          id: req.id, employeeId: int.parse(empId));
      if (res['success'] == true) {
        setState(() => _all.removeWhere((r) => r.id == req.id));
        _snack('Request cancelled', isError: true);
      } else {
        _snack(res['message'] ?? 'Could not cancel', isError: true);
      }
    } catch (e) {
      _snack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  // ── Check Out ─────────────────────────────────────────────────────────────
  Future<void> _checkOut(_GatePassRequest req) async {
    final ok = await showGatePassCheckOutDialog(
      context:      context,
      gatePassCode: req.gatePassCode ?? 'Gate Pass #${req.id}',
    );
    if (ok != true) return;
    setState(() => _checkingOutId = req.id);
    try {
      final empId = (widget.user['employee_id'] ?? widget.user['employeeId'] ?? '').toString();
      final res   = await StaffGatePassService.checkOutGatePass(
          id: req.id, employeeId: int.parse(empId));
      if (res['success'] == true) { _snack('Checked out successfully', isError: false); _load(); }
      else { _snack(res['message'] ?? 'Could not check out', isError: true); }
    } catch (e) { _snack(e.toString(), isError: true); }
    finally { if (mounted) setState(() => _checkingOutId = null); }
  }

  // ── Check In ──────────────────────────────────────────────────────────────
  Future<void> _checkIn(_GatePassRequest req) async {
    final ok = await showGatePassCheckInDialog(
      context:      context,
      gatePassCode: req.gatePassCode ?? 'Gate Pass #${req.id}',
      checkedOutAt: req.checkedOutAt != null
          ? _fmtDateTime(req.checkedOutAt!) : null,
    );
    if (ok != true) return;
    setState(() => _checkingInId = req.id);
    try {
      final empId = (widget.user['employee_id'] ?? widget.user['employeeId'] ?? '').toString();
      final res   = await StaffGatePassService.checkInGatePass(
          id: req.id, employeeId: int.parse(empId));
      if (res['success'] == true) { _snack('Checked in — gate pass completed', isError: false); _load(); }
      else { _snack(res['message'] ?? 'Could not check in', isError: true); }
    } catch (e) { _snack(e.toString(), isError: true); }
    finally { if (mounted) setState(() => _checkingInId = null); }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        color: const Color(0xFF1565C0),
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildTabBar()),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(
                    color: Color(0xFF1565C0), strokeWidth: 2)),
              )
            else if (_error != null)
              SliverFillRemaining(child: _buildError())
            else if (_filtered.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildCard(_filtered[i]),
                    ),
                    childCount: _filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFFF5F7FA),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: _tabLabels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final active = _tab == i;
            final count  = _all.where((r) => r.status == _tabStatuses[i]).length;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF1565C0) : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active ? const Color(0xFF1565C0) : const Color(0xFFE1E6EF),
                  ),
                  boxShadow: active
                      ? [BoxShadow(
                          color: const Color(0xFF1565C0).withOpacity(0.25),
                          blurRadius: 8, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_tabLabels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : const Color(0xFF334155),
                        )),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withOpacity(0.3)
                              : const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('$count',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Card ──────────────────────────────────────────────────────────────────
  Widget _buildCard(_GatePassRequest req) {
    final bool isPending    = req.status == 'PENDING';
    final bool isApproved   = req.status == 'APPROVED';
    final bool isCheckedOut = req.status == 'CHECKED_OUT';

    final String headerTitle = isPending
        ? 'Pending Approval'
        : (req.gatePassCode != null && req.gatePassCode!.isNotEmpty
            ? req.gatePassCode!
            : 'Gate Pass #${req.id}');

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerTitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: isPending
                            ? const Color(0xFF1E2A3A)
                            : const Color(0xFF1565C0),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Gate Pass',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B7A90),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _statusChip(req.status),
            ],
          ),

          const SizedBox(height: 10),

          // ── Details box ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _detailRow('Date',     _fmtDate(req.gatePassDate)),
                const SizedBox(height: 8),
                _detailRow('Time',     '${_fmtTime(req.outTime)}  –  ${_fmtTime(req.returnTime)}'),
                const SizedBox(height: 8),
                _detailRow('Reason',   req.reason),
                const SizedBox(height: 8),
                _detailRow('Approver', req.managerName),
                if (req.vehicleNo != null && req.vehicleNo!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _detailRow('Vehicle', req.vehicleNo!),
                ],
                if (req.checkedOutAt != null) ...[
                  const SizedBox(height: 8),
                  _detailRow('Out At', _fmtDateTime(req.checkedOutAt!)),
                ],
                if (req.checkedInAt != null) ...[
                  const SizedBox(height: 8),
                  _detailRow('In At', _fmtDateTime(req.checkedInAt!)),
                ],
              ],
            ),
          ),

          // ── Companions — overlapping avatars (tap to see all) ──────────
          if (req.companions.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showCompanionsSheet(req.companions),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
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
                          for (int i = 0;
                              i < req.companions.length.clamp(0, 3);
                              i++)
                            Positioned(
                              left: i * 24.0,
                              child: _avatarCircle(
                                  req.companions[i].id,
                                  req.companions[i].name,
                                  i),
                            ),
                          if (req.companions.length > 3)
                            Positioned(
                              left: 3 * 24.0,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2.5),
                                ),
                                child: Center(
                                  child: Text(
                                    '+${req.companions.length - 3}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF475569)),
                                  ),
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
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569)),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Colors.black38),
                  ],
                ),
              ),
            ),
          ],

          // ── Remark ───────────────────────────────────────────────────────
          if (req.remark != null && req.remark!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _noteBox(Icons.comment_outlined, req.remark!,
                bg: const Color(0xFFF8FAFC), fg: Colors.black45),
          ],

          // ── Reject reason ─────────────────────────────────────────────
          if (req.rejectReason != null && req.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _noteBox(Icons.cancel_outlined, req.rejectReason!,
                bg: const Color(0xFFFFEBEE),
                fg: Colors.redAccent,
                border: const Color(0xFFFFCDD2)),
          ],

          // ── Manager comment ───────────────────────────────────────────
          if (req.managerComment != null && req.managerComment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _noteBox(Icons.mark_chat_read_outlined, req.managerComment!,
                bg: const Color(0xFFF0FFF4),
                fg: Colors.green,
                border: const Color(0xFFC8E6C9)),
          ],

          // ── Footer: applied date ──────────────────────────────────────
          const SizedBox(height: 14),
          Text(
            'Applied on: ${_fmtDateTime(req.createdAt)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7A90)),
          ),

          // ── Action buttons ────────────────────────────────────────────
          const SizedBox(height: 12),

          if (isPending)
            _deletingId == req.id
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.red),
                    ),
                  )
                : _fullWidthBtn(
                    label: 'Cancel Request',
                    icon: Icons.close_rounded,
                    colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                    onTap: () => _delete(req),
                  ),

          if (isApproved)
            _checkingOutId == req.id
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF1565C0)),
                    ),
                  )
                : _fullWidthBtn(
                    label: 'Check Out',
                    icon: Icons.logout_rounded,
                    colors: const [Color(0xFF1565C0), Color(0xFF1E88E5)],
                    onTap: () => _checkOut(req),
                  ),

          if (isCheckedOut)
            _checkingInId == req.id
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.green),
                    ),
                  )
                : _fullWidthBtn(
                    label: 'Check In',
                    icon: Icons.login_rounded,
                    colors: const [Color(0xFF2E7D32), Color(0xFF43A047)],
                    onTap: () => _checkIn(req),
                  ),
        ],
      ),
    );
  }

  // ── Detail row — label  value ────────────────────────────────────────────
  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7A90)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2A3A)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  // ── Full-width gradient button (Cancel / Check Out / Check In) ─────────
  Widget _fullWidthBtn({
    required String       label,
    required IconData     icon,
    required List<Color>  colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }

  // ── Status chip ───────────────────────────────────────────────────────────
  Widget _statusChip(String status) {
    Color bg, fg;
    IconData icon;
    String label;
    switch (status) {
      case 'APPROVED':
        bg = const Color(0xFFE8F5E9); fg = const Color(0xFF2E7D32);
        icon = Icons.check_circle_outline; label = 'Approved'; break;
      case 'REJECTED':
        bg = const Color(0xFFFFEBEE); fg = Colors.redAccent;
        icon = Icons.cancel_outlined; label = 'Rejected'; break;
      case 'CHECKED_OUT':
        bg = const Color(0xFFE3F2FD); fg = const Color(0xFF1565C0);
        icon = Icons.logout_rounded; label = 'Checked Out'; break;
      case 'COMPLETED':
        bg = const Color(0xFFEDE7F6); fg = const Color(0xFF512DA8);
        icon = Icons.verified_outlined; label = 'Completed'; break;
      case 'CANCELLED':
        bg = const Color(0xFFF5F5F5); fg = Colors.black45;
        icon = Icons.block_outlined; label = 'Cancelled'; break;
      default:
        bg = const Color(0xFFFFF8E1); fg = const Color(0xFFF9A825);
        icon = Icons.hourglass_top_outlined; label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }

  // ── Avatar circle with real photo / initials fallback ────────────────────
  Widget _avatarCircle(int id, String name, int index) {
    const colors = [
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFF6A1B9A),
      Color(0xFFE65100),
    ];
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty ? parts[0][0].toUpperCase() : '?');

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getPhoto(id),
      builder: (_, snap) {
        final url = (snap.data?['fileUrl'] ?? '').toString().trim();
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: url.isEmpty ? colors[index % colors.length] : null,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            image: url.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(url), fit: BoxFit.cover)
                : null,
          ),
          child: url.isEmpty
              ? Center(
                  child: Text(initials,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                )
              : null,
        );
      },
    );
  }

  // ── Companions bottom sheet ────────────────────────────────────────────────
  void _showCompanionsSheet(List<_Companion> companions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.group_outlined, color: Color(0xFF1565C0), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Going With (${companions.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: companions.length,
            separatorBuilder: (context, i) =>
                const Divider(height: 1, indent: 72, endIndent: 20),
            itemBuilder: (_, i) {
              final c = companions[i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getPhoto(c.id),
                      builder: (_, snap) {
                        final url =
                            (snap.data?['fileUrl'] ?? '').toString().trim();
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFFEAF1FF),
                            child: SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  color: Color(0xFF1565C0), strokeWidth: 1.5),
                            ),
                          );
                        }
                        if (url.isNotEmpty) {
                          return CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFEAF1FF),
                            backgroundImage: NetworkImage(url),
                          );
                        }
                        final parts = c.name.trim().split(' ').where((p) => p.isNotEmpty).toList();
                        final initials = parts.length >= 2
                            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                            : (parts.isNotEmpty
                                ? parts[0][0].toUpperCase()
                                : '?');
                        return CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF1565C0),
                          child: Text(initials,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        c.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2A3A)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
        ],
      ),
    );
  }

  double _avatarStackWidth(int count) {
    final visible = count.clamp(0, 4);
    return (visible * 24.0) + 12;
  }

  Widget _noteBox(IconData icon, String text,
      {required Color bg, required Color fg, Color? border}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Expanded(child: Text(text,
              style: const TextStyle(fontSize: 12, color: Colors.black54))),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No ${_tabLabels[_tab].toLowerCase()} requests',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 4),
          const Text('Pull down to refresh',
              style: TextStyle(fontSize: 12, color: Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildError() {
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

  // ── Helpers ───────────────────────────────────────────────────────────────
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

  void _snack(String msg, {required bool isError}) {
    TopBanner.show(
      context,
      title:     isError ? 'Error'   : 'Success',
      message:   msg,
      icon:      isError ? Icons.error_outline : Icons.check_circle,
      isError:   isError,
      isSuccess: !isError,
    );
  }
}