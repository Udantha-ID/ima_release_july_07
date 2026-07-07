import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Services/vehicle_api_service.dart';
import '../Leaves/top_banner.dart';
import '../Services/api_service.dart';
import '../ui/dialogs/vehicle_reject_dialog.dart';
import '../ui/dialogs/vehicle_approve_dialog.dart';
import '../ui/dialogs/manager_vehicle_change_dialog.dart';
import 'personal_vehicle_summary_screen.dart';

class PersonalRequestScreen extends StatefulWidget {
  final String managerId;
  final Map<String, dynamic>? user;

  const PersonalRequestScreen({
    super.key,
    required this.managerId,
    this.user,
  });

  @override
  State<PersonalRequestScreen> createState() => _PersonalRequestScreenState();
}

class _PersonalRequestScreenState extends State<PersonalRequestScreen> {
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String? errorText;
  int _selectedTab = 0;

bool get _isGeneralManager {
  final u = widget.user;
  if (u == null) return false;

  // Check by job title ID (GM = 15)
  final jobTitleId = (u["jobTitleId"] ?? u["job_title_id"])?.toString() ?? "";
  if (jobTitleId == "15") return true;

  // Check by job title name — covers MD and any other senior title
  final jobTitle = (u["jobTitle"] ?? u["job_title_name"] ?? "")
      .toString()
      .toLowerCase();
  if (jobTitle.contains("general manager")) return true;
  if (jobTitle.contains("managing director")) return true;

  return false;
} 

  static String _requestStatus(Map<String, dynamic> r) {
    return (r["status"] ?? r["request_status"] ?? "PENDING")
        .toString()
        .trim()
        .toUpperCase();
  }

  static String _hodComment(Map<String, dynamic> r) {
    return (r["hod_comment"] ?? r["hodComment"] ?? "").toString().trim();
  }

  static String _resolveVehicleType(Map<String, dynamic> r) {
    final candidates = [
      r["vehicle_type"],
    ];
    for (final c in candidates) {
      final v = (c ?? "").toString().trim();
      if (v.isNotEmpty && v != "-") return v;
    }
    return "";
  }

  @override
  void initState() {
    super.initState();
    _loadManagerVehicleRequests();
  }

Future<void> _loadManagerVehicleRequests() async {
  setState(() {
    loading = true;
    errorText = null;
  });

  try {
      // In _loadManagerVehicleRequests, capture the server message
      final data = _isGeneralManager
        ? await VehicleApiService.fetchGeneralManagerPersonalRequests(
            userId: widget.managerId,
          )
        : await VehicleApiService.fetchManagerPersonalRequests(
            managerId: widget.managerId,
          );

    setState(() {
      requests = data;
      loading = false;
    });
  } catch (e) {
    setState(() {
      errorText = e.toString();
      loading = false;
    });
  }
}

  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

    Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
      return _photoFutureCache.putIfAbsent(
        employeeId,
        () => ApiService.getProfilePhoto(employeeId: employeeId),
      );
    }

  // ====================== REJECT POPUP (delegated to dialog file) ======================
  Future<void> _showRejectDialog(BuildContext context, Map<String, dynamic> r) async {
    final requestId = int.parse(
      (r["request_id"] ?? r["id"] ?? "0").toString(),
    );

    await showVehicleRejectDialog(
      context: context,
      initialNote: "",
      onReject: (comment) async {
        try {
          await VehicleApiService.rejectVehicleRequest(
            requestId: requestId,
            comment: comment,
          );

          await _loadManagerVehicleRequests();

          if (mounted) {
            TopBanner.show(
              context,
              title: "Reject Request",
              message: "Vehicle request rejected successfully.",
              icon: Icons.cancel,
            );
          }
        } catch (e) {
          if (mounted) {
            TopBanner.show(
              context,
              title: "Reject Failed",
              message: e.toString().replaceFirst("Exception: ", ""),
              icon: Icons.error_outline,
              isSuccess: false,
            );
          }
        }
      },
    );
  }

  // ====================== APPROVE POPUP (delegated to dialog file) ======================
  Future<void> _showApproveDialog(BuildContext context, Map<String, dynamic> r) async {
    final requestId = int.parse(r["request_id"].toString());
    final employeeName = (r["employee_name"] ?? r["employeeName"] ?? "USER").toString();

    await showVehicleApproveDialog(
      context: context,
      employeeName: employeeName,
      isPersonalRequest: true,
      onAcceptAndForward: (comment) async {
        try {
          final res = await VehicleApiService.approveVehicleRequest(
            requestId: requestId,
            hodComment: comment,
          );

          await _loadManagerVehicleRequests();

          if (!mounted) return;

          final tripCode = VehicleApiService.tripCodeFromApproveResponse(res);
          final serverMsg = res["message"]?.toString() ?? "";

          if (tripCode != null) {
            TopBanner.show(
              context,
              title: "Request fully approved",
              message:
                  "Personal request for $employeeName is approved. Trip code: $tripCode",
              icon: Icons.check_circle,
              isSuccess: true,
            );
          } else {
            TopBanner.show(
              context,
              title: "Accepted & forwarded",
              message: serverMsg.isNotEmpty
                  ? serverMsg
                  : "Request for $employeeName was forwarded. Trip code is issued after final approval.",
              icon: Icons.check_circle,
              isSuccess: true,
            );
          }
        } catch (e) {
          if (mounted) {
            TopBanner.show(
              context,
              title: "Accept & Forward Failed",
              message: e.toString().replaceFirst("Exception: ", ""),
              icon: Icons.error_outline,
              isSuccess: false,
            );
          }
        }
      },
    );
  }

  Future<void> _showGmApproveDialog(BuildContext context, Map<String, dynamic> r) async {
    final requestId = int.parse(r["request_id"].toString());
    final employeeName = (r["employee_name"] ?? r["employeeName"] ?? "USER").toString();

    await showVehicleApproveDialog(
      context: context,
      employeeName: employeeName,
      isPersonalRequest: false,
      onApprove: () async {
        try {
          final res = await VehicleApiService.approveVehicleRequest(
            requestId: requestId,
            hodComment: "",
          );

          await _loadManagerVehicleRequests();

          if (!mounted) return;

          final tripCode = VehicleApiService.tripCodeFromApproveResponse(res);
          TopBanner.show(
            context,
            title: "Request approved",
            message: tripCode != null
                ? "Personal request for $employeeName approved. Trip code: $tripCode"
                : "Personal request for $employeeName approved.",
            icon: Icons.check_circle,
            isSuccess: true,
          );
        } catch (e) {
          if (mounted) {
            TopBanner.show(
              context,
              title: "Approve Failed",
              message: e.toString().replaceFirst("Exception: ", ""),
              icon: Icons.error_outline,
              isSuccess: false,
            );
          }
        }
      },
    );
  }

  Future<void> _changeVehicleByManager(Map<String, dynamic> request, {
    required String vehicleType,
    required String vehicleNo,
    required int vehicleId,
  }) async {
    final requestId = VehicleApiService.transportServiceIdFromRequest(request) ?? 0;
    if (requestId <= 0) {
      if (!mounted) return;
      TopBanner.show(
        context,
        title: "Invalid Request",
        message: "Invalid request ID. Please refresh and try again.",
        icon: Icons.error_outline,
        isSuccess: false,
      );
      return;
    }

    final currentType = _resolveVehicleType(request);
    if (currentType.isNotEmpty &&
        currentType.toLowerCase() != vehicleType.trim().toLowerCase()) {
      if (!mounted) return;
      TopBanner.show(
        context,
        title: "Vehicle Type Mismatch",
        message: "Only $currentType type vehicles can be changed for this request.",
        icon: Icons.error_outline,
        isSuccess: false,
      );
      return;
    }

    try {
      final res = await VehicleApiService.changePersonalRequestVehicle(
        requestId: requestId,
        currentVehicleType: currentType,
        selectedVehicleType: vehicleType.trim(),
        vehicleNo: vehicleNo.trim(),
        vehicleId: vehicleId,
      );

      if (res["success"] == true) {
        await _loadManagerVehicleRequests();
        if (!mounted) return;
        TopBanner.show(
          context,
          title: "Vehicle changed",
          message: "Vehicle updated successfully.",
          icon: Icons.check_circle,
          isSuccess: true,
        );
      } else {
        throw Exception((res["message"] ?? "Vehicle change failed").toString());
      }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(
        context,
        title: "Vehicle change failed",
        message: e.toString(),
        icon: Icons.error_outline,
        isSuccess: false,
      );
    }
  }

  Future<void> _showManagerChangeVehicleDialog(Map<String, dynamic> request) async {
    final vehicleType = _resolveVehicleType(request);

    final fromDate = (request["from_date"] ?? request["fromDate"] ?? "").toString();
    final toDate = (request["to_date"] ?? request["toDate"] ?? "").toString();

    await showManagerVehicleChangeDialog(
      context: context,
      currentVehicleType: vehicleType,
      fromDate: fromDate,
      toDate: toDate,
      onConfirm: ({
        required String vehicleType,
        required String vehicleNo,
        required int vehicleId,
      }) async {
        await _changeVehicleByManager(
          request,
          vehicleType: vehicleType,
          vehicleNo: vehicleNo,
          vehicleId: vehicleId,
        );
      },
    );
  }

  String get _appBarTitle =>
      _isGeneralManager ? "Personal Vehicle Requests" : "Personal Vehicle Requests";

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;
    final pad = isTablet ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(_appBarTitle),
        foregroundColor: Colors.black,
        elevation: 0.6,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _tabBtn('Requests', Icons.assignment_outlined, 0),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tabBtn('Summary', Icons.bar_chart_outlined, 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                RefreshIndicator(
                  onRefresh: _loadManagerVehicleRequests,
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
                          child: Center(
                            child: CircularProgressIndicator(
                                color: Colors.blue,
                                backgroundColor: Colors.white),
                          ),
                        )
                      else if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
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
                                onPressed: _loadManagerVehicleRequests,
                                icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                                label: const Text('Retry', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      else if (requests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              _isGeneralManager
                                  ? "No HOD-approved personal requests"
                                  : "No vehicle requests",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...requests.map((r) {
                          final st = _requestStatus(r);
                          final gm = _isGeneralManager;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _VehicleRequestCard(
                              data: r,
                              status: st,
                              hodComment: _hodComment(r),
                              generalManagerView: gm,
                              onReject: () => _showRejectDialog(context, r),
                              onPrimary: gm
                                  ? () => _showGmApproveDialog(context, r)
                                  : () => _showApproveDialog(context, r),
                              primaryLabel:
                                  gm ? "Approve" : "Accept & Forward",
                              getPhoto: _getPhotoFuture,
                              onChangeVehicle: () =>
                                  _showManagerChangeVehicleDialog(r),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                PersonalVehicleSummaryScreen(
                  managerId: int.tryParse(widget.managerId) ?? 0,
                  isGeneralManager: _isGeneralManager,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, IconData icon, int index) {
    final isActive = _selectedTab == index;
    final blue = Colors.blue[800]!;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? blue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? blue : const Color(0xFFE1E6EF),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17,
                color: isActive ? Colors.white : Colors.black87),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================== CARD UI ======================
class _VehicleRequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String status;
  final String hodComment;
  final bool generalManagerView;
  final VoidCallback onReject;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final Future<Map<String, dynamic>?> Function(int employeeId) getPhoto;
  final VoidCallback onChangeVehicle;

  const _VehicleRequestCard({
    required this.data,
    required this.status,
    required this.hodComment,
    required this.generalManagerView,
    required this.onReject,
    required this.onPrimary,
    required this.primaryLabel,
    required this.getPhoto,
    required this.onChangeVehicle,
  });

  Widget _statusBadge() {
    if (status == "HOD_APPROVED") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFA5D6A7)),
        ),
        child: const Text(
          "HOD APPROVED",
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1B5E20),
            letterSpacing: 0.2,
          ),
        ),
      );
    }
    if (status == "PENDING") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFFE08A)),
        ),
        child: const Text(
          "PENDING",
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF8A5A00),
            letterSpacing: 0.3,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE1E6EF)),
      ),
      child: Text(
        status.replaceAll("_", " "),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: Color(0xFF6B7A90),
        ),
      ),
    );
  }

  Widget _hodCommentBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            generalManagerView ? "HOD comment" : "Status & HOD comment",
            style: const TextStyle(
              color: Color(0xFF6B7A90),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Status: $status",
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2A3A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hodComment.isEmpty ? "—" : hodComment,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2A3A),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;

    final employeeName = (data["employee_name"] ?? data["employeeName"] ?? "").toString();
    final employeeCode = (data["employee_code"] ?? data["employeeId"] ?? "").toString();
    final jobTitle = (data["job_title_name"] ?? data["position"] ?? "").toString();

    final vehicleNo = (data["vehicle_no"] ?? data["vehicleNo"] ?? "").toString();
    final reason = (data["type"] ?? data["reason"] ?? "Office Service").toString();

    final fromDate = (data["from_date"] ?? data["fromDate"] ?? "").toString();
    final toDate = (data["to_date"] ?? data["toDate"] ?? "").toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Builder(
                builder: (context) {
                  final int empId = int.tryParse((data["employee_id"] ?? data["employeeId"] ?? "0").toString()) ?? 0;
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: empId > 0 ? getPhoto(empId) : Future.value(null),
                    builder: (context, snap) {
                      final url = (snap.data?["fileUrl"] ?? "").toString().trim();

                      if (snap.connectionState == ConnectionState.waiting) {
                        return const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFFEAF1FF),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                            backgroundColor: Colors.white,
                            strokeWidth: 2
                            ),
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

                      return const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFEAF1FF),
                        child: Icon(Icons.person, color: Color(0xFF1E88E5)),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: Color(0xFF1E2A3A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$jobTitle\nEmployee ID: $employeeCode",
                      style: const TextStyle(
                        color: Color(0xFF6B7A90),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 108,
                height: 30,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: 22,
                      top: 2,
                      child: _statusBadge(),
                    ),
                    Positioned(
                      right: -16,
                      top: -22,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          popupMenuTheme: const PopupMenuThemeData(
                            color: Colors.white,
                            surfaceTintColor: Colors.white,
                            shadowColor: Colors.black26,
                            elevation: 8,
                            textStyle: TextStyle(
                              color: Color(0xFF1E2A3A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          color: Colors.white,
                          surfaceTintColor: Colors.white,
                          shadowColor: Colors.black26,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          splashRadius: 12,
                          icon: const Icon(
                            Icons.more_vert,
                            color: Color(0xFF64748B),
                            size: 16,
                          ),
                          onSelected: (value) {
                            if (value == "change_vehicle" && generalManagerView) {
                              onChangeVehicle();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: "change_vehicle",
                              enabled: generalManagerView,
                              child: Text(
                                generalManagerView
                                    ? "Change Vehicle"
                                    : "Change Vehicle (GM only)",
                                style: TextStyle(
                                  color: generalManagerView
                                      ? const Color(0xFF1E2A3A)
                                      : const Color(0xFF9AA4B2),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _attemptBanner(),

          const SizedBox(height: 10),

          // details box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _detailRow("Vehicle No", vehicleNo),
                const SizedBox(height: 8),
                _vehicleModelRow(),
                const SizedBox(height: 8),
                _detailRow("Reason", reason),
                const SizedBox(height: 8),
                _detailRow("From date", fromDate),
                const SizedBox(height: 8),
                _detailRow("To date", toDate),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _hodCommentBox(),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD10A0A), Color(0xFF5B0000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Reject",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      primaryLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_fmtApplied((data["created_at"] ?? data["requested_at"] ?? "").toString()).isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _fmtApplied((data["created_at"] ?? data["requested_at"] ?? "").toString()),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7A90)),
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

  Widget _attemptBanner() {
    final attempt = int.tryParse(
            (data['current_attempt'] ?? data['usage_count'] ?? '1').toString()) ??
        1;
    final label =
        (data['attempt_label'] ?? (attempt == 1 ? 'First Attempt' : '$attempt Attempt'))
            .toString()
            .trim();

    final isFirst = attempt <= 1;

    final Color bg      = isFirst ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final Color border  = isFirst ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A);
    final Color iconCol = isFirst ? const Color(0xFF15803D) : const Color(0xFFB45309);
    final Color textCol = isFirst ? const Color(0xFF14532D) : const Color(0xFF78350F);
    final IconData icon = isFirst ? Icons.verified_outlined : Icons.repeat_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconCol),
          const SizedBox(width: 8),
          Text(
            "Attempt:",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textCol,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: textCol,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: iconCol.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "#$attempt",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: iconCol,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7A90),
            ),
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
                color: Color(0xFF1E2A3A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
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