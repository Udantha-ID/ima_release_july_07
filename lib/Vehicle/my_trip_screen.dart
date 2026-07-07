import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../ui/dialogs/start_trip_dialog.dart';
import '../ui/dialogs/stop_trip_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Services/api_service.dart';
import '../Leaves/top_banner.dart';
import '../ui/dialogs/cancel_trip_dialog.dart';
import '../ui/dialogs/show_change_vehicle_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Companion model
// ─────────────────────────────────────────────────────────────────────────────

class _TripCompanion {
  final int    id;
  final String name;
  const _TripCompanion({required this.id, required this.name});

  factory _TripCompanion.fromJson(Map<String, dynamic> j) => _TripCompanion(
        id:   int.tryParse((j['employee_id'] ?? '').toString()) ?? 0,
        name: (j['name'] ?? '').toString().trim(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class MyTripsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const MyTripsScreen({super.key, required this.user});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  int selectedTab = 0;
  bool loading = false;
  String? errorText;
  List<Map<String, dynamic>> trips = [];

  @override
  void initState() { super.initState(); _refreshTrips(); }

  String _employeeId() {
    final u = widget.user;
    final v = u["employee_id"] ?? u["employeeId"] ?? u["id"] ?? u["user_id"];
    return (v ?? "").toString().trim();
  }

  Future<void> _refreshTrips() async {
    try {
      setState(() { loading = true; errorText = null; });

      final empId = _employeeId();
      if (empId.isEmpty || empId == "0" || empId == "null") {
        throw Exception("employee_id missing in login data");
      }

      final res = await VehicleApiService.getMyTrips(employeeId: empId);
      if (res["success"] != true) throw Exception(res["message"] ?? "Failed to load trips");

      final data    = res["data"] ?? [];
      final rawList = List<Map<String, dynamic>>.from(data);

      final mapped = await Future.wait(rawList.map((e) async {
        final tripId     = (e["id"] ?? "").toString();
        String vehicleName = (e["vehicle_name"] ?? "").toString();

        try {
          final vd = await VehicleApiService.fetchVehicleDetails(
              transportServiceId: tripId);
          final make  = (vd["make"]  ?? "-").toString();
          final model = (vd["model"] ?? "-").toString();
          if (make != "-" || model != "-") vehicleName = "$make $model".trim();
        } catch (_) {}

        return {...e, "vehicleName": vehicleName};
      }));

      setState(() => trips = mapped);
    } catch (e) {
      if (mounted) setState(() => errorText = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _filteredTrips() {
    const statusMap = {
      0: ["PENDING"],
      1: ["APPROVED"],
      2: ["IN_PROGRESS", "VEHICLE_CHANGING"],
      3: ["COMPLETED"],
    };
    final statuses = statusMap[selectedTab] ?? const [];
    return trips.where((t) => statuses.contains((t["status"] ?? ""))).toList();
  }

  Future<bool?> _confirmCancelTrip() => showCancelTripDialog(context);

  Future<void> _startTripAndMoveToInProgress({
    required Map<String, dynamic> trip,
    required String meterReading,
    required String fuelPercent,
    required File   meterPhoto,
    String?         remark,
  }) async {
    final tripId = int.tryParse((trip["id"] ?? 0).toString()) ?? 0;
    if (tripId <= 0) return;
    try {
      setState(() => loading = true);
      final res = await VehicleApiService.startTrip(
        transportServiceId: tripId,
        odometer:           int.parse(meterReading),
        fuelPercent:        double.parse(fuelPercent),
        photoFile:          meterPhoto,
        remark:             remark,
      );
      if (res["success"] == true) {
        if (!mounted) return;
        setState(() => selectedTab = 2);
        await _refreshTrips();
        if (!mounted) return;
        TopBanner.show(context,
            title: "Trip Started",
            message: "Trip started successfully and moved to In Progress.",
            icon: Icons.check_circle, isSuccess: true);
      } else {
        throw Exception(res["message"] ?? "Start trip failed");
      }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(context, title: "Start Trip Failed",
          message: e.toString(), icon: Icons.error_outline, isSuccess: false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _stopTripAndMoveToCompleted({
    required Map<String, dynamic> trip,
    required String meterReading,
    required String fuelPercent,
    required File   meterPhoto,
    String?         remark,
  }) async {
    final tripId = int.tryParse((trip["id"] ?? 0).toString()) ?? 0;
    if (tripId <= 0) return;
    try {
      setState(() => loading = true);
      final res = await VehicleApiService.stopTrip(
        transportServiceId: tripId,
        endOdometer:        int.parse(meterReading),
        endFuelPercent:     double.parse(fuelPercent),
        photoFile:          meterPhoto,
        remark:             remark,
      );
      if (res["success"] == true) {
        if (!mounted) return;
        setState(() => selectedTab = 3);
        await _refreshTrips();
        if (!mounted) return;
        TopBanner.show(context,
            title: "Trip Completed", message: "Trip completed successfully.",
            icon: Icons.check_circle, isSuccess: true);
      } else {
        throw Exception(res["message"] ?? "Stop trip failed");
      }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(context, title: "Stop Trip Failed",
          message: e.toString(), icon: Icons.error_outline, isSuccess: false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _cancelTrip(Map<String, dynamic> t) async {
    try {
      setState(() => loading = true);
      final id = (t["id"] ?? "").toString();
      if (id.isEmpty) throw Exception("Trip id missing");
      final res = await VehicleApiService.cancelTrip(id: id);
      if (res["success"] == true) {
        if (!mounted) return;
        TopBanner.show(context,
            title:   "Request Cancelled",
            message: "Your pending vehicle trip request has been cancelled.",
            icon:    Icons.cancel);
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

  Future<void> _endCurrentVehicle({
    required Map<String, dynamic> trip,
    required int    endMeter,
    required double endFuel,
    required File   endPhoto,
    String?         remark,
  }) async {
    final tripId = int.tryParse((trip["id"] ?? 0).toString()) ?? 0;
    if (tripId <= 0) return;
    try {
      setState(() => loading = true);
      final res = await VehicleApiService.endCurrentVehicle(
        transportServiceId: tripId,
        endMeter: endMeter, endFuel: endFuel, endPhoto: endPhoto,
        remark: remark,
      );
      if (res["success"] == true) {
        if (!mounted) return;
        await _refreshTrips();
        if (!mounted) return;
        TopBanner.show(context,
            title: "Vehicle Ended",
            message: "Vehicle A recorded. Now start your new vehicle.",
            icon: Icons.swap_horiz_rounded, isSuccess: true);
      } else { throw Exception(res["message"] ?? "End vehicle failed"); }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(context, title: "End Vehicle Failed",
          message: e.toString().replaceFirst("Exception: ", ""),
          icon: Icons.error_outline, isSuccess: false);
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _startNewVehicle({
    required Map<String, dynamic> trip,
    required String newVehicleNo,
    required int    startMeter,
    required double startFuel,
    required File   startPhoto,
    String?         remark,
    String?         destination,
  }) async {
    final tripId = int.tryParse((trip["id"] ?? 0).toString()) ?? 0;
    if (tripId <= 0) return;
    try {
      setState(() => loading = true);
      final res = await VehicleApiService.startNewVehicle(
        transportServiceId: tripId, newVehicleNo: newVehicleNo,
        startMeter: startMeter, startFuel: startFuel,
        startPhoto: startPhoto, remark: remark, destination: destination,
      );
      if (res["success"] == true) {
        if (!mounted) return;
        await _refreshTrips();
        if (!mounted) return;
        TopBanner.show(context,
            title: "New Vehicle Started",
            message: "Now driving $newVehicleNo. Trip in progress.",
            icon: Icons.check_circle, isSuccess: true);
      } else { throw Exception(res["message"] ?? "Start new vehicle failed"); }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(context, title: "Start Vehicle Failed",
          message: e.toString().replaceFirst("Exception: ", ""),
          icon: Icons.error_outline, isSuccess: false);
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTrips();

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
                      onChanged:     (i) => setState(() => selectedTab = i),
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(child: CircularProgressIndicator(
                          color: Colors.blue, strokeWidth: 4)),
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
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                          child: Text("No trips found",
                              style: TextStyle(color: Colors.grey))),
                    ),
                ],
              );
            }

            final t = filtered[index - 1];

            // Parse companions from API response
            final rawCompanions = t["companions"] as List? ?? [];
            final companions    = rawCompanions
                .map((c) => _TripCompanion.fromJson(c as Map<String, dynamic>))
                .toList();

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TripCard(
                data:       t,
                companions: companions,
                onCancel:   t["status"] == "PENDING"
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

// ─────────────────────────────────────────────────────────────────────────────
// Segmented tabs (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentTabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          _pill("Pending",     0),
          const SizedBox(width: 6),
          _pill("Approved",    1),
          const SizedBox(width: 6),
          _pill("In Progress", 2),
          const SizedBox(width: 6),
          _pill("Completed",   3),
        ],
      ),
    );
  }

  Widget _pill(String text, int index) {
    final active = selectedIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0B5FA5) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10, offset: const Offset(0, 6))]
                : [],
          ),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : const Color(0xFF334155))),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Companion photo avatar — loads once, falls back to colour + initials
// ─────────────────────────────────────────────────────────────────────────────

class _CompanionPhoto extends StatefulWidget {
  final int    id;
  final String name;
  final int    colorIndex;
  final double radius;
  final bool   withBorder;

  const _CompanionPhoto({
    required this.id,
    required this.name,
    required this.colorIndex,
    this.radius    = 18,
    this.withBorder = true,
  });

  @override
  State<_CompanionPhoto> createState() => _CompanionPhotoState();
}

class _CompanionPhotoState extends State<_CompanionPhoto> {
  late final Future<Map<String, dynamic>?> _photoFuture;

  static const _colors = [
    Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100),
  ];

  @override
  void initState() {
    super.initState();
    _photoFuture = ApiService.getProfilePhoto(employeeId: widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final parts    = widget.name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty ? parts[0][0].toUpperCase() : '?');
    final bgColor  = _colors[widget.colorIndex % _colors.length];
    final size     = widget.radius * 2;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _photoFuture,
      builder: (_, snap) {
        final url = (snap.data?['fileUrl'] ?? '').toString().trim();
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: url.isNotEmpty ? null : bgColor,
            shape: BoxShape.circle,
            border: widget.withBorder
                ? Border.all(color: Colors.white, width: 2.5)
                : null,
            image: url.isNotEmpty
                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                : null,
          ),
          child: url.isEmpty
              ? Center(
                  child: Text(initials,
                      style: TextStyle(
                          fontSize: widget.radius * 0.65,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)))
              : null,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip Card
// ─────────────────────────────────────────────────────────────────────────────

class TripCard extends StatelessWidget {
  final Map<String, dynamic>  data;
  final List<_TripCompanion>  companions;
  final VoidCallback?         onCancel;

  const TripCard({
    super.key,
    required this.data,
    required this.companions,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status            = (data["status"] ?? "").toString();
    final isPending         = status == "PENDING";
    final isApproved        = status == "APPROVED";
    final isInProgress      = status == "IN_PROGRESS";
    final isVehicleChanging = status == "VEHICLE_CHANGING";
    final isCompleted       = status == "COMPLETED";
    final changeVehicleNo   = (data["changeVehicleNo"]?.toString() ?? "").trim();
    final alreadyChanged    = changeVehicleNo.isNotEmpty && !isVehicleChanging;
    final cStartM    = int.tryParse(data["startMeter"]?.toString()               ?? "");
    final cOrigEndM  = int.tryParse(data["oldVehicleEndMeter"]?.toString()       ?? "");
    final cTripEndM  = int.tryParse(data["tripEndOdometer"]?.toString()          ?? "");
    final cChgStartM = int.tryParse(data["changeVehicleStartMeter"]?.toString()  ?? "");
    final cChgEndM   = int.tryParse(data["changeVehicleEndMeter"]?.toString()    ?? "");
    final appliedStr   = _fmtApplied([
      data["created_at"], data["requested_at"], data["request_date"],
      data["apply_date"], data["applied_date"],
    ].map((v) => v?.toString() ?? "").firstWhere((s) => s.isNotEmpty, orElse: () => ""));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [

          // ── Header ───────────────────────────────────────────────────────
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
                      Text((data["vehicleNo"] ?? "").toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Color(0xFF1E2A3A))),
                      if (alreadyChanged)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.swap_horiz_rounded,
                                  size: 12, color: Color(0xFFE65100)),
                              const SizedBox(width: 4),
                              Text(
                                "Changed to: $changeVehicleNo",
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE65100)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text((data["vehicleName"] ?? "").toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                _statusPill(status),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [

                // PENDING
                if (isPending) ...[
                  _infoRow("Reason",      "Office Service"),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("From Date",   (data["fromDate"]    ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("To Date",     (data["toDate"]      ?? "").toString()),

                  // Companions
                  if (companions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _companionsRow(context, companions),
                  ],

                  if (onCancel != null) ...[
                    const SizedBox(height: 12),
                    _gradientButton(text: "Cancel Request",
                        colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                        onTap: onCancel!),
                  ],
                ],

                // APPROVED
                if (isApproved) ...[
                  _infoRow("Trip Code",   (data["tripCode"]       ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason",      (data["reason"]         ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"]    ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("From Date",   (data["fromDate"]       ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("To Date",     (data["toDate"]         ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Approved By", (data["approvedByName"] ?? "").toString()),

                  // Companions
                  if (companions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _companionsRow(context, companions),
                  ],

                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) => _gradientButton(
                      text: "Start Trip (Enter Meter Reading)",
                      onTap: () {
                        showStartTripDialog(
                          context: ctx,
                          vehicleNo:   (data["vehicleNo"]   ?? "-").toString(),
                          destination: (data["destination"] ?? "-").toString(),
                          isSubmitting: false,
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                            remark,
                          }) async {
                            final state = ctx.findAncestorStateOfType<_MyTripsScreenState>();
                            await state?._startTripAndMoveToInProgress(
                              trip:         data,
                              meterReading: meterReading,
                              fuelPercent:  fuelPercent,
                              meterPhoto:   meterPhoto,
                              remark:       remark,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                // IN_PROGRESS
                if (isInProgress) ...[
                  if (alreadyChanged && (data["changeVehicleTripCode"]?.toString() ?? "").trim().isNotEmpty)
                    _infoRow("New Trip Code", (data["changeVehicleTripCode"] ?? "").toString(), highlight: true)
                  else
                    _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason",      (data["reason"]      ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination",
                      (alreadyChanged && (data["changeVehicleDestination"]?.toString() ?? "").trim().isNotEmpty
                          ? data["changeVehicleDestination"]
                          : data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Start Meter",
                      "${alreadyChanged ? (data["changeVehicleStartMeter"] ?? data["startMeter"] ?? "-") : (data["startMeter"] ?? "-")} km"),

                  if (alreadyChanged) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCC80)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 15, color: Color(0xFFE65100)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Vehicle already changed to $changeVehicleNo",
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w700,
                                  color: Color(0xFFE65100)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Companions
                  if (companions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _companionsRow(context, companions),
                  ],

                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) {
                      Widget stopBtn() => _gradientButton(
                        text:   "Stop Trip",
                        colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                        icon:   Icons.stop_circle_outlined,
                        onTap: () {
                          showStopTripDialog(
                            context: ctx,
                            vehicleNo:   (data["vehicleNo"]   ?? "-").toString(),
                            destination: (data["destination"] ?? "-").toString(),
                            isSubmitting: false,
                            onConfirm: ({
                              required meterReading,
                              required fuelPercent,
                              required meterPhoto,
                              remark,
                            }) async {
                              final state = ctx.findAncestorStateOfType<_MyTripsScreenState>();
                              await state?._stopTripAndMoveToCompleted(
                                trip:         data,
                                meterReading: meterReading,
                                fuelPercent:  fuelPercent,
                                meterPhoto:   meterPhoto,
                                remark:       remark,
                              );
                            },
                          );
                        },
                      );

                      if (alreadyChanged) return stopBtn();

                      return Row(
                        children: [
                          Expanded(
                            child: _gradientButton(
                              text:   "Switch Vehicle",
                              colors: const [Color(0xFFE65100), Color(0xFF8D2F00)],
                              icon:   Icons.swap_horiz_rounded,
                              onTap: () {
                                showEndCurrentVehicleDialog(
                                  context: ctx,
                                  currentVehicleNo: (data["vehicleNo"] ?? "-").toString(),
                                  isSubmitting: false,
                                  onConfirm: ({
                                    required endMeter,
                                    required endFuel,
                                    required endPhoto,
                                    remark,
                                  }) async {
                                    final state = ctx.findAncestorStateOfType<_MyTripsScreenState>();
                                    await state?._endCurrentVehicle(
                                      trip:     data,
                                      endMeter: endMeter,
                                      endFuel:  endFuel,
                                      endPhoto: endPhoto,
                                      remark:   remark,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: stopBtn()),
                        ],
                      );
                    },
                  ),
                ],

                // VEHICLE_CHANGING
                if (isVehicleChanging) ...[
                  _infoRow("Trip Code",   (data["tripCode"]    ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Vehicle",     (data["vehicleNo"]   ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("End Meter",   "${data["oldVehicleEndMeter"] ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("End Fuel",    "${data["oldVehicleEndFuel"]  ?? "-"} %"),

                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFFE65100)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Vehicle A recorded. Please start your new vehicle to continue the trip.",
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Companions
                  if (companions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _companionsRow(context, companions),
                  ],

                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) => _gradientButton(
                      text:   "Start New Vehicle",
                      colors: const [Color(0xFF1565C0), Color(0xFF003580)],
                      icon:   Icons.directions_car_outlined,
                      onTap: () {
                        showStartNewVehicleDialog(
                          context: ctx,
                          isSubmitting: false,
                          originalDestination: (data["destination"] ?? "").toString(),
                          onConfirm: ({
                            required newVehicleNo,
                            required startMeter,
                            required startFuel,
                            required startPhoto,
                            remark,
                            destination,
                          }) async {
                            final state = ctx.findAncestorStateOfType<_MyTripsScreenState>();
                            await state?._startNewVehicle(
                              trip:         data,
                              newVehicleNo: newVehicleNo,
                              startMeter:   startMeter,
                              startFuel:    startFuel,
                              startPhoto:   startPhoto,
                              remark:       remark,
                              destination:  destination,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                // COMPLETED
                if (isCompleted) ...[
                  // Top trip code: show New Trip Code when vehicle was changed
                  if (alreadyChanged && (data["changeVehicleTripCode"]?.toString() ?? "").trim().isNotEmpty)
                    _infoRow("New Trip Code", (data["changeVehicleTripCode"] ?? "").toString(), highlight: true)
                  else
                    _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),

                  // ── No vehicle change: single odometer range + distance ──
                  if (!alreadyChanged) ...[
                    if (cStartM != null && cTripEndM != null) ...[
                      const SizedBox(height: 8),
                      _infoRow("Odometer", "$cStartM km  –  $cTripEndM km"),
                    ],
                    const SizedBox(height: 8),
                    _infoRow("Distance", "${data["distanceKm"] ?? "-"} km"),
                  ],

                  // ── Vehicle changed: Vehicle A odometer + change block ───
                  if (alreadyChanged) ...[
                    if (cStartM != null && cOrigEndM != null) ...[
                      const SizedBox(height: 8),
                      _infoRow("Odometer", "$cStartM km  –  $cOrigEndM km"),
                      const SizedBox(height: 8),
                      _infoRow("Distance", "${cOrigEndM - cStartM} km"),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCC80)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFFE65100)),
                              SizedBox(width: 6),
                              Text("Vehicle Changed Mid Trip",
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFE65100))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _infoRow("Change Destination", (data["changeVehicleDestination"] ?? "").toString()),
                          if (cChgStartM != null && cChgEndM != null) ...[
                            const SizedBox(height: 6),
                            _infoRow("Odometer", "$cChgStartM km  –  $cChgEndM km"),
                            const SizedBox(height: 6),
                            _infoRow("Distance",  "${cChgEndM - cChgStartM} km"),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRow("Total Distance", "${data["distanceKm"] ?? "-"} km"),
                  ],

                  // Companions
                  if (companions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _companionsRow(context, companions),
                  ],
                ],

                if (appliedStr.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      appliedStr,
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

  // ── Companions row — overlapping avatars + tap to see all ─────────────────
  Widget _companionsRow(BuildContext context, List<_TripCompanion> list) {
    return GestureDetector(
      onTap: () => _showCompanionsSheet(context, list),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE6F8)),
        ),
        child: Row(
          children: [
            SizedBox(
              height: 36,
              width: _avatarStackWidth(list.length),
              child: Stack(
                children: [
                  for (int i = 0; i < list.length.clamp(0, 3); i++)
                    Positioned(
                      left: i * 24.0,
                      child: _CompanionPhoto(
                        id:         list[i].id,
                        name:       list[i].name,
                        colorIndex: i,
                      ),
                    ),
                  if (list.length > 3)
                    Positioned(
                      left: 3 * 24.0,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: Center(
                          child: Text('+${list.length - 3}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF475569))),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                list.length == 1
                    ? list.first.name
                    : '${list.length} people going',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569)),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  // ── Companions bottom sheet ────────────────────────────────────────────────
  void _showCompanionsSheet(BuildContext context, List<_TripCompanion> list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.group_outlined,
                    color: Color(0xFF1565C0), size: 20),
                const SizedBox(width: 8),
                Text('Going With (${list.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 72, endIndent: 20),
            itemBuilder: (_, i) {
              final c = list[i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    _CompanionPhoto(
                      id:         c.id,
                      name:       c.name,
                      colorIndex: i,
                      radius:     22,
                      withBorder: false,
                    ),
                    const SizedBox(width: 14),
                    Text(c.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2A3A))),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double _avatarStackWidth(int count) => (count.clamp(0, 4) * 24.0) + 12;

  Widget _gradientButton({
    required String text,
    required VoidCallback onTap,
    List<Color> colors = const [Color(0xFF1DB954), Color(0xFF0B7A34)],
    IconData? icon,
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
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 15),
                    const SizedBox(width: 5),
                    Text(text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.8)),
                  ],
                )
              : Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.8)),
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final label = {
      "PENDING":          "Pending",
      "APPROVED":         "Approved",
      "IN_PROGRESS":      "In-progress",
      "VEHICLE_CHANGING": "Changing Vehicle",
      "COMPLETED":        "Completed",
    }[status] ?? status;

    Color bg, border, text, iconColor;
    IconData icon;

    switch (status) {
      case "PENDING":
        bg = const Color(0xFFFFF3CD); border = const Color(0xFFFFE49A);
        text = const Color(0xFF8A6D3B); iconColor = const Color(0xFF8A6D3B);
        icon = Icons.hourglass_bottom; break;
      case "APPROVED":
        bg = const Color(0xFFE5E5E5); border = const Color(0xFFD3D3D3);
        text = const Color(0xFF7A7A7A); iconColor = const Color(0xFF7A7A7A);
        icon = Icons.check_circle; break;
      case "IN_PROGRESS":
        bg = const Color(0xFFE6E6E6); border = const Color(0xFFD0D0D0);
        text = const Color(0xFF7A7A7A); iconColor = const Color(0xFF7A7A7A);
        icon = Icons.schedule; break;
      case "VEHICLE_CHANGING":
        bg = const Color(0xFFFFF3E0); border = const Color(0xFFFFCC80);
        text = const Color(0xFFE65100); iconColor = const Color(0xFFE65100);
        icon = Icons.swap_horiz_rounded; break;
      default:
        bg = const Color(0xFFCDEED3); border = const Color(0xFF9AD7A6);
        text = const Color(0xFF2E7D32); iconColor = const Color(0xFF2E7D32);
        icon = Icons.verified;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w900, color: text)),
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
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155))),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                softWrap: true,
                style: const TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}