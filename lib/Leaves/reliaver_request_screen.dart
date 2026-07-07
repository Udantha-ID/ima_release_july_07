import 'dart:ui';
import 'top_banner.dart';
import 'package:flutter/material.dart';
import 'package:test_app/Services/api_service.dart';
import '../ui/dialogs/reliever_decline_dialog.dart';
import '../ui/dialogs/reliever_accept_dialog.dart';

class RelieverRequestView extends StatefulWidget {
  final Map<String, dynamic> user;
  const RelieverRequestView({super.key, required this.user});

  @override
  State<RelieverRequestView> createState() => _RelieverRequestViewState();

  
}

class _RelieverRequestViewState extends State<RelieverRequestView> {
  List<Map<String, dynamic>> requests = [];
  bool loading = false;
  String? errorText;



  void _showSuccessBanner(String title, String message) {
  TopBanner.show(
    context,
    title: title,
    message: message,
    icon: Icons.check_circle,
    rightButtonText: "OK",
  );
}

void _showErrorBanner(String title, String message) {
  TopBanner.show(
    context,
    title: title,
    message: message,
    icon: Icons.error_outline,
    rightButtonText: "OK",
  );
}

final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
  return _photoFutureCache.putIfAbsent(
    employeeId,
    () => ApiService.getProfilePhoto(employeeId: employeeId),
  );
}


  @override
  void initState() {
    super.initState();
    _loadRelieverRequests();
  }

  Future<void> _loadRelieverRequests() async {
    try {
      setState(() {
        loading = true;
        errorText = null;
      });

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) {
        setState(() {
          loading = false;
          errorText = "employeeId not found in login data";
        });
        return;
      }

      final res = await ApiService.getRelieverRequests(employeeId: employeeId);

      if (!mounted) return;

      if (res["success"] == true) {
        final raw = res["requests"] ?? res["data"] ?? [];
        final list = List<Map<String, dynamic>>.from(raw);

        // Keep reference to old controllers so we can dispose after build
        final oldRequests = List<Map<String, dynamic>>.from(requests);

        // add controller per item for new list
        for (final r in list) {
          r["noteController"] = TextEditingController(text: "");
        }

        setState(() {
          requests = list;
          loading = false;
        });

        // Dispose old controllers after this frame so TextFields have released them
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final r in oldRequests) {
            final c = r["noteController"];
            if (c is TextEditingController) c.dispose();
          }
        });
      } else {
        setState(() {
          loading = false;
          errorText = (res["message"] ?? "Failed to load").toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = e.toString();
      });
    }
  }

  @override
  void dispose() {
    for (final r in requests) {
      final c = r["noteController"];
      if (c is TextEditingController) c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue[800] ?? Colors.blue;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
      onRefresh: _loadRelieverRequests,
      color: Colors.blue,
      backgroundColor: Colors.white,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 8),

        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            //child: Center(child: CircularProgressIndicator()),
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
                  onPressed: _loadRelieverRequests,
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                  label: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          )
        else if (requests.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Center(child: Text("No reliever requests", style: TextStyle(color: Colors.grey))),
          )
        else
          ...requests.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _requestCard(r, blue),

              )),
            ],
          ),
        ),
      );
    }

  // ---------------- CARD UI ----------------

  Widget _requestCard(Map<String, dynamic> r, Color blue) {

    final int applicantEmpId =
    int.tryParse((r["employeeId"] ?? r["applicant_employee_id"] ?? "0").toString()) ?? 0;

    String getStr(List<String> keys, {String fallback = "-"}) {
      for (final k in keys) {
        final v = r[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    final int leaveRequestId = (r["leaveRequestId"] is int)
        ? r["leaveRequestId"] as int
        : int.tryParse((r["leaveRequestId"] ?? "0").toString()) ?? 0;

    final relieverId = widget.user["employeeId"]?.toString() ?? "";

    final name = getStr(["name", "employee_name"]);
    final role = getStr(["job_title_name", "designation", "job_title"], fallback: "");
    final empNo = getStr(["empNo", "employeeCode", "employee_code"], fallback: "-");
    final leaveType = getStr(["leaveType", "leave_type"]);
    final from = getStr(["from", "leave_start_date"]);
    final to = getStr(["to", "leave_end_date"]);
    final days = getStr(["days", "number_of_days"], fallback: "0");
    final applyOn = getStr(["applyOn", "requested_at"], fallback: "-");
    final status = getStr(["status"], fallback: "Awaiting");

    print("RELIEVER ITEM keys: employee_id=${r["employee_id"]}, employee_code=${r["employee_code"]}, empNo=${r["empNo"]}, employeeId=${r["employeeId"]}");

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: applicantEmpId > 0 ? _getPhotoFuture(applicantEmpId) : Future.value(null),
                builder: (context, snap) {
                  final url = (snap.data?["fileUrl"] ?? "").toString().trim();

                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircleAvatar(
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2A3A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${role.isEmpty ? '' : role}\nEmployee No: $empNo",
                      style: const TextStyle(
                        fontSize: 10.8,
                        height: 1.2,
                        color: Color(0xFF6B7A90),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(status, const Color(0xFFE7D48A), const Color(0xFF6B4F00)),
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
                _rowLine("Leave type", leaveType),
                const SizedBox(height: 8),
                _rowLine("From date", from),
                const SizedBox(height: 8),
                _rowLine("To date", to),
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
                        days,
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: () => showRelieverDeclineDialog(
                    context: context,
                    employeeName: name,
                    initialNote: "",
                    onDecline: (comment) async{
                        if (leaveRequestId <= 0 || relieverId.isEmpty) return;

                       final res = await ApiService.relieverDecline(
                          leaveRequestId: leaveRequestId,
                          relieverId: relieverId,
                          comment: comment,
                        );

                        if (!mounted) return;

                        if (res["success"] == true) {
                        TopBanner.show(
                          context,
                          title: "Request Declined",
                          message: "Your awaiting leave request has been canceled successfully.",
                          icon: Icons.cancel,
                          isSuccess: true,
                        );

                          // refresh list
                          await _loadRelieverRequests();
                        } else {
                          _showErrorBanner(
                            "Decline failed",
                            res["message"]?.toString() ?? "Please try again.",
                          );
                        }
                        await _loadRelieverRequests();
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      "Decline\nCoverage",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: () => showRelieverAcceptDialog(
                      context: context,
                      employeeName: name,
                      initialNote: "",
                      onAccept: (comment) async {
                        if (leaveRequestId <= 0 || relieverId.isEmpty) return;

                        final res = await ApiService.relieverAccept(
                          leaveRequestId: leaveRequestId,
                          relieverId: relieverId,
                          comment: comment,
                        );

                        if (!mounted) return;
                       if (res["success"] == true) {
                        TopBanner.show(
                          context,
                          title: "Request Accepted.",
                          message: "Your awaiting leave request has been accepted successfully.",
                          icon: Icons.check_circle,
                        );

                          // refresh list
                          await _loadRelieverRequests();
                        } else {
                          _showSuccessBanner(
                            "Accept failed",
                            res["message"]?.toString() ?? "Please try again.",
                          );
                        }
                        await _loadRelieverRequests();
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      "Accept and\nForward",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            "Apply on: $applyOn",
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7A90),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowLine(String left, String right) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7A90),
            ),
          ),
        ),
        Text(
          right,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E2A3A),
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}
