import 'package:flutter/material.dart';
import 'dart:ui';
import '../../Services/api_service.dart';
import '../../Leaves/top_banner.dart';
Future<void> showRejectDialog({
  required BuildContext context,
  required Map<String, dynamic> request,
  required String managerId,
  required Future<void> Function() reload,
}) async {

  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.15),
    builder: (ctx) {

      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.92).clamp(280.0, 420.0);

      return Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.transparent),
          ),

          Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),

              child: SizedBox(
                width: dialogW,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),

                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),

                            const Expanded(
                              child: Text(
                                "Reject Leave Request",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),

                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        const Text(
                          "This action cannot be undone.",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          "Your Comment",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: controller,
                          maxLines: 3,

                          decoration: InputDecoration(
                            hintText: "Peak season - unable to approve...",

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 1.4,
                              ),
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                          ),

                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return "Comment is required for reject";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          "Are you sure you want to reject this leave request?",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),

                        const SizedBox(height: 16),

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

                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),

                                child: const Text("Cancel"),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD10A0A),
                                      Color(0xFF5B0000),
                                    ],
                                  ),

                                  borderRadius: BorderRadius.circular(12),
                                ),

                                child: ElevatedButton(
                                  onPressed: () async {

                                    if (!formKey.currentState!.validate()) return;

                                    final comment = controller.text.trim();

                                    final leaveId = int.parse(
                                      request["leave_request_id"].toString(),
                                    );

                                    await ApiService.rejectLeave(
                                      managerId: managerId,
                                      leaveRequestId: leaveId,
                                      comment: comment,
                                    );

                                    Navigator.pop(ctx);

                                    await reload();

                                    TopBanner.show(
                                      context,
                                      title: "Reject Request",
                                      message: "Your pending leave request has been rejected successfully.",
                                      icon: Icons.cancel,
                                    );
                                  },

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),

                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),

                                    elevation: 0,
                                  ),

                                  child: const Text(
                                    "Reject",
                                    style: TextStyle(color: Colors.white),
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
            ),
          ),
        ],
      );
    },
  );
}