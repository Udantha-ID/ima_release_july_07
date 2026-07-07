import 'package:flutter/material.dart';
import 'dart:ui';
import '../../Services/api_service.dart';
import '../../Leaves/top_banner.dart';

Future<void> showApproveDialog({
  required BuildContext context,
  required Map<String, dynamic> request,
  required String managerId,
  required Future<void> Function() reload,
}) async {

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.15),

    builder: (ctx) {

      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.90).clamp(300.0, 420.0);

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

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Colors.green),

                          const SizedBox(width: 10),

                          const Expanded(
                            child: Text(
                              "Approve Leave Request",
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
                        "Please confirm approval.",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        "Approve leave for ${request['employeeName']}?",
                        style: const TextStyle(fontWeight: FontWeight.w800),
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
                                  color: Color(0xFFC4C4C4),
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
                                    Color(0xFF2E7D32),
                                    Color(0xFF1B5E20),
                                  ],
                                ),

                                borderRadius: BorderRadius.circular(12),
                              ),

                              child: ElevatedButton(
                                onPressed: () async {
  try {
    final leaveId = int.parse(
      request["leave_request_id"].toString(),
    );

    await ApiService.approveLeave(
      managerId: managerId,
      leaveRequestId: leaveId,
    );

    Navigator.pop(ctx);

    await reload();

    TopBanner.show(
      context,
      title: "Accept Request",
      message:
          "Your pending leave request has been accepted successfully.",
      icon: Icons.check_circle,
    );

  } catch (e) {
    print("Approve Error: $e");

    TopBanner.show(
      context,
      title: "Error",
      message: e.toString(),
      icon: Icons.error,
    );
  }
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
                                  "Approve",
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
        ],
      );
    },
  );
}