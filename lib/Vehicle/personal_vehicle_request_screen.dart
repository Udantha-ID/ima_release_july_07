import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Leaves/dashbord_screen.dart';
import '../ui/dialogs/vehicle_submit_dialog.dart';
import '../ui/dialogs/personal_vehicle_policy_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Services/transport_service_config.dart';
import '../Leaves/top_banner.dart';
import 'dart:convert';
import '../Services/api_service.dart';
import '../ui/widgets/common_form_widgets.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;


class PersonalVehicleRequestScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onRequestSubmitted;

  const PersonalVehicleRequestScreen({super.key, required this.user, this.onRequestSubmitted});

  @override
  State<PersonalVehicleRequestScreen> createState() => _PersonalVehicleRequestScreenState();
}

// Google Places API Key  
const String googlePlacesKey = "AIzaSyAHmbwBrk0OKY0Nhp9FrR_zn8HKLGZ54OU";

class PlaceSuggestion {
  final String description;
  final String placeId;

  PlaceSuggestion({required this.description, required this.placeId});

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      description: json['description'],
      placeId: json['place_id'],
    );
  }
}

class AvailableVehicleOption {
  final int id;
  final String regNo;
  final String make;
  final String model;
  final String vehicleTypeName;

  AvailableVehicleOption({
    required this.id,
    required this.regNo,
    required this.make,
    required this.model,
    required this.vehicleTypeName,
  });

  factory AvailableVehicleOption.fromJson(Map<String, dynamic> json) {
    return AvailableVehicleOption(
      id: int.tryParse((json["id"] ?? "").toString()) ?? 0,
      regNo: (json["reg_no"] ?? "").toString().trim(),
      make: (json["make"] ?? "").toString().trim(),
      model: (json["model"] ?? "").toString().trim(),
      vehicleTypeName: (json["vehicle_type_name"] ?? "").toString().trim(),
    );
  }

  String get displayLabel => "$regNo - ${"$make $model".trim()}";
}

Future<List<PlaceSuggestion>> fetchPlaceSuggestions(String input) async {
  input = input.trim();
  if (input.isEmpty) return [];

  final uri = Uri.https(
    "maps.googleapis.com",
    "/maps/api/place/autocomplete/json",
    {
      "input": input,
      "key": googlePlacesKey,
      "components": "country:lk",
    },
  );

  final res = await http.get(uri);
  final body = res.body;
  final data = jsonDecode(body) as Map<String, dynamic>;

  final status = (data["status"] ?? "").toString();
  final err = (data["error_message"] ?? "").toString();

  debugPrint("Places status=$status code=${res.statusCode} err=$err");

  if (res.statusCode != 200) return [];
  if (status != "OK") return [];

  final preds = (data["predictions"] as List? ?? []);
  return preds
      .map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>))
      .toList();
}

class _PersonalVehicleRequestScreenState extends State<PersonalVehicleRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _policyDialogVisible = false;
  bool _policyAccepted = false;

  // Read-only user details
  final nameController = TextEditingController();
  final employeeController = TextEditingController();
  final departmentController = TextEditingController();
  final contactController = TextEditingController();

  // Fields
  final destinationController = TextEditingController();

  DateTime? fromDate;
  DateTime? toDate;

  String? vehicleError;
  String? vehicleTypeName;
  int _checkGeneration = 0;
  final TextEditingController _availableVehicleController = TextEditingController();
  List<AvailableVehicleOption> _availableVehicles = [];
  AvailableVehicleOption? _selectedVehicle;
  bool _isLoadingAvailableVehicles = false;
  String? _availableVehicleError;

  // Manager
  List<Map<String, String>> managers = [];
  String? selectedManagerId;
  bool loadingManagers = true;
  String? managerError;
  String? reportingManagerId;

  bool _isSubmitting = false;

  int _previousRequestCount = 0;
  bool _loadingRequestCount = true;
  static const int _maxFocDaysPerRequest = 2;
  static const int _maxHalfOffDaysPerRequest = 3;

  int? vehicleId;

  // Photo cache for manager avatars
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};
  final remarkController = TextEditingController();


//check if the vehicle type is a car type
  bool _isCarTypeForFreeAttempt(String? typeName) {
    final t = (typeName ?? "").trim().toLowerCase();
    return t.contains("car");
  }

  @override
  void initState() {
    super.initState();
    _loadManagers();
    _loadRequestCount();

    nameController.text = widget.user['name'] ?? '';
    employeeController.text = widget.user['employeeCode'] ?? '';
    departmentController.text = widget.user['department'] ?? '';
    contactController.text = widget.user['phone'] ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) => _enforcePolicyAcceptance());
  }

  @override
  void dispose() {
    _availableVehicleController.dispose();
    remarkController.dispose();
    super.dispose();
  }

  Future<void> _enforcePolicyAcceptance() async {
    if (!mounted || _policyAccepted || _policyDialogVisible) {
      return;
    }
    _policyDialogVisible = true;

    final agreed = await showPersonalVehiclePolicyDialog(context: context);
    _policyDialogVisible = false;
    if (!mounted) return;

    if (agreed) {
      setState(() => _policyAccepted = true);
      return;
    }

    TopBanner.show(
      context,
      title: "Policy Required",
      message: "You must agree to the vehicle policy to continue.",
      icon: Icons.error_outline,
      isSuccess: false,
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => DashboardScreen(user: widget.user)),
      (route) => false,
    );
  }

  Future<void> _loadRequestCount() async {
    try {
      final employeeId = widget.user["employeeId"]?.toString() ?? "";

      final count = await VehicleApiService.getPersonalUsageCount(employeeId);

      if (!mounted) return;

      setState(() {
        _previousRequestCount = count;
        _loadingRequestCount = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loadingRequestCount = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load usage count: $e")),
      );
    }
  }

    Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
    return _photoFutureCache.putIfAbsent(
      employeeId,
      () => ApiService.getProfilePhoto(employeeId: employeeId),
    );
  }

Future<void> _loadManagers() async {
  try {
    setState(() {
      loadingManagers = true;
      managerError = null;
    });

    final empId = widget.user["employee_id"]?.toString()
        ?? widget.user["employeeId"]?.toString()
        ?? "";

    if (empId.isEmpty) throw Exception("employee_id missing in login data");

    final res = await VehicleApiService.getDefaultManagers(
      employeeId: int.parse(empId),
    );

    if (res["success"] != true) {
      throw Exception(res["message"] ?? "API failed");
    }

    final data = res["data"] ?? {};
    final raw  = List.from(data["managers"] ?? []);

    // ── KEY FIX: use the API's returned manager ID, not widget.user ──
    // The API already resolved the fallback chain (unavailable/on-leave managers
    // are skipped and replaced with HR → GM → Director in order).
    final resolvedManagerId = data["reporting_manager_id"]?.toString();

    final list = raw.map<Map<String, String>>((e) {
      return {
        "id":   e["id"].toString(),
        "name": (e["name"] ?? "").toString(),
      };
    }).toList();

    setState(() {
      managers          = list;
      // Use API-resolved manager as the pre-selected and displayed manager
      reportingManagerId = resolvedManagerId;
      selectedManagerId  = resolvedManagerId;
      loadingManagers    = false;
    });

    // Optional debug — remove before release
    debugPrint("Resolved manager: $resolvedManagerId");
    debugPrint("Fallback reason: ${data["fallback_reason"]}");

  } catch (e) {
    setState(() {
      loadingManagers   = false;
      managerError      = e.toString();
      managers          = [];
      selectedManagerId = null;
    });
  }
}

Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;
  if (fromDate == null || toDate == null) return;

  final attempt = _previousRequestCount + 1;
  final isFreeAttempt = attempt <= 2;
  final isHalfOffAttempt = attempt >= 3 && attempt <= 5;
  final requestedDays = toDate!.difference(fromDate!).inDays + 1;
  if (isFreeAttempt && requestedDays > _maxFocDaysPerRequest) {
     TopBanner.show(
            context,
            title: "Request Failed",
            message: "Free requests are limited to maximum 2 days per request.",
            icon: Icons.error,
            isSuccess: false,
        );
    return;
  }
  if (isHalfOffAttempt && requestedDays > _maxHalfOffDaysPerRequest) {
     TopBanner.show(
            context,
            title: "Request Failed",
            message: "50% off requests are limited to maximum 3 days per request.",
            icon: Icons.error,
            isSuccess: false,
        );
    return;
  }
  if (isFreeAttempt && !_isCarTypeForFreeAttempt(vehicleTypeName)) {
     TopBanner.show(
            context,
            title: "Request Failed",
            message: "For the 1st and 2nd free attempts, only Car type vehicles are allowed.",
            icon: Icons.error,
            isSuccess: false,
        );
    return;
  }

  if (_isLoadingAvailableVehicles) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please wait for vehicle availability check to complete.")),
    );
    return;
  }
  if (_selectedVehicle == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select an available vehicle.")),
    );
    return;
  }

  setState(() => _isSubmitting = true);

  try {
    String _employeeIdFromUser() {
      final u = widget.user;
      final v = u["employee_id"] ?? u["employeeId"] ?? u["id"] ?? u["user_id"];
      return (v ?? "").toString().trim();
    }
    final empId = _employeeIdFromUser();
    final managerId = selectedManagerId!;
    final employeeName = nameController.text.trim();
    final employeePhone = contactController.text.trim();

    final vehicleNo = _selectedVehicle!.regNo;

    final fromDateTxt = DateFormat("yyyy-MM-dd").format(fromDate!);
    final toDateTxt = DateFormat("yyyy-MM-dd").format(toDate!);

    final vehicleType = _selectedVehicle!.vehicleTypeName.isEmpty
        ? (vehicleTypeName ?? "-")
        : _selectedVehicle!.vehicleTypeName;

    debugPrint("[SubmitForm] ── Payload ──────────────────────");
    debugPrint("[SubmitForm] employeeId  : $empId");
    debugPrint("[SubmitForm] managerId   : $managerId");
    debugPrint("[SubmitForm] vehicleNo   : $vehicleNo");
    debugPrint("[SubmitForm] vehicleType : $vehicleType");
    debugPrint("[SubmitForm] vehicleId   : $vehicleId");
    debugPrint("[SubmitForm] fromDate    : $fromDateTxt");
    debugPrint("[SubmitForm] toDate      : $toDateTxt");
    debugPrint("[Remark] remark: ${remarkController.text}");
    debugPrint("[SubmitForm] ────────────────────────────────");

    final res = await VehicleApiService.createPersonalVehicleRequest(
      employeeId: empId,
      managerId: managerId,
      vehicleNo: vehicleNo,
      fromDate: fromDateTxt,
      toDate: toDateTxt,
      //destination: destinationController.text.trim(),
      contactNo: employeePhone,
      employeeName: employeeName,
      reason: "Personal Request",
      vehicleType: vehicleType,  // ← new optional param
      vehicleId: _selectedVehicle!.id, // <-- pass the ID here
      remark:       remarkController.text.trim().isEmpty
                    ? null
                    : remarkController.text.trim(), // ← read controller HERE
      
    );
    print("Vehicle Type Name: $vehicleType");

    if (res["success"] == true) {
          if (!mounted) return;

          TopBanner.show(
            context,
            title: "Request Submitted",
            message: "Your vehicle request has been submitted successfully.",
            icon: Icons.check_circle,
            isSuccess: true,
      );
      if (widget.onRequestSubmitted != null) {
        widget.onRequestSubmitted!();
      } else {
        Navigator.pop(context);
      }
    } else {
      throw Exception(res["message"] ?? "Submission failed");
    }
  } catch (e) {
    if (!mounted) return;
    final errText = e
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
    TopBanner.show(
      context,
      title: "Submission Failed",
      message: errText.isEmpty ? "Something went wrong." : errText,
      icon: Icons.error_outline,
      isSuccess: false,
    );
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}
void _showVehicleSubmitConfirmation() {
  final vehicleNoTxt = _selectedVehicle?.regNo ?? "-";

  final fromTxt = fromDate == null ? "-" : DateFormat('MM/dd/yyyy').format(fromDate!);
  final toTxt = toDate == null ? "-" : DateFormat('MM/dd/yyyy').format(toDate!);

  final destinationTxt = destinationController.text.trim().isEmpty
      ? "-"
      : destinationController.text.trim();

  showVehicleSubmitDialog(
    context: context,
    vehicleNoTxt: vehicleNoTxt,
    fromTxt: fromTxt,
    toTxt: toTxt,
    destinationTxt: destinationTxt,
    isSubmitting: _isSubmitting,
    onConfirm: _submitForm,
    showDestination: false,
  );
}

    Future<void> _fetchAvailableVehicles() async {
      if (fromDate == null || toDate == null) {
        setState(() {
          _availableVehicles = [];
          _selectedVehicle = null;
          _availableVehicleController.clear();
          _availableVehicleError = null;
          vehicleTypeName = null;
          vehicleId = null;
          _isLoadingAvailableVehicles = false;
        });
        return;
      }
      final gen = ++_checkGeneration;

      setState(() {
        _isLoadingAvailableVehicles = true;
        _availableVehicleError = null;
        _availableVehicles = [];
        _selectedVehicle = null;
        _availableVehicleController.clear();
        vehicleTypeName = null;
        vehicleId = null;
        vehicleError = null;
      });

      try {
        final start = DateFormat("yyyy-MM-dd").format(fromDate!);
        final end = DateFormat("yyyy-MM-dd").format(toDate!);
        final uri = Uri.parse(TransportServiceConfig.availableVehiclesUrl).replace(
          queryParameters: {
            "start_date": start,
            "end_date": end,
          },
        );

        final response = await http.get(
          uri,
          headers: const {"Accept": "application/json"},
        );

        if (gen != _checkGeneration) return;
        final body = response.body.trim();
        if (body.isEmpty) {
          setState(() {
            _availableVehicleError = "No response from server.";
            _isLoadingAvailableVehicles = false;
          });
          return;
        }

        final payload = Map<String, dynamic>.from(jsonDecode(body) as Map);
        final attempt = _previousRequestCount + 1;
        final isFreeAttempt = attempt <= 2;
        final list = (payload["data"] as List? ?? [])
            .whereType<Map>()
            .map((e) => AvailableVehicleOption.fromJson(Map<String, dynamic>.from(e)))
            .where((v) => v.id > 0 && v.regNo.isNotEmpty)
            .where((v) {
              if (!isFreeAttempt) return true;
              return _isCarTypeForFreeAttempt(v.vehicleTypeName);
            })
            .toList();

        if (payload["success"] != true) {
          setState(() {
            _availableVehicleError = (payload["message"] ?? "Could not load available vehicles.").toString();
            _isLoadingAvailableVehicles = false;
          });
          return;
        }

        setState(() {
          _availableVehicles = list;
          _availableVehicleError = list.isEmpty
              ? (isFreeAttempt
                    ? "No available Car type vehicles for selected dates."
                    : "No available vehicles for selected dates.")
              : null;
          _isLoadingAvailableVehicles = false;
        });
      } catch (_) {
        if (gen != _checkGeneration) return;
        setState(() {
          _availableVehicleError = "Could not load available vehicles. Please try again.";
          _isLoadingAvailableVehicles = false;
        });
      }
    }
  

  

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
              // ---------------- DISCOUNT NOTICE ----------------
              _buildDiscountNotice(),
              const SizedBox(height: 16),

              // ---------------- YOUR DETAILS (compact card) ----------------
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

              // Reason (read-only)
              const FormSectionTitle("Reason for request"),
              const SizedBox(height: 8),
              const ReadonlyInfoField(value: "Personal Request"),

              const SizedBox(height: 16),

                            // From / To date
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
                            if (toDate != null && toDate!.isBefore(d)) {
                              toDate = null;
                            }
                          });

                          _fetchAvailableVehicles();
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
                        _buildDatePicker("To date", toDate, (d) {
                          setState(() => toDate = d);
                          _fetchAvailableVehicles();
                        }, minDate: fromDate),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Available vehicles
              const FormSectionTitle("Available Vehicle *"),
              const SizedBox(height: 8),
              TypeAheadField<AvailableVehicleOption>(
                controller: _availableVehicleController,
                hideOnEmpty: true,
                hideOnError: false,
                hideOnUnfocus: false,
                hideWithKeyboard: false,
                decorationBuilder: (context, child) => Material(
                  color: Colors.white,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
                suggestionsCallback: (pattern) {
                  final q = pattern.trim().toLowerCase();
                  if (q.isEmpty) return _availableVehicles;
                  return _availableVehicles.where((vehicle) {
                    final full = "${vehicle.regNo} ${vehicle.make} ${vehicle.model} ${vehicle.vehicleTypeName}".toLowerCase();
                    return full.contains(q);
                  }).toList();
                },
                itemBuilder: (context, suggestion) => ListTile(
                  dense: true,
                  tileColor: Colors.white,
                  title: Text(
                    suggestion.displayLabel,
                    style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                  ),
                  subtitle: Text(
                    suggestion.vehicleTypeName,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                onSelected: (suggestion) {
                  setState(() {
                    _selectedVehicle = suggestion;
                    _availableVehicleController.text = suggestion.displayLabel;
                    vehicleId = suggestion.id;
                    vehicleTypeName = suggestion.vehicleTypeName;
                    vehicleError = null;
                  });
                },
                builder: (context, controller, focusNode) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.black, fontSize: 15),
                    decoration: _inputDecoration(
                      "Search vehicle by number or model",
                      icon: Icons.directions_car_outlined,
                    ),
                    validator: (_) {
                      if (fromDate == null || toDate == null) return "Select date range first";
                      if (_selectedVehicle == null) return "Please select an available vehicle";
                      return null;
                    },
                  );
                },
                emptyBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("No matching vehicles found."),
                ),
              ),
              if (_isLoadingAvailableVehicles)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Loading available vehicles...",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_isLoadingAvailableVehicles && _availableVehicleError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _availableVehicleError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_isLoadingAvailableVehicles && _selectedVehicle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        "Selected: ${_selectedVehicle!.regNo} · Type: ${_selectedVehicle!.vehicleTypeName}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              const SizedBox(height: 10),
                if (fromDate != null && toDate != null)
                  Builder(
                    builder: (_) {
                      final attempt = _previousRequestCount + 1;
                      final isFreeAttempt = attempt <= 2;
                      final isHalfOffAttempt = attempt >= 3 && attempt <= 5;
                      final requestedDays = toDate!.difference(fromDate!).inDays + 1;
                      final isOverFreeLimit =
                          isFreeAttempt && requestedDays > _maxFocDaysPerRequest;
                      final isOverHalfOffLimit =
                          isHalfOffAttempt && requestedDays > _maxHalfOffDaysPerRequest;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF1FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Days',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E2A3A)),
                                ),
                                Text(
                                  '$requestedDays days',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF1E2A3A)),
                                ),
                              ],
                            ),
                          ),
                          if (isOverFreeLimit)
                            const Padding(
                              padding: EdgeInsets.only(top: 8, left: 2),
                              child: Text(
                                'Free requests are limited to maximum 2 days per request.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                            ),
                          if (isOverHalfOffLimit)
                            const Padding(
                              padding: EdgeInsets.only(top: 8, left: 2),
                              child: Text(
                                '50% off requests are limited to maximum 3 days per request.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

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

            const SizedBox(height: 16),

              // Approving Manager dropdown
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

                    // Only show the manager that matches reportingManagerId
                    children: managers
                      .where((m) => m["id"].toString() == reportingManagerId)
                      .map((m) {
                      final managerId = (m["id"] ?? "").toString();
                      final empId = int.tryParse(managerId) ?? 0;

                      return RadioListTile<String>(
                        value: managerId,
                        groupValue: selectedManagerId,
                        onChanged: (v) => setState(() => selectedManagerId = v),

                        // radio on right
                        controlAffinity: ListTileControlAffinity.trailing,

                        // radio color
                        fillColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) return Colors.blue;
                          return Colors.grey;
                        }),

                        // photo on left
                        secondary: FutureBuilder<Map<String, dynamic>?>(
                          future: empId > 0 ? _getPhotoFuture(empId) : Future.value(null),
                          builder: (context, snap) {
                            final url = (snap.data?["fileUrl"] ?? "").toString().trim();

                            if (snap.connectionState == ConnectionState.waiting) {
                              return const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFEAF1FF),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    backgroundColor: Colors.white,
                                    color: Colors.blue,
                                    strokeWidth: 2),
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
                              child: Icon(Icons.person, size: 18, color: Colors.black54),
                            );
                          },
                        ),

                        // name
                        title: Text(
                          (m["name"] ?? "-").toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 18),
              // Submit
            GradientSubmitButton(
              label: 'SUBMIT',
              isLoading: _isSubmitting,
              onPressed: (_isLoadingAvailableVehicles || _selectedVehicle == null || _availableVehicleError != null)
                  ? null
                  : _showVehicleSubmitConfirmation,
            ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------
  // Same input style as login/leave form - clear on all devices
  InputDecoration _inputDecoration(String hint, {IconData? icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade600),
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade700) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
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
        fontSize: 12.5,
      ),
    );
  }
  // ── Discount notice ──────────────────────────────────────────────────────
  Widget _buildDiscountNotice() {
    // usage_count from API IS the current attempt number (server increments before we load the form)
    final usageCount = _previousRequestCount;
    final attempt = _previousRequestCount + 1; // no +1: usage_count already equals the attempt number

    String discount;
    Color discountColor;
    if (attempt <= 2) {
      discount = "FREE";
      discountColor = const Color(0xFF2E7D32);
    } else if (attempt <= 5) {
      discount = "50% OFF";
      discountColor = const Color(0xFF1565C0);
    } else {
      discount = "0%";
      discountColor = const Color(0xFFB71C1C);
    }

    final tableRows = [
      ["1",  "1st",  "100%", "2", "Mini/Sedan"],
      ["2",  "2nd",  "100%", "2", "Mini/Sedan"],
      ["3",  "3rd",  "50%",  "3", "Mini/Sedan/Compact SUV"],
      ["4",  "4th",  "50%",  "3", "Mini/Sedan/Compact SUV"],
      ["5",  "5th",  "50%",  "3", "Mini/Sedan/Compact SUV"],
      ["6+", "6th+", "0%",   "-", "Not under policy"],
    ];

    String currentKey = attempt >= 6 ? "6+" : attempt.toString();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDD0F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 15),
                SizedBox(width: 7),
                Text(
                  "Personal Vehicle Request Policy",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Current attempt summary ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: _loadingRequestCount
                ? const Row(children: [
                    SizedBox(
                      width: 13, height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1565C0)),
                    ),
                    SizedBox(width: 8),
                    Text("Loading your request info...",
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7A90))),
                  ])
                : Row(
                    children: [
                      _statBox("Your Attempt", "#$attempt", const Color(0xFF1E2A3A)),
                      const SizedBox(width: 14),
                      _statBox("Discount", discount, discountColor),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: const Color(0xFFBDD0F8)),
                        ),
                        child: Text(
                          "Usage count: $usageCount",
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2A3A),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFCDDAF8)),

          // ── Policy table ──
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DISCOUNT POLICY",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7A90),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Table(
                    border: TableBorder.all(
                      color: const Color(0xFFCDDAF8),
                      width: 1,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(1.1),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1.6),
                    },
                    children: [
                      // Header row
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFD6E4FF)),
                        children: [
                          _tableCell("Attempt", isHeader: true),
                          _tableCell("Discount", isHeader: true),
                          _tableCell("Max Days", isHeader: true),
                          _tableCell("Category", isHeader: true),
                        ],
                      ),
                      // Data rows
                      ...tableRows.map((r) {
                        final isCurrent = r[0] == currentKey;
                        return TableRow(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFFE3EDFF)
                                : Colors.white,
                          ),
                          children: [
                            _tableCell(r[1], isCurrent: isCurrent),
                            _tableCell(r[2], isCurrent: isCurrent, isDiscount: true),
                            _tableCell(r[3], isCurrent: isCurrent),
                            _tableCell(r[4], isCurrent: isCurrent),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10.5, color: Color(0xFF6B7A90), fontWeight: FontWeight.w600)),
        const SizedBox(height: 1),
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: valueColor)),
      ],
    );
  }

  Widget _tableCell(String text,
      {bool isHeader = false, bool isCurrent = false, bool isDiscount = false}) {
    Color textColor = const Color(0xFF1E2A3A);
    if (isHeader) textColor = const Color(0xFF1565C0);
    if (isDiscount && !isHeader) {
      if (text == "100%")      textColor = const Color(0xFF2E7D32);
      else if (text == "50%")  textColor = const Color(0xFF1565C0);
      else if (text == "25%")  textColor = const Color(0xFFE65100);
      else                     textColor = const Color(0xFFB71C1C);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: (isHeader || isCurrent) ? FontWeight.w800 : FontWeight.w600,
          color: textColor,
        ),
      ),
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
      decoration: _inputDecoration(
        label,
        suffix: Icon(Icons.calendar_today, color: Colors.grey.shade700),
      ),
      controller: TextEditingController(
        text: selected == null ? '' : DateFormat('MM/dd/yyyy').format(selected),
      ),
      validator: (_) => selected == null ? 'Required' : null,
      onTap: () async {
        final now = DateTime.now();

        final firstDate = minDate ?? DateTime(now.year, now.month, now.day);

        final initialDate = selected ??
            (now.isBefore(firstDate) ? firstDate : now);

        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF1565C0),
                onPrimary: Colors.white,
                surface: Colors.white,
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