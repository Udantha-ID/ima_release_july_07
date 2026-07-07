import 'dart:ui';
import 'package:flutter/material.dart';



Future<void> showLeaveSubmitDialog({
  required BuildContext context,
  required String leaveType,
  required String fromTxt,
  required String toTxt,
  required String daysTxt,
  required bool isSubmitting,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.92).clamp(280.0, 420.0);

      return Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
          Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: SizedBox(
                width: dialogW,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFF0060A6)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text("Apply Leave Request",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Text("This action cannot be undone.",
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),

                      const SizedBox(height: 14),
                      
                      // Leave details card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leaveType,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              daysTxt,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$fromTxt to $toTxt",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        "Are you sure you want to submit this leave request?\nYour leave balance will be restored.",
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Color(0xFF0060A6), // Text color
                                    side: const BorderSide(color: Color.fromARGB(255, 196, 196, 196), width: 1.2),
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
                                height: 48,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: isSubmitting
                                        ? null
                                        : const LinearGradient(
                                            colors: [Color(0xFF0060A6), Color(0xFF003580)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isSubmitting
                                        ? null
                                        : () {
                                            onConfirm();
                                            Navigator.pop(ctx);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: isSubmitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Send',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
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
            ),
          ),
        ],
      );
    },
  );
}
