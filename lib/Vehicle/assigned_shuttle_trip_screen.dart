import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../ui/dialogs/start_trip_dialog.dart';
import '../ui/dialogs/stop_trip_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../ui/dialogs/generate_trip_code_dialog.dart';
import '../Leaves/top_banner.dart';

class AssignedShuttleTripScreen extends StatefulWidget {
  final Map<String, dynamic> user; // must contain: employeeId, name, role
  const AssignedShuttleTripScreen({super.key, required this.user});

  @override
  State<AssignedShuttleTripScreen> createState() =>
      _AssignedShuttleTripScreenState();
}

class _AssignedShuttleTripScreenState extends State<AssignedShuttleTripScreen> {
  int selectedTab = 0; // 0 Assigned, 1 Start Trip, 2 In Progress, 3 Completed
  bool loading = false;

  List<Map<String, dynamic>> trips = [];

  String _statusFromTab(int tab) {
    switch (tab) {
      case 0:
        return "ASSIGNED";
      case 1:
        return "START_TRIP";
      case 2:
        return "IN_PROGRESS";
      default:
        return "COMPLETED";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTripsByTab();
  }

  Future<void> _loadTripsByTab() async {
    try {
      setState(() => loading = true);

      // SAME AS YOUR RELIEVER SCREEN
      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) {
        if (mounted) {
          TopBanner.show(
            context,
            title: "Session Error",
            message: "Employee ID not found. Please log in again.",
            icon: Icons.error_outline,
            isSuccess: false,
          );
        }
        return;
      }

      final status = _statusFromTab(selectedTab);

      // API returns: List<Map> (from transport_services table)
      final rows = await VehicleApiService.fetchShuttleTrips(
        employeeId: employeeId, // String is OK (will be in URL)
        status: status,
      );

      // Map DB rows -> UI shape used in TripCard
      List<Map<String, dynamic>> mapped = [];
      
      for (final e in rows) {
        String _getDate(String v) => v.length >= 10 ? v.substring(0, 10) : "-";

        String _getTime(String v) => v.length >= 16 ? v.substring(11, 16) : "-";

        // START
        final startAt = (e["assigned_start_at"] ?? "").toString();
        final assignedStartDate = _getDate(startAt);
        final startTime = _getTime(startAt);

        // STOP
        final stopAt = (e["trip_start_datetime"] ?? "").toString();
        final startDate = _getDate(stopAt);

        // END
        final endAt = (e["trip_end_datetime"] ?? "").toString();
        final endDate = _getDate(endAt);

        final tripId = (e["id"] ?? "").toString();

        String vehicleMake = "-";
        String vehicleModel = "-";
        String vehicleName = (e["vehicle_name"] ?? "").toString();

        try {
          final vehicleDetails = await VehicleApiService.fetchVehicleDetails(
            transportServiceId: tripId,
          );

          vehicleMake = (vehicleDetails["make"] ?? "-").toString();
          vehicleModel = (vehicleDetails["model"] ?? "-").toString();

          if (vehicleMake != "-" || vehicleModel != "-") {
            vehicleName = "$vehicleMake $vehicleModel".trim();
          }
        } catch (_) {
          // optional: keep silent and fallback
        }

        mapped.add(<String, dynamic>{
          "id": e["id"].toString(),
          "status": (e["status"] ?? "").toString(),

          "vehicleNo": (e["vehicle_no"] ?? "-").toString(),
          "vehicleName": vehicleName, // optional

          "pickup": (e["pickup_location"] ?? "-").toString(),
          "dropoff": (e["dropoff_location"] ?? "-").toString(),

          "passengers": "${e["passenger_count"] ?? "-"} pax",
          "time": startTime,
          "assignedDate": assignedStartDate,

          "startDate": startDate,
          "endDate": endDate,

          "tripCode": e["trip_code"],

          // optional fields if you add later:
          "startMeter": (e["trip_start_odometer"] ?? "-").toString(),
          "endMeter": (e["trip_end_odometer"] ?? "-").toString(),
          "odoDistance": (e["distance_km"] ?? "-").toString(),
          "gpsDistance": e["gps_distance"],
        });
      }

      if (!mounted) return;
      setState(() => trips = mapped);
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(
        context,
        title: "Failed to Load Trips",
        message: e.toString().replaceFirst("Exception: ", ""),
        icon: Icons.error_outline,
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _refreshTrips() async {
    await _loadTripsByTab();
  }

    // When Start Trip is confirmed in dialog, call this to hit API and move to In Progress
    Future<void> _startTripAndMoveToInProgress({
      required Map<String, dynamic> trip,
      required String meterReading,
      required String fuelPercent,
      required File meterPhoto,
      String? remark,
    }) async {
      final tripId = int.tryParse(trip["id"].toString()) ?? 0;
      if (tripId <= 0) return;

      try {
        setState(() => loading = true);

        final res = await VehicleApiService.startTrip(
          transportServiceId: tripId,
          odometer: int.parse(meterReading),
          fuelPercent: double.parse(fuelPercent),
          photoFile: meterPhoto,
          remark: remark,
        );

        if (res["success"] == true) {
          if (!mounted) return;

          // move to tab 2 (IN_PROGRESS)
          setState(() => selectedTab = 2);

          // reload list based on tab
          await _loadTripsByTab();

          if (!mounted) return;

          TopBanner.show(
            context,
            title: "Trip Started",
            message: "Trip started successfully and moved to In Progress.",
            icon: Icons.check_circle,
            isSuccess: true,
          );
        } else {
          throw Exception(res["message"] ?? "Start trip failed");
        }
      } catch (e) {
        if (!mounted) return;
        TopBanner.show(
          context,
          title: "Start Trip Failed",
          message: e.toString(),
          icon: Icons.error_outline,
          isSuccess: false,
        );
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }

    // When Stop Trip is confirmed in dialog, call this to hit API and move to Completed
    Future<void> _stopTripAndMoveToCompleted({
      required Map<String, dynamic> trip,
      required String meterReading,
      required String fuelPercent,
      required File meterPhoto,
      String? remark,
    }) async {
      final tripId = int.tryParse(trip["id"].toString()) ?? 0;
      if (tripId <= 0) return;

      try {
        setState(() => loading = true);

        final res = await VehicleApiService.stopTrip(
          transportServiceId: tripId,
          endOdometer: int.parse(meterReading),
          endFuelPercent: double.parse(fuelPercent),
          photoFile: meterPhoto,
          remark: remark,
        );

        if (res["success"] == true) {
          if (!mounted) return;

          // move to tab 2 (IN_PROGRESS)
          setState(() => selectedTab = 3);

          // reload list based on tab
          await _loadTripsByTab();

          if (!mounted) return;

          TopBanner.show(
            context,
            title: "Trip Completed",
            message: "Trip completed successfully.",
            icon: Icons.check_circle,
            isSuccess: true,
          );
        } else {
          throw Exception(res["message"] ?? "Stop trip failed");
        }
      } catch (e) {
        if (!mounted) return;
        TopBanner.show(
          context,
          title: "Stop Trip Failed",
          message: e.toString(),
          icon: Icons.error_outline,
          isSuccess: false,
        );
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }

    // Generates a random trip code like #INDU1234 based on employee name and random number
    String _generateTripCode(String employeeName) {
      final rnd = Random();
      // 1. Clean name (remove spaces, uppercase)
      String cleanName = employeeName
          .replaceAll(RegExp(r'\s+'), '')
          .toUpperCase();
      // 2. Ensure at least 4 characters
      if (cleanName.length < 4) {
        cleanName = cleanName.padRight(4, 'X');
      }
      // 3. Take first 4 letters
      final namePart = cleanName.substring(0, 4);
      // 4. Generate random 4-digit number
      final numberPart = (1000 + rnd.nextInt(9000)).toString();
      // 5. Combine
      return "#$namePart$numberPart";
    }

    // Confirmation dialog before generating trip code and moving to Start Trip
    Future<void> _confirmGenerateAndUpdate(Map<String, dynamic> trip) async {
      final tripId = int.tryParse(trip["id"].toString()) ?? 0;
      if (tripId <= 0) return;

      final code = _generateTripCode(widget.user["name"]?.toString() ?? "USER");

      try {
        setState(() => loading = true);

        final res = await VehicleApiService.generateTripCode(
          tripId: tripId,
          tripCode: code,
        );

        if (res["success"] == true) {
          setState(() => selectedTab = 1);
          await _loadTripsByTab();

          if (!mounted) return;

          TopBanner.show(
            context,
            title: "Trip Code Generated",
            message: "Your trip code has been generated successfully: $code.",
            icon: Icons.check_circle,
            isSuccess: true,
          );
        } else {
          if (!mounted) return;
          TopBanner.show(
            context,
            title: "Generate Failed",
            message: (res["message"] ?? "Generate failed").toString(),
            icon: Icons.error_outline,
            isSuccess: false,
          );
        }
      } catch (e) {
        if (!mounted) return;
        TopBanner.show(
          context,
          title: "Generate Failed",
          message: e.toString(),
          icon: Icons.error_outline,
          isSuccess: false,
        );
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }

    // Show dialog to confirm before generating trip code and moving to Start Trip
    void _showGenerateTripDialog(Map<String, dynamic> trip) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => GenerateTripCodeDialog(
          onGenerate: () => _confirmGenerateAndUpdate(trip),
        ),
      );
    }

  @override
  Widget build(BuildContext context) {
    final list = trips;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
        title: const Text(
          "Assigned Shuttle Trip",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.blue,
          backgroundColor: Colors.white,
          onRefresh: _refreshTrips,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            itemCount: list.length + 3, // header + tabs + state row
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Header(user: widget.user),
                );
              }

              if (index == 1) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SegmentTabs(
                    selectedIndex: selectedTab,
                    onChanged: (i) async {
                      setState(() => selectedTab = i);
                      await _loadTripsByTab();
                    },
                  ),
                );
              }

              // loading / empty state line
              if (index == 2) {
                if (loading) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator(
                                color: Colors.blue,
                                backgroundColor: Colors.white,
                                strokeWidth: 4,
                    )),
                  );
                }
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text("No trips found", style: TextStyle(color: Colors.grey))),
                  );
                }
                return const SizedBox.shrink();
              }

              final t = list[index - 3];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TripCard(
                  data: t,
                  onGenerateTripCode: () => _showGenerateTripDialog(t),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ------------------ Header ------------------
class _Header extends StatelessWidget {
  final Map<String, dynamic> user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user["name"] ?? "_").toString();
    final jobTitle = (user["jobTitle"] ?? "_").toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Assigned Shuttle Trip",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E2A3A)),
          ),
          const SizedBox(height: 4),
          Text(
            "$name - $jobTitle",
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

/// ------------------ Tabs ------------------
class _SegmentTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const _SegmentTabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip("Assigned", 0),
          const SizedBox(width: 8),
          _chip("Start Trip", 1),
          const SizedBox(width: 8),
          _chip("In Progress", 2),
          const SizedBox(width: 8),
          _chip("Completed", 3),
        ],
      ),
    );
  }

  Widget _chip(String text, int index) {
    final active = selectedIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0B5FA5) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE6ECF5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(active ? 0.12 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: active ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

/// ------------------ Trip Card (SAME UI STYLE) ------------------
class TripCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onGenerateTripCode;

  const TripCard({
    super.key,
    required this.data,
    required this.onGenerateTripCode,
  });

  Widget _gradientButton({
    required String text,
    required VoidCallback onTap,
    List<Color> colors = const [Color(0xFF1DB954), Color(0xFF0B7A34)],
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12.8,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = (data["status"] ?? "").toString();
    final isAssigned = status == "ASSIGNED";
    final isStartTrip = status == "START_TRIP";
    final isInProgress = status == "IN_PROGRESS";
    final isCompleted = status == "COMPLETED";

    final vehicleName = (data["vehicleName"] ?? "-").toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // header (same style)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Shuttle Trip",
                        style:
                            TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E2A3A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vehicleName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _statusPill(status),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                // ================= NON-COMPLETED =================
                if (!isCompleted) ...[
                  // Shuttle code only for Start / In Progress
                  if (isStartTrip || isInProgress) ...[
                    _infoRow(
                      "Shuttle Code",
                      (data["tripCode"] ?? "-").toString(),
                      highlight: true,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _infoRow("Vehicle No", (data["vehicleNo"] ?? "-").toString()), 
                  const SizedBox(height: 8),
                  _infoRow("Pick up", (data["pickup"] ?? "-").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Drop-off", (data["dropoff"] ?? "-").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Passengers", (data["passengers"] ?? "-").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Assigned Time", (data["time"] ?? "-").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Assigned Date", (data["assignedDate"] ?? "-").toString()),
                ],

                // ================= COMPLETED =================
                if (isCompleted) ...[
                  _infoRow("Vehicle No", (data["vehicleNo"] ?? "-").toString()), 
                  const SizedBox(height: 8),
                  _infoRow("Pick up", (data["pickup"] ?? "-").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Drop-off", (data["dropoff"] ?? "-").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Start Date", (data["startDate"] ?? "-").toString()),
                  const SizedBox(height: 8),
                  _infoRow("End Date", (data["endDate"] ?? "-").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Start Meter", "${data["startMeter"]} km"),
                  const SizedBox(height: 8),
                  _infoRow("End Meter", "${data["endMeter"]} km"),
                  const SizedBox(height: 8),
                  _infoRow(
                    "Distance KM",
                    "${data["odoDistance"] ?? "-"} km",
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    "GPS Distance",
                    "${data["gpsDistance"] ?? "-"} km",
                  ),
                ],

                // ================= BUTTONS =================
                if (isAssigned) ...[
                  const SizedBox(height: 12),
                  _gradientButton(
                    text: "Generate Trip Code",
                    colors: const [Color(0xFF0B5FA5), Color(0xFF084C8A)],
                    onTap: onGenerateTripCode,
                  ),
                ],

                if (isStartTrip) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) => _gradientButton(
                      text: "Start Trip (Enter Meter Reading)",
                      colors: const [Color(0xFF1DB954), Color(0xFF0B7A34)],
                      onTap: () {
                        showStartTripDialog(
                          context: context,
                          vehicleNo: data["vehicleNo"] ?? "-",
                          destination: data["dropoff"] ?? "-",
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                            remark,
                          }) async {
                            // Call the parent state method
                            final state = context.findAncestorStateOfType<_AssignedShuttleTripScreenState>();
                            await state?._startTripAndMoveToInProgress(
                              trip: data,
                              meterReading: meterReading,
                              fuelPercent: fuelPercent,
                              meterPhoto: meterPhoto,
                              remark: remark,
                            );
                          },
                          isSubmitting: false,
                        );
                      },
                    ),
                  ),
                ],

                if (isInProgress) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) => _gradientButton(
                      text: "Stop Trip & Submit (Enter Meter Reading)",
                      colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                      onTap: () {
                        showStopTripDialog(
                          context: context,
                          vehicleNo: data["vehicleNo"] ?? "-",
                          destination: data["dropoff"] ?? "-",
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                            remark,
                          }) async {
                            // Call the parent state method
                            final state = context.findAncestorStateOfType<_AssignedShuttleTripScreenState>();
                            await state?._stopTripAndMoveToCompleted(
                              trip: data,
                              meterReading: meterReading,
                              fuelPercent: fuelPercent,
                              meterPhoto: meterPhoto,
                              remark: remark,
                            );
                          },
                          isSubmitting: false,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Same row UI
Widget _infoRow(String label, String value, {bool highlight = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: highlight ? const Color(0xFFD8E7F4) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFD7E3F3)),
    ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: const TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Same pill UI
  Widget _statusPill(String status) {
    final label = status == "ASSIGNED"
        ? "Assigned"
        : status == "START_TRIP"
            ? "Start Trip"
            : status == "IN_PROGRESS"
                ? "In Progress"
                : "Completed";

    Color bg;
    Color border;
    Color text;

    if (status == "ASSIGNED") {
      bg = const Color(0xFFE5E5E5);
      border = const Color(0xFFD3D3D3);
      text = const Color(0xFF7A7A7A);
    } else if (status == "START_TRIP") {
      bg = const Color(0xFFEAF2FF);
      border = const Color(0xFFBFD5FF);
      text = const Color(0xFF0B5FA5);
    } else if (status == "IN_PROGRESS") {
      bg = const Color(0xFFE6E6E6);
      border = const Color(0xFFD0D0D0);
      text = const Color(0xFF7A7A7A);
    } else {
      bg = const Color(0xFFCDEED3);
      border = const Color(0xFF9AD7A6);
      text = const Color(0xFF2E7D32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: text,
        ),
      ),
    );
  }
}