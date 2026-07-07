import 'dart:ui';
import 'package:intl/intl.dart';
import '../ui/dialogs/cancel_leave_dialog.dart';
import 'package:flutter/material.dart';
import 'package:test_app/Services/api_service.dart';
import 'top_banner.dart';


class LeaveHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const LeaveHistoryScreen({super.key, required this.user});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

//Leave Status Enum
enum LeaveStatus {
  pending,
  relieverAccepted,
  relieverDeclined,
  approved,   
  rejected,       
}

class LeaveRequest {
  final int leaveRequestId;
  final String leaveType;
  final String reason;
  final String startDate;
  final String endDate;
  final String duration;
  final String appliedOn;
  final LeaveStatus status;
  final String? managerComment;
  final String? relieverComment;

  LeaveRequest({
    required this.leaveRequestId,
    required this.leaveType,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.appliedOn,
    required this.status,
    this.managerComment,
    this.relieverComment,
  });
}
class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  int selectedFilter = 0; // 0 all, 1 pending, 2 approved, 3 rejected

  bool loading = true;
  String? error;
  List<LeaveRequest> allRequests = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }
  
LeaveStatus _parseStatus(String s) {
  s = s.toUpperCase().trim();

  if (s == "APPROVED") return LeaveStatus.approved;
  if (s == "REJECTED") return LeaveStatus.rejected;

  if (s == "RELIEVER ACCEPTED") return LeaveStatus.relieverAccepted;
  if (s == "RELIEVER DECLINED") return LeaveStatus.relieverDeclined;

  // default
  return LeaveStatus.pending;
}


  Future<void> _loadHistory() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) {
        setState(() {
          loading = false;
          error = "employeeId not found in login data";
        });
        return;
      }

      final res = await ApiService.getLeaveHistory(employeeId: employeeId);

      if (res["success"] == true) {
        final list = List<Map<String, dynamic>>.from(res["data"] ?? []);

        setState(() {
          allRequests = list.map((x) {
            final id = int.tryParse(x["leave_request_id"]?.toString() ?? "") ?? 0;
            final numDays = x["number_of_days"]?.toString() ?? "0";
            return LeaveRequest(
              leaveRequestId: id,
              leaveType: (x["leave_type"] ?? "-").toString(),
              reason: (x["reason"] ?? "-").toString(),
              startDate: (x["leave_start_date"] ?? "-").toString(),
              endDate: (x["leave_end_date"] ?? "-").toString(),
              duration: "$numDays Days",
              appliedOn: () {
                final v = (x["requested_at"] ?? "-").toString();
                try {
                  return DateFormat('yyyy-MM-dd  hh:mm a').format(DateTime.parse(v));
                } catch (_) {
                  return v.length >= 16 ? v.substring(0, 16) : v;
                }
              }(),
              status: _parseStatus((x["status"] ?? "PENDING").toString()),
              managerComment: x["manager_comment"]?.toString(),
              relieverComment: x["reliever_comment"]?.toString() ?? x["reliever_notes"]?.toString(),
            );
          }).toList();
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          error = res["message"]?.toString() ?? "Failed to load";
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _cancelRequest(LeaveRequest r) async {
    final employeeId = widget.user["employeeId"]?.toString() ?? "";
    if (employeeId.isEmpty) return;

    try {
      final res = await ApiService.cancelLeaveRequest(
        employeeId: employeeId,
        leaveRequestId: r.leaveRequestId,
      );

      if (res["success"] == true) {
        if (!mounted) return;

        TopBanner.show(
          context,
          title: "Request canceled",
          message: "Your pending leave request has been canceled successfully.",
          icon: Icons.cancel,
        );
        _loadHistory(); // refresh list
        
        // Remove item from UI immediately
        setState(() {
          allRequests.removeWhere((x) => x.leaveRequestId == r.leaveRequestId);
        });

      } else {
        if (!mounted) return;
        TopBanner.show(
          context,
          title: "Cancel Failed",
          message: (res["message"] ?? "Failed to cancel request.").toString(),
          icon: Icons.error_outline,
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(
        context,
        title: "Cancel Failed",
        message: e.toString().replaceFirst("Exception: ", ""),
        icon: Icons.error_outline,
        isSuccess: false,
      );
    }
  }

@override
Widget build(BuildContext context) {
  final blue = Colors.blue[800]!;
  final counts = _counts(allRequests);
  final filtered = _filteredList(allRequests);

  return Scaffold(
    backgroundColor: Colors.white,
    body: RefreshIndicator(
      onRefresh: _loadHistory,
      color: Colors.blue,
      backgroundColor: Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SizedBox(height: 8),

          // --- loading ---
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              // child: Center(child: CircularProgressIndicator()),
            )

          // --- error ---
          else if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 200),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loadHistory,
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                    label: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )

          else ...[
            // Filter chips (full-width aligned, similar to trip tabs)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All (${counts['all']})', 0, blue),
                    const SizedBox(width: 8),
                    _filterChip('Pending (${counts['pending']})', 1, blue),
                    const SizedBox(width: 8),
                    _filterChip('Approved (${counts['approved']})', 2, blue),
                    const SizedBox(width: 8),
                    _filterChip('Rejected (${counts['rejected']})', 3, blue),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: Text("No requests found", style: TextStyle(color: Colors.grey))),
              )
            else
              ...filtered.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _leaveCard(r, blue),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}


  // ---------------- FILTER CHIPS ----------------

  Widget _filterChip(String text, int index, Color blue) {
    final active = selectedFilter == index;

    return InkWell(
      onTap: () => setState(() => selectedFilter = index),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? blue : const Color(0xFFE1E6EF)),
          boxShadow: [
            if (active)
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF1E2A3A),
          ),
        ),
      ),
    );
  }

  // ---------------- LEAVE CARD ----------------

  Widget _leaveCard(LeaveRequest r, Color blue) {
    final statusUi = _statusUI(r.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: leave type + reason + status pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.leaveType,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2A3A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7A90),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _statusPill(
                statusUi['text'] as String,
                statusUi['bg'] as Color,
                statusUi['fg'] as Color,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Details box — matches request card style
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _cardDetailRow('Start Date', r.startDate),
                const SizedBox(height: 8),
                _cardDetailRow('End Date', r.endDate),
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
                          'Duration:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E2A3A),
                          ),
                        ),
                      ),
                      Text(
                        r.duration,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E2A3A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Manager comment
          if (r.managerComment != null && r.managerComment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _cardBoxField(
              "Manager's Comment",
              r.managerComment!,
              const Color.fromARGB(255, 246, 219, 215),
            ),
          ],

          // Reliever comment
          if (r.relieverComment != null && r.relieverComment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _cardBoxField(
              "Reliever's Comment",
              r.relieverComment!,
              r.status == LeaveStatus.relieverDeclined
                  ? const Color(0xFFFFD9D9)
                  : const Color(0xFFD7E8F6),
            ),
          ],

          const SizedBox(height: 12),
          Text(
            'Applied on: ${r.appliedOn}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7A90),
            ),
          ),

          // Cancel button — pending / reliever declined / reliever accepted
          if (r.status == LeaveStatus.pending || r.status == LeaveStatus.relieverDeclined || r.status == LeaveStatus.relieverAccepted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
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
                  onPressed: () async {
                    final ok = await showCancelConfirmPopup(context);
                    if (ok == true) _cancelRequest(r);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel Request',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardDetailRow(String label, String value) {
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
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E2A3A),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardBoxField(String label, String value, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E2A3A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2A3A),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  // ---------------- HELPERS ----------------

Map<String, dynamic> _statusUI(LeaveStatus s) {
  switch (s) {
    case LeaveStatus.pending:
      return {'text': 'Pending', 'bg': const Color(0xFFE7D48A), 'fg': const Color(0xFF6B4F00)};

    case LeaveStatus.relieverAccepted:
      return {'text': 'Reliever Accepted', 'bg': const Color(0xFFD7F3FF), 'fg': const Color(0xFF0B4F6C)};

    case LeaveStatus.relieverDeclined:
      return {'text': 'Reliever Declined', 'bg': const Color(0xFFE7D48A), 'fg': const Color(0xFF6B4F00)};

    case LeaveStatus.approved:
      return {'text': 'Approved', 'bg': const Color(0xFFCFF1D6), 'fg': const Color(0xFF0F6B2D)};

    case LeaveStatus.rejected:
      return {'text': 'Rejected', 'bg': const Color(0xFFFFD1D1), 'fg': const Color(0xFF9B1C1C)};
  }
}


Map<String, int> _counts(List<LeaveRequest> list) {
  int pending = 0, approved = 0, rejected = 0;

  for (final r in list) {
    if (r.status == LeaveStatus.approved) approved++;
    else if (r.status == LeaveStatus.rejected) rejected++;
    else {
      // everything not final goes to "Pending"
      pending++;
    }
  }

  return {
    'all': list.length,
    'pending': pending,
    'approved': approved,
    'rejected': rejected,
  };
}


List<LeaveRequest> _filteredList(List<LeaveRequest> list) {
  if (selectedFilter == 0) return list;

  return list.where((r) {
    if (selectedFilter == 1) {
      // PENDING TAB includes reliever states too
      return r.status == LeaveStatus.pending ||
             r.status == LeaveStatus.relieverAccepted ||
             r.status == LeaveStatus.relieverDeclined;
    }
    if (selectedFilter == 2) return r.status == LeaveStatus.approved;
    if (selectedFilter == 3) return r.status == LeaveStatus.rejected;
    return true;
  }).toList();
}

}
