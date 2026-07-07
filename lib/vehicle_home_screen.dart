import 'package:flutter/material.dart';
import 'package:test_app/Services/vehicle_api_service.dart';
import '../Vehicle/assigned_shuttle_trip_screen.dart';
import '../Vehicle/assigned_transfer_trip_screen.dart';

class VehicleHomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const VehicleHomeScreen({super.key, required this.user});

  @override
  State<VehicleHomeScreen> createState() => _VehicleHomeScreenState();
}

class _VehicleHomeScreenState extends State<VehicleHomeScreen> {
  static const blue = Color(0xFF0060A6);

  int shuttleAssignedCount = 0;
  int transferAssignedCount = 0;
  bool firstLoad = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => firstLoad = true);
    await _loadAssignedCounts();
    if (mounted) setState(() => firstLoad = false);
  }

  Future<void> _loadAssignedCounts() async {
    try {
      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) return;

      final results = await Future.wait([
        VehicleApiService.fetchShuttleAssignedCount(employeeId: employeeId),
        VehicleApiService.fetchTransferAssignedCount(employeeId: employeeId),
      ]);

      if (!mounted) return;
      setState(() {
        shuttleAssignedCount = results[0];
        transferAssignedCount = results[1];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        shuttleAssignedCount = 0;
        transferAssignedCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Shuttle & Transfer Trip",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ),
      body: firstLoad
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
                backgroundColor: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAssignedCounts,
              color: Colors.blue,
              backgroundColor: Colors.white,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // subtitle
                  const Text(
                    "Select a service type to continue",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _tripCard(
                    image: 'assets/shuttle.png',
                    fallbackIcon: Icons.route_rounded,
                    title: "Shuttle",
                    description:
                        "Regular office shuttle routes.\nVehicle and driver are auto-assigned.",
                    chipLabel: "Auto assigned",
                    chipBg: const Color(0xFFEAF1FF),
                    chipFg: const Color(0xFF1E5BB8),
                    badgeCount: shuttleAssignedCount,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AssignedShuttleTripScreen(user: widget.user),
                        ),
                      );
                      if (mounted) _loadAssignedCounts();
                    },
                  ),

                  const SizedBox(height: 14),

                  _tripCard(
                    image: 'assets/transfer.png',
                    fallbackIcon: Icons.place_rounded,
                    title: "Transfer",
                    description:
                        "Point-to-point transport.\nVehicle and driver are auto-assigned.",
                    chipLabel: "Quick request",
                    chipBg: const Color(0xFFE8F8EE),
                    chipFg: const Color(0xFF1E7D47),
                    badgeCount: transferAssignedCount,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AssignedTransferTripScreen(user: widget.user),
                        ),
                      );
                      if (mounted) _loadAssignedCounts();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tripCard({
    required String image,
    required IconData fallbackIcon,
    required String title,
    required String description,
    required String chipLabel,
    required Color chipBg,
    required Color chipFg,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4EBF8)),
                boxShadow: [
                  BoxShadow(
                    color: blue.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon box
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Image.asset(
                        image,
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            Icon(fallbackIcon, size: 36, color: blue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text + chip
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: chipBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                chipLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: chipFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8A97AD),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF8A97AD), size: 20),
                ],
              ),
            ),
          ),
        ),

        // Badge
        if (badgeCount > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
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
    );
  }
}
