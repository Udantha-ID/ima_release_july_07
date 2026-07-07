import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../Services/staff_gate_pass_service.dart';
import '../Services/api_service.dart';
import '../ui/dialogs/gate_pass_dialogs.dart';
import '../Leaves/top_banner.dart';
import '../ui/widgets/time_picker_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model — matches get_all_staff.php response fields
// ─────────────────────────────────────────────────────────────────────────────

class StaffMember {
  final int id;           // employee_id
  final String name;      // name  (preferred_name ?? full_name)
  final int? jobTitleId;  // job_title_id
  final String jobTitle;  // job_title

  const StaffMember({
    required this.id,
    required this.name,
    this.jobTitleId,
    required this.jobTitle,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id:         int.tryParse((json['employee_id'] ?? '').toString()) ?? 0,
      name:       (json['name']      ?? '').toString().trim(),
      jobTitleId: int.tryParse((json['job_title_id'] ?? '').toString()),
      jobTitle:   (json['job_title'] ?? 'Unknown').toString().trim(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class GatePassRequestFormScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onRequestSubmitted;

  const GatePassRequestFormScreen({
    super.key,
    required this.user,
    this.onRequestSubmitted,
  });

  @override
  State<GatePassRequestFormScreen> createState() =>
      _GatePassRequestFormScreenState();
}

class _GatePassRequestFormScreenState
    extends State<GatePassRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Read-only user detail controllers ─────────────────────────────────────
  final _nameController       = TextEditingController();
  final _employeeController   = TextEditingController();
  final _departmentController = TextEditingController();
  final _contactController    = TextEditingController();

  // ── Gate pass field controllers ───────────────────────────────────────────
  final _reasonController         = TextEditingController();
  final _remarkController         = TextEditingController();
  final _vehicleLettersController = TextEditingController();
  final _vehicleNumbersController = TextEditingController();

  // ── Date / time ───────────────────────────────────────────────────────────
  DateTime?  _date;
  TimeOfDay? _outTime;
  TimeOfDay? _returnTime;

  // ── Staff multi-select ────────────────────────────────────────────────────
  List<StaffMember> _allStaff      = [];
  bool              _loadingStaff  = true;
  String?           _staffError;
  final Set<int>    _selectedStaffIds   = {};
  final _staffSearchController         = TextEditingController();
  String            _staffSearchQuery  = '';

  bool _isSubmitting = false;

  // ── Approving manager ─────────────────────────────────────────────────────
  List<Map<String, String>> _managers          = [];
  String?                   _selectedManagerId;
  bool                      _loadingManagers   = true;
  String?                   _managerError;
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache      = {};
  final Map<int, Future<Map<String, dynamic>?>> _staffPhotoFutureCache = {};

// ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Keys match login map (camelCase)
    _nameController.text       = (widget.user['preferredName'] ?? widget.user['name'] ?? widget.user['fullName'] ?? '').toString();
    _employeeController.text   = (widget.user['employeeCode']  ?? '').toString();
    _departmentController.text = (widget.user['department']    ?? '').toString();
    _contactController.text    = (widget.user['phone']         ?? '').toString();
    _loadAllStaff();
    _loadManagers();
  }
 
  @override
  void dispose() {
    _nameController.dispose();
    _employeeController.dispose();
    _departmentController.dispose();
    _contactController.dispose();
    _reasonController.dispose();
    _remarkController.dispose();
    _vehicleLettersController.dispose();
    _vehicleNumbersController.dispose();
    _staffSearchController.dispose();
    super.dispose();
  }

 // ── Load managers from API ─────────────────────────────────────────────────
 Future<void> _loadManagers() async {
  try {
    setState(() {
      _loadingManagers = true;
      _managerError    = null;
    });

    final res = await StaffGatePassService.getGatePassManagers();
    if (res['success'] != true) throw Exception(res['message'] ?? 'Failed to load manager');

    final raw = List.from((res['data']?['managers']) ?? []);
    final managers = raw.map<Map<String, String>>((e) => {
      'id'  : e['id'].toString(),
      'name': (e['name'] ?? '').toString(),
    }).toList();

    setState(() {
      _managers          = managers;
      _selectedManagerId = managers.isNotEmpty ? managers.first['id'] : null;
      _loadingManagers   = false;
    });
  } catch (e) {
    setState(() {
      _loadingManagers = false;
      _managerError    = e.toString();
    });
  }
}

  Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
    return _photoFutureCache.putIfAbsent(
      employeeId,
      () => ApiService.getProfilePhoto(employeeId: employeeId),
    );
  }

  Future<Map<String, dynamic>?> _getStaffPhotoFuture(int employeeId) {
    return _staffPhotoFutureCache.putIfAbsent(
      employeeId,
      () => ApiService.getProfilePhoto(employeeId: employeeId),
    );
  }

  // ── Load staff from API ───────────────────────────────────────────────────
  Future<void> _loadAllStaff() async {
    try {
      setState(() {
        _loadingStaff = true;
        _staffError   = null;
      });

      final res = await StaffGatePassService.getAllStaff();

      if (res['success'] != true) {
        throw Exception(res['message'] ?? 'Failed to load staff');
      }

      final raw = List.from(res['members'] ?? []);
      final currentEmpId =
          (widget.user['employee_id'] ?? widget.user['employeeId'] ?? '')
              .toString()
              .trim();

      setState(() {
        _allStaff = raw
            .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
            // Exclude the logged-in employee from the list
            .where((s) => s.id.toString() != currentEmpId)
            .toList();
        _loadingStaff = false;
      });
    } catch (e) {
      setState(() {
        _loadingStaff = false;
        _staffError   = e.toString();
      });
    }
  }

  

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Your Details (compact card) ───────────────────────────────
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
                        Expanded(child: _infoCell('Name', _nameController.text, Icons.badge_outlined)),
                        const SizedBox(width: 20),
                        Expanded(child: _infoCell('Employee No.', _employeeController.text, Icons.tag_rounded)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _infoCell('Department', _departmentController.text, Icons.apartment_rounded)),
                        const SizedBox(width: 20),
                        Expanded(child: _infoCell('Contact No.', _contactController.text, Icons.phone_outlined)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Gate Pass Details ─────────────────────────────────────────
              _sectionHeader('Gate Pass Details', Icons.badge_outlined),
              const SizedBox(height: 12),

              // Date (single day)
              _fieldLabel('Date *'),
              const SizedBox(height: 8),
              _buildDatePicker(),

              const SizedBox(height: 16),

              // Out time & Return time on the same row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Out Time *'),
                        const SizedBox(height: 8),
                        _buildTimePicker(
                          'Out time',
                          _outTime,
                          (t) => setState(() => _outTime = t),
                          isRequired: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Return Time *'),
                        const SizedBox(height: 8),
                        _buildTimePicker(
                          'Return time',
                          _returnTime,
                          (t) => setState(() => _returnTime = t),
                          isRequired: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Reason
              _fieldLabel('Reason for Gate Pass *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                decoration: _inputDecoration(
                  'Enter reason…',
                  icon: Icons.edit_note_outlined,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 22),

              // ── Vehicle (optional) ────────────────────────────────────────
              _sectionHeader('Vehicle Details', Icons.directions_car_outlined),
              const SizedBox(height: 4),
              const Text(
                'Optional — fill in only if travelling by personal vehicle',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const SizedBox(height: 12),

              _fieldLabel('Vehicle Number'),
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
                      decoration: _inputDecoration(
                        'Letters (e.g. ABC)',
                        icon: Icons.directions_car_outlined,
                      ),
                      validator: (v) {
                        final letters = (v ?? '').trim();
                        final numbers = _vehicleNumbersController.text.trim();
                        if (numbers.isNotEmpty && letters.isEmpty) {
                          return 'Enter letters too';
                        }
                        if (letters.isNotEmpty &&
                            (letters.length < 2 || letters.length > 3)) {
                          return '2–3 letters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    child: Text(
                      '–',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
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
                      decoration: _inputDecoration('Numbers (e.g. 1234)'),
                      validator: (v) {
                        final numbers = (v ?? '').trim();
                        final letters = _vehicleLettersController.text.trim();
                        if (letters.isNotEmpty && numbers.isEmpty) {
                          return 'Enter 4 digits';
                        }
                        if (numbers.isNotEmpty && numbers.length != 4) {
                          return 'Exactly 4 digits';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ── Going Out With ────────────────────────────────────────────
              _sectionHeader('Going Out With', Icons.group_outlined),
              const SizedBox(height: 4),
              const Text(
                'Select staff members accompanying you (optional)',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const SizedBox(height: 12),
              _buildStaffSelector(),

              const SizedBox(height: 26),

              // ── Approving Manager ─────────────────────────────────────────
              _sectionHeader('Approving Manager', Icons.manage_accounts_outlined),
              const SizedBox(height: 12),
              _buildManagerSection(),

              const SizedBox(height: 26),

              // ── Remark (optional) ─────────────────────────────────────────
              _sectionHeader('Remark', Icons.comment_outlined),
              const SizedBox(height: 4),
              const Text(
                'Optional — any additional notes for the approver',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarkController,
                maxLines: 2,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                decoration: _inputDecoration(
                  'Enter remark…',
                  icon: Icons.comment_outlined,
                ),
              ),

              const SizedBox(height: 26),

              // ── Submit button ─────────────────────────────────────────────
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1565C0),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Color(0xFFDDE4F0), thickness: 1)),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E2A3A),
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

  // ── Single date picker ────────────────────────────────────────────────────
  Widget _buildDatePicker() {
    return TextFormField(
      readOnly: true,
      style: const TextStyle(color: Colors.black, fontSize: 14),
      decoration: _inputDecoration(
        'Select date',
        icon: Icons.calendar_today,
        suffix: Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
      ),
      controller: TextEditingController(
        text: _date == null ? '' : DateFormat('MM/dd/yyyy').format(_date!),
      ),
      validator: (_) => _date == null ? 'Required' : null,
      onTap: () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final picked = await showDatePicker(
          context: context,
          initialDate: _date ?? today,
          firstDate: today,
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF1565C0),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF1E2A3A),
              ),
              dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _date = picked);
      },
    );
  }

  // ── Time picker ───────────────────────────────────────────────────────────
  Widget _buildTimePicker(
    String label,
    TimeOfDay? selected,
    Function(TimeOfDay) onSelect, {
    bool isRequired = false,
  }) {
    return TextFormField(
      readOnly: true,
      style: const TextStyle(color: Colors.black, fontSize: 14),
      decoration: _inputDecoration(
        label,
        suffix: Icon(Icons.access_time, size: 18, color: Colors.grey.shade600),
      ),
      controller: TextEditingController(
        text: selected == null ? '' : selected.format(context),
      ),
      validator: isRequired ? (_) => selected == null ? 'Required' : null : null,
      onTap: () async {
        final picked = await showTimePickerSheet(
          context,
          initial: selected,
          title: label,
        );
        if (picked != null) onSelect(picked);
      },
    );
  }

  // ── Searchable multi-select staff list ────────────────────────────────────
  Widget _buildStaffSelector() {
    // Loading state
    if (_loadingStaff) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(
              color: Color(0xFF1565C0), strokeWidth: 2),
        ),
      );
    }

    // Error state
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
              child: Text(
                _staffError!,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            TextButton(
              onPressed: _loadAllStaff,
              child: const Text('Retry',
                  style: TextStyle(color: Color(0xFF1565C0))),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (_allStaff.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('No staff members found.',
              style: TextStyle(color: Colors.black45)),
        ),
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
          controller: _staffSearchController,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          decoration: _inputDecoration(
            'Search by name or job title…',
            icon: Icons.search,
            suffix: _staffSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() {
                      _staffSearchController.clear();
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
                .map(
                  (s) => Chip(
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
                    label: Text(
                      s.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    backgroundColor: const Color(0xFFEAF1FF),
                    side: const BorderSide(color: Color(0xFFB3C8F0)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () =>
                        setState(() => _selectedStaffIds.remove(s.id)),
                  ),
                )
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
                    child: Text(
                      'No results found',
                      style: TextStyle(color: Colors.black45),
                    ),
                  ),
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

                            // Name + job title
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    staff.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    staff.jobTitle,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.black45),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Animated checkbox
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

  // ── Approving manager card ────────────────────────────────────────────────
  Widget _buildManagerSection() {
    if (_loadingManagers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: Color(0xFF1565C0), strokeWidth: 2),
        ),
      );
    }

    if (_managerError != null) {
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
              child: Text(_managerError!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ),
            TextButton(
              onPressed: _loadManagers,
              child: const Text('Retry', style: TextStyle(color: Color(0xFF1565C0))),
            ),
          ],
        ),
      );
    }

    // _managers is already filtered to exclude the direct reporting manager
    final visible = _managers;

    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No approving manager found.',
            style: TextStyle(color: Colors.black45)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E6EF)),
      ),
      child: Column(
        children: visible.map((m) {
          final mgrId = m['id'] ?? '';
          final empId = int.tryParse(mgrId) ?? 0;
          return RadioListTile<String>(
            value: mgrId,
            groupValue: _selectedManagerId,
            onChanged: (v) => setState(() => _selectedManagerId = v),
            controlAffinity: ListTileControlAffinity.trailing,
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return const Color(0xFF1565C0);
              return Colors.grey;
            }),
            secondary: FutureBuilder<Map<String, dynamic>?>(
              future: empId > 0 ? _getPhotoFuture(empId) : Future.value(null),
              builder: (context, snap) {
                final url = (snap.data?['fileUrl'] ?? '').toString().trim();
                if (snap.connectionState == ConnectionState.waiting) {
                  return const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFEAF1FF),
                    child: SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: Color(0xFF1565C0), strokeWidth: 2),
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
              (m['name'] ?? '-').toString(),
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
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isSubmitting ? null : _onSubmitPressed,
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'SUBMIT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _onSubmitPressed() {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null)        { _showSnack('Please select a date',        isError: true); return; }
    if (_outTime == null)     { _showSnack('Please select an out time',   isError: true); return; }
    if (_returnTime == null)  { _showSnack('Please select a return time', isError: true); return; }
    if (_selectedManagerId == null) {
      _showSnack('No approving manager available', isError: true);
      return;
    }

    final letters      = _vehicleLettersController.text.trim().toUpperCase();
    final numbers      = _vehicleNumbersController.text.trim();
    final vehicleNoTxt = (letters.isNotEmpty && numbers.isNotEmpty)
        ? '$letters-$numbers' : 'None';
    final companions   = _allStaff
        .where((s) => _selectedStaffIds.contains(s.id))
        .map((s) => s.name)
        .join(', ');
    final managerName  = _managers
        .firstWhere((m) => m['id'] == _selectedManagerId,
            orElse: () => {'name': ''})['name'] ?? '';

    showGatePassSubmitDialog(
      context:       context,
      dateTxt:       DateFormat('MM/dd/yyyy').format(_date!),
      outTimeTxt:    _outTime!.format(context),
      returnTimeTxt: _returnTime!.format(context),
      vehicleNoTxt:  vehicleNoTxt,
      reason:        _reasonController.text.trim().isEmpty
          ? '-' : _reasonController.text.trim(),
      managerName:   managerName,
      companions:    companions.isNotEmpty ? companions : null,
      remark:        _remarkController.text.trim().isNotEmpty
          ? _remarkController.text.trim() : null,
      onConfirm:     _submitGatePass,
    );
  }

  Future<void> _submitGatePass() async {
    setState(() => _isSubmitting = true);
    try {
      final letters = _vehicleLettersController.text.trim().toUpperCase();
      final numbers = _vehicleNumbersController.text.trim();
      final vehicleNo = (letters.isNotEmpty && numbers.isNotEmpty)
          ? '$letters-$numbers' : null;

      final empIdRaw = widget.user['employeeId'] ?? widget.user['employee_id'] ?? 0;

      final res = await StaffGatePassService.createGatePass(
        employeeId:           int.tryParse(empIdRaw.toString()) ?? 0,
        employeeName:         _nameController.text.trim(),
        contactNo:            _contactController.text.trim(),
        managerId:            int.tryParse(_selectedManagerId ?? '0') ?? 0,
        gatePassDate:         DateFormat('yyyy-MM-dd').format(_date!),
        outTime:              '${_outTime!.hour.toString().padLeft(2, '0')}:${_outTime!.minute.toString().padLeft(2, '0')}:00',
        returnTime:           '${_returnTime!.hour.toString().padLeft(2, '0')}:${_returnTime!.minute.toString().padLeft(2, '0')}:00',
        reason:               _reasonController.text.trim(),
        vehicleNo:            vehicleNo,
        companionEmployeeIds: _selectedStaffIds.toList(),
        remark:               _remarkController.text.trim().isEmpty
            ? null : _remarkController.text.trim(),
      );

      if (!mounted) return;

      if (res['success'] == true) {
        _showSnack('Gate pass submitted successfully', isSuccess: true);
        widget.onRequestSubmitted?.call();
      } else {
        _showSnack(res['message']?.toString() ?? 'Submission failed', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg,
      {bool isError = false, bool isSuccess = false}) {
    TopBanner.show(
      context,
      title:     isSuccess ? 'Submitted'     : (isError ? 'Error'  : 'Notice'),
      message:   msg,
      icon:      isSuccess ? Icons.check_circle : (isError ? Icons.error_outline : Icons.info_outline),
      isSuccess: isSuccess,
      isError:   isError,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String hint,
      {IconData? icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.grey.shade600, size: 20)
          : null,
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
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.4),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFD32F2F),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}