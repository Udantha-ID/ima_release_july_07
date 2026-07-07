import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Leaves/top_banner.dart';
import '../Services/api_service.dart';
import '../Services/meeting_and_event_service.dart';
import '../ui/dialogs/meeting_event_dialogs.dart';
import 'participants_sheet.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Hub — two tab cards (New Event / My Events), matches GatePassScreen
// ═══════════════════════════════════════════════════════════════════════════════

class MeetingDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const MeetingDashboardScreen({super.key, required this.user});

  @override
  State<MeetingDashboardScreen> createState() => _MeetingDashboardScreenState();
}

class _MeetingDashboardScreenState extends State<MeetingDashboardScreen> {
  int _tab = 1;
  int _myEventsRefreshKey = 0;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Meeting & Events",
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ),
      body: Column(
        children: [
          // ── Tab cards ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _tabCard(
                    label: "New Event",
                    icon: Icons.add_circle_outline,
                    isActive: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                    activeColor: blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tabCard(
                    label: "My Events",
                    icon: Icons.event_note_outlined,
                    isActive: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                    activeColor: blue,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _CreateEventTab(
                  user: widget.user,
                  onCreated: () => setState(() {
                    _tab = 1;
                    _myEventsRefreshKey++;
                  }),
                ),
                _MyEventsTab(
                  user: widget.user,
                  key: ValueKey(_myEventsRefreshKey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabCard({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE1E6EF),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? Colors.white : Colors.black54,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 0 — New Event form (styled like GatePassRequestFormScreen)
// ═══════════════════════════════════════════════════════════════════════════════

class _CreateEventTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onCreated;
  const _CreateEventTab({required this.user, required this.onCreated});

  @override
  State<_CreateEventTab> createState() => _CreateEventTabState();
}

class _CreateEventTabState extends State<_CreateEventTab> {
  final _formKey        = GlobalKey<FormState>();
  final _titleCtrl      = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _locationCtrl   = TextEditingController();
  final _linkCtrl       = TextEditingController();
  final _searchCtrl     = TextEditingController();

  DateTime?  _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  String meetingType  = "Meeting";
  String locationType = "physical";
  bool   _submitting  = false;
  bool   _loadingStaff = true;

  PlatformFile? _attachedFile;
  bool _attachingFile = false;

  List<Map<String, String>> _allStaff = [];
  String _staffSearch = '';
  final Set<String> _selectedIds = {};
  final Map<int, Future<Map<String, dynamic>?>> _photoCache = {};

  @override
  void initState() {
    super.initState();
    _locationCtrl.text = "Meeting Room";
    _loadStaff();
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose();
    _locationCtrl.dispose(); _linkCtrl.dispose(); _searchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _photo(int id) =>
      _photoCache.putIfAbsent(id, () => ApiService.getProfilePhoto(employeeId: id));

  Future<void> _loadStaff() async {
    setState(() => _loadingStaff = true);
    try {
      final res = await MeetingAndEventService.getAllStaff();
      if (res['success'] != true) throw Exception();
      final list = (res['members'] as List? ?? [])
          .map<Map<String, String>>((e) {
            final item = Map<String, dynamic>.from(e);
            final id = (item["id"] ?? item["employee_id"] ?? "").toString();
            if (id.trim().isEmpty) return {};
            return {
              "id": id,
              "name": (item["name"] ?? "Unknown").toString(),
              "job_title": (item["job_title"] ?? "").toString(),
            };
          })
          .where((m) => m.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() { _photoCache.clear(); _allStaff = list; });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to load staff members")));
      }
    } finally {
      if (mounted) setState(() => _loadingStaff = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final p = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1565C0), onPrimary: Colors.white,
            surface: Colors.white, onSurface: Color(0xFF1E2A3A)),
          dialogBackgroundColor: Colors.white,
        ),
        child: child!,
      ),
    );
    if (p != null) setState(() => _date = p);
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart
        ? (_startTime ?? TimeOfDay.now())
        : (_endTime ?? _startTime ?? TimeOfDay.now());
    final p = await showTimePicker(
      context: context, initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1565C0), onPrimary: Colors.white,
            surface: Colors.white, onSurface: Color(0xFF1E2A3A)),
          dialogBackgroundColor: Colors.white,
        ),
        child: child!,
      ),
    );
    if (p != null) setState(() => isStart ? _startTime = p : _endTime = p);
  }

  Future<void> _pickPdf() async {
    setState(() => _attachingFile = true);
    try {
      final r = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf'],
          withData: false, withReadStream: false);
      if (r != null && r.files.isNotEmpty) setState(() => _attachedFile = r.files.first);
    } finally {
      if (mounted) setState(() => _attachingFile = false);
    }
  }

  DateTime? _dt(TimeOfDay? t) {
    if (_date == null || t == null) return null;
    return DateTime(_date!.year, _date!.month, _date!.day, t.hour, t.minute);
  }

  String _duration() {
    final from = _dt(_startTime), to = _dt(_endTime);
    if (from == null || to == null || !to.isAfter(from)) return "—";
    final d = to.difference(from);
    final h = d.inHours, m = d.inMinutes % 60;
    if (h > 0 && m > 0) return "${h}h ${m}m";
    if (h > 0) return "${h}h";
    return "${m}m";
  }

  String get _defaultLocation =>
      meetingType == "Training" ? "Training Room" : "Meeting Room";

  int? _resolveUserId() {
    int? p(dynamic v) => v == null ? null : int.tryParse(v.toString().trim());
    return p(widget.user["employee_id"]) ??
        p(widget.user["employeeId"]) ??
        p(widget.user["id"]);
  }

  void _resetForm() {
    _titleCtrl.clear(); _descCtrl.clear(); _linkCtrl.clear();
    _searchCtrl.clear();
    _locationCtrl.text = "Meeting Room";
    setState(() {
      _date = null; _startTime = null; _endTime = null;
      meetingType = "Meeting"; locationType = "physical";
      _attachedFile = null; _selectedIds.clear(); _staffSearch = '';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIds.isEmpty) {
      TopBanner.show(context,
          title: "Required", message: "Select at least one participant",
          icon: Icons.warning_amber_rounded, isError: true);
      return;
    }
    final userId = _resolveUserId();
    if (userId == null) {
      TopBanner.show(context,
          title: "Error", message: "Missing employee ID",
          icon: Icons.error_outline, isError: true);
      return;
    }
    if (_date == null || _startTime == null || _endTime == null) {
      TopBanner.show(context,
          title: "Required", message: "Select date, start time and end time",
          icon: Icons.warning_amber_rounded, isError: true);
      return;
    }
    final from = _dt(_startTime), to = _dt(_endTime);
    if (!to!.isAfter(from!)) {
      TopBanner.show(context,
          title: "Invalid", message: "End time must be after start time",
          icon: Icons.warning_amber_rounded, isError: true);
      return;
    }

    // Show confirmation dialog — actual submit happens in onConfirm
    await showMeetingSubmitDialog(
      context:          context,
      type:             meetingType,
      title:            _titleCtrl.text.trim(),
      dateTxt:          DateFormat('yyyy-MM-dd').format(_date!),
      startTimeTxt:     _startTime!.format(context),
      endTimeTxt:       _endTime!.format(context),
      duration:         _duration(),
      location:         locationType == "physical"
                            ? _locationCtrl.text.trim()
                            : _linkCtrl.text.trim(),
      participantCount: _selectedIds.length,
      attachmentName:   _attachedFile?.name,
      onConfirm:        () => _doSubmit(userId),
    );
  }

  Future<void> _doSubmit(int userId) async {
    setState(() => _submitting = true);
    final date = DateFormat('yyyy-MM-dd').format(_date!);
    final s = "${_startTime!.hour.toString().padLeft(2,'0')}:${_startTime!.minute.toString().padLeft(2,'0')}:00";
    final e = "${_endTime!.hour.toString().padLeft(2,'0')}:${_endTime!.minute.toString().padLeft(2,'0')}:00";
    final loc = locationType == "physical" ? _locationCtrl.text.trim() : _linkCtrl.text.trim();

    try {
      Map<String, dynamic> res;
      if (_attachedFile != null && _attachedFile!.path != null) {
        res = await MeetingAndEventService.createMeetingWithAttachment(
          type: meetingType.toLowerCase(),
          title: _titleCtrl.text.trim(), description: _descCtrl.text.trim(),
          meetingDate: date, startTime: s, endTime: e,
          locationType: locationType, location: loc,
          membersIds: _selectedIds.toList(), createdBy: userId,
          attachmentFile: File(_attachedFile!.path!), attachmentName: _attachedFile!.name,
        );
      } else {
        res = await MeetingAndEventService.createMeeting(
          type: meetingType.toLowerCase(),
          title: _titleCtrl.text.trim(), description: _descCtrl.text.trim(),
          meetingDate: date, startTime: s, endTime: e,
          locationType: locationType, location: loc,
          membersIds: _selectedIds.toList(), createdBy: userId,
        );
      }
      if (!mounted) return;
      setState(() => _submitting = false);
      if (res["success"] == true) {
        TopBanner.show(context,
            title: "Success",
            message: res["message"] ?? "Event created successfully",
            icon: Icons.check_circle, isSuccess: true);
        _resetForm();
        widget.onCreated();
      } else {
        TopBanner.show(context,
            title: "Failed", message: res["message"] ?? "Failed to create",
            icon: Icons.error_outline, isError: true);
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _submitting = false);
      TopBanner.show(context,
          title: "Error", message: "Failed: $err",
          icon: Icons.error_outline, isError: true);
    }
  }

  // ── UI helpers (matching gate pass style) ─────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: Color(0xFF1565C0), letterSpacing: 0.2)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Color(0xFFDDE4F0), thickness: 1)),
      ],
    );
  }

  Widget _fieldLabel(String label) => Text(label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: Color(0xFF1E2A3A)));

  InputDecoration _inputDeco(String hint, {IconData? icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.grey.shade600, size: 20) : null,
      suffixIcon: suffix,
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.4)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.4)),
      errorStyle: const TextStyle(color: Color(0xFFD32F2F),
          fontWeight: FontWeight.w700, fontSize: 12),
    );
  }

  Widget _submitBtn() {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.35),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: _submitting
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Text("CREATE EVENT",
                  style: TextStyle(color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _staffSearch.isEmpty
        ? _allStaff
        : _allStaff.where((s) =>
            (s["name"] ?? "").toLowerCase().contains(_staffSearch.toLowerCase()) ||
            (s["job_title"] ?? "").toLowerCase().contains(_staffSearch.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Event Details ─────────────────────────────────────────────
              _sectionHeader("Event Details", Icons.event_outlined),
              const SizedBox(height: 12),

              _fieldLabel("Type *"),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: meetingType,
                decoration: _inputDeco("Select type", icon: Icons.category_outlined),
                items: const [
                  DropdownMenuItem(value: "Meeting",  child: Text("Meeting")),
                  DropdownMenuItem(value: "Event",    child: Text("Event")),
                  DropdownMenuItem(value: "Training", child: Text("Training")),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    meetingType = v;
                    if (locationType == "physical") _locationCtrl.text = _defaultLocation;
                  });
                },
              ),
              const SizedBox(height: 14),

              _fieldLabel("Title *"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                decoration: _inputDeco("Enter event title…",
                    icon: Icons.title_outlined),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 14),

              _fieldLabel("Description"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                decoration: _inputDeco("Enter description…",
                    icon: Icons.notes_outlined),
              ),

              const SizedBox(height: 22),

              // ── Date & Time ───────────────────────────────────────────────
              _sectionHeader("Date & Time", Icons.calendar_month_outlined),
              const SizedBox(height: 12),

              _fieldLabel("Date *"),
              const SizedBox(height: 8),
              TextFormField(
                readOnly: true,
                style: const TextStyle(color: Colors.black, fontSize: 14),
                decoration: _inputDeco("Select date", icon: Icons.calendar_today,
                    suffix: Icon(Icons.calendar_today,
                        size: 18, color: Colors.grey.shade600)),
                controller: TextEditingController(
                    text: _date == null ? "" : DateFormat("yyyy-MM-dd").format(_date!)),
                validator: (_) => _date == null ? "Required" : null,
                onTap: _pickDate,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel("Start Time *"),
                        const SizedBox(height: 8),
                        TextFormField(
                          readOnly: true,
                          style: const TextStyle(color: Colors.black, fontSize: 14),
                          decoration: _inputDeco("Start",
                              suffix: Icon(Icons.access_time, size: 18,
                                  color: Colors.grey.shade600)),
                          controller: TextEditingController(
                              text: _startTime == null ? "" : _startTime!.format(context)),
                          validator: (_) => _startTime == null ? "Required" : null,
                          onTap: () => _pickTime(true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel("End Time *"),
                        const SizedBox(height: 8),
                        TextFormField(
                          readOnly: true,
                          style: const TextStyle(color: Colors.black, fontSize: 14),
                          decoration: _inputDeco("End",
                              suffix: Icon(Icons.timelapse, size: 18,
                                  color: Colors.grey.shade600)),
                          controller: TextEditingController(
                              text: _endTime == null ? "" : _endTime!.format(context)),
                          validator: (_) => _endTime == null ? "Required" : null,
                          onTap: () => _pickTime(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Duration",
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
                    Text(_duration(),
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w900, color: Color(0xFF1565C0))),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Location ──────────────────────────────────────────────────
              _sectionHeader("Location", Icons.place_outlined),
              const SizedBox(height: 12),

              Row(
                children: [
                  _locationPill("physical", "Physical", Icons.place_outlined),
                  const SizedBox(width: 10),
                  _locationPill("online", "Online", Icons.videocam_outlined),
                ],
              ),
              const SizedBox(height: 12),

              if (locationType == "physical") ...[
                _fieldLabel("Location"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationCtrl,
                  readOnly: true,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: _inputDeco("Location", icon: Icons.meeting_room_outlined),
                ),
              ] else ...[
                _fieldLabel("Meeting Link *"),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _linkCtrl,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: _inputDeco("https://…", icon: Icons.link_outlined),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
              ],

              const SizedBox(height: 22),

              // ── Attachment ────────────────────────────────────────────────
              _sectionHeader("Attachment", Icons.attach_file_outlined),
              const SizedBox(height: 4),
              const Text("Optional — PDF document",
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _attachingFile ? null : _pickPdf,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _attachedFile != null
                        ? const Color(0xFF1565C0) : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _attachedFile != null
                            ? Icons.picture_as_pdf_outlined
                            : Icons.upload_file_outlined,
                        size: 20,
                        color: _attachedFile != null
                            ? const Color(0xFFD32F2F) : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _attachingFile
                            ? const SizedBox(height: 14, width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(
                                _attachedFile == null
                                    ? "Tap to attach PDF…"
                                    : _attachedFile!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: _attachedFile != null
                                        ? Colors.black87 : Colors.grey.shade500),
                              ),
                      ),
                      if (_attachedFile != null)
                        GestureDetector(
                          onTap: () => setState(() => _attachedFile = null),
                          child: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ── Participants ──────────────────────────────────────────────
              _sectionHeader("Participants", Icons.group_outlined),
              const SizedBox(height: 4),
              const Text("Select staff members to invite *",
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 12),

              if (_loadingStaff)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(
                        color: Color(0xFF1565C0), strokeWidth: 2),
                  ),
                )
              else ...[
                // Search
                TextFormField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: _inputDeco("Search by name or job title…",
                      icon: Icons.search,
                      suffix: _staffSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() {
                                _searchCtrl.clear(); _staffSearch = '';
                              }))
                          : null),
                  onChanged: (v) => setState(() => _staffSearch = v),
                ),

                // Selected chips
                if (_selectedIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: _allStaff
                        .where((s) => _selectedIds.contains(s["id"]))
                        .map((s) => Chip(
                              backgroundColor: const Color(0xFFEAF1FF),
                              side: const BorderSide(color: Color(0xFFB3C8F0)),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () =>
                                  setState(() => _selectedIds.remove(s["id"])),
                              label: Text(s["name"] ?? "",
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700)),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 10),
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
                            child: Text("No results found",
                                style: TextStyle(color: Colors.black45)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (context, i) =>
                              const Divider(height: 1, color: Color(0xFFEEF2F8)),
                          itemBuilder: (_, i) {
                            final member  = filtered[i];
                            final id      = member["id"] ?? "";
                            final empId   = int.tryParse(id) ?? 0;
                            final checked = _selectedIds.contains(id);
                            return InkWell(
                              onTap: () => setState(() =>
                                  checked ? _selectedIds.remove(id) : _selectedIds.add(id)),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    FutureBuilder<Map<String, dynamic>?>(
                                      future: empId > 0 ? _photo(empId) : Future.value(null),
                                      builder: (_, snap) {
                                        final url = (snap.data?["fileUrl"] ?? "").toString().trim();
                                        if (snap.connectionState == ConnectionState.waiting) {
                                          return const CircleAvatar(
                                            radius: 18, backgroundColor: Color(0xFFEAF1FF),
                                            child: SizedBox(width: 12, height: 12,
                                              child: CircularProgressIndicator(
                                                  color: Color(0xFF1565C0), strokeWidth: 1.5)),
                                          );
                                        }
                                        if (url.isNotEmpty) {
                                          return CircleAvatar(radius: 18,
                                              backgroundColor: const Color(0xFFEAF1FF),
                                              backgroundImage: NetworkImage(url));
                                        }
                                        return const CircleAvatar(
                                          radius: 18, backgroundColor: Color(0xFFEAF1FF),
                                          child: Icon(Icons.person, size: 18, color: Colors.black45));
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(member["name"] ?? "",
                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 13, fontWeight: FontWeight.w800,
                                                  color: Colors.black87)),
                                          if ((member["job_title"] ?? "").trim().isNotEmpty)
                                            Text(member["job_title"]!,
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 11, color: Colors.black45)),
                                        ],
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: 22, height: 22,
                                      decoration: BoxDecoration(
                                        color: checked ? const Color(0xFF1565C0) : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: checked ? const Color(0xFF1565C0) : const Color(0xFFCDD5E0),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: checked
                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
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

              const SizedBox(height: 26),
              _submitBtn(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationPill(String value, String label, IconData icon) {
    final active = locationType == value;
    return GestureDetector(
      onTap: () => setState(() {
        locationType = value;
        if (value == "physical") {
          _locationCtrl.text = _defaultLocation;
          _linkCtrl.clear();
        } else {
          _locationCtrl.clear();
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? const Color(0xFF1565C0) : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: active ? Colors.white : Colors.black54),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 1 — My Events list (styled like GatePassRequestScreen)
// ═══════════════════════════════════════════════════════════════════════════════

class _MyEventsTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const _MyEventsTab({super.key, required this.user});

  @override
  State<_MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<_MyEventsTab> {
  bool    _loading = true;
  String? _error;
  int     _tab = 0; // 0 = My Events, 1 = Invited

  List<Map<String, dynamic>> _created = [];
  List<Map<String, dynamic>> _invited = [];

  final Map<int, Future<Map<String, dynamic>?>> _photoCache = {};
  final Map<int, String> _staffNames = {};

  @override
  void initState() { super.initState(); _load(); _loadStaffDir(); }

  String get _empId =>
      (widget.user["employee_id"] ?? widget.user["employeeId"] ??
          widget.user["id"] ?? "").toString().trim();

  Future<void> _loadStaffDir() async {
    try {
      final res = await MeetingAndEventService.getAllStaff();
      final mapped = <int, String>{};
      for (final raw in (res["members"] as List? ?? [])) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final id = int.tryParse((item["employee_id"] ?? item["id"] ?? "").toString());
        if (id == null) continue;
        final name = (item["name"] ?? "").toString().trim();
        mapped[id] = name.isEmpty ? "Unknown" : name;
      }
      if (!mounted) return;
      setState(() => _staffNames..clear()..addAll(mapped));
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    final empId = _empId;
    if (empId.isEmpty || empId == "0") {
      setState(() { _error = "Missing employee ID"; _loading = false; }); return;
    }
    try {
      final data = await MeetingAndEventService.getMyMeetings(employeeId: empId);
      if (!mounted) return;
      setState(() {
        final cr = data["created"];
        final inv = data["invited"];
        _created = (cr is List) ? cr.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
        _invited = (inv is List) ? inv.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _confirmCancel(Map<String, dynamic> meeting) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel Meeting?"),
        content: Text("\"${meeting['title']}\" will be permanently removed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Yes, Cancel", style: TextStyle(color: Colors.red.shade600))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final meetingId = int.tryParse((meeting["id"] ?? "").toString()) ?? 0;
    if (meetingId <= 0) return;

    try {
      final res = await MeetingAndEventService.deleteMeeting(
          meetingId: meetingId, employeeId: _empId);
      if (!mounted) return;
      if (res["success"] == true) {
        setState(() {
          final idx = _created.indexWhere((m) => m["id"].toString() == meeting["id"].toString());
          if (idx != -1) {
            _created[idx] = Map<String, dynamic>.from(_created[idx])..["status"] = "cancelled";
          }
        });
        TopBanner.show(context, title: "Cancelled",
            message: res["message"] ?? "Meeting cancelled",
            icon: Icons.check_circle, isSuccess: true);
      } else {
        TopBanner.show(context, title: "Error",
            message: res["message"] ?? "Failed to cancel",
            icon: Icons.error_outline, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(context, title: "Error", message: "Failed: $e",
          icon: Icons.error_outline, isError: true);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _photo(int id) =>
      _photoCache.putIfAbsent(id, () => ApiService.getProfilePhoto(employeeId: id));

  List<Map<String, dynamic>> get _current => _tab == 0 ? _created : _invited;

  List<int> _memberIds(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => int.tryParse(e.toString())).whereType<int>().toList();
  }

  Map<String, String> _responseMap(dynamic v) {
    if (v is! Map) return {};
    return v.map((k, val) => MapEntry(k.toString(), (val ?? "pending").toString()));
  }

  String _fmtDate(String d) {
    try { return DateFormat('MMM dd, yyyy').format(DateTime.parse(d)); }
    catch (_) { return d; }
  }

  String _fmtTime(String raw) {
    try {
      final p = raw.split(":");
      final h = int.parse(p[0]), m = int.parse(p[1]);
      final suffix = h >= 12 ? "PM" : "AM";
      final hr = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return "${hr.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix";
    } catch (_) { return raw; }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F7FA),
      child: RefreshIndicator(
        color: const Color(0xFF1565C0),
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildTabBar()),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: Color(0xFF1565C0), strokeWidth: 2)))
            else if (_error != null)
              SliverFillRemaining(child: _buildError())
            else if (_current.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildCard(_current[i]),
                    ),
                    childCount: _current.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final labels = [
      "My Events (${_created.length})",
      "Invited (${_invited.length})",
    ];
    return Container(
      color: const Color(0xFFF5F7FA),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(2, (i) {
            final active = _tab == i;
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF1565C0) : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active ? const Color(0xFF1565C0) : const Color(0xFFE1E6EF),
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> m) {
    final status    = (m["status"] ?? "scheduled").toString();
    final type      = (m["type"] ?? "").toString();
    final title     = (m["title"] ?? "Untitled").toString();
    final date      = _fmtDate((m["meeting_date"] ?? "").toString());
    final timeStr   = "${_fmtTime((m["start_time"] ?? "").toString())}  –  ${_fmtTime((m["end_time"] ?? "").toString())}";
    final location  = (m["location"] ?? "—").toString();
    final attachUrl = (m["attachment_url"] ?? "").toString().trim();
    final memberIds = _memberIds(m["members_ids"]);
    final respMap   = _responseMap(m["response_status"]);
    final isCreator = _tab == 0;
    final isCancelled = status.toLowerCase() == "cancelled";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ─────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                            color: isCancelled
                                ? const Color(0xFF6B7A90)
                                : const Color(0xFF1565C0))),
                    const SizedBox(height: 2),
                    Text(type.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF6B7A90),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _statusChip(status),
            ],
          ),

          const SizedBox(height: 10),

          // ── Details box ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _detailRow("Date",     date),
                const SizedBox(height: 8),
                _detailRow("Time",     timeStr),
                const SizedBox(height: 8),
                _detailRow("Location", location),
                const SizedBox(height: 8),
                _detailRow("Members",  "${memberIds.length} invited"),
                if (attachUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.tryParse(attachUrl);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Row(
                      children: [
                        const SizedBox(width: 0),
                        const SizedBox(
                          width: 75,
                          child: Text("File",
                              style: TextStyle(fontSize: 11.5,
                                  fontWeight: FontWeight.w700, color: Color(0xFF6B7A90))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.picture_as_pdf_outlined,
                                    size: 13, color: Color(0xFFD32F2F)),
                                const SizedBox(width: 4),
                                const Text("PDF Attached",
                                    style: TextStyle(fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFD32F2F))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Participants avatars ───────────────────────────────────────────
          if (memberIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                if (memberIds.any((id) => !_staffNames.containsKey(id))) {
                  await _loadStaffDir();
                }
                if (!mounted) return;
                showParticipantsSheet(
                  context: context, title: title,
                  memberIds: memberIds, responseStatus: respMap,
                  staffNameById: _staffNames, getPhotoFuture: _photo,
                );
              },
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
                      width: _avatarStackWidth(memberIds.length),
                      child: Stack(
                        children: [
                          for (int i = 0; i < memberIds.length.clamp(0, 3); i++)
                            Positioned(
                              left: i * 24.0,
                              child: _avatarCircle(memberIds[i], i),
                            ),
                          if (memberIds.length > 3)
                            Positioned(
                              left: 3 * 24.0,
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFCBD5E1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5)),
                                child: Center(
                                  child: Text('+${memberIds.length - 3}',
                                      style: const TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.w900,
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
                        memberIds.length == 1
                            ? (_staffNames[memberIds[0]] ?? "1 person")
                            : "${memberIds.length} people invited",
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.black38),
                  ],
                ),
              ),
            ),
          ],

          // ── Cancel button (creator only, not already cancelled) ────────────
          if (isCreator && !isCancelled) ...[
            const SizedBox(height: 12),
            _cancelBtn(() => _confirmCancel(m)),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 75,
          child: Text(label,
              style: const TextStyle(fontSize: 11.5,
                  fontWeight: FontWeight.w700, color: Color(0xFF6B7A90))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w900, color: Color(0xFF1E2A3A))),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    Color bg, fg;
    IconData icon;
    String label;
    switch (status.toLowerCase()) {
      case "ongoing":
        bg = const Color(0xFFE8F5E9); fg = const Color(0xFF2E7D32);
        icon = Icons.play_circle_outline; label = "Live"; break;
      case "completed":
        bg = const Color(0xFFEDE7F6); fg = const Color(0xFF512DA8);
        icon = Icons.verified_outlined; label = "Done"; break;
      case "cancelled":
        bg = const Color(0xFFF5F5F5); fg = Colors.black45;
        icon = Icons.block_outlined; label = "Cancelled"; break;
      default:
        bg = const Color(0xFFFFF8E1); fg = const Color(0xFFF9A825);
        icon = Icons.hourglass_top_outlined; label = "Upcoming";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }

  Widget _cancelBtn(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFD10A0A), Color(0xFF5B0000)],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: const Color(0xFFD10A0A).withOpacity(0.35),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.close_rounded, size: 17, color: Colors.white),
            SizedBox(width: 8),
            Text("Cancel Meeting",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _avatarCircle(int id, int index) {
    const colors = [Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFF6A1B9A), Color(0xFFE65100)];
    return FutureBuilder<Map<String, dynamic>?>(
      future: _photo(id),
      builder: (_, snap) {
        final url = (snap.data?["fileUrl"] ?? "").toString().trim();
        return Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: url.isEmpty ? colors[index % colors.length] : null,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            image: url.isNotEmpty
                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
          ),
          child: url.isEmpty
              ? Center(
                  child: Text(
                    (_staffNames[id] ?? "?").trim().isNotEmpty
                        ? (_staffNames[id]!.trim().split(" ").take(2)
                              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : "")
                              .join())
                        : "?",
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                )
              : null,
        );
      },
    );
  }

  double _avatarStackWidth(int count) => (count.clamp(0, 4) * 24.0) + 12;

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _tab == 0 ? "No events created yet" : "No meeting invitations",
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w700, color: Colors.black45),
          ),
          const SizedBox(height: 4),
          const Text("Pull down to refresh",
              style: TextStyle(fontSize: 12, color: Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
              label: const Text("Retry", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
