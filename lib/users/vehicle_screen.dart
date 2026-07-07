import 'package:flutter/material.dart';
import '../Vehicle/vehicle_new_request_screen.dart';
import '../Vehicle/my_trip_screen.dart';
import '../Vehicle/vehicle_request_screen.dart';
import '../Services/vehicle_api_service.dart';
import '../Vehicle/office_vehicle_summary_screen.dart';
class VehicleScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final int initialTab;

  const VehicleScreen({super.key, this.initialTab = 0, required this.user});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  late int selectedTab;
  int _tripsRefreshKey = 0;
  int myTripsPendingCount = 0;
  int managerPendingCount = 0;

  bool hideMyTripsBadge = false;
  bool hideManagerBadge = false;     

bool get isManager {
  final id = widget.user["jobTitleId"]?.toString() ?? "";
  return id == "3";
}

Future<void> _loadTabBadges() async {
  try {
    final employeeId = widget.user["employeeId"]?.toString()
        ?? widget.user["employee_id"]?.toString()
        ?? "";
    if (employeeId.isEmpty) return;

    // 1) My Trips pending
    final myRes = await VehicleApiService.getMyTrips(employeeId: employeeId);
    final myList = List<Map<String, dynamic>>.from(myRes["data"] ?? []);

    final myPending = myList.where((e) {
      final status = (e["status"] ?? "").toString().toUpperCase().trim();
      // If you ONLY want office pending, uncomment next 2 lines:
      final type = (e["reason"] ?? e["type"] ?? "").toString().toUpperCase().trim();
      return type == "OFFICE" && status == "APPROVED";
      // If you want ALL pending (shuttle/transfer too), use:
      // return status == "PENDING";
    }).length;

    // 2) Manager approvals pending
    int mgrPending = 0;
    if (isManager) {
      final mgrList = await VehicleApiService.fetchManagerVehicleRequests(managerId: employeeId);
      mgrPending = mgrList.where((e) {
        final status = (e["status"] ?? "").toString().toUpperCase().trim();
        final type = (e["reason"] ?? e["type"] ?? "").toString().toUpperCase().trim();
        return type == "OFFICE" && status == "PENDING";
      }).length;
    }

    if (!mounted) return;
    setState(() {
      myTripsPendingCount = myPending;
      managerPendingCount = mgrPending;
      hideMyTripsBadge = false;
      hideManagerBadge = false;
    });
  } catch (_) {
    if (!mounted) return;
    setState(() {
      myTripsPendingCount = 0;
      managerPendingCount = 0;
    });
  }
}

  void _onRequestSubmitted() {
    setState(() {
      selectedTab = 1;
      _tripsRefreshKey++;
    });
    _loadTabBadges();
  }

@override
void initState() {
  super.initState();
  selectedTab = widget.initialTab;

  // load badges immediately when screen opens
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadTabBadges();
  });
}

  String getAppBarTitle() {
    switch (selectedTab) {
      case 0:
        return "New Request";
      case 1:
        return "My Trips";
      case 2:
        return "Requests";
      case 3:
        return "Summary";
      default:
        return "Vehicle";
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue[800]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
         title: Text(
        getAppBarTitle(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
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
                  width: 100,
                  child: _tabButton(
                    label: "My Trips",
                    icon: Icons.directions_car_outlined,
                    isActive: selectedTab == 1,
                    onTap: () {
                      setState(() {
                        selectedTab = 1;
                        hideMyTripsBadge = true;
                      });
                    },
                    activeColor: blue,
                    badgeCount: hideMyTripsBadge ? 0 : myTripsPendingCount,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: _tabButton(
                    label: "Requests",
                    icon: Icons.assignment_outlined,
                    isActive: selectedTab == 2,
                    onTap: () {
                      setState(() {
                        selectedTab = 2;
                        hideManagerBadge = true;
                      });
                    },
                    activeColor: blue,
                    badgeCount: hideManagerBadge ? 0 : managerPendingCount,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
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

          Expanded(
            child: IndexedStack(
              index: selectedTab,
              children: [
                VehicleRequestFormScreen(user: widget.user, onRequestSubmitted: _onRequestSubmitted),
                MyTripsScreen(key: ValueKey(_tripsRefreshKey), user: widget.user),
                VehicleRequestScreen(
                  managerId: widget.user["employeeId"]?.toString() ??
                      widget.user["employee_id"]?.toString() ??
                      "",
                ),
                OfficeVehicleSummaryScreen(
                  managerId: int.tryParse(
                        widget.user["employeeId"]?.toString() ??
                        widget.user["employee_id"]?.toString() ?? "0",
                      ) ?? 0,
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
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                Icon(icon, size: 18, color: isActive ? Colors.white : Colors.black87),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Badge top-right
          if (badgeCount > 0)
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
                  "$badgeCount",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}