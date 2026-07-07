import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../ui/dialogs/start_trip_dialog.dart';
import '../ui/dialogs/stop_trip_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Leaves/top_banner.dart';
import '../ui/dialogs/cancel_trip_dialog.dart';

class PersonalTripScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const PersonalTripScreen({super.key, required this.user});

  @override
  State<PersonalTripScreen> createState() => _PersonalTripScreenState();
}

class _PersonalTripScreenState extends State<PersonalTripScreen> {
  int selectedTab = 0; // 0 Pending, 1 Approved, 2 In Progress, 3 Completed, 4 Rejected
  bool loading = false;
  String? errorText;

  List<Map<String, dynamic>> trips = [];

  @override
  void initState() {
    super.initState();
    _refreshTrips();
  }

  String _statusFromTab(int tab) {
    switch (tab) {
      case 0:
        return "PENDING";
      case 1:
        return "APPROVED";
      case 2:
        return "IN_PROGRESS";
      case 3:
        return "COMPLETED";
      case 4:
        return "REJECTED";
      default:
        return "PENDING";
    }
  }

Future<void> _loadTripsByTab() async {
    try {
      setState(() { loading = true; errorText = null; });

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) {
        if (mounted) setState(() => errorText = "Employee ID not found. Please log in again.");
        return;
      }

      // Pending tab: PENDING + HOD_APPROVED (waiting for GM), merged & deduped
      final List<Map<String, dynamic>> rows;
      if (selectedTab == 0) {
        final pending = await VehicleApiService.fetchPersonalTrips(
          employeeId: employeeId,
          status: "PENDING",
        );
        final hodApproved = await VehicleApiService.fetchPersonalTrips(
          employeeId: employeeId,
          status: "HOD_APPROVED",
        );
        final hodRejected = await VehicleApiService.fetchPersonalTrips(
          employeeId: employeeId,
          status: "HOD_REJECTED",
        );
        final byId = <String, Map<String, dynamic>>{};
        for (final r in pending) {
          byId[r["id"]?.toString() ?? ""] = r;
        }
        for (final r in hodApproved) {
          byId[r["id"]?.toString() ?? ""] = r;
        }
        for (final r in hodRejected) {
          byId[r["id"]?.toString() ?? ""] = r;
        }
        byId.removeWhere((k, _) => k.isEmpty);
        rows = byId.values.toList()
          ..sort((a, b) {
            final ia = int.tryParse(a["id"]?.toString() ?? "0") ?? 0;
            final ib = int.tryParse(b["id"]?.toString() ?? "0") ?? 0;
            return ib.compareTo(ia);
          });
      } else {
        final status = _statusFromTab(selectedTab);
        rows = await VehicleApiService.fetchPersonalTrips(
          employeeId: employeeId,
          status: status,
        );
      }

      // Map DB rows -> UI shape used in TripCard
      final mapped = await Future.wait(rows.map((e) async {
        
        String _getDate(String v) => v.length >= 10 ? v.substring(0, 10) : "-";

        String _getTime(String v) => v.length >= 16 ? v.substring(11, 16) : "-";

        // START
        final startAt = (e["assigned_start_at"] ?? "").toString();
        final assignedStartDate = _getDate(startAt);
        final startTime = _getTime(startAt);

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

        
        return <String, dynamic>{
          ...Map<String, dynamic>.from(e),
          "id": e["id"].toString(),
          "status": (e["status"] ?? "").toString(),

          "vehicleNo": (e["vehicle_no"] ?? "-").toString(),
          "vehicleType": (e["vehicle_type"] ?? "").toString(),
          "isVehicleAssigned": (e["is_vehicle_assigned"]?.toString() ?? "0") == "1",
          "reason": (e["type"] ?? "-").toString(),
          "type": (e["type"] ?? "personal").toString(),

          "vehicleName": vehicleName,

          "pickup": (e["pickup_location"] ?? "-").toString(),
          "dropoff": (e["dropoff_location"] ?? "-").toString(),
          "destination": (e["dropoff_location"] ?? e["destination"] ?? "-").toString(),

          "hodComment": (e["hod_comment"] ?? e["hodComment"] ?? "").toString().trim(),
          "rejectReason": (e["reject_reason"] ?? e["rejectReason"] ?? "").toString().trim(),

          "passengers": "${e["passenger_count"] ?? "-"} pax",
          "time": startTime,
          "assignedDate": assignedStartDate,

          // Full datetimes kept for vehicle validation API
          "assignedStartAt": startAt,
          "assignedEndAt": (e["assigned_end_at"] ?? "").toString(),

          "fromDate": assignedStartDate,
          "toDate": _getDate((e["assigned_end_at"] ?? "").toString()),

          "tripCode": e["trip_code"],

          // optional fields if you add later:
          "startMeter": (e["trip_start_odometer"] ?? "-").toString(),
          "endMeter": (e["trip_end_odometer"] ?? "-").toString(),
          "odoDistance": (e["distance_km"] ?? "-").toString(),
          "gpsDistance": e["gps_distance"],
          "appliedOn": (e["created_at"] ?? e["requested_at"] ?? "").toString(),
        };
      }));

      if (!mounted) return;
      setState(() => trips = mapped);
    } catch (e) {
      if (!mounted) return;
      setState(() => errorText = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _refreshTrips() async {
    await _loadTripsByTab();
  }
Future<bool?> _confirmCancelTrip() async {
  return showCancelTripDialog(context);
}

  Future<void> _startTripAndMoveToInProgress({
    required Map<String, dynamic> trip,
    required String meterReading,
    required String fuelPercent,
    required File meterPhoto,
    String? remark,
  }) async {
    final tripId = int.tryParse((trip["id"] ?? trip["transport_service_id"] ?? "0").toString()) ?? 0;
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
        setState(() => selectedTab = 2);
        await _refreshTrips();
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

  Future<void> _stopTripAndMoveToCompleted({
    required Map<String, dynamic> trip,
    required String meterReading,
    required String fuelPercent,
    required File meterPhoto,
    String? remark,
  }) async {
    final tripId = int.tryParse((trip["id"] ?? trip["transport_service_id"] ?? "0").toString()) ?? 0;
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
        setState(() => selectedTab = 3);
        await _refreshTrips();
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

  Future<void> _cancelTrip(Map<String, dynamic> t) async {
    try {
      final id = (t["id"] ?? "").toString();
      if (id.isEmpty) throw Exception("Trip id missing");

      setState(() => loading = true);

      final res = await VehicleApiService.cancelTrip(id: id);

      if (res["success"] == true) {
        if (!mounted) return;
        TopBanner.show(
          context,
          title: "Request canceled",
          message: "Your pending vehicle trip request has been canceled successfully.",
          icon: Icons.cancel,
        );
        await _refreshTrips();
      } else {
        throw Exception(res["message"] ?? "Cancel failed");
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
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = trips;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _refreshTrips,
        color: Colors.blue,
        backgroundColor: Colors.white,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          itemCount: filtered.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SegmentTabs(
                      selectedIndex: selectedTab,
                      onChanged: (i) async {
                        setState(() => selectedTab = i);
                        await _refreshTrips();
                      },
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(child: CircularProgressIndicator(
                                color: Colors.blue,
                                backgroundColor: Colors.white,
                                strokeWidth: 4,
                      )),
                    ),
                  if (!loading && errorText != null)
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
                            onPressed: _refreshTrips,
                            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                            label: const Text('Retry', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  if (!loading && errorText == null && filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12, top: 10),
                      child: Center(child: Text("No trips found", style: TextStyle(color: Colors.grey))),
                    ),
                ],
              );
            }

            final t = filtered[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TripCard(
                data: t,
                onCancel: ((t["status"]?.toString() == "PENDING") ||
                        (t["status"]?.toString() == "HOD_REJECTED"))
                    ? () async {
                        final ok = await _confirmCancelTrip();
                        if (ok == true) _cancelTrip(t);
                      }
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ------------------ Segmented Tabs ------------------
class _SegmentTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _pill("Pending", 0),
            const SizedBox(width: 2),
            _pill("Approved", 1),
            const SizedBox(width: 2),
            _pill("In Progress", 2),
            const SizedBox(width: 2),
            _pill("Completed", 3),
            const SizedBox(width: 2),
            _pill("Rejected", 4),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, int index) {
    final active = selectedIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(index),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF0B5FA5)
                : const Color.fromARGB(255, 250, 250, 250),
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : const Color(0xFF334155),
            ),
          ),
      ),
    );
  }
}

/// ------------------ Trip Card ------------------
class TripCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onCancel;

  const TripCard({super.key, required this.data, this.onCancel});

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

  String get _reasonLabel {
    final r = (data["reason"] ?? "").toString().trim();
    if (r.isEmpty || r == "-") return "Personal Request";
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final status = (data["status"] ?? "").toString();

    final isPending = status == "PENDING";
    final isHodApproved = status == "HOD_APPROVED";
    final isHodRejected = status == "HOD_REJECTED";
    final isApproved = status == "APPROVED";
    final isInProgress = status == "IN_PROGRESS";
    final isCompleted = status == "COMPLETED";
    final isRejected = status == "REJECTED";

    final hodNote = (data["hodComment"] ?? "").toString().trim();
    final rejectReason = (data["rejectReason"] ?? "").toString().trim();

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
          // header
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
                      Text(
                        (data["vehicleNo"] ?? "").toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E2A3A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (data["vehicleName"] ?? "").toString(),
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
                // PENDING + HOD_APPROVED: same detail block (HOD adds comment + GM notice)
                if (isPending || isHodApproved || isHodRejected) ...[
                
                  _infoRow("Reason", _reasonLabel),
                  const SizedBox(height: 8),
                  _infoRow("From Date", (data["fromDate"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("To Date", (data["toDate"] ?? "").toString()),
                  const SizedBox(height: 8),
                  if (isHodApproved) ...[
                    _commentBox("HOD Comment", hodNote),
                    const SizedBox(height: 10),
                  ],
                  if (isHodRejected) ...[
                    _commentBox(
                      "HOD Comment",
                      hodNote.isNotEmpty ? hodNote : rejectReason,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if ((isPending || isHodRejected) && onCancel != null) ...[
                    const SizedBox(height: 12),
                    _gradientButton(
                      text: "Cancel Request",
                      colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                      onTap: onCancel!,
                    ),
                  ],
                ],

                // APPROVED: show Trip Code + Approved By ONLY here
                if (isApproved) ...[
                  _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason", _reasonLabel),
                  const SizedBox(height: 8),
                  _infoRow("From Date", (data["fromDate"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("To Date", (data["toDate"] ?? "").toString()),
                  const SizedBox(height: 8),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) => _gradientButton(
                      text: "Start Trip (Enter Meter Reading)",
                      onTap: () {
                        showStartTripDialog(
                          context: ctx,
                          vehicleNo: (data["vehicleNo"] ?? "-").toString(),
                          destination: (data["destination"] ?? "-").toString(),
                          isSubmitting: false,
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                            remark,
                          }) async {
                            final state = ctx.findAncestorStateOfType<_PersonalTripScreenState>();
                            await state?._startTripAndMoveToInProgress(
                              trip: data,
                              meterReading: meterReading,
                              fuelPercent: fuelPercent,
                              meterPhoto: meterPhoto,
                              remark: remark,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                // IN_PROGRESS: show Trip Code + Start Meter details
                if (isInProgress) ...[
                  _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason", _reasonLabel),
                  const SizedBox(height: 8),
                  _infoRow("Start Meter", "${data["startMeter"] ?? "-"} km"),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) => _gradientButton(
                      text: "Stop Trip & Submit (Enter Meter Reading)",
                      colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                      onTap: () {
                        showStopTripDialog(
                          context: ctx,
                          vehicleNo: (data["vehicleNo"] ?? "-").toString(),
                          destination: (data["destination"] ?? "-").toString(),
                          isSubmitting: false,
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                            remark,
                          }) async {
                            final state = ctx.findAncestorStateOfType<_PersonalTripScreenState>();
                            await state?._stopTripAndMoveToCompleted(
                              trip: data,
                              meterReading: meterReading,
                              fuelPercent: fuelPercent,
                              meterPhoto: meterPhoto,
                              remark: remark,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                // COMPLETED: keep your full details (ok)
                if (isCompleted) ...[
                  _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason", _reasonLabel),
                  const SizedBox(height: 8),
                  _infoRow("Start Meter", "${data["startMeter"] ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("End Meter", "${data["endMeter"] ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("Distance Traveled by Odometer", "${data["odoDistance"] ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("GPS Calculated Distance", "${data["gpsDistance"] ?? "-"} km"),
                ],

                // REJECTED (by manager/GM): show reject reason
                if (isRejected) ...[
                  _infoRow("Reason", _reasonLabel),
                  const SizedBox(height: 8),
                  _infoRow("From Date", (data["fromDate"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("To Date", (data["toDate"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _commentBox(
                    "Manager Comment",
                    rejectReason.isNotEmpty ? rejectReason : hodNote,
                  ),
                ],

                if (_fmtApplied((data["appliedOn"] ?? "").toString()).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _fmtApplied((data["appliedOn"] ?? "").toString()),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7A90)),
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

  String _fmtApplied(String v) {
    if (v.isEmpty) return "";
    try {
      return 'Applied on: ${DateFormat('MMM dd, yyyy  hh:mm a').format(DateTime.parse(v))}';
    } catch (_) {
      return v.length >= 16 ? 'Applied on: ${v.substring(0, 16)}' : (v.isNotEmpty ? 'Applied on: $v' : '');
    }
  }

  Widget _commentBox(String title, String note) {
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
            title,
            style: const TextStyle(
              color: Color(0xFF6B7A90),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note.isEmpty ? "—" : note,
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

  Widget _statusPill(String status) {
    final label = status == "PENDING"
        ? "Pending"
        : status == "HOD_APPROVED"
            ? "HOD approved"
            : status == "HOD_REJECTED"
                ? "HOD rejected"
            : status == "APPROVED"
                ? "Approved"
                : status == "IN_PROGRESS"
                    ? "In-progress"
                    : status == "REJECTED"
                        ? "Rejected"
                    : "Completed";

    Color bg;
    Color border;
    Color text;
    IconData icon;
    Color iconColor;

    if (status == "PENDING") {
      bg = const Color(0xFFFFF3CD);
      border = const Color(0xFFFFE49A);
      text = const Color(0xFF8A6D3B);
      icon = Icons.hourglass_bottom;
      iconColor = const Color(0xFF8A6D3B);
    } else if (status == "HOD_REJECTED") {
      bg = const Color(0xFFFFE5E5);
      border = const Color(0xFFFFB3B3);
      text = const Color(0xFF8A1C1C);
      icon = Icons.cancel_outlined;
      iconColor = const Color(0xFF8A1C1C);
    } else if (status == "HOD_APPROVED") {
      bg = const Color(0xFFE8F5E9);
      border = const Color(0xFFA5D6A7);
      text = const Color(0xFF1B5E20);
      icon = Icons.verified_user_outlined;
      iconColor = const Color(0xFF1B5E20);
    } else if (status == "REJECTED") {
      bg = const Color(0xFFFFE5E5);
      border = const Color(0xFFFFB3B3);
      text = const Color(0xFF8A1C1C);
      icon = Icons.block;
      iconColor = const Color(0xFF8A1C1C);
    } else if (status == "APPROVED") {
      bg = const Color(0xFFE5E5E5);
      border = const Color(0xFFD3D3D3);
      text = const Color(0xFF7A7A7A);
      icon = Icons.check_circle;
      iconColor = const Color(0xFF7A7A7A);
    } else if (status == "IN_PROGRESS") {
      bg = const Color(0xFFE6E6E6);
      border = const Color(0xFFD0D0D0);
      text = const Color(0xFF7A7A7A);
      icon = Icons.schedule;
      iconColor = const Color(0xFF7A7A7A);
    } else {
      bg = const Color(0xFFCDEED3);
      border = const Color(0xFF9AD7A6);
      text = const Color(0xFF2E7D32);
      icon = Icons.verified;
      iconColor = const Color(0xFF2E7D32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: text),
          ),
        ],
      ),
    );
  }
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
}