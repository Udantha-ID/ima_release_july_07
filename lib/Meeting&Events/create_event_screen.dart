import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Constants/app_colors.dart';
import '../Services/api_service.dart';
import '../Services/meeting_and_event_service.dart';
import '../ui/dialogs/meeting_event_dialogs.dart';
import '../ui/widgets/time_picker_sheet.dart';

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CreateEventScreen({super.key, required this.user});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController meetingLinkController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  String meetingType = "Meeting"; // Meeting | Event | Training
  String locationType = "physical"; // physical | online
  bool isLoading = false;
  bool isLoadingMembers = false;

  // Feature 2 — PDF attachment
  PlatformFile? _attachedFile;
  bool _isAttachingFile = false;

  List<Map<String, String>> allStaffMembers = [];
  final Set<String> selectedParticipantIds = {};
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

  @override
  void initState() {
    super.initState();
    locationController.text = "Meeting Room";
    _loadStaffMembers();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    meetingLinkController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
    return _photoFutureCache.putIfAbsent(
      employeeId,
      () => ApiService.getProfilePhoto(employeeId: employeeId),
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1565C0), onPrimary: Colors.white,
            surface: Colors.white, onSurface: Color(0xFF1E2A3A),
          ),
          dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePickerSheet(
      context,
      initial: startTime,
      title: 'Start Time',
    );
    if (picked != null) setState(() => startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePickerSheet(
      context,
      initial: endTime ?? startTime,
      title: 'End Time',
    );
    if (picked != null) setState(() => endTime = picked);
  }

  Future<void> _pickPdfFile() async {
    setState(() => _isAttachingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
        withReadStream: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _attachedFile = result.files.first);
      }
    } finally {
      if (mounted) setState(() => _isAttachingFile = false);
    }
  }

  Future<void> _loadStaffMembers() async {
    setState(() => isLoadingMembers = true);
    try {
      final res = await MeetingAndEventService.getAllStaff();
      if (res['success'] != true) throw Exception("API failed");

      final List members = res['members'] ?? [];
      final list = members
          .map<Map<String, String>>((e) {
            final item = Map<String, dynamic>.from(e);
            final id = (item["id"] ?? item["employee_id"] ?? "").toString();
            final name = (item["name"] ?? "Unknown").toString();
            final jobTitle = (item["job_title"] ?? "").toString();
            if (id.trim().isEmpty) return {};
            return {"id": id, "name": name, "job_title": jobTitle};
          })
          .where((m) => m.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _photoFutureCache.clear();
        allStaffMembers = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load staff members")),
      );
    } finally {
      if (mounted) setState(() => isLoadingMembers = false);
    }
  }

  DateTime? _toDateTime(TimeOfDay? time) {
    if (selectedDate == null || time == null) return null;
    return DateTime(
      selectedDate!.year, selectedDate!.month, selectedDate!.day,
      time.hour, time.minute,
    );
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }

  int? _resolveUserId() {
    final topLevel = _parseInt(widget.user["employee_id"]) ??
        _parseInt(widget.user["employeeId"]) ??
        _parseInt(widget.user["id"]) ??
        _parseInt(widget.user["emp_id"]) ??
        _parseInt(widget.user["user_id"]) ??
        _parseInt(widget.user["staff_id"]);
    if (topLevel != null) return topLevel;

    final nestedCandidates = [
      widget.user["user"],
      widget.user["employee"],
      widget.user["data"],
      widget.user["profile"],
    ];
    for (final candidate in nestedCandidates) {
      if (candidate is Map) {
        final nested = Map<String, dynamic>.from(candidate);
        final nestedId = _parseInt(nested["employee_id"]) ??
            _parseInt(nested["employeeId"]) ??
            _parseInt(nested["id"]) ??
            _parseInt(nested["emp_id"]) ??
            _parseInt(nested["user_id"]) ??
            _parseInt(nested["staff_id"]);
        if (nestedId != null) return nestedId;
      }
    }
    return null;
  }

  String _computedDurationText() {
    final from = _toDateTime(startTime);
    final to = _toDateTime(endTime);
    if (from == null || to == null || !to.isAfter(from)) return "-";
    final diff = to.difference(from);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0 && minutes > 0) return "${hours}h ${minutes}m";
    if (hours > 0) return "${hours}h";
    return "${minutes}m";
  }

  String _defaultLocation() {
    if (meetingType == "Training") return "Training Room";
    return "Meeting Room";
  }

  Future<void> createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one participant")),
      );
      return;
    }

    final userId = _resolveUserId();
    if (userId == null) {
      debugPrint("CreateEventScreen user payload: ${widget.user}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing employee_id")),
      );
      return;
    }

    final from = _toDateTime(startTime);
    final to   = _toDateTime(endTime);
    if (selectedDate == null || from == null || to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select date, start time and end time")),
      );
      return;
    }
    if (!to.isAfter(from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End time must be after start time")),
      );
      return;
    }

    // Show confirmation dialog — actual submit happens in onConfirm
    await showMeetingSubmitDialog(
      context: context,
      type:             meetingType,
      title:            titleController.text.trim(),
      dateTxt:          DateFormat('yyyy-MM-dd').format(selectedDate!),
      startTimeTxt:     startTime!.format(context),
      endTimeTxt:       endTime!.format(context),
      duration:         _computedDurationText(),
      location:         locationType == "physical"
                            ? locationController.text.trim()
                            : meetingLinkController.text.trim(),
      participantCount: selectedParticipantIds.length,
      attachmentName:   _attachedFile?.name,
      onConfirm:        () => _doSubmit(userId),
    );
  }

  Future<void> _doSubmit(int userId) async {
    setState(() => isLoading = true);

    final formattedDate      = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final formattedStartTime =
        "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00";
    final formattedEndTime   =
        "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}:00";
    final resolvedLocation   = locationType == "physical"
        ? locationController.text.trim()
        : meetingLinkController.text.trim();

    try {
      Map<String, dynamic> response;

      if (_attachedFile != null && _attachedFile!.path != null) {
        response = await MeetingAndEventService.createMeetingWithAttachment(
          type:             meetingType.toLowerCase(),
          title:            titleController.text.trim(),
          description:      descriptionController.text.trim(),
          meetingDate:      formattedDate,
          startTime:        formattedStartTime,
          endTime:          formattedEndTime,
          locationType:     locationType,
          location:         resolvedLocation,
          membersIds:       selectedParticipantIds.toList(),
          createdBy:        userId,
          attachmentFile:   File(_attachedFile!.path!),
          attachmentName:   _attachedFile!.name,
        );
      } else {
        response = await MeetingAndEventService.createMeeting(
          type:         meetingType.toLowerCase(),
          title:        titleController.text.trim(),
          description:  descriptionController.text.trim(),
          meetingDate:  formattedDate,
          startTime:    formattedStartTime,
          endTime:      formattedEndTime,
          locationType: locationType,
          location:     resolvedLocation,
          membersIds:   selectedParticipantIds.toList(),
          createdBy:    userId,
        );
      }

      if (!mounted) return;
      setState(() => isLoading = false);

      if (response["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response["message"] ?? "Event Created Successfully")),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response["message"] ?? "Failed to create event")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create event: $e")),
      );
    }
  }

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E2A3A)),
        ),
      );

  InputDecoration _inputDecoration(String hint, {IconData? icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600, size: 20) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
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
      errorStyle: const TextStyle(
          color: Color(0xFFD32F2F), fontWeight: FontWeight.w700, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Event")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Meeting / Event / Training type
              DropdownButtonFormField<String>(
                value: meetingType,
                decoration: const InputDecoration(labelText: "Title Type"),
                items: const [
                  DropdownMenuItem(value: "Meeting", child: Text("Meeting")),
                  DropdownMenuItem(value: "Event", child: Text("Event")),
                  DropdownMenuItem(value: "Training", child: Text("Training")),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    meetingType = v;
                    if (locationType == "physical") {
                      locationController.text = _defaultLocation();
                    }
                  });
                },
              ),

              const SizedBox(height: 10),

              // Event title
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
                validator: (v) => v!.isEmpty ? "Enter title" : null,
              ),

              const SizedBox(height: 10),

              // Description
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
              ),

              const SizedBox(height: 10),

              // PDF Attachment (Feature 2)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Attachment (Optional)",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: _isAttachingFile
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.attach_file, size: 18),
                          label: Text(
                            _attachedFile == null
                                ? "Attach PDF Document"
                                : _attachedFile!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed: _isAttachingFile ? null : _pickPdfFile,
                        ),
                      ),
                      if (_attachedFile != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.red),
                          tooltip: "Remove attachment",
                          onPressed: () => setState(() => _attachedFile = null),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Date
              _fieldLabel('Date *'),
              TextFormField(
                readOnly: true,
                style: const TextStyle(color: Colors.black, fontSize: 14),
                controller: TextEditingController(
                  text: selectedDate == null
                      ? ''
                      : DateFormat('yyyy-MM-dd').format(selectedDate!),
                ),
                decoration: _inputDecoration(
                  'Select date',
                  icon: Icons.calendar_today,
                  suffix: Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                ),
                validator: (_) => selectedDate == null ? 'Required' : null,
                onTap: pickDate,
              ),

              const SizedBox(height: 14),

              // Start & End time side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Start Time *'),
                        TextFormField(
                          readOnly: true,
                          style: const TextStyle(color: Colors.black, fontSize: 14),
                          controller: TextEditingController(
                            text: startTime == null ? '' : startTime!.format(context),
                          ),
                          decoration: _inputDecoration(
                            'Start',
                            suffix: Icon(Icons.access_time, size: 18,
                                color: Colors.grey.shade600),
                          ),
                          validator: (_) => startTime == null ? 'Required' : null,
                          onTap: _pickStartTime,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('End Time *'),
                        TextFormField(
                          readOnly: true,
                          style: const TextStyle(color: Colors.black, fontSize: 14),
                          controller: TextEditingController(
                            text: endTime == null ? '' : endTime!.format(context),
                          ),
                          decoration: _inputDecoration(
                            'End',
                            suffix: Icon(Icons.timelapse, size: 18,
                                color: Colors.grey.shade600),
                          ),
                          validator: (_) => endTime == null ? 'Required' : null,
                          onTap: _pickEndTime,
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Duration",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1565C0)),
                    ),
                    Text(
                      _computedDurationText(),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1565C0)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Location Type
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: const Text("Physical"),
                      value: "physical",
                      groupValue: locationType,
                      onChanged: (value) {
                        setState(() {
                          locationType = value.toString();
                          locationController.text = _defaultLocation();
                          meetingLinkController.clear();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: const Text("Online"),
                      value: "online",
                      groupValue: locationType,
                      onChanged: (value) {
                        setState(() {
                          locationType = value.toString();
                          locationController.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Location or Link
              if (locationType == "physical")
                TextFormField(
                  controller: locationController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: "Location"),
                ),

              if (locationType == "online")
                TextFormField(
                  controller: meetingLinkController,
                  decoration: const InputDecoration(labelText: "Meeting Link"),
                  validator: (v) => v!.isEmpty ? "Enter meeting link" : null,
                ),

              const SizedBox(height: 15),

              // Participants
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Participants *",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              if (isLoadingMembers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (allStaffMembers.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "No staff members available",
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E6EF)),
                  ),
                  child: SizedBox(
                    height: 260,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        itemCount: allStaffMembers.length,
                        itemBuilder: (context, index) {
                          final member = allStaffMembers[index];
                          final memberId = member["id"]!;
                          final checked = selectedParticipantIds.contains(memberId);
                          final empId = int.tryParse(memberId) ?? 0;

                          return CheckboxListTile(
                            value: checked,
                            controlAffinity: ListTileControlAffinity.trailing,
                            activeColor: AppColors.primaryStart,
                            secondary: FutureBuilder<Map<String, dynamic>?>(
                              future: empId > 0
                                  ? _getPhotoFuture(empId)
                                  : Future.value(null),
                              builder: (context, snap) {
                                final url = (snap.data?["fileUrl"] ?? "")
                                    .toString()
                                    .trim();
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Color(0xFFEAF1FF),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
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
                              member["name"] ?? "",
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: (member["job_title"] ?? "").trim().isNotEmpty
                                ? Text(
                                    member["job_title"]!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  selectedParticipantIds.add(memberId);
                                } else {
                                  selectedParticipantIds.remove(memberId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryStart, AppColors.primaryEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isLoading ? null : createEvent,
                    child: isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Create Event",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
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
