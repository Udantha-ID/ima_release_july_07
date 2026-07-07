import 'package:flutter/material.dart';
import '../StaffGatePass/gate_pass_request_form_screen.dart';
import '../StaffGatePass/gate_pass_request_screen.dart';
import '../StaffGatePass/manager_gate_pass_request_screen.dart';
import '../Services/staff_gate_pass_service.dart';
import '../StaffGatePass/gate_pass_summary_screen.dart';

class GatePassScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final int initialTab;

  // Default to tab 1 → "My Gate Passes" so users land there first
  const GatePassScreen({super.key, this.initialTab = 1, required this.user});

  @override
  State<GatePassScreen> createState() => _GatePassScreenState();
}

class _GatePassScreenState extends State<GatePassScreen> {
  late int selectedTab;
  int _myPassesRefreshKey  = 0;
  int _requestsRefreshKey  = 0;
  int _pendingCount        = 0;

  bool get isManager {
    final id = widget.user["jobTitleId"]?.toString() ?? "";
    return id == "3";
  }

  void _onRequestSubmitted() {
    setState(() {
      selectedTab = 1;
      _myPassesRefreshKey++;
    });
  }

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab;
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    if (!isManager) return;
    try {
      final empId = int.tryParse(
              (widget.user['employee_id'] ?? widget.user['employeeId'] ?? '')
                  .toString()) ??
          0;
      if (empId <= 0) return;
      final res = await StaffGatePassService.getManagerGatePassRequests(
          managerId: empId, status: 'PENDING');
      if (res['success'] == true && mounted) {
        setState(() => _pendingCount = List.from(res['requests'] ?? []).length);
      }
    } catch (_) {}
  }

  String _appBarTitle() {
    switch (selectedTab) {
      case 0:  return "New Gate Pass Request";
      case 1:  return "My Gate Passes";
      case 2:  return "Requests";
      default: return "Gate Pass";
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue[800]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          _appBarTitle(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Tab bar ──────────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: _tabButton(
                    label: "New\nRequest",
                    icon: Icons.add_circle_outline,
                    isActive: selectedTab == 0,
                    onTap: () => setState(() => selectedTab = 0),
                    activeColor: blue,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: _tabButton(
                    label: "My Gate\nPasses",
                    icon: Icons.badge_outlined,
                    isActive: selectedTab == 1,
                    onTap: () => setState(() => selectedTab = 1),
                    activeColor: blue,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: _tabButton(
                    label: "Requests",
                    icon: Icons.assignment_outlined,
                    isActive: selectedTab == 2,
                    onTap: () {
                      setState(() {
                        selectedTab = 2;
                        _requestsRefreshKey++;
                      });
                      _loadPendingCount();
                    },
                    activeColor: blue,
                    badgeCount: _pendingCount,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: _tabButton(
                    label: "Summary",
                    icon: Icons.bar_chart_outlined,
                    isActive: selectedTab == 3,
                    onTap: () => setState(() => selectedTab = 3),
                    activeColor: blue,
                  ),
                ),
              ],
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: selectedTab,
              children: [
                // Tab 0 — New Gate Pass Request form
                GatePassRequestFormScreen(
                  user: widget.user,
                  onRequestSubmitted: _onRequestSubmitted,
                ),
 
                // Tab 1 — My Gate Passes list
                GatePassRequestScreen(
                  user: widget.user,
                  key: ValueKey(_myPassesRefreshKey),
                ),
 
                // Tab 2 — Manager gate pass approvals
                ManagerGatePassScreen(
                  user: widget.user,
                  key: ValueKey(_requestsRefreshKey),
                ),
 
                // Tab 3 — Summary (manager approved gate passes)
                GatePassSummaryScreen(
                  user: widget.user,
                  key: const ValueKey('summary'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isActive ? activeColor : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? activeColor : const Color(0xFFE1E6EF),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17,
                    color: isActive ? Colors.white : Colors.black87),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
