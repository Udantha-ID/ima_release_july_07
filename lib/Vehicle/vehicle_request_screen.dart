import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Services/vehicle_api_service.dart';
import '../Leaves/top_banner.dart';
import '../Services/api_service.dart';
import '../ui/dialogs/vehicle_reject_dialog.dart';
import '../ui/dialogs/vehicle_approve_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Companion model
// ─────────────────────────────────────────────────────────────────────────────

class _VCompanion {
  final int    id;
  final String name;
  const _VCompanion({required this.id, required this.name});

  factory _VCompanion.fromJson(Map<String, dynamic> j) => _VCompanion(
        id:   int.tryParse((j['employee_id'] ?? '').toString()) ?? 0,
        name: (j['name'] ?? '').toString().trim(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class VehicleRequestScreen extends StatefulWidget {
  final String managerId;
  const VehicleRequestScreen({super.key, required this.managerId});

  @override
  State<VehicleRequestScreen> createState() => _VehicleRequestScreenState();
}

class _VehicleRequestScreenState extends State<VehicleRequestScreen> {
  List<Map<String, dynamic>> requests = [];
  bool   loading   = true;
  String? errorText;

  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

  Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) =>
      _photoFutureCache.putIfAbsent(
          employeeId, () => ApiService.getProfilePhoto(employeeId: employeeId));

  @override
  void initState() { super.initState(); _loadRequests(); }

  Future<void> _loadRequests() async {
    setState(() { loading = true; errorText = null; });
    try {
      final data = await VehicleApiService.fetchManagerVehicleRequests(
          managerId: widget.managerId);
      setState(() { requests = data; loading = false; });
    } catch (e) {
      setState(() { errorText = e.toString(); loading = false; });
    }
  }

  // ── Companion removed callback — updates list in place ───────────────────
  void _onCompanionRemoved(int requestId, int companionId) {
    setState(() {
      final idx = requests.indexWhere(
          (r) => int.tryParse((r["request_id"] ?? r["id"] ?? "0").toString()) == requestId);
      if (idx == -1) return;
      final companions = List<Map<String, dynamic>>.from(
          requests[idx]["companions"] as List? ?? []);
      companions.removeWhere(
          (c) => int.tryParse((c["employee_id"] ?? "0").toString()) == companionId);
      requests[idx] = {...requests[idx], "companions": companions};
    });
  }

  Future<void> _showRejectDialog(BuildContext context, Map<String, dynamic> r) async {
    final requestId = int.parse(
        (r["request_id"] ?? r["id"] ?? "0").toString());

    await showVehicleRejectDialog(
      context: context,
      initialNote: "",
      onReject: (comment) async {
        try {
          await VehicleApiService.rejectVehicleRequest(
              requestId: requestId, comment: comment);
          await _loadRequests();
          if (mounted) {
            TopBanner.show(context,
                title:   "Request Rejected",
                message: "Vehicle request rejected successfully.",
                icon:    Icons.cancel);
          }
        } catch (e) {
          if (mounted) {
            TopBanner.show(context,
                title:   "Reject Failed",
                message: e.toString().replaceFirst("Exception: ", ""),
                icon:    Icons.error_outline,
                isSuccess: false);
          }
        }
      },
    );
  }

  Future<void> _showApproveDialog(BuildContext context, Map<String, dynamic> r) async {
    final requestId    = int.parse(r["request_id"].toString());
    final employeeName = (r["employee_name"] ?? r["employeeName"] ?? "USER").toString();

    await showVehicleApproveDialog(
      context:      context,
      employeeName: employeeName,
      onApprove: () async {
        try {
          final res = await VehicleApiService.approveVehicleRequest(
              requestId: requestId);
          await _loadRequests();
          if (!mounted) return;
          final tripCode = VehicleApiService.tripCodeFromApproveResponse(res);
          TopBanner.show(context,
              title:     "Request Approved",
              message:   tripCode != null
                  ? "Vehicle request approved. Trip code: $tripCode"
                  : "Vehicle request approved successfully.",
              icon:      Icons.check_circle,
              isSuccess: true);
        } catch (e) {
          if (mounted) {
            TopBanner.show(context,
                title:   "Approve Failed",
                message: e.toString().replaceFirst("Exception: ", ""),
                icon:    Icons.error_outline,
                isSuccess: false);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        color: Colors.blue,
        backgroundColor: Colors.white,
        strokeWidth: 2,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(
                    color: Colors.blue, backgroundColor: Colors.white)),
              )
            else if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 200),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _loadRequests,
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                      label: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              )
            else if (requests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text("No vehicle requests")),
              )
            else
              ...requests.map((r) {
                final requestId = int.tryParse(
                    (r["request_id"] ?? r["id"] ?? "0").toString()) ?? 0;

                final rawCompanions = r["companions"] as List? ?? [];
                final companions = rawCompanions
                    .map((c) => _VCompanion.fromJson(
                        c as Map<String, dynamic>))
                    .toList();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _VehicleRequestCard(
                    data:        r,
                    companions:  companions,
                    managerId:   int.tryParse(widget.managerId) ?? 0,
                    requestId:   requestId,
                    onReject:    () => _showRejectDialog(context, r),
                    onApprove:   () => _showApproveDialog(context, r),
                    getPhoto:    _getPhotoFuture,
                    onCompanionRemoved: _onCompanionRemoved,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleRequestCard extends StatelessWidget {
  final Map<String, dynamic>   data;
  final List<_VCompanion>      companions;
  final int                    managerId;
  final int                    requestId;
  final VoidCallback           onReject;
  final VoidCallback           onApprove;
  final Future<Map<String, dynamic>?> Function(int) getPhoto;
  final void Function(int requestId, int companionId) onCompanionRemoved;

  const _VehicleRequestCard({
    required this.data,
    required this.companions,
    required this.managerId,
    required this.requestId,
    required this.onReject,
    required this.onApprove,
    required this.getPhoto,
    required this.onCompanionRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    final employeeName = (data["employee_name"] ?? data["employeeName"] ?? "").toString();
    final employeeCode = (data["employee_code"] ?? data["employeeId"]   ?? "").toString();
    final jobTitle     = (data["job_title_name"] ?? data["position"]    ?? "").toString();
    final vehicleNo    = (data["vehicle_no"] ?? data["vehicleNo"]       ?? "").toString();
    final reason       = (data["type"] ?? data["reason"] ?? "Office Service").toString();
    final destination  = (data["destination"] ?? data["dropoff_location"] ?? "").toString();
    final fromDate     = (data["from_date"] ?? data["fromDate"]         ?? "").toString();
    final toDate       = (data["to_date"]   ?? data["toDate"]           ?? "").toString();
    final appliedStr   = _fmtApplied([
      data["created_at"], data["requested_at"], data["request_date"],
      data["apply_date"], data["applied_date"],
    ].map((v) => v?.toString() ?? "").firstWhere((s) => s.isNotEmpty, orElse: () => ""));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Employee header ───────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Builder(builder: (context) {
                final empId = int.tryParse(
                    (data["employee_id"] ?? data["employeeId"] ?? "0").toString()) ?? 0;
                return FutureBuilder<Map<String, dynamic>?>(
                  future: empId > 0 ? getPhoto(empId) : Future.value(null),
                  builder: (_, snap) {
                    final url = (snap.data?["fileUrl"] ?? "").toString().trim();
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFEAF1FF),
                        child: SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.blue,
                                backgroundColor: Colors.white,
                                strokeWidth: 2)),
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
                );
              }),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(employeeName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                  color: Colors.black)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFFE08A)),
                          ),
                          child: const Text("WAITING",
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF8A5A00),
                                  letterSpacing: 0.3)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text("$jobTitle\nEmployee ID: $employeeCode",
                        style: const TextStyle(
                            color: Color(0xFF6B7A90),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Details box ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _detailRow("Vehicle No",  vehicleNo),
                const SizedBox(height: 8),
                _vehicleModelRow(),
                const SizedBox(height: 8),
                _detailRow("Reason",      reason),
                const SizedBox(height: 8),
                _detailRow("Destination", destination),
                const SizedBox(height: 8),
                _detailRow("From Date",   fromDate),
                const SizedBox(height: 8),
                _detailRow("To Date",     toDate),
              ],
            ),
          ),

          // ── Going With ────────────────────────────────────────────────
          if (companions.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showCompanionsSheet(context),
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
                      width: _avatarStackWidth(companions.length),
                      child: Stack(
                        children: [
                          for (int i = 0;
                              i < companions.length.clamp(0, 3);
                              i++)
                            Positioned(
                              left: i * 24.0,
                              child: _avatarCircle(companions[i].name, i, companions[i].id),
                            ),
                          if (companions.length > 3)
                            Positioned(
                              left: 3 * 24.0,
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2.5),
                                ),
                                child: Center(
                                  child: Text('+${companions.length - 3}',
                                      style: const TextStyle(
                                          fontSize: 11,
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
                        companions.length == 1
                            ? companions.first.name
                            : '${companions.length} people going',
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

          const SizedBox(height: 12),

          // ── Reject / Approve buttons ──────────────────────────────────
          Row(
            children: [
              Expanded(child: _gradientBtn("Reject",
                  const [Color(0xFFD10A0A), Color(0xFF5B0000)], onReject)),
              const SizedBox(width: 12),
              Expanded(child: _gradientBtn("Approve",
                  const [Color(0xFF2E7D32), Color(0xFF1B5E20)], onApprove)),
            ],
          ),
          if (appliedStr.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                appliedStr,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7A90)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtApplied(String v) {
    if (v.isEmpty) return "";
    try {
      return 'Applied on: ${DateFormat('MMM dd, yyyy  hh:mm a').format(DateTime.parse(v))}';
    } catch (_) {
      return v.length >= 16 ? 'Applied on: ${v.substring(0, 16)}' : (v.isNotEmpty ? 'Applied on: $v' : '');
    }
  }

  // ── Companions sheet — stateful so removal updates live ───────────────────
  void _showCompanionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _VehicleCompanionsSheet(
        companions:  List.from(companions),
        requestId:   requestId,
        managerId:   managerId,
        getPhoto:    getPhoto,
        onRemoved:   (companionId) {
          onCompanionRemoved(requestId, companionId);
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double _avatarStackWidth(int count) => (count.clamp(0, 4) * 24.0) + 12;

  Widget _avatarCircle(String name, int index, int id) {
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
        if (url.isNotEmpty) {
          return Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
            ),
          );
        }
        return Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: colors[index % colors.length],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: Center(
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        );
      },
    );
  }

  Widget _gradientBtn(String label, List<Color> colors, VoidCallback onTap) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor:     Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 95,
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
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2A3A)),
                overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }

  Widget _vehicleModelRow() {
    return FutureBuilder<String?>(
      future: VehicleApiService.fetchVehicleMakeModelForRequest(data),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _detailRow("Vehicle model", "...");
        }
        final text = (snap.data ?? "").trim();
        return _detailRow("Vehicle model", text.isEmpty ? "-" : text);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Companions bottom sheet — StatefulWidget so removal updates live
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleCompanionsSheet extends StatefulWidget {
  final List<_VCompanion>                        companions;
  final int                                      requestId;
  final int                                      managerId;
  final Future<Map<String, dynamic>?> Function(int) getPhoto;
  final void Function(int companionId)           onRemoved;

  const _VehicleCompanionsSheet({
    required this.companions,
    required this.requestId,
    required this.managerId,
    required this.getPhoto,
    required this.onRemoved,
  });

  @override
  State<_VehicleCompanionsSheet> createState() =>
      _VehicleCompanionsSheetState();
}

class _VehicleCompanionsSheetState extends State<_VehicleCompanionsSheet> {
  late List<_VCompanion> _companions;
  int? _removingId;

  @override
  void initState() {
    super.initState();
    _companions = List.from(widget.companions);
  }

  Future<void> _remove(_VCompanion c) async {
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE1E6EF)),
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
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black54,
                                  side: const BorderSide(
                                      color: Color(0xFFC4C4C4),
                                      width: 1.2),
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
                                      Color(0xFF5B0000),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(12),
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
                                          fontWeight:
                                              FontWeight.w800)),
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
      final res = await VehicleApiService.removeVehicleCompanion(
        transportServiceId: widget.requestId,
        companionId:        c.id,
        managerId:          widget.managerId,
      );

      if (res['success'] == true) {
        setState(() => _companions.removeWhere((x) => x.id == c.id));
        widget.onRemoved(c.id);

        if (mounted) {
          TopBanner.show(context,
              title:   "Member Removed",
              message: "${c.name} has been removed from the trip.",
              icon:    Icons.check_circle,
              isSuccess: true);
        }

        if (_companions.isEmpty && mounted) Navigator.pop(context);
      } else {
        if (mounted) {
          TopBanner.show(context,
              title:   "Remove Failed",
              message: (res['message'] ?? 'Could not remove').toString(),
              icon:    Icons.error_outline,
              isSuccess: false);
        }
      }
    } catch (e) {
      if (mounted) {
        TopBanner.show(context,
            title:   "Remove Failed",
            message: e.toString().replaceFirst("Exception: ", ""),
            icon:    Icons.error_outline,
            isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
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
                const Icon(Icons.group_outlined,
                    color: Color(0xFF1565C0), size: 20),
                const SizedBox(width: 8),
                Text('Going With (${_companions.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                const Text('Tap  ✕  to remove',
                    style: TextStyle(fontSize: 11, color: Colors.black38)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _companions.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72, endIndent: 20),
            itemBuilder: (_, i) {
              final c          = _companions[i];
              final isRemoving = _removingId == c.id;
              final parts      = c.name.trim().split(' ')
                  .where((p) => p.isNotEmpty).toList();
              final initials   = parts.length >= 2
                  ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                  : (parts.isNotEmpty ? parts[0][0].toUpperCase() : '?');

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                child: Row(
                  children: [

                    // Avatar — real photo if available
                    FutureBuilder<Map<String, dynamic>?>(
                      future: c.id > 0
                          ? widget.getPhoto(c.id)
                          : Future.value(null),
                      builder: (_, snap) {
                        final url =
                            (snap.data?['fileUrl'] ?? '').toString().trim();
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFFEAF1FF),
                            child: SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF1565C0),
                                    strokeWidth: 1.5)),
                          );
                        }
                        if (url.isNotEmpty) {
                          return CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFEAF1FF),
                              backgroundImage: NetworkImage(url));
                        }
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
                      child: Text(c.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E2A3A))),
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
                                border: Border.all(
                                    color: const Color(0xFFFFCDD2)),
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

          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}