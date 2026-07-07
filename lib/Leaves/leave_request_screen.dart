import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../Services/api_service.dart';
import '../ui/dialogs/reject_leave_dialog.dart';
import '../ui/dialogs/approve_leave_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
class LeaveRequestScreen extends StatefulWidget {

  final String managerId;
  const LeaveRequestScreen({super.key, required this.managerId});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String? errorText;

  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

  @override
  void initState() {
    super.initState();
    _loadManagerRequests();
  }

  Future<void> _loadManagerRequests() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final data = await ApiService.fetchManagerLeaveRequests(managerId: widget.managerId);
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

  Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
    return _photoFutureCache.putIfAbsent(
      employeeId,
      () => ApiService.getProfilePhoto(employeeId: employeeId),
    );
  }
  
  // Show reject dialog
  Future<void> _showRejectDialog(BuildContext context, Map<String, dynamic> r) async {
  showRejectDialog(
    context: context,
    request: r,
    managerId: widget.managerId,
    reload: _loadManagerRequests,
  );
  }

  // Show approve dialog
    Future<void> _showApproveDialog(BuildContext context, Map<String, dynamic> r) async {
  showApproveDialog(
    context: context,
    request: r,
    managerId: widget.managerId,
    reload: _loadManagerRequests,
  );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;
    final pad = isTablet ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Leave Request"),
        foregroundColor: Colors.black,
        elevation: 0.6,
      ),
      body: RefreshIndicator(
        onRefresh: _loadManagerRequests,
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
                  color: Colors.blue,
                  backgroundColor: Colors.white,)
                ),
              )
            else if (errorText != null)
              Column(
                children: [
                  Text(errorText!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loadManagerRequests,
                    child: const Text("Retry"),
                  ),
                ],
              )
            else if (requests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text("No manager requests", style: TextStyle(color: Colors.grey))),
              )
            else
              ...requests.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _LeaveRequestCard(
                      data: r,
                      onReject: () => _showRejectDialog(context, r),
                      onApprove: () => _showApproveDialog(context, r),
                        getPhoto: _getPhotoFuture,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ====================== CARD UI ======================
class _LeaveRequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final Future<Map<String, dynamic>?> Function(int employeeId) getPhoto;


  const _LeaveRequestCard({
    required this.data,
    required this.onReject,
    required this.onApprove,
    required this.getPhoto,

  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;

    final attachment = data["attachmentName"];
    final covering = data["coveringOfficer"] as Map<String, dynamic>?;
    final isSpecial = data["is_special_request"].toString() == "1";
    final attachmentName = data["attachmentName"];
    final attachmentPath = data["attachmentPath"];
    final String rawApplied = (data["requested_at"] ?? data["appliedOn"] ?? data["applied_on"] ?? "-").toString();
    final String appliedOn = () {
      try {
        return DateFormat('yyyy-MM-dd  hh:mm a').format(DateTime.parse(rawApplied));
      } catch (_) {
        return rawApplied.length >= 16 ? rawApplied.substring(0, 16) : rawApplied;
      }
    }();



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

                    // loading
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

                    // show photo
                    if (url.isNotEmpty) {
                      return CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFEAF1FF),
                        backgroundImage: NetworkImage(url),
                      );
                    }

                    // fallback
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data["employeeName"] ?? "",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900, 
                            fontSize: 13.5, color: Color(0xFF1E2A3A)
                          ),
                        ),
                      ),
                      if (isSpecial)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD), // light amber
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFFE08A)),
                          ),
                          child: const Text(
                            "SPECIAL",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF8A5A00),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),

                    const SizedBox(height: 0.5),
                    Text(
                      "${data["position"] ?? ""}\nEmployee ID: ${data["employeeId"] ?? ""}",
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
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _detailRow("Leave type", (data["leaveType"] ?? "").toString()),
                const SizedBox(height: 8),
                _detailRow("From date", (data["from"] ?? "").toString()),
                const SizedBox(height: 8),
                _detailRow("To date", (data["to"] ?? "").toString()),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Total Days:",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E2A3A),
                          ),
                        ),
                      ),
                      Text(
                        "${data["days"]}",
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E2A3A),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _boxField("Reason", (data["reason"] ?? "").toString()),
          const SizedBox(height: 10),

          // ===== RELIEVER / SPECIAL REQUEST SECTION =====
          if (covering != null) ...[
            _boxField(
              "Reliever Comment",
              "Name: ${covering["name"] ?? "-"}\nComment: ${covering["note"] ?? "-"}",
            ),
            const SizedBox(height: 10),
          ]
          else if (isSpecial) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE08A)),
              ),
              child: const Text(
                "Special Request (No relievers).",
                style: TextStyle(
                  fontSize: 12.3,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A5A00),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],


          if (attachment != null && attachment.toString().trim().isNotEmpty) ...[
            _attachmentRow(
              context: context,
              fileName: attachmentName.toString(),
              filePath: attachmentPath.toString(),
            ),

            const SizedBox(height: 10),
          ] else ...[
            const Text(
              "Attached document: No update",
              style: TextStyle(
                color: Color(0xFF6B7A90),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],

          Text(
            'Applied on: $appliedOn',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7A90),
            ),
          ),
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
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Approve",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
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
          width: 85,
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

  Widget _boxField(String label, String value) {
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
            label,
            style: const TextStyle(
              color: Color(0xFF6B7A90),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
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



  Widget _attachmentRow({
    required BuildContext context,
    required String fileName,
    required String filePath, // relative path from DB
  }) {
    // Make full URL (change domain to your server)
    final fileUrl = "https://exploresuite.lk/mobile-api/$filePath";

    bool isImage(String name) {
      final n = name.toLowerCase();
      return n.endsWith(".jpg") || n.endsWith(".jpeg") || n.endsWith(".png");
    }

    Future<void> openUrl(String url) async {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception("Could not open $url");
      }
    }


  void showImagePreviewWithBlur(BuildContext context, String fileUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.15), // dim
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        final dialogW = (w * 0.92).clamp(280.0, 520.0);

        return Stack(
          children: [
            //Blurred Background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.transparent),
            ),

            // DIALOG
            Center(
              child: Dialog(
                insetPadding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: SizedBox(
                  width: dialogW,
                  height: 420,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.black,
                          child: PhotoView(
                            imageProvider: NetworkImage(fileUrl),
                            backgroundDecoration: const BoxDecoration(color: Colors.black),
                            minScale: PhotoViewComputedScale.contained,
                            maxScale: PhotoViewComputedScale.covered * 2.5,
                          ),
                        ),

                        // Close button
                        Positioned(
                          right: 6,
                          top: 6,
                          child: IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
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
  }


    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: Color(0xFF1E88E5), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E88E5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 👁 View (only for images)
          IconButton(
            tooltip: "View",
            onPressed: () {
              if (isImage(fileName)) {
                showImagePreviewWithBlur(context, fileUrl);
              } else {
                // for PDF/DOC open external
                openUrl(fileUrl);
              }
            },
            icon: const Icon(Icons.remove_red_eye, size: 18),
          ),

          // ⬇ Download/Open
          IconButton(
            tooltip: "Open",
            onPressed: () => openUrl(fileUrl),
            icon: const Icon(Icons.download, size: 18),
          ),
        ],
      ),
    );
  }
}
