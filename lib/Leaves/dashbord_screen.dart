import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'leave_form.dart';
import '../users/user_screen.dart';
import 'leave_request_screen.dart';
import 'package:test_app/Services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_app/login_screen.dart';
import '../ui/dialogs/logout_dialog.dart';
import '../Vehicle/personal_request_screen.dart';
import '../Services/vehicle_api_service.dart';
class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}
 
class _DashboardScreenState extends State<DashboardScreen> {

// Helper getter to check if user is HOD (for showing manager approvals)
bool get isManagers {
  final id = widget.user["jobTitleId"]?.toString() ?? "";
  return ["11", "14", "15", "16", "17", "18", "19", "20", "48"].contains(id);
}

/// General Manager — personal vehicle queue uses [get_general_manager_personal_vehicle_request.php].
bool get isGeneralManager {
  final id = widget.user["jobTitleId"] ?? widget.user["job_title_id"];
  return id?.toString() == "15";
}

  int relieverBadgeCount = 0;
  int managerBadgeCount = 0;
  int personalVehicleBadgeCount = 0;
  int approvedPersonalTripCount = 0;

  Map<String, dynamic>? leaveBalance;
  bool loadingLeave = true;
  String? leaveError;

  // Recent leave requests from API (same source as leave_history_screen)
  List<Map<String, dynamic>> recentLeaves = [];
  bool loadingRecentLeaves = true;
  String? recentLeavesError;

  String? profilePhotoUrl;
  bool photoLoading = false;

  Future<void> _loadProfilePhoto() async {
    if (!mounted) return;
    setState(() => photoLoading = true);

    String? url;
    try {
      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isNotEmpty) {
        final photo = await ApiService.getProfilePhoto(
            employeeId: int.parse(employeeId));
        url = (photo?["fileUrl"] as String?)?.trim();
      }
    } catch (_) {
      url = null;
    }

    // Single setState at the end — avoids the double rebuild that caused the flicker
    if (!mounted) return;
    setState(() {
      profilePhotoUrl = url;
      photoLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLeaveBalance();
    _loadRecentLeaves();

    _loadRelieverRequestCount();
    _loadManagerRequestCount();
    _loadPersonalVehicleRequestCount();
    _loadApprovedPersonalTripCount();
    _loadProfilePhoto();

  }

    static const int _recentLeavesLimit = 10;

Future<void> _loadRelieverRequestCount() async {
  try {
    final employeeId = widget.user["employeeId"]?.toString() ?? "";
    if (employeeId.isEmpty) return;

    final res = await ApiService.getRelieverRequests(employeeId: employeeId);
    print("RELIEVER API RES = $res");

    if (res["success"] == true) {
      final List list = (res["requests"] ?? []) as List;

      // count only "Awaiting Your Response"
      final pendingCount = list.where((e) {
        final status = (e["status"] ?? "").toString().toUpperCase();
        return status.contains("AWAITING YOUR RESPONSE");
      }).length;

      setState(() => relieverBadgeCount = pendingCount);
    } else {
      setState(() => relieverBadgeCount = 0);
    }
  } catch (e) {
    setState(() => relieverBadgeCount = 0);
  }
}

Future<void> _loadManagerRequestCount() async {
  try {
    if (!isManagers) {
      setState(() => managerBadgeCount = 0);
      return;
    }

    final managerId = widget.user["employeeId"]?.toString() ?? "";
    if (managerId.isEmpty) return;

    final list = await ApiService.fetchManagerLeaveRequests(managerId: managerId);

    final pendingCount = list.where((e) {
      final status = (e["status"] ?? "").toString().toUpperCase();
      final isSpecial = (e["is_special_request"]?.toString() ?? "0") == "1";

      final isRelieverAccepted = status == "RELIEVER ACCEPTED";

      // Special request waiting manager action
      final isSpecialPending = isSpecial && status == "PENDING";

      return isRelieverAccepted || isSpecialPending;
    }).length;

        setState(() => managerBadgeCount = pendingCount);
      } catch (e) {
        setState(() => managerBadgeCount = 0);
      }
    }

Future<void> _loadPersonalVehicleRequestCount() async {
  try {
    if (!isManagers) {
      setState(() => personalVehicleBadgeCount = 0);
      return;
    }

    final managerId = widget.user["employeeId"]?.toString() ?? "";
    if (managerId.isEmpty) return;

    final list = isGeneralManager
        ? await VehicleApiService.fetchGeneralManagerPersonalRequests()
        : await VehicleApiService.fetchManagerPersonalRequests(managerId: managerId);
    setState(() => personalVehicleBadgeCount = list.length);
  } catch (e) {
    setState(() => personalVehicleBadgeCount = 0);
  }
}

Future<void> _loadApprovedPersonalTripCount() async {
  try {
    final employeeId = widget.user["employeeId"]?.toString() ?? "";
    if (employeeId.isEmpty) return;

    final list = await VehicleApiService.fetchPersonalTrips(
      employeeId: employeeId,
      status: "APPROVED",
    );

    if (!mounted) return;
    setState(() => approvedPersonalTripCount = list.length);
  } catch (e) {
    if (!mounted) return;
    setState(() => approvedPersonalTripCount = 0);
  }
}

    void _openLogoutDialog(BuildContext context) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => LogoutDialog(
          onLogout: () async {
            // TODO: clear saved session if you use SharedPreferences
            // final prefs = await SharedPreferences.getInstance();
            // await prefs.clear();

            // OR if you don't use routes:
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (r) => false,
            );
          },
        ),
      );
    }

    Widget badgeWrapper({
      required Widget child,
      required int count,
    }) {
      if (count <= 0) return child;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    }

  Future<void> _loadRecentLeaves() async {
    try {
      setState(() {
        loadingRecentLeaves = true;
        recentLeavesError = null;
      });

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) {
        setState(() {
          loadingRecentLeaves = false;
          recentLeavesError = "employeeId not found";
        });
        return;
      }

      final res = await ApiService.getRecentLeaveHistory(employeeId: employeeId);

      if (res["success"] == true) {
        final list = List<Map<String, dynamic>>.from(res["data"] ?? []);

        // sort newest -> oldest
        list.sort((a, b) {
          DateTime parseDate(dynamic v) {
            final s = (v ?? "").toString();
            return DateTime.tryParse(s) ?? DateTime(1970);
          }

          final aDate = parseDate(a["requested_at"] ?? a["leave_start_date"]);
          final bDate = parseDate(b["requested_at"] ?? b["leave_start_date"]);
          return bDate.compareTo(aDate); // newest first
        });

        final mapped = list.take(_recentLeavesLimit).map((x) {
          final statusStr = (x["status"] ?? "PENDING").toString().toUpperCase();

          String status;
          Color color;

          if (statusStr == "APPROVED") {
            status = "Approved";
            color = Colors.green;
          } else if (statusStr == "REJECTED") {
            status = "Rejected";
            color = Colors.red;
          } else if (statusStr == "RELIEVER ACCEPTED") {
            status = "Reliever Accepted";
            color = Colors.blue;
          } else if (statusStr == "RELIEVER DECLINED") {
            status = "Reliever Declined";
            color = Colors.deepOrange;
          } else {
            status = "Pending";
            color = Colors.orange;
          }

          final numDays = x["number_of_days"]?.toString() ?? "0";
          final days = numDays == "1" ? "1 day" : "$numDays days";

          return {
            "type": (x["leave_type"] ?? "-").toString(),
            "date": (x["leave_start_date"] ?? x["requested_at"] ?? "-").toString(),
            "days": days,
            "status": status,
            "color": color,
          };
        }).toList();


        setState(() {
          recentLeaves = mapped;
          loadingRecentLeaves = false;
        });
      } else {
        setState(() {
          loadingRecentLeaves = false;
          recentLeavesError = res["message"]?.toString() ?? "Failed to load recent requests";
        });
      }
    } catch (e) {
      setState(() {
        loadingRecentLeaves = false;
        recentLeavesError = e.toString();
      });
    }
  }

  /// Reloads both leave balance and recent leaves. Call this for pull-to-refresh or refresh button.
  Future<void> _reloadPage() async {
    await Future.wait([
      _loadLeaveBalance(),
      _loadRecentLeaves(),
      _loadRelieverRequestCount(),
      _loadManagerRequestCount(),
      _loadPersonalVehicleRequestCount(),
      _loadApprovedPersonalTripCount(),
    ]);
  }

  Future<void> _loadLeaveBalance() async {
    try {
      setState(() {
        loadingLeave = true;
        leaveError = null;
      });

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) {
        setState(() {
          loadingLeave = false;
          leaveError = "employeeId not found in login user data";
        });
        return;
      }

      // Call API (you must implement ApiService.getLeaveBalance)
      final res = await ApiService.getLeaveBalance(employeeId: employeeId);

      if (res["success"] == true) {
        setState(() {
          leaveBalance = Map<String, dynamic>.from(res["data"] ?? {});
          loadingLeave = false;
        });
      } else {
        setState(() {
          loadingLeave = false;
          leaveError = res["message"]?.toString() ?? "Failed to load leave balance";
        });
      }
    } catch (e) {
      setState(() {
        loadingLeave = false;
        leaveError = e.toString().replaceFirst('Exception: ', ''); // ✅ only this line changes
      });
    }
  }

  

  @override
  Widget build(BuildContext context) {
    final fullName = widget.user["name"] ?? "";
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : "";
    //final lastName  = parts.length > 1 ? parts.last : "";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _reloadPage,
          color: Colors.blue,
          backgroundColor: Colors.white,
          strokeWidth: 2,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER (blue + blur + floating card) ALSO SCROLLS
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 300,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Color.fromARGB(255, 51, 144, 219),
                          Color.fromARGB(255, 11, 63, 139),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 16,
                      16,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER ICONS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                badgeWrapper(
                                  count: relieverBadgeCount + managerBadgeCount + personalVehicleBadgeCount + approvedPersonalTripCount,
                                  child: const Icon(Icons.notifications, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => _reloadPage(),
                                  child: const Icon(Icons.refresh, color: Colors.white),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                ),
                                const SizedBox(width: 10),

                                PopupMenuButton<String>(
                                  color: Colors.white,
                                  elevation: 8,
                                  offset: const Offset(0, 45),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (value) async {
                                    if (value == "profile") {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserScreen(user: widget.user),
                                        ),
                                      );
                                    } else if (value == "logout") {
                                      _openLogoutDialog(context);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: "profile",
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_outline, color: Colors.blue),
                                          SizedBox(width: 10),
                                          Text("View Profile",style: TextStyle(color: Colors.black),),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: "logout",
                                      child: Row(
                                        children: [
                                          Icon(Icons.logout, color: Colors.red),
                                          SizedBox(width: 10),
                                          Text("Logout",style: TextStyle(color: Colors.black),),
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: ClipOval(
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty)
                                          ? Image.network(
                                              profilePhotoUrl!,
                                              fit: BoxFit.cover,
                                              gaplessPlayback: true,
                                              loadingBuilder: (context, child, progress) {
                                                if (progress == null) return child;
                                                return Container(
                                                  color: Colors.white,
                                                  alignment: Alignment.center,
                                                  child: const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(
                                                      backgroundColor: Colors.white,
                                                      color: Colors.blue,
                                                      strokeWidth: 2),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (_, __, ___) => Container(
                                                color: Colors.white,
                                                child: const Icon(Icons.person, size: 16, color: Colors.blue),
                                              ),
                                            )
                                          : (photoLoading
                                              ? Container(
                                                  color: Colors.white,
                                                  alignment: Alignment.center,
                                                  child: const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(
                                                      color: Colors.blue,
                                                      backgroundColor: Colors.white,
                                                      strokeWidth: 2
                                                      ),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.white,
                                                  child: const Icon(Icons.person, size: 16, color: Colors.blue),
                                                )),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Welcome Back, $firstName !',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Apply your leaves...',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Floating card from API
                        _leaveBalanceSection(),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),

              // REST CONTENT
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Action',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, 
                        color: Colors.black
                      ),
                    ),
                    _quickActions(context),

                    const SizedBox(height: 20),

                    Text(
                      'Recent Requests',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.black
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (loadingRecentLeaves)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(
                          color: Colors.blue,
                          strokeWidth: 3,
                        )),
                      )
                    else if (recentLeavesError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Text(
                              recentLeavesError!,
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadRecentLeaves,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else if (recentLeaves.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No recent requests',
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...recentLeaves.map(
                        (leave) => _leaveStatus(
                          leave['type'] as String,
                          leave['date'] as String,
                          leave['days'] as String,
                          leave['status'] as String,
                          leave['color'] as Color,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // Handles loading/error/success for the balance card
  Widget _leaveBalanceSection() {
  
    if (loadingLeave) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (leaveError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Leave balance error: $leaveError",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadLeaveBalance,
            child: const Text("Retry"),
          ),
        ],
      );
    }

    // When user has no leave balance data, show 0/0 for each type
    final data = leaveBalance ?? {};
    return _leaveBalanceCard(Map<String, dynamic>.from(data));
  }

  // Leave Balance Card
  Widget _leaveBalanceCard(Map<String, dynamic> balance) {

    // safe parse
    double d(dynamic v) => double.tryParse(v?.toString() ?? "0") ?? 0;

    final annualRemaining = d(balance["annual_days"]);
    final medicalRemaining = d(balance["medical_days"]);
    final casualRemaining = d(balance["casual_days"]);

    // Use API totals; when user has no leaves of any type, show 0/0
    final annualTotal = d(balance["annual_total"]);
    final medicalTotal = d(balance["medical_total"]);
    final casualTotal = d(balance["casual_total"]);

    final annualUsed = (annualTotal - annualRemaining).clamp(0.0, annualTotal).toDouble();
    final medicalUsed = (medicalTotal - medicalRemaining).clamp(0.0, medicalTotal).toDouble();
    final casualUsed = (casualTotal - casualRemaining).clamp(0.0, casualTotal).toDouble();

    return Card(
      //color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                 Image.asset('assets/arrow.png', width: 28, height: 28),
                //const Icon(Icons.trending_up_rounded, color: Color(0xFF2B7DE9), size: 20),
                const SizedBox(width: 4),
                Text(
                  'Leave Balance Overview',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _progressRow('Annual Leave', annualUsed, annualTotal),
            _progressRow('Medical Leave', medicalUsed, medicalTotal),
            _progressRow('Casual Leave', casualUsed, casualTotal),
          ],
        ),
      ),
    );
  }

    // Color by usage: green (low) → blue (middle) → red (near total)
    Color _progressColor(double value) {
      final v = value.clamp(0.0, 1.0);
      if (v <= 0.5) {
        return Color.lerp(Colors.green, Colors.blue, v / 0.5)!;
      }
      return Color.lerp(Colors.blue, Colors.red, (v - 0.5) / 0.5)!;
    }

    Widget _progressRow(String type, double used, double total) {
      final safeTotal = total == 0 ? 1.0 : total;
      final value = used / safeTotal;
      String fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(type, style: GoogleFonts.poppins()),
                Text('${fmt(used)}/${fmt(total)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 8,
              valueColor: AlwaysStoppedAnimation<Color>(_progressColor(value)),
              backgroundColor: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      );
    }

    // QUICK ACTIONS
    Widget _quickActions(BuildContext context) {
    final actions = <Widget>[
      _QuickAction(
        icon: Icons.add_circle,
        label: 'Apply Leave',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LeaveFormScreen(user: widget.user)),
          );
          if (!mounted) return;
          _loadRecentLeaves();
          _loadLeaveBalance();
        },
      ),
      _QuickAction(
        icon: Icons.history,
        label: 'Leave History',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserScreen(user: widget.user, initialTab: 1),
            ),
          );
        },
      ),
      _QuickAction(
        icon: Icons.person,
        label: 'Reliever Request',
        badgeCount: relieverBadgeCount,
        onTap: () async {
          // mark as seen
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('reliever_seen', true);

          // hide immediately
          setState(() => relieverBadgeCount = 0);

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserScreen(user: widget.user, initialTab: 2),
            ),
          );
        },
      ),
      // _QuickAction(
      //   icon: Icons.directions_car,
      //   label: 'Vehicle Request',
      //   badgeCount: approvedPersonalTripCount,
      //   onTap: () async {
      //     setState(() => approvedPersonalTripCount = 0);
      //     await Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (context) => VehicleScreen(user: widget.user),
      //       ),
      //     );
      //   },
      // ),
    ];

    // Only HOD sees Request button
    if (isManagers) {
      final managerId = widget.user["employeeId"]?.toString() ?? "";
      actions.add(
        _QuickAction(
          icon: Icons.cabin,
          label: 'Leave Request',
          badgeCount: managerBadgeCount,
          onTap: () async {          
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('manager_seen', true);
            //optional: hide immediately when opened
            setState(() => managerBadgeCount = 0);

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LeaveRequestScreen(managerId: managerId),
              ),
            );
          },
        ),
      );
      actions.add(
        _QuickAction(
          icon: Icons.assignment_turned_in,
          label: 'Vehicle Approval Queue',
          badgeCount: personalVehicleBadgeCount,
          onTap: () async {

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('manager_seen', true);

            setState(() => personalVehicleBadgeCount = 0);

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PersonalRequestScreen(
                  managerId: managerId,
                  user: widget.user,
                ),
              ),
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        const gap = 12.0;
        final itemW = (constraints.maxWidth - gap) / 2;
        const itemH = 88.0;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: actions
              .map((a) => SizedBox(width: itemW, height: itemH, child: a))
              .toList(),
        );
      },
    );
  }


void showBottomMessage(String text) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E63B5),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
    builder: (sheetContext) {
      Future.delayed(const Duration(seconds: 1), () {
        if (Navigator.of(sheetContext).canPop()) {
          Navigator.of(sheetContext).pop();
        }
      });

      return Container(
        width: double.infinity,
        height: 70,
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    },
  );
}

  // Recent request card — simple, user-friendly
  Widget _leaveStatus(String type, String date, String days, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E2A3A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$date  ·  $days',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7A90),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // full-size card
          SizedBox.expand(
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.blue, size: 28),
                  const SizedBox(height: 8),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 12)),
                ],
              ),
            ),
          ),

          // badge
          if (badgeCount > 0)
            Positioned(
              top: -2,
              right:-2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

