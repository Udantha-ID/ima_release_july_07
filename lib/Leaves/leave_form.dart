import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:test_app/Services/api_service.dart';
import 'dart:ui';
import 'dart:io';
import 'package:test_app/ui/dialogs/leave_submit_dialog.dart';
import 'package:test_app/ui/widgets/common_form_widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'leave_history_screen.dart';
import 'top_banner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';



class LeaveFormScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const LeaveFormScreen({super.key, required this.user});

  @override
  _LeaveFormScreenState createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final nameController = TextEditingController();
  final employeeController = TextEditingController();
  final departmentController = TextEditingController();
  final contactController = TextEditingController();
  final reasonController = TextEditingController();
  final addressController = TextEditingController();

  // Leave type
  String? selectedLeaveType;

  // Dates
  DateTime? fromDate;
  DateTime? toDate;

  // File (mock)
  File? attachedFile;
  String? attachedFileName;

  // Example leave types
  final leaveTypes = ['Annual Leave', 'Medical Leave', 'Casual Leave', 'Half Day'];

  bool isHalfDay = false;
  String? halfDaySession; // 'MORNING' or 'EVENING'


  //Filtered members
  List<Map<String, String>> availableMembers = [];

  String? selectedMember;
  bool noMemberConfirmed = false;

  // show loading on Send button
  bool _isSubmitting = false;

  // inline field errors for non-FormField widgets
  String? _memberError;
  String? _confirmError;

  // No Pay Leave split state
  double? _remainingBalance;
  double  _paidDays  = 0;
  double  _noPayDays = 0;
  bool    _noPayAcknowledged = false;
  String? _noPayError;

  // Multi-select calendar (Annual Leave)
  Set<DateTime> _selectedDates = {};

  // Annual Leave remaining balance — drives adaptive minimum days
  double? _annualLeaveRemaining;

  // Approving manager
  List<Map<String, String>> _leaveManagers = [];
  String? _selectedManagerId;
  bool _loadingManagers = true;
  String? _managerError;

  // Manager employee IDs (fetched from server)
  List<String> _managerIds = [];

  // Cache for profile photo futures to avoid redundant API calls
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

  // For picking profile photo in member list
  final ImagePicker _picker = ImagePicker();

  bool _isImageFile(String? name) {
  if (name == null) return false;

  final lower = name.toLowerCase();

  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp');
}

  // Check if the user is a manager, based on IDs fetched from the server
  bool get _isManager {
    final empId = (widget.user["employeeId"] ?? widget.user["employee_id"] ?? "")
        .toString().trim();
    return _managerIds.contains(empId);
  }



  // Same input style as login/forgot password - clear on all devices
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

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
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

@override
void initState() {
  super.initState();
  debugPrint("FORM USER DATA: ${widget.user}");
  
  nameController.text = widget.user['name'] ?? '';
  employeeController.text = widget.user['employeeCode'] ?? '';
  departmentController.text = widget.user['department'] ?? '';
  contactController.text = widget.user['phone'] ?? '';

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _recoverLostData();
  });

  // Load manager IDs first — this drives _isManager check
  _loadManagerIds();
  _loadLeaveManagers();
}

Future<void> _loadManagerIds() async {
  final ids = await ApiService.getManagerIds();
  if (!mounted) return;
  setState(() {
    _managerIds = ids;
    // Auto-confirm no reliever if this user is a manager
    if (_isManager) {
      noMemberConfirmed = true;
    }
  });
}

Future<void> _loadLeaveManagers() async {
  try {
    setState(() { _loadingManagers = true; _managerError = null; });

    final empId = widget.user["employeeId"]?.toString()
        ?? widget.user["employee_id"]?.toString()
        ?? "";
    if (empId.isEmpty) throw Exception("employeeId missing");

    final res = await ApiService.getLeaveManagers(employeeId: empId);
    if (res["success"] != true) throw Exception(res["message"] ?? "Failed");

    final data       = res["data"] ?? {};
    final raw        = List.from(data["managers"] ?? []);
    // This is the single best available manager after fallback chain:
    // reporting manager → HR (10) → GM (14) → MD (11)
    final resolvedId = data["reporting_manager_id"]?.toString();

    final allManagers = raw.map<Map<String, String>>((e) => {
      "id":   e["id"].toString(),
      "name": (e["name"] ?? "").toString(),
    }).toList();

    // ── KEY: filter to show ONLY the resolved single manager ─────────────
    // Same as PersonalVehicleRequestScreen — employee sees one manager,
    // already resolved through the availability/fallback chain on the server.
    final displayList = allManagers
        .where((m) => m["id"].toString() == resolvedId)
        .toList();

    setState(() {
      _leaveManagers     = displayList;  // only 1 manager shown
      _selectedManagerId = resolvedId;   // auto-selected
      _loadingManagers   = false;
    });

  } catch (e) {
    setState(() {
      _loadingManagers = false;
      _managerError    = e.toString();
    });
  }
}

Future<void> _submitForm() async {

  if (!_formKey.currentState!.validate()) return;

  // Only validate reliever selection for non-managers
  if (!_isManager) {
    if (availableMembers.isNotEmpty && selectedMember == null) {
      setState(() => _memberError = 'Please select a team member to cover your duties');
      return;
    }
    if (availableMembers.isEmpty && !noMemberConfirmed) {
      setState(() => _confirmError = 'Please confirm to proceed without a reliever');
      return;
    }
  }

  if (selectedLeaveType == null) return;
  if (!isHalfDay && _selectedDates.isEmpty) return;
  if (isHalfDay && (fromDate == null || toDate == null)) return;

  // Enforce minimum working days per leave type
  final totalDays = isHalfDay ? 1 : _selectedDates.length;
  final minDays = _minimumDays();
  if (totalDays < minDays) {
    TopBanner.show(
      context,
      title: 'Minimum Days Required',
      message: '$selectedLeaveType requires at least $minDays working days (weekends excluded). Please adjust your dates.',
      icon: Icons.warning_amber_rounded,
      rightButtonText: 'OK',
      onRightTap: () {},
    );
    return;
  }

  if (_noPayDays > 0 && !_noPayAcknowledged) {
    setState(() => _noPayError =
        "Please tick the checkbox to confirm you understand this includes "
        "unpaid leave");
    TopBanner.show(
      context,
      title: 'Confirmation Required',
      message: 'Please confirm you understand this request includes '
               'No Pay Leave before submitting.',
      icon: Icons.warning_amber_rounded,
      rightButtonText: 'OK',
      onRightTap: () {},
    );
    return;
  }

  // map leave type name -> leave_policy_id
  final leavePolicyId = _leaveTypeToId(selectedLeaveType!);

  final start = DateFormat('yyyy-MM-dd').format(fromDate!);
  final end = DateFormat('yyyy-MM-dd').format(toDate!);
  final days = isHalfDay ? 0.5 : _selectedDates.length.toDouble();

  try {
    setState(() {
      _isSubmitting = true;
    });

    final res = await ApiService.applyLeaveRequest(
      employeeId: widget.user["employeeId"].toString(),
      leavePolicyId: leavePolicyId,
      startDate: start,
      endDate: end,
      numberOfDays: days,
      reason: reasonController.text.trim(),
      overseeMemberId: selectedMember,
      isSpecialRequest: noMemberConfirmed,
      address: addressController.text.trim(),
      halfDaySession: isHalfDay ? halfDaySession : null,
      managerId: _selectedManagerId,
      acknowledgeNoPay: _noPayAcknowledged ? 1 : 0,
    );

      if (res["success"] == true) {

        // 1) Get new leave_request_id from response
        final int leaveRequestId = int.parse(res["leave_request_id"].toString());

        // 2) Upload document if user selected a file
        if (attachedFile != null) {
          try {
            await ApiService.uploadLeaveDocument(
              leaveRequestId: leaveRequestId,
              file: attachedFile!,
            );
          } catch (e) {
            // upload failed but leave request created
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Document upload failed: $e")),
            );
          }
        }

        //  3) show top banner
        TopBanner.show(
          context,
          title: "Request send successful..",
          message: "Your leave request has been submitted successfully.",
          icon: Icons.check_circle,
          leftButtonText: "View request",
          rightButtonText: "Ok",
          onLeftTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LeaveHistoryScreen(user: widget.user)),
            );
          },
          onRightTap: () {},
        );

        Navigator.pop(context);
        Future.delayed(const Duration(milliseconds: 1000), () {});
      }
      else {
      // ERROR MESSAGE FROM PHP
      final msg = res["message"] ?? "Request failed";

            TopBanner.show(
              context,
              title: "Leave Request Failed",
              message: msg,
              icon: Icons.warning_amber_rounded,
              rightButtonText: "OK",
              onRightTap: () {},
              );
            }
          } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        } finally {
          if (mounted) {
            setState(() {
              _isSubmitting = false;
            });
          }
        }
      }

int _leaveTypeToId(String type) {
  if (type == "Annual Leave") return 1;
  if (type == "Medical Leave") return 2;
  if (type == "Casual Leave") return 3;
  if (type == "Half Day") return 4;
  return 0;
}


  // Fetch profile photo with caching to optimize performance
  Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
    return _photoFutureCache.putIfAbsent(
      employeeId,
      () => ApiService.getProfilePhoto(employeeId: employeeId),
    );
  }


//Call the submit confirmation dialog
void _showSubmitConfirmation() {
  final leaveType = selectedLeaveType ?? "Leave";
  final fromTxt = fromDate == null ? "-" : DateFormat('yyyy-MM-dd').format(fromDate!);
  final toTxt = toDate == null ? "-" : DateFormat('yyyy-MM-dd').format(toDate!);
  final daysTxt = isHalfDay
      ? "Half Day"
      : _selectedDates.isNotEmpty
          ? "${_selectedDates.length} working days"
          : "-";

  showLeaveSubmitDialog(
    context: context,
    leaveType: leaveType,
    fromTxt: fromTxt,
    toTxt: toTxt,
    daysTxt: daysTxt,
    isSubmitting: _isSubmitting,
    onConfirm: _submitForm,
  );
}


  Future<void> _loadAnnualLeaveBalance() async {
    final empId = widget.user["employeeId"]?.toString()
        ?? widget.user["employee_id"]?.toString() ?? "";
    if (empId.isEmpty) return;
    try {
      final res = await ApiService.checkLeaveNoPayPreview(
        employeeId:    empId,
        leavePolicyId: 1,   // Annual Leave
        days:          1,   // probe — we only need the remaining field
      );
      if (!mounted) return;
      if (selectedLeaveType != 'Annual Leave') return; // stale guard
      if (res["success"] == true) {
        final remaining = (res["data"]?["remaining"] as num?)?.toDouble();
        if (remaining != null) setState(() => _annualLeaveRemaining = remaining);
      }
    } catch (_) {}
  }

  Future<void> _checkNoPayPreview() async {
    if (selectedLeaveType == null) return;
    final rawPolicyId = _leaveTypeToId(selectedLeaveType!);
    // Half Day (4) checks against Casual Leave (3) balance with 0.5 days
    final leavePolicyId = rawPolicyId == 4 ? 3 : rawPolicyId;

    if (![1, 2, 3].contains(leavePolicyId)) {
      setState(() {
        _remainingBalance  = null;
        _paidDays          = 0;
        _noPayDays         = 0;
        _noPayAcknowledged = false;
      });
      return;
    }

    final double days;
    if (rawPolicyId == 4) {
      if (fromDate == null) return;
      days = 0.5;
    } else {
      if (_selectedDates.isEmpty) return;
      days = _selectedDates.length.toDouble();
    }
    final empId = widget.user["employeeId"]?.toString()
        ?? widget.user["employee_id"]?.toString() ?? "";
    if (empId.isEmpty) return;

    try {
      final res = await ApiService.checkLeaveNoPayPreview(
        employeeId:    empId,
        leavePolicyId: leavePolicyId, // 3 for Half Day
        days:          days,          // 0.5 for Half Day
      );
      if (!mounted) return;
      // Discard stale response if leave type changed while awaiting
      if (_leaveTypeToId(selectedLeaveType ?? '') != rawPolicyId) return;
      if (res["success"] == true) {
        final d = res["data"] ?? {};
        setState(() {
          _remainingBalance  = (d["remaining"] as num?)?.toDouble();
          _paidDays          = (d["paidDays"]  as num?)?.toDouble() ?? days;
          _noPayDays         = (d["noPayDays"] as num?)?.toDouble() ?? 0;
          _noPayAcknowledged = false;
          _noPayError        = null;
        });
      }
    } catch (_) {
      // fail silently — PHP validates again on actual submit
    }
  }

  Future<void> _openMultiDatePicker({bool singleSelect = false}) async {
    final result = await showModalBottomSheet<Set<DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MultiSelectCalendarSheet(
        initialSelected: _selectedDates,
        firstDate: _leavePickerFirstDate(),
        singleSelect: singleSelect,
      ),
    );

    if (result != null) {
      final sorted = result.toList()..sort();
      setState(() {
        _selectedDates = result;
        fromDate = sorted.isEmpty ? null : sorted.first;
        toDate   = sorted.isEmpty ? null : sorted.last;
      });
      _loadRelievers();
      _checkNoPayPreview();
    }
  }

  // ===== DATE RANGE FILTER LOGIC =====
    Future<void> _loadRelievers() async {

      // Managers don't need a reliever — skip loading
      if (_isManager) return;
      if (fromDate == null) return;

      // for half day: toDate = fromDate
      final effectiveTo = isHalfDay ? fromDate : toDate;
      if (effectiveTo == null) return;

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      final deptId = widget.user["departmentId"]?.toString() ?? "";
      if (employeeId.isEmpty || deptId.isEmpty) return;

      final from = DateFormat('yyyy-MM-dd').format(fromDate!);
      final to = DateFormat('yyyy-MM-dd').format(effectiveTo);

      try {
        final res = await ApiService.getRelievers(
          employeeId: employeeId,
          departmentId: deptId,
          fromDate: from,
          toDate: to,
        );

        if (res["success"] == true) {
          final list = List<Map<String, dynamic>>.from(res["members"] ?? []);

          // Clear photo cache to avoid showing wrong photos after date change
          _photoFutureCache.clear();

          setState(() {
            availableMembers = list
                .map((m) => {
                      "id": m["id"].toString(),
                      "name": m["name"].toString(),
                    })
                .toList();

            selectedMember = null;
            noMemberConfirmed = false;
          });
        } else {
          setState(() {
            availableMembers = [];
            selectedMember = null;
          });
        }
      } catch (e) {
        setState(() {
          availableMembers = [];
          selectedMember = null;
        });
      }
    }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue[800] ?? Colors.blue;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
      backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: Colors.black87,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Apply for leave',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Employee info card ──────────────────────────────────
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
                    Row(
                      children: [
                        //const SizedBox(width: 8),
                        const Text(
                          'Your Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFDDE5F8)),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _infoCell('Name', nameController.text, Icons.badge_outlined),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _infoCell('Employee No.', employeeController.text, Icons.tag_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _infoCell('Department', departmentController.text, Icons.apartment_rounded),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _infoCell('Contact No.', contactController.text, Icons.phone_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---------------- LEAVE TYPE ----------------
              const FormSectionTitle('Leave Type *'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedLeaveType,
                dropdownColor: Colors.white,
                decoration: _dropdownDecoration(),
                hint: Text('Select leave type', style: TextStyle(color: Colors.grey.shade600)),
                items: leaveTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t,
                    style: const TextStyle(     // ITEM TEXT COLOR
                    color: Colors.black,
                    fontWeight: FontWeight.w600
                          ),
                          )
                        )
                        )
                    .toList(),
                onChanged: (v) {
                setState(() {
                  selectedLeaveType = v;
                  isHalfDay = (v == "Half Day");
                  halfDaySession = null;
                  fromDate = null;
                  toDate = null;
                  _selectedDates = {};
                  _annualLeaveRemaining = null; // reset on every type change
                });
                if (v == 'Annual Leave') _loadAnnualLeaveBalance();
                _checkNoPayPreview();
              },

                validator: (v) => v == null ? 'Select leave type' : null,
              ),

              const SizedBox(height: 16),



              // ---------------- DATES (SIDE BY SIDE) ----------------
              if (isHalfDay) ...[
                const FormSectionTitle('Date *'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openMultiDatePicker(singleSelect: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: Colors.grey.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: fromDate == null
                              ? Text('Tap to select date',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15))
                              : Text(
                                  DateFormat('EEE, d MMM yyyy').format(fromDate!),
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                        Icon(Icons.edit_calendar_outlined,
                            color: Colors.grey.shade700, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const FormSectionTitle('Half Day Session *'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: halfDaySession,
                  dropdownColor: Colors.white,
                  decoration: _dropdownDecoration(),
                  hint: Text('Select session', style: TextStyle(color: Colors.grey.shade600)),
                  items: const [
                    DropdownMenuItem(value: 'MORNING', child: Text('Morning',style: const TextStyle(color: Colors.black,fontWeight: FontWeight.w600))),
                    DropdownMenuItem(value: 'EVENING', child: Text('Evening',style: const TextStyle(color: Colors.black,fontWeight: FontWeight.w600))),
                  ],
                  onChanged: (v) => setState(() => halfDaySession = v),
                  validator: (v) => v == null ? 'Select session' : null,
                ),


                const SizedBox(height: 10),


                if (fromDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Days',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Half Day',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                if (_noPayDays > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            "Insufficient Leave Balance",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                                color: Color(0xFFE65100)),
                          )),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          "You have ${_remainingBalance?.toStringAsFixed(1) ?? '0'} day(s) "
                          "of $selectedLeaveType remaining.\n"
                          "${_paidDays.toStringAsFixed(1)} day(s) will be paid leave, "
                          "${_noPayDays.toStringAsFixed(1)} day(s) will be No Pay Leave "
                          "(salary deduction applies).",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: Color(0xFF6B4A1E), height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _noPayAcknowledged,
                          onChanged: (v) => setState(() {
                            _noPayAcknowledged = v ?? false;
                            _noPayError = null;
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: const Color(0xFFE65100),
                          title: const Text(
                            "I understand and confirm this request includes unpaid "
                            "(No Pay) leave — salary deduction will apply",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800,
                                color: Colors.black87),
                          ),
                        ),
                        if (_noPayError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, left: 4),
                            child: Text(_noPayError!,
                                style: const TextStyle(color: Color(0xFFD32F2F),
                                    fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
              // ── Annual Leave: tap individual working days ─────────────────────
              if (selectedLeaveType == 'Annual Leave') ...[
                const FormSectionTitle('Select Working Days *'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openMultiDatePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: Colors.grey.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _selectedDates.isEmpty
                              ? Text('Tap to select working days',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15))
                              : Text(
                                  '${_selectedDates.length} day${_selectedDates.length == 1 ? '' : 's'} selected'
                                  ' · ${DateFormat('d MMM').format(fromDate!)} – ${DateFormat('d MMM').format(toDate!)}',
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                        Icon(Icons.edit_calendar_outlined,
                            color: Colors.grey.shade700, size: 18),
                      ],
                    ),
                  ),
                ),
                if (_selectedDates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedDates.length < _minimumDays()
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Selected Days',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                          Text('${_selectedDates.length} working days',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: _selectedDates.length < _minimumDays()
                                      ? const Color(0xFFD32F2F)
                                      : Colors.black87)),
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                // ── Medical / Casual: same multi-select calendar ──────────────
                const FormSectionTitle('Leave Dates *'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openMultiDatePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: Colors.grey.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _selectedDates.isEmpty
                              ? Text('Tap to select leave dates',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15))
                              : Text(
                                  '${_selectedDates.length} day${_selectedDates.length == 1 ? '' : 's'} selected'
                                  ' · ${DateFormat('d MMM').format(fromDate!)} – ${DateFormat('d MMM').format(toDate!)}',
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                        Icon(Icons.edit_calendar_outlined,
                            color: Colors.grey.shade700, size: 18),
                      ],
                    ),
                  ),
                ),
                if (_selectedDates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedDates.length < _minimumDays()
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Selected Days',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                          Text('${_selectedDates.length} working days',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: _selectedDates.length < _minimumDays()
                                      ? const Color(0xFFD32F2F)
                                      : Colors.black87)),
                        ],
                      ),
                    ),
                  ),
              ],
                if (_noPayDays > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            "Insufficient Leave Balance",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                                color: Color(0xFFE65100)),
                          )),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          "You have ${_remainingBalance?.toStringAsFixed(1) ?? '0'} day(s) "
                          "of $selectedLeaveType remaining.\n"
                          "${_paidDays.toStringAsFixed(1)} day(s) will be paid leave, "
                          "${_noPayDays.toStringAsFixed(1)} day(s) will be No Pay Leave "
                          "(salary deduction applies).",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: Color(0xFF6B4A1E), height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _noPayAcknowledged,
                          onChanged: (v) => setState(() {
                            _noPayAcknowledged = v ?? false;
                            _noPayError = null;
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: const Color(0xFFE65100),
                          title: const Text(
                            "I understand and confirm this request includes unpaid "
                            "(No Pay) leave — salary deduction will apply",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800,
                                color: Colors.black87),
                          ),
                        ),
                        if (_noPayError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, left: 4),
                            child: Text(_noPayError!,
                                style: const TextStyle(color: Color(0xFFD32F2F),
                                    fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 16),

              // ---------------- REASON ----------------
              const FormSectionTitle('Reason for leave *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: reasonController,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                maxLines: 4,
                decoration: _inputDecoration('Enter reason for leave...'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // ---------------- TEAM MEMBER (RELIEVER) ----------------
              if (_isManager) ...[
                // Managers see a simple info card instead of reliever selection
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBDD0F8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "No reliever required",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E2A3A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "As a manager, your leave request will be sent directly to your reporting manager for approval.",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7A90),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Non-managers: show full reliever selection (existing UI unchanged)
                const FormSectionTitle('Select Team Member to Cover Your Duties *'),
                const SizedBox(height: 10),

                if (fromDate != null && toDate != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: blue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            availableMembers.isNotEmpty
                                ? 'Showing team availability for ${DateFormat('yyyy-MM-dd').format(fromDate!)} to ${DateFormat('yyyy-MM-dd').format(toDate!)}'
                                : 'Peak leave period detected - all members unavailable',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E2A3A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                if (availableMembers.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE1E6EF)),
                    ),
                    child: Column(
                      children: availableMembers.map((m) {
                        final empId = int.tryParse(m["id"] ?? "") ?? 0;
                        return RadioListTile<String>(
                          value: m['id']!,
                          groupValue: selectedMember,
                          onChanged: (v) => setState(() {
                            selectedMember = v;
                            _memberError = null;
                          }),
                          fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                            if (states.contains(MaterialState.selected)) return Colors.blue;
                            return Colors.black54;
                          }),
                          controlAffinity: ListTileControlAffinity.trailing,
                          secondary: FutureBuilder<Map<String, dynamic>?>(
                            future: empId > 0 ? _getPhotoFuture(empId) : Future.value(null),
                            builder: (context, snap) {
                              final url = (snap.data?["fileUrl"] ?? "").toString().trim();
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0xFFEAF1FF),
                                  child: SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                      color: Colors.blue,
                                      backgroundColor: Colors.white,
                                      strokeWidth: 2,
                                    ),
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
                          title: Text(
                            m['name']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else if (fromDate != null && toDate != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7E8F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Proceed without reliever team member (By HOD Approval)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: const Text(
                        'This request will be escalated to HR for special approval.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      value: noMemberConfirmed,
                      onChanged: (v) => setState(() {
                        noMemberConfirmed = v!;
                        _confirmError = null;
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.blue,
                    ),
                  ),

                if (_memberError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 14),
                        const SizedBox(width: 4),
                        Text(_memberError!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),

                if (_confirmError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 14),
                        const SizedBox(width: 4),
                        Text(_confirmError!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 16),


              // ---------------- ADDRESS ----------------
              const FormSectionTitle('Address While on Leave (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: addressController,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                maxLines: 2,
                decoration: _inputDecoration('Enter address while on leave...'),
              ),

              const SizedBox(height: 16),

              // ---------------- ATTACHMENT ----------------
              const FormSectionTitle('Attach Document (Optional)'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickAttachment,
                child: DottedBorder(
                  radius: const Radius.circular(12),
                  dashPattern: const [6, 4],
                  color: Colors.grey.shade400,
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: attachedFile != null && _isImageFile(attachedFileName)
                        ? Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                attachedFile!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.insert_drive_file_outlined,
                                  size: 34, color: Colors.black54),
                              const SizedBox(height: 8),
                              Text(
                                attachedFileName ?? 'Tap to upload document',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              // ---------------- APPROVING MANAGER ----------------
              const SizedBox(height: 16),
              const FormSectionTitle('Approving Manager *'),
              const SizedBox(height: 8),

              if (_loadingManagers)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
                  ),
                )
              else if (_managerError != null)
                Text(_managerError!, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 12, fontWeight: FontWeight.w700))
              else if (_leaveManagers.isEmpty)
                const Text("No managers available", style: TextStyle(color: Colors.grey))
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E6EF)),
                  ),
                  child: Column(
                    children: _leaveManagers.map((m) {
                      final mId = (m["id"] ?? "").toString();
                      final eId = int.tryParse(mId) ?? 0;
                      return RadioListTile<String>(
                        value: mId,
                        groupValue: _selectedManagerId,
                        onChanged: (v) => setState(() => _selectedManagerId = v),
                        controlAffinity: ListTileControlAffinity.trailing,
                        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.selected)) {
                            return Colors.blue;
                          }
                          return Colors.black54;
                        }),
                        secondary: FutureBuilder<Map<String, dynamic>?>(
                          future: eId > 0 ? _getPhotoFuture(eId) : Future.value(null),
                          builder: (context, snap) {
                            final url = (snap.data?["fileUrl"] ?? "").toString().trim();
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFEAF1FF),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.blue, backgroundColor: Colors.white, strokeWidth: 2),
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
                        title: Text(
                          (m["name"] ?? "-"),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 18),

              // ---------------- SUBMIT ----------------
              GradientSubmitButton(
                label: 'SUBMIT',
                isLoading: _isSubmitting,
                onPressed: _showSubmitConfirmation,
              ),
            ],
          ),
        ),
      ),
    );
  }

            // ================== Document Picker Function ==================
            Future<void> _pickAttachment() async {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take photo"),
              onTap: () async {
                Navigator.pop(context);

                final ok = await _ensureCameraPermission();
                if (!ok) {
                  _showMsg("Camera permission denied");
                  return;
                }

                try {
                  final XFile? x = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                  );

                  if (x == null) return;
                  if (!mounted) return;

                  setState(() {
                    attachedFile = File(x.path);
                    attachedFileName = x.name;
                  });
                } catch (e) {
                  _showMsg("Failed to open camera: $e");
                }
              },
            ),
                        ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from gallery"),
              onTap: () async {
                Navigator.pop(context);

                final ok = await _ensureGalleryPermission();
                if (!ok) {
                  _showMsg("Gallery permission denied");
                  return;
                }

                try {
                  final XFile? x = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                  );

                  if (x == null) return;
                  if (!mounted) return;

                  setState(() {
                    attachedFile = File(x.path);
                    attachedFileName = x.name;
                  });
                } catch (e) {
                  _showMsg("Failed to open gallery: $e");
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text("Choose document (PDF/DOC)"),
              onTap: () async {
                Navigator.pop(context);

                try {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
                    withData: true,
                  );

                  if (result == null || result.files.isEmpty) return;

                  final picked = result.files.single;

                  if (picked.path != null && picked.path!.isNotEmpty) {
                    setState(() {
                      attachedFile = File(picked.path!);
                      attachedFileName = picked.name;
                    });
                  } else if (picked.bytes != null) {
                    final tempDir = await getTemporaryDirectory();
                    final tempFile = File('${tempDir.path}/${picked.name}');
                    await tempFile.writeAsBytes(picked.bytes!);

                    setState(() {
                      attachedFile = tempFile;
                      attachedFileName = picked.name;
                    });
                  } else {
                    _showMsg("Unable to access selected file");
                  }
                } catch (e) {
                  _showMsg("Failed to pick file: $e");
                }
              },
            ),
            if (attachedFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Remove attachment"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    attachedFile = null;
                    attachedFileName = null;
                  });
                },
              ),
          ],
        ),
      );
    },
  );
}

  // Handle lost data (e.g. app killed while picking image)
  Future<void> _recoverLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();

      if (response.isEmpty) return;

      if (response.files != null && response.files!.isNotEmpty) {
        final XFile file = response.files!.first;

        if (!mounted) return;
        setState(() {
          attachedFile = File(file.path);
          attachedFileName = file.name;
        });

        _showMsg("Recovered captured image");
        return;
      }

      if (response.file != null) {
        final XFile file = response.file!;

        if (!mounted) return;
        setState(() {
          attachedFile = File(file.path);
          attachedFileName = file.name;
        });

        _showMsg("Recovered captured image");
        return;
      }

      if (response.exception != null) {
        debugPrint("Lost data exception: ${response.exception}");
      }
    } catch (e) {
      debugPrint("retrieveLostData error: $e");
    }
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> _ensureGalleryPermission() async {
    if (await Permission.photos.isGranted || await Permission.storage.isGranted) {
      return true;
    }

    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) return true;

    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ---------------- UI HELPERS (UI ONLY) ----------------

  /// Earliest selectable date — depends on leave type:
  /// Annual Leave   → today (no past).
  /// Medical Leave  → yesterday (can report next day after illness).
  /// Others         → 3 days in the past (retroactive casual/half-day).
  DateTime _leavePickerFirstDate() {
    final today = DateUtils.dateOnly(DateTime.now());
    if (selectedLeaveType == 'Annual Leave') {
      return today;
    }
    if (selectedLeaveType == 'Medical Leave') {
      return today.subtract(const Duration(days: 1));
    }
    return today.subtract(const Duration(days: 3));
  }

  int _minimumDays() {
    if (selectedLeaveType == 'Annual Leave') {
      final r = _annualLeaveRemaining;
      // remaining is always a whole number (0, 1, 2, 3 …)
      // if < 3, the minimum matches remaining (at least 1)
      if (r != null && r < 3) return r.toInt().clamp(1, 2);
      return 3;
    }
    return 1;
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-select calendar sheet (Annual Leave)
// ─────────────────────────────────────────────────────────────────────────────
class _MultiSelectCalendarSheet extends StatefulWidget {
  final Set<DateTime> initialSelected;
  final DateTime firstDate;
  final bool singleSelect;

  const _MultiSelectCalendarSheet({
    required this.initialSelected,
    required this.firstDate,
    this.singleSelect = false,
  });

  @override
  State<_MultiSelectCalendarSheet> createState() =>
      _MultiSelectCalendarSheetState();
}

class _MultiSelectCalendarSheetState extends State<_MultiSelectCalendarSheet> {
  late Set<DateTime> _selected;
  late DateTime _focusedMonth;

  static const _dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.map(DateUtils.dateOnly).toSet();
    final today = DateUtils.dateOnly(DateTime.now());
    _focusedMonth = DateTime(today.year, today.month, 1);
  }

  bool _isWeekend(DateTime d) =>
      d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  bool _isBeforeFirst(DateTime d) =>
      DateUtils.dateOnly(d).isBefore(DateUtils.dateOnly(widget.firstDate));

  bool _isSelected(DateTime d) =>
      _selected.any((s) => DateUtils.isSameDay(s, d));

  void _toggle(DateTime d) {
    if (_isBeforeFirst(d) || _isWeekend(d)) return;
    final key = DateUtils.dateOnly(d);

    if (widget.singleSelect) {
      setState(() {
        if (_isSelected(key)) {
          _selected.clear();
        } else {
          _selected = {key};
        }
      });
      return;
    }

    if (_selected.isEmpty) {
      setState(() => _selected.add(key));
      return;
    }

    final sorted = _selected.toList()..sort();
    final first = sorted.first;
    final last  = sorted.last;

    if (DateUtils.isSameDay(key, first)) {
      setState(() => _selected.removeWhere((s) => DateUtils.isSameDay(s, first)));
    } else if (DateUtils.isSameDay(key, last)) {
      setState(() => _selected.removeWhere((s) => DateUtils.isSameDay(s, last)));
    } else if (key.isAfter(last)) {
      setState(() {
        DateTime fill = last.add(const Duration(days: 1));
        while (!fill.isAfter(key)) {
          if (!_isWeekend(fill)) _selected.add(DateUtils.dateOnly(fill));
          fill = fill.add(const Duration(days: 1));
        }
      });
    } else if (key.isBefore(first)) {
      setState(() {
        DateTime fill = key;
        while (fill.isBefore(first)) {
          if (!_isWeekend(fill)) _selected.add(DateUtils.dateOnly(fill));
          fill = fill.add(const Duration(days: 1));
        }
      });
    }
  }

  void _clearSelection() => setState(() => _selected.clear());

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    // weekday of the 1st: 1=Mon … 7=Sun (our grid starts on Monday)
    final firstWeekday =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    final count = _selected.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Text(
                    widget.singleSelect ? 'Select Date' : 'Select Working Days',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2A3A)),
                  ),
                  SizedBox(
                    width: 48,
                    child: _selected.isNotEmpty
                        ? GestureDetector(
                            onTap: _clearSelection,
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.w700),
                              textAlign: TextAlign.right,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.singleSelect
                    ? 'Tap a working day to select your half day date'
                    : 'Tap a date to start · extend forward or backward · weekends auto-skipped',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // month navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left,
                        color: Color(0xFF1565C0)),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(
                          _focusedMonth.year, _focusedMonth.month - 1, 1);
                    }),
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_focusedMonth),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2A3A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: Color(0xFF1565C0)),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(
                          _focusedMonth.year, _focusedMonth.month + 1, 1);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // day-of-week headers
              Row(
                children: _dayLabels.map((label) {
                  final isWeekendCol = label == 'Sa' || label == 'Su';
                  return Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isWeekendCol
                              ? Colors.grey.shade300
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
              // day grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemCount: (firstWeekday - 1) + daysInMonth,
                itemBuilder: (_, index) {
                  if (index < firstWeekday - 1) return const SizedBox();
                  final day = index - (firstWeekday - 1) + 1;
                  final d = DateTime(
                      _focusedMonth.year, _focusedMonth.month, day);
                  final weekend = _isWeekend(d);
                  final beforeFirst = _isBeforeFirst(d);
                  final disabled = weekend || beforeFirst;
                  final selected = _isSelected(d);

                  return GestureDetector(
                    onTap: disabled ? null : () => _toggle(d),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? const Color(0xFF1565C0)
                            : Colors.transparent,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : disabled
                                  ? Colors.grey.shade300
                                  : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // selected-day chips preview
              if (count > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (_selected.toList()..sort()).map((d) => Text(
                          DateFormat('EEE d MMM').format(d),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E2A3A)),
                        )).toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: count == 0
                      ? null
                      : () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    disabledBackgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    count == 0
                        ? (widget.singleSelect ? 'Select a date' : 'Select at least 1 day')
                        : widget.singleSelect
                            ? 'Confirm  ·  ${DateFormat('EEE, d MMM').format(_selected.first)}'
                            : 'Confirm $count day${count == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: count == 0
                          ? Colors.grey.shade400
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
