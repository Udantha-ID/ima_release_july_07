import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<void> showStopTripDialog({
  required BuildContext context,
  required String vehicleNo,
  required String destination,
  required bool isSubmitting,
  required Future<void> Function({
    required String meterReading,
    required String fuelPercent,
    required File   meterPhoto,
    String?         remark,
  }) onConfirm,
}) async {
  final meterCtrl  = TextEditingController();
  final fuelCtrl   = TextEditingController();
  final remarkCtrl = TextEditingController();
  final formKey    = GlobalKey<FormState>();

  File? photoFile;
  String? photoName;

  bool isImageFile(String? name) {
    if (name == null) return false;
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.92).clamp(290.0, 440.0);
      final theme = Theme.of(ctx);
      bool submitting = isSubmitting;

      InputDecoration inputFieldStyle(String hint) {
        return InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.hintColor),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blue, width: 1.4),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: theme.colorScheme.outline, width: 1),
          ),
        );
      }

      Widget label(String t) => Text(
            t,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: theme.textTheme.bodyLarge?.color,
            ),
          );

      return StatefulBuilder(
        builder: (_, setDialogState) {
          Future<void> pickPhoto(ImageSource source) async {
            final x = await ImagePicker().pickImage(
                source: source, imageQuality: 80);
            if (x == null) return;
            setDialogState(() { photoFile = File(x.path); photoName = x.name; });
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: SizedBox(
                    width: dialogW,
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Red gradient header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFD10A0A), Color(0xFF5B0000)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius.vertical(top: Radius.circular(14)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Stop Trip",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$vehicleNo - $destination",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.90),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Scrollable body
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
                                  label("Final Meter Reading (km) *"),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: meterCtrl,
                                    style: TextStyle(
                                        color: theme.textTheme.bodyLarge?.color),
                                    keyboardType: TextInputType.number,
                                    decoration:
                                        inputFieldStyle("Enter final reading"),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return "Required";
                                      }
                                      if (!RegExp(r'^\d+(\.\d+)?$')
                                          .hasMatch(v.trim())) {
                                        return "Numbers only";
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 10),

                                  label("Current Fuel Reading (%) *"),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: fuelCtrl,
                                    style: TextStyle(
                                        color: theme.textTheme.bodyLarge?.color),
                                    keyboardType: TextInputType.number,
                                    decoration:
                                        inputFieldStyle("Enter current fuel reading"),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return "Required";
                                      }
                                      final val = double.tryParse(v.trim());
                                      if (val == null) return "Numbers only";
                                      if (val < 0 || val > 100) return "0 - 100 only";
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 10),

                                  label("Upload Meter Photo *"),
                                  const SizedBox(height: 8),

                                  GestureDetector(
                                    onTap: () async {
                                      FocusScope.of(ctx).unfocus();
                                      await Future.delayed(const Duration(milliseconds: 150));
                                      if (!ctx.mounted) return;
                                      await showModalBottomSheet(
                                        context: ctx,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(16)),
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
                                                if (photoFile != null)
                                                  ListTile(
                                                    leading: const Icon(Icons.delete,
                                                        color: Colors.red),
                                                    title: const Text("Remove photo"),
                                                    onTap: () {
                                                      Navigator.pop(ctx);
                                                      setDialogState(() {
                                                        photoFile = null;
                                                        photoName = null;
                                                      });
                                                    },
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: theme.colorScheme.outline),
                                        color: theme.colorScheme.surfaceContainerHighest,
                                      ),
                                      child: photoFile != null && isImageFile(photoName)
                                          ? Center(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: Image.file(
                                                  photoFile!,
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            )
                                          : Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.photo_camera_outlined,
                                                  size: 26,
                                                  color: theme.hintColor,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  photoFile == null
                                                      ? "Tap to take/upload meter photo JPG, PNG\n(Max 5MB)"
                                                      : "Photo selected",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme.hintColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Text(
                                    "• Ensure the photo clearly shows the meter reading\n"
                                    "• Double-check the number you entered matches the photo",
                                    style: TextStyle(
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w700,
                                      color: theme.hintColor,
                                      height: 1.25,
                                    ),
                                  ),

                                  const SizedBox(height: 10),
                                  label("Remark (Optional)"),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: remarkCtrl,
                                    maxLines: 2,
                                    maxLength: 300,
                                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                    decoration: inputFieldStyle("Add any notes about this trip end..."),
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
                                              color: Color.fromARGB(255, 196, 196, 196),
                                              width: 1.2,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
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
                                                      colors: [
                                                        Color(0xFF1565C0),
                                                        Color(0xFF003580),
                                                      ],
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
                                                      if (photoFile == null) {
                                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                                          const SnackBar(
                                                              content: Text("Please upload meter photo")),
                                                        );
                                                        return;
                                                      }
                                                      setDialogState(() => submitting = true);
                                                      await onConfirm(
                                                        meterReading: meterCtrl.text.trim(),
                                                        fuelPercent:  fuelCtrl.text.trim(),
                                                        meterPhoto:   photoFile!,
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
                                                      height: 20,
                                                      width: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : const Text(
                                                      "Stop Trip Now",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
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
