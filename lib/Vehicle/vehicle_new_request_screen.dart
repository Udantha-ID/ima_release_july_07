import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../ui/dialogs/vehicle_submit_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Services/staff_gate_pass_service.dart';
import '../Leaves/top_banner.dart';
import 'dart:convert';
import '../Services/api_service.dart';
import '../ui/widgets/common_form_widgets.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Existing models (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class PlaceSuggestion {
  final String description;
  final String placeId;

  PlaceSuggestion({required this.description, required this.placeId});

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) => PlaceSuggestion(
        description: json['description'],
        placeId:     json['place_id'],
      );
}

Future<List<PlaceSuggestion>> fetchPlaceSuggestions(String input) async {
  input = input.trim();
  if (input.isEmpty) return [];

  final apiKey = await VehicleApiService.getGooglePlacesApiKey();
  if (apiKey == null || apiKey.isEmpty) {
    debugPrint("Places: could not load API key from backend");
    return [];
  }

  final uri = Uri.https(
    "maps.googleapis.com",
    "/maps/api/place/autocomplete/json",
    {"input": input, "key": apiKey, "components": "country:lk"},
  );

  final res  = await http.get(uri);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final status = (data["status"] ?? "").toString();

  debugPrint("Places status=$status code=${res.statusCode}");
  if (res.statusCode != 200 || status != "OK") return [];

  final preds = (data["predictions"] as List? ?? []);
  return preds.map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>)).toList();
}

class AvailableVehicleOption {
  final int    id;
  final String regNo;
  final String make;
  final String model;
  final String companyName;
  final String vehicleTypeName;

  AvailableVehicleOption({
    required this.id,
    required this.regNo,
    required this.make,
    required this.model,
    required this.companyName,
    required this.vehicleTypeName,
  });

  factory AvailableVehicleOption.fromJson(Map<String, dynamic> json) =>
      AvailableVehicleOption(
        id:              int.tryParse((json["id"] ?? "").toString()) ?? 0,
        regNo:           (json["reg_no"]           ?? "").toString().trim(),
        make:            (json["make"]              ?? "").toString().trim(),
        model:           (json["model"]             ?? "").toString().trim(),
        companyName:     (json["company_name"]      ?? "").toString().trim(),
        vehicleTypeName: (json["vehicle_type_name"] ?? "").toString().trim(),
      );

  String get displayLabel => "$regNo - ${"$make $model".trim()}";
}

// ─────────────────────────────────────────────────────────────────────────────
// Staff member model (same as gate pass)
// ─────────────────────────────────────────────────────────────────────────────

class _StaffMember {
  final int    id;
  final String name;
  final String jobTitle;

  const _StaffMember({
    required this.id,
    required this.name,
    required this.jobTitle,
  });

  factory _StaffMember.fromJson(Map<String, dynamic> j) => _StaffMember(
        id:       int.tryParse((j['employee_id'] ?? '').toString()) ?? 0,
        name:     (j['name']      ?? '').toString().trim(),
        jobTitle: (j['job_title'] ?? '').toString().trim(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class VehicleRequestFormScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onRequestSubmitted;

  const VehicleRequestFormScreen(
      {super.key, required this.user, this.onRequestSubmitted});

  @override
  State<VehicleRequestFormScreen> createState() =>
      _VehicleRequestFormScreenState();
}

class _VehicleRequestFormScreenState extends State<VehicleRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Read-only user detail controllers ─────────────────────────────────────
  final nameController       = TextEditingController();
  final employeeController   = TextEditingController();
  final departmentController = TextEditingController();
  final contactController    = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();

  // ── Form fields ───────────────────────────────────────────────────────────
  final destinationController     = TextEditingController();
  final _vehicleLettersController = TextEditingController();
  final _vehicleNumbersController = TextEditingController();
  DateTime? fromDate;
  DateTime? toDate;

  // ── Managers ──────────────────────────────────────────────────────────────
  List<Map<String, String>> managers       = [];
  String?                   selectedManagerId;
  bool                      loadingManagers = true;
  String?                   managerError;
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};
  final Map<int, Future<Map<String, dynamic>?>> _staffPhotoFutureCache = {};

  // ── Staff (Going With) ────────────────────────────────────────────────────
  List<_StaffMember> _allStaff         = [];
  bool               _loadingStaff     = true;
  String?            _staffError;
  final Set<int>     _selectedStaffIds = {};
  final              _staffSearchCtrl  = TextEditingController();
  String             _staffSearchQuery = '';
  final remarkController = TextEditingController();


  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    nameController.text       = widget.user['name']         ?? '';
    employeeController.text   = widget.user['employeeCode'] ?? '';
    departmentController.text = widget.user['department']   ?? '';
    contactController.text    = widget.user['phone']        ?? '';
    _loadManagers();
    _loadAllStaff();
  }

  @override
  void dispose() {
    _vehicleLettersController.dispose();
    _vehicleNumbersController.dispose();
    _staffSearchCtrl.dispose();
    remarkController.dispose();
    super.dispose();
  }

  // ── Photo helpers ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) =>
      _photoFutureCache.putIfAbsent(
          employeeId, () => ApiService.getProfilePhoto(employeeId: employeeId));

  Future<Map<String, dynamic>?> _getStaffPhotoFuture(int employeeId) =>
      _staffPhotoFutureCache.putIfAbsent(
          employeeId, () => ApiService.getProfilePhoto(employeeId: employeeId));

  // ── Load managers ─────────────────────────────────────────────────────────
  Future<void> _loadManagers() async {
    try {
      setState(() { loadingManagers = true; managerError = null; });

      final empId = widget.user["employee_id"]?.toString() ??
          widget.user["employeeId"]?.toString() ?? "";
      if (empId.isEmpty) throw Exception("employee_id missing in login data");

      final res = await VehicleApiService.getDefaultManagers(
          employeeId: int.parse(empId));
      if (res["success"] != true) throw Exception(res["message"] ?? "API failed");

      final data        = res["data"] ?? {};
      final raw         = List.from(data["managers"] ?? []);
      final reportingId = data["reporting_manager_id"]?.toString();

      final list = raw.map<Map<String, String>>((e) => {
            "id":   e["id"].toString(),
            "name": (e["name"] ?? "").toString(),
          }).toList();

      String? defaultId;
      if (reportingId != null && list.any((m) => m["id"] == reportingId)) {
        defaultId = reportingId;
      } else if (list.isNotEmpty) {
        defaultId = list.first["id"];
      }

      setState(() {
        managers          = list;
        selectedManagerId = defaultId;
        loadingManagers   = false;
      });
    } catch (e) {
      setState(() {
        loadingManagers   = false;
        managerError      = e.toString();
        managers          = [];
        selectedManagerId = null;
      });
    }
  }

  // ── Load staff ────────────────────────────────────────────────────────────
  Future<void> _loadAllStaff() async {
    try {
      setState(() { _loadingStaff = true; _staffError = null; });

      final res = await StaffGatePassService.getAllStaff();
      if (res['success'] != true) throw Exception(res['message'] ?? 'Failed');

      final raw          = List.from(res['members'] ?? []);
      final currentEmpId = (widget.user['employee_id'] ??
              widget.user['employeeId'] ?? '').toString().trim();

      setState(() {
        _allStaff = raw
            .map((e) => _StaffMember.fromJson(e as Map<String, dynamic>))
            .where((s) => s.id.toString() != currentEmpId)
            .toList();
        _loadingStaff = false;
      });
    } catch (e) {
      setState(() { _loadingStaff = false; _staffError = e.toString(); });
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (fromDate == null || toDate == null) return;

    setState(() => _isSubmitting = true);

    try {
      final u      = widget.user;
      final empId  = (u["employee_id"] ?? u["employeeId"] ??
              u["id"] ?? u["user_id"] ?? "").toString().trim();
      final managerId     = selectedManagerId!;
      final employeeName  = nameController.text.trim();
      final employeePhone = contactController.text.trim();

      final letters   = _vehicleLettersController.text.trim().toUpperCase();
      final numbers   = _vehicleNumbersController.text.trim();
      final vehicleNo = "$letters-$numbers";

      final fromDateTxt = DateFormat("yyyy-MM-dd").format(fromDate!);
      final toDateTxt   = DateFormat("yyyy-MM-dd").format(toDate!);

      final res = await VehicleApiService.createOfficeVehicleRequest(
        employeeId:           empId,
        managerId:            managerId,
        vehicleNo:            vehicleNo,
        fromDate:             fromDateTxt,
        toDate:               toDateTxt,
        destination:          destinationController.text.trim(),
        contactNo:            employeePhone,
        employeeName:         employeeName,
        reason:               "Office Service",
        vehicleType:          "-",
        vehicleId:            0,
        remark:               remarkController.text.trim().isEmpty
                              ? null
                              : remarkController.text.trim(),
        companionEmployeeIds: _selectedStaffIds.toList(), // ← new
      );

      if (res["success"] == true) {
        if (!mounted) return;
        TopBanner.show(context,
            title:     "Request Submitted",
            message:   "Your vehicle request has been submitted successfully.",
            icon:      Icons.check_circle,
            isSuccess: true);
        widget.onRequestSubmitted != null
            ? widget.onRequestSubmitted!()
            : Navigator.pop(context);
      } else {
        throw Exception(res["message"] ?? "Submission failed");
      }
    } catch (e) {
      if (!mounted) return;
      final errText = e.toString()
          .replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      TopBanner.show(context,
          title:     "Submission Failed",
          message:   errText.isEmpty ? "Something went wrong." : errText,
          icon:      Icons.error_outline,
          isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showVehicleSubmitConfirmation() {
    final letters      = _vehicleLettersController.text.trim().toUpperCase();
    final numbers      = _vehicleNumbersController.text.trim();
    final vehicleNoTxt = (letters.isNotEmpty || numbers.isNotEmpty)
        ? "$letters-$numbers"
        : "-";
    final fromTxt = fromDate == null ? "-" : DateFormat('MM/dd/yyyy').format(fromDate!);
    final toTxt   = toDate   == null ? "-" : DateFormat('MM/dd/yyyy').format(toDate!);
    final destTxt = destinationController.text.trim().isEmpty
        ? "-"
        : destinationController.text.trim();

    showVehicleSubmitDialog(
      context:        context,
      vehicleNoTxt:   vehicleNoTxt,
      fromTxt:        fromTxt,
      toTxt:          toTxt,
      destinationTxt: destTxt,
      isSubmitting:   _isSubmitting,
      onConfirm:      _submitForm,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── User details (compact card) ───────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDDE5F8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFDDE5F8)),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _infoCell('Name', nameController.text, Icons.badge_outlined)),
                        const SizedBox(width: 20),
                        Expanded(child: _infoCell('Employee No.', employeeController.text, Icons.tag_rounded)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _infoCell('Department', departmentController.text, Icons.apartment_rounded)),
                        const SizedBox(width: 20),
                        Expanded(child: _infoCell('Contact No.', contactController.text, Icons.phone_outlined)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const FormSectionTitle("Reason for request"),
              const SizedBox(height: 8),
              const ReadonlyInfoField(value: "Office Service"),

              const SizedBox(height: 16),

              // ── From / To date (unchanged) ────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FormSectionTitle("From date *"),
                        const SizedBox(height: 8),
                        _buildDatePicker("From date", fromDate, (d) {
                          setState(() {
                            fromDate = d;
                            if (toDate != null && toDate!.isBefore(d)) toDate = null;
                          });
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FormSectionTitle("To date *"),
                        const SizedBox(height: 8),
                        _buildDatePicker("To date", toDate,
                            (d) => setState(() => toDate = d),
                            minDate: fromDate),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Vehicle number (unchanged) ────────────────────────────
              const FormSectionTitle("Vehicle Number"),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _vehicleLettersController,
                      style: const TextStyle(color: Colors.black, fontSize: 15),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        TextInputFormatter.withFunction((old, nv) =>
                            nv.copyWith(text: nv.text.toUpperCase())),
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z]')),
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: _inputDecoration("Letters (e.g. ABC)",
                          icon: Icons.directions_car_outlined),
                      validator: (v) {
                        final val = (v ?? '').trim();
                        if (val.length < 2 || val.length > 3) {
                          return '2 or 3 letters required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    child: Text("-",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54)),
                  ),
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _vehicleNumbersController,
                      style: const TextStyle(color: Colors.black, fontSize: 15),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: _inputDecoration("Numbers (e.g. 1234)"),
                      validator: (v) {
                        final val = (v ?? '').trim();
                        if (val.length != 4) return 'Enter exactly 4 digits';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Total days
              if (fromDate != null && toDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Days',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E2A3A))),
                      Text('${toDate!.difference(fromDate!).inDays + 1} days',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E2A3A))),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ── Destination (unchanged) ───────────────────────────────
              const FormSectionTitle("Destination *"),
              const SizedBox(height: 8),
              TypeAheadField<PlaceSuggestion>(
                controller:       destinationController,
                focusNode:        _destinationFocusNode,
                debounceDuration: const Duration(milliseconds: 400),
                suggestionsCallback: fetchPlaceSuggestions,
                loadingBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Colors.blue,
                          backgroundColor: Colors.white,
                          strokeWidth: 2)),
                ),
                itemBuilder: (context, s) => ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(s.description),
                ),
                onSelected: (s) {
                  destinationController.text = s.description;
                  _destinationFocusNode.unfocus();
                },
                builder: (context, controller, focusNode) => TextFormField(
                  controller: controller,
                  focusNode:  focusNode,
                  style: const TextStyle(color: Colors.black),
                  decoration: _inputDecoration("Enter your destination",
                      icon: Icons.location_on_outlined),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
              ),

              const SizedBox(height: 20),

              // ── Going With (NEW) ──────────────────────────────────────
              const FormSectionTitle("Going With "),
              //_buildSectionHeader('Going With', Icons.group_outlined),
              const SizedBox(height: 4),
              const Text(
                'Select staff members accompanying you (optional)',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const SizedBox(height: 10),
              _buildStaffSelector(),

              const SizedBox(height: 20),

              
            const SizedBox(height: 2),

            // ── Remark (Optional) ──────────────────────────────────────────────────
            const FormSectionTitle("Remark (Optional)"),
            const SizedBox(height: 8),
            TextFormField(
              controller: remarkController,
              style: const TextStyle(color: Colors.black, fontSize: 15),
              maxLines: 2,
              maxLength: 300,
              decoration: _inputDecoration(
                "Enter any additional notes or remarks...",
              ),
              // No validator — field is optional
            ),

              // ── Approving Manager (unchanged) ─────────────────────────
              const FormSectionTitle("Select Approving Manager *"),
              const SizedBox(height: 8),
              if (managers.isEmpty)
                const Text("No managers found")
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E6EF)),
                  ),
                  child: Column(
                    children: managers.map((m) {
                      final mId  = (m["id"] ?? "").toString();
                      final eId  = int.tryParse(mId) ?? 0;
                      return RadioListTile<String>(
                        value:            mId,
                        groupValue:       selectedManagerId,
                        onChanged:        (v) => setState(() => selectedManagerId = v),
                        controlAffinity:  ListTileControlAffinity.trailing,
                        fillColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) return Colors.blue;
                          return Colors.grey;
                        }),
                        secondary: FutureBuilder<Map<String, dynamic>?>(
                          future: eId > 0 ? _getPhotoFuture(eId) : Future.value(null),
                          builder: (context, snap) {
                            final url = (snap.data?["fileUrl"] ?? "").toString().trim();
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFEAF1FF),
                                child: SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        backgroundColor: Colors.white,
                                        color: Colors.blue,
                                        strokeWidth: 2)),
                              );
                            }
                            if (url.isNotEmpty) {
                              return CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFFEAF1FF),
                                  backgroundImage: NetworkImage(url));
                            }
                            return const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFEAF1FF),
                                child: Icon(Icons.person, size: 18, color: Colors.black54));
                          },
                        ),
                        title: Text((m["name"] ?? "-").toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87)),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 18),

              GradientSubmitButton(
                label:     'SUBMIT',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _showVehicleSubmitConfirmation,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Staff selector (identical to gate pass) ───────────────────────────────
  Widget _buildStaffSelector() {
    if (_loadingStaff) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(
              color: Color(0xFF1565C0), strokeWidth: 2),
        ),
      );
    }

    if (_staffError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3F3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_staffError!,
                    style: const TextStyle(fontSize: 12, color: Colors.black54))),
            TextButton(
              onPressed: _loadAllStaff,
              child: const Text('Retry',
                  style: TextStyle(color: Color(0xFF1565C0))),
            ),
          ],
        ),
      );
    }

    if (_allStaff.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No staff members found.',
            style: TextStyle(color: Colors.black45)),
      );
    }

    final filtered = _staffSearchQuery.isEmpty
        ? _allStaff
        : _allStaff
            .where((s) =>
                s.name.toLowerCase().contains(_staffSearchQuery.toLowerCase()) ||
                s.jobTitle.toLowerCase().contains(_staffSearchQuery.toLowerCase()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Search bar
        TextFormField(
          controller: _staffSearchCtrl,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          decoration: _inputDecoration(
            'Search by name or job title…',
            icon: Icons.search,
            suffix: _staffSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() {
                      _staffSearchCtrl.clear();
                      _staffSearchQuery = '';
                    }),
                  )
                : null,
          ),
          onChanged: (v) => setState(() => _staffSearchQuery = v),
        ),

        // Selected chips
        if (_selectedStaffIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _allStaff
                .where((s) => _selectedStaffIds.contains(s.id))
                .map((s) => Chip(
                      avatar: FutureBuilder<Map<String, dynamic>?>(
                        future: _getStaffPhotoFuture(s.id),
                        builder: (_, snap) {
                          final url = (snap.data?['fileUrl'] ?? '').toString().trim();
                          if (url.isNotEmpty) {
                            return CircleAvatar(backgroundImage: NetworkImage(url));
                          }
                          return const CircleAvatar(
                            backgroundColor: Color(0xFF1565C0),
                            child: Icon(Icons.person, size: 12, color: Colors.white),
                          );
                        },
                      ),
                      label: Text(s.name,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFFEAF1FF),
                      side: const BorderSide(color: Color(0xFFB3C8F0)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () =>
                          setState(() => _selectedStaffIds.remove(s.id)),
                    ))
                .toList(),
          ),
        ],

        const SizedBox(height: 10),

        // Staff list
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1E6EF)),
          ),
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                      child: Text('No results found',
                          style: TextStyle(color: Colors.black45))),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFEEF2F8)),
                  itemBuilder: (ctx, i) {
                    final staff    = filtered[i];
                    final selected = _selectedStaffIds.contains(staff.id);
                    return InkWell(
                      onTap: () => setState(() => selected
                          ? _selectedStaffIds.remove(staff.id)
                          : _selectedStaffIds.add(staff.id)),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            FutureBuilder<Map<String, dynamic>?>(
                              future: _getStaffPhotoFuture(staff.id),
                              builder: (_, snap) {
                                final url = (snap.data?['fileUrl'] ?? '').toString().trim();
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Color(0xFFEAF1FF),
                                    child: SizedBox(
                                      width: 12, height: 12,
                                      child: CircularProgressIndicator(
                                          color: Color(0xFF1565C0), strokeWidth: 1.5),
                                    ),
                                  );
                                }
                                if (url.isNotEmpty) {
                                  return CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFEAF1FF),
                                    backgroundImage: NetworkImage(url),
                                  );
                                }
                                return const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0xFFEAF1FF),
                                  child: Icon(Icons.person, size: 18, color: Colors.black45),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(staff.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(staff.jobTitle,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.black45),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF1565C0)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF1565C0)
                                      : const Color(0xFFCDD5E0),
                                  width: 1.5,
                                ),
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── UI helpers (unchanged) ────────────────────────────────────────────────
  InputDecoration _inputDecoration(String hint,
      {IconData? icon, Widget? suffix}) {
    return InputDecoration(
      hintText:   hint,
      hintStyle:  TextStyle(color: Colors.grey.shade600),
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade700) : null,
      suffixIcon: suffix,
      filled:     true,
      fillColor:  Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.blue, width: 1.4),
      ),
      errorStyle: const TextStyle(
          color: Color(0xFFD32F2F),
          fontWeight: FontWeight.w700,
          fontSize: 12.5),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? selected,
    Function(DateTime) onSelect, {
    DateTime? minDate,
  }) {
    return TextFormField(
      readOnly: true,
      style: const TextStyle(color: Colors.black, fontSize: 15),
      decoration: _inputDecoration(label,
          suffix: Icon(Icons.calendar_today, color: Colors.grey.shade700)),
      controller: TextEditingController(
        text: selected == null ? '' : DateFormat('MM/dd/yyyy').format(selected),
      ),
      validator: (_) => selected == null ? 'Required' : null,
      onTap: () async {
        final now       = DateTime.now();
        final firstDate = minDate ?? DateTime(now.year, now.month, now.day);
        final initial   = selected ?? (now.isBefore(firstDate) ? firstDate : now);
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate:   firstDate,
          lastDate:    DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary:   Color(0xFF1565C0),
                onPrimary: Colors.white,
                surface:   Colors.white,
                onSurface: Color(0xFF1E2A3A),
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          ),
        );
        if (picked != null) onSelect(picked);
      },
    );
  }

  Widget _infoCell(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF8A9BB0)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A97AD),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '—' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2A3A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}