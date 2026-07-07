import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../Services/vehicle_api_service.dart';

// ── Places autocomplete ───────────────────────────────────────────────────────

class _PlaceSuggestion {
  final String description;
  final String placeId;
  _PlaceSuggestion({required this.description, required this.placeId});
  factory _PlaceSuggestion.fromJson(Map<String, dynamic> json) =>
      _PlaceSuggestion(description: json['description'], placeId: json['place_id']);
}

Future<List<_PlaceSuggestion>> _fetchPlaceSuggestions(String input) async {
  input = input.trim();
  if (input.isEmpty) return [];
  final apiKey = await VehicleApiService.getGooglePlacesApiKey();
  if (apiKey == null || apiKey.isEmpty) return [];
  final uri = Uri.https(
    "maps.googleapis.com",
    "/maps/api/place/autocomplete/json",
    {"input": input, "key": apiKey, "components": "country:lk"},
  );
  final res  = await http.get(uri);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200 || (data["status"] ?? "") != "OK") return [];
  return (data["predictions"] as List? ?? [])
      .map((e) => _PlaceSuggestion.fromJson(e as Map<String, dynamic>))
      .toList();
}

// ── Dialog A: End current vehicle ────────────────────────────────────────────

Future<void> showEndCurrentVehicleDialog({
  required BuildContext context,
  required String currentVehicleNo,
  required bool isSubmitting,
  required Future<void> Function({
    required int    endMeter,
    required double endFuel,
    required File   endPhoto,
    String?         remark,
  }) onConfirm,
}) async {
  final meterCtrl  = TextEditingController();
  final fuelCtrl   = TextEditingController();
  final remarkCtrl = TextEditingController();
  final formKey    = GlobalKey<FormState>();

  bool isImageFile(String? name) {
    if (name == null) return false;
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
           lower.endsWith('.png') || lower.endsWith('.webp');
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      File?   photo;
      String? photoName;
      bool    submitting = isSubmitting;

      final w       = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.92).clamp(290.0, 440.0);
      final theme   = Theme.of(ctx);

      InputDecoration inputStyle(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.hintColor),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blue, width: 1.4)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.outline, width: 1)),
      );

      Widget fieldLabel(String t) => Text(t,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900,
              color: theme.textTheme.bodyLarge?.color));

      return StatefulBuilder(
        builder: (_, setDialogState) {
          Future<void> pickPhoto(ImageSource source) async {
            final x = await ImagePicker().pickImage(source: source, imageQuality: 80);
            if (x == null) return;
            setDialogState(() { photo = File(x.path); photoName = x.name; });
          }

          return Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black.withValues(alpha: 0.20)),
              ),
              Center(
                child: Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: SizedBox(
                    width: dialogW,
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Orange gradient header ─────────────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFE65100), Color(0xFF8D2F00)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.swap_horiz_rounded,
                                    color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("End Current Vehicle",
                                          style: TextStyle(color: Colors.white,
                                              fontWeight: FontWeight.w900, fontSize: 14)),
                                      const SizedBox(height: 3),
                                      Text("Recording end of $currentVehicleNo",
                                          style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.90),
                                              fontWeight: FontWeight.w700, fontSize: 11.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Body ──────────────────────────────────────────
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(ctx).size.height * 0.72
                                  - MediaQuery.of(ctx).viewInsets.bottom,
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                fieldLabel("End Meter Reading (km) *"),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: meterCtrl,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                  decoration: inputStyle("Enter end odometer reading"),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return "Required";
                                    if (!RegExp(r'^\d+$').hasMatch(v.trim())) return "Numbers only";
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 10),
                                fieldLabel("End Fuel Reading (%) *"),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: fuelCtrl,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                  decoration: inputStyle("Enter fuel % (0-100)"),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return "Required";
                                    final val = double.tryParse(v.trim());
                                    if (val == null) return "Numbers only";
                                    if (val < 0 || val > 100) return "0 – 100 only";
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 10),
                                fieldLabel("End Meter Photo *"),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () async {
                                    FocusScope.of(ctx).unfocus();
                                    await Future.delayed(const Duration(milliseconds: 150));
                                    if (!ctx.mounted) return;
                                    await showModalBottomSheet(
                                      context: ctx,
                                      shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                                      builder: (_) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.camera_alt),
                                              title: const Text("Take photo"),
                                              onTap: () async {
                                                Navigator.pop(ctx);
                                                await pickPhoto(ImageSource.camera);
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.photo_library),
                                              title: const Text("Choose from gallery"),
                                              onTap: () async {
                                                Navigator.pop(ctx);
                                                await pickPhoto(ImageSource.gallery);
                                              },
                                            ),
                                            if (photo != null)
                                              ListTile(
                                                leading: const Icon(Icons.delete, color: Colors.red),
                                                title: const Text("Remove photo"),
                                                onTap: () {
                                                  Navigator.pop(ctx);
                                                  setDialogState(() { photo = null; photoName = null; });
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: theme.colorScheme.outline),
                                      color: theme.colorScheme.surfaceContainerHighest,
                                    ),
                                    child: photo != null && isImageFile(photoName)
                                        ? Center(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Image.file(photo!, width: 100, height: 100, fit: BoxFit.cover),
                                            ),
                                          )
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.photo_camera_outlined, size: 26, color: theme.hintColor),
                                              const SizedBox(height: 6),
                                              Text(
                                                photo == null
                                                    ? "Tap to take/upload meter photo JPG, PNG\n(Max 5MB)"
                                                    : "Photo selected",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                                                    color: theme.hintColor),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 10),
                                Text(
                                  "• Ensure the photo clearly shows the meter reading\n"
                                  "• Double-check the number you entered matches the photo",
                                  style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700,
                                      color: theme.hintColor, height: 1.25),
                                ),

                                const SizedBox(height: 10),
                                fieldLabel("Remark (Optional)"),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: remarkCtrl,
                                  maxLines: 2,
                                  maxLength: 300,
                                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                  decoration: inputStyle("Add any notes about ending this vehicle..."),
                                ),

                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF0060A6),
                                          side: const BorderSide(
                                              color: Color.fromARGB(255, 196, 196, 196), width: 1.2),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: const Text("Cancel"),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SizedBox(
                                        height: 46,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: submitting
                                                ? null
                                                : const LinearGradient(
                                                    colors: [Color(0xFFE65100), Color(0xFF8D2F00)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: ElevatedButton(
                                            onPressed: submitting
                                                ? null
                                                : () async {
                                                    if (!formKey.currentState!.validate()) return;
                                                    if (photo == null) {
                                                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                                          content: Text("Please upload meter photo")));
                                                      return;
                                                    }
                                                    setDialogState(() => submitting = true);
                                                    await onConfirm(
                                                      endMeter: int.parse(meterCtrl.text.trim()),
                                                      endFuel:  double.parse(fuelCtrl.text.trim()),
                                                      endPhoto: photo!,
                                                      remark: remarkCtrl.text.trim().isEmpty
                                                          ? null : remarkCtrl.text.trim(),
                                                    );
                                                    if (ctx.mounted) Navigator.pop(ctx);
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12)),
                                              elevation: 0,
                                            ),
                                            child: submitting
                                                ? const SizedBox(
                                                    height: 20, width: 20,
                                                    child: CircularProgressIndicator(
                                                        strokeWidth: 2.5, color: Colors.white),
                                                  )
                                                : const Text("End Vehicle &\nSwitch",
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w900)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

// ── Dialog B: Start new vehicle ───────────────────────────────────────────────

Future<void> showStartNewVehicleDialog({
  required BuildContext context,
  required bool isSubmitting,
  String? originalDestination,
  required Future<void> Function({
    required String newVehicleNo,
    required int    startMeter,
    required double startFuel,
    required File   startPhoto,
    String?         remark,
    String?         destination,
  }) onConfirm,
}) async {
  final lettersCtrl     = TextEditingController();
  final numbersCtrl     = TextEditingController();
  final meterCtrl       = TextEditingController();
  final fuelCtrl        = TextEditingController();
  final remarkCtrl      = TextEditingController();
  final destinationCtrl      = TextEditingController();
  final destinationFocusNode = FocusNode();
  final formKey              = GlobalKey<FormState>();

  bool isImageFile(String? name) {
    if (name == null) return false;
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
           lower.endsWith('.png') || lower.endsWith('.webp');
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      File?   photo;
      String? photoName;
      bool    submitting = isSubmitting;

      final w       = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.92).clamp(290.0, 440.0);
      final theme   = Theme.of(ctx);

      InputDecoration inputStyle(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.hintColor),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blue, width: 1.4)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.outline, width: 1)),
      );

      Widget fieldLabel(String t) => Text(t,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900,
              color: theme.textTheme.bodyLarge?.color));

      return StatefulBuilder(
        builder: (_, setDialogState) {
          Future<void> pickPhoto(ImageSource source) async {
            final x = await ImagePicker().pickImage(source: source, imageQuality: 80);
            if (x == null) return;
            setDialogState(() { photo = File(x.path); photoName = x.name; });
          }

          return Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black.withValues(alpha: 0.20)),
              ),
              Center(
                child: Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: SizedBox(
                    width: dialogW,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Blue gradient header ───────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF003580)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.directions_car_outlined,
                                  color: Colors.white, size: 22),
                              SizedBox(width: 10),
                              Text("Start New Vehicle",
                                  style: TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.w900, fontSize: 14)),
                            ],
                          ),
                        ),

                        // ── Scrollable body ────────────────────────────────
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(ctx).size.height * 0.72
                                - MediaQuery.of(ctx).viewInsets.bottom,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            child: Form(
                              key: formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  fieldLabel("New Vehicle Number *"),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 90,
                                        child: TextFormField(
                                          controller: lettersCtrl,
                                          keyboardType: TextInputType.text,
                                          textCapitalization: TextCapitalization.characters,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                                            LengthLimitingTextInputFormatter(3),
                                            _UpperCaseFormatter(),
                                          ],
                                          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                          decoration: inputStyle("ABC"),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) return "Req.";
                                            if (v.trim().length < 2) return "2-3 chars";
                                            return null;
                                          },
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Text("-", style: TextStyle(
                                            fontSize: 18, fontWeight: FontWeight.w900,
                                            color: Color(0xFF334155))),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: numbersCtrl,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(4),
                                          ],
                                          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                          decoration: inputStyle("0000"),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) return "Required";
                                            if (v.trim().length != 4) return "4 digits required";
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  fieldLabel("Start Meter Reading (km) *"),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: meterCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                    decoration: inputStyle("Enter start odometer reading"),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return "Required";
                                      if (!RegExp(r'^\d+$').hasMatch(v.trim())) return "Numbers only";
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 10),
                                  fieldLabel("Start Fuel Reading (%) *"),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: fuelCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                    decoration: inputStyle("Enter fuel % (0-100)"),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return "Required";
                                      final val = double.tryParse(v.trim());
                                      if (val == null) return "Numbers only";
                                      if (val < 0 || val > 100) return "0 – 100 only";
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 10),
                                  fieldLabel("New Vehicle Meter Photo *"),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      FocusScope.of(ctx).unfocus();
                                      await Future.delayed(const Duration(milliseconds: 150));
                                      if (!ctx.mounted) return;
                                      await showModalBottomSheet(
                                        context: ctx,
                                        shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                                        builder: (_) => SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons.camera_alt),
                                                title: const Text("Take photo"),
                                                onTap: () async {
                                                  Navigator.pop(ctx);
                                                  await pickPhoto(ImageSource.camera);
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.photo_library),
                                                title: const Text("Choose from gallery"),
                                                onTap: () async {
                                                  Navigator.pop(ctx);
                                                  await pickPhoto(ImageSource.gallery);
                                                },
                                              ),
                                              if (photo != null)
                                                ListTile(
                                                  leading: const Icon(Icons.delete, color: Colors.red),
                                                  title: const Text("Remove photo"),
                                                  onTap: () {
                                                    Navigator.pop(ctx);
                                                    setDialogState(() { photo = null; photoName = null; });
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: theme.colorScheme.outline),
                                        color: theme.colorScheme.surfaceContainerHighest,
                                      ),
                                      child: photo != null && isImageFile(photoName)
                                          ? Center(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: Image.file(photo!, width: 100, height: 100, fit: BoxFit.cover),
                                              ),
                                            )
                                          : Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.photo_camera_outlined, size: 26, color: theme.hintColor),
                                                const SizedBox(height: 6),
                                                Text(
                                                  photo == null
                                                      ? "Tap to take/upload meter photo JPG, PNG\n(Max 5MB)"
                                                      : "Photo selected",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                                                      color: theme.hintColor),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  fieldLabel("Destination *"),
                                  const SizedBox(height: 6),
                                  TypeAheadField<_PlaceSuggestion>(
                                    controller:          destinationCtrl,
                                    focusNode:           destinationFocusNode,
                                    debounceDuration:    const Duration(milliseconds: 400),
                                    suggestionsCallback: _fetchPlaceSuggestions,
                                    loadingBuilder: (context) => const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Center(child: CircularProgressIndicator(
                                          color: Colors.blue,
                                          backgroundColor: Colors.white,
                                          strokeWidth: 2)),
                                    ),
                                    itemBuilder: (context, s) => ListTile(
                                      leading: const Icon(Icons.location_on_outlined),
                                      title: Text(s.description,
                                          style: TextStyle(
                                              color: theme.textTheme.bodyLarge?.color)),
                                    ),
                                    onSelected: (s) {
                                      destinationCtrl.text = s.description;
                                      destinationFocusNode.unfocus();
                                    },
                                    builder: (context, controller, focusNode) => TextFormField(
                                      controller: controller,
                                      focusNode:  focusNode,
                                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                      decoration: inputStyle("Enter destination"),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return "Required";
                                        return null;
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 16),
                                  fieldLabel("Reason for change (Optional)"),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: remarkCtrl,
                                    maxLines: 2,
                                    maxLength: 300,
                                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                    decoration: inputStyle("Enter reason for changing vehicle..."),
                                  ),



                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF0060A6),
                                            side: const BorderSide(
                                                color: Color.fromARGB(255, 196, 196, 196), width: 1.2),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          child: const Text("Cancel"),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: SizedBox(
                                          height: 46,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: submitting
                                                  ? null
                                                  : const LinearGradient(
                                                      colors: [Color(0xFF1565C0), Color(0xFF003580)],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: ElevatedButton(
                                              onPressed: submitting
                                                  ? null
                                                  : () async {
                                                      if (!formKey.currentState!.validate()) return;
                                                      if (photo == null) {
                                                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                                            content: Text("Please upload meter photo")));
                                                        return;
                                                      }
                                                      setDialogState(() => submitting = true);
                                                      final vehicleNo =
                                                          "${lettersCtrl.text.trim()}-${numbersCtrl.text.trim()}";
                                                      await onConfirm(
                                                        newVehicleNo: vehicleNo,
                                                        startMeter:   int.parse(meterCtrl.text.trim()),
                                                        startFuel:    double.parse(fuelCtrl.text.trim()),
                                                        startPhoto:   photo!,
                                                        remark: remarkCtrl.text.trim().isEmpty
                                                            ? null : remarkCtrl.text.trim(),
                                                        destination: destinationCtrl.text.trim(),
                                                      );
                                                      if (ctx.mounted) Navigator.pop(ctx);
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12)),
                                                elevation: 0,
                                              ),
                                              child: submitting
                                                  ? const SizedBox(
                                                      height: 20, width: 20,
                                                      child: CircularProgressIndicator(
                                                          strokeWidth: 2.5, color: Colors.white),
                                                    )
                                                  : const Text("Start Trip",
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w900)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) =>
      next.copyWith(text: next.text.toUpperCase());
}
