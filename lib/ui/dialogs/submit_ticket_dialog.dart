import 'dart:ui';
import 'package:flutter/material.dart';

/// Shows a confirmation dialog before submitting a new support ticket.
/// Returns `true` if the user confirmed, `null` / `false` if cancelled.
Future<bool?> showSubmitTicketDialog({
  required BuildContext context,
  required String platformName,
  required String issueTitle,
  required String ticketTitle,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.15),
    builder: (ctx) {
      final dialogW =
          (MediaQuery.of(ctx).size.width * 0.90).clamp(300.0, 440.0);

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
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: SizedBox(
                width: dialogW,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ────────────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Color(0xFF1565C0),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Submit Support Ticket',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E2A3A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Your ticket will be sent to the IT team',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8A97AD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close,
                                  size: 20, color: Color(0xFF8A97AD)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Ticket summary ─────────────────────────────────────
                      // Container(
                      //   width: double.infinity,
                      //   padding: const EdgeInsets.all(14),
                      //   decoration: BoxDecoration(
                      //     color: const Color(0xFFF4F7FC),
                      //     borderRadius: BorderRadius.circular(12),
                      //     border: Border.all(color: const Color(0xFFE4EBF8)),
                      //   ),
                      //   child: Column(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       // Category + Issue breadcrumb
                      //       Row(
                      //         children: [
                      //           const Icon(Icons.devices_outlined,
                      //               size: 12, color: Color(0xFF8A97AD)),
                      //           const SizedBox(width: 5),
                      //           Expanded(
                      //             child: Text(
                      //               platformName +
                      //                   (issueTitle.isNotEmpty &&
                      //                           issueTitle != 'Custom Issue'
                      //                       ? '  ›  $issueTitle'
                      //                       : ''),
                      //               maxLines: 1,
                      //               overflow: TextOverflow.ellipsis,
                      //               style: const TextStyle(
                      //                 fontSize: 11.5,
                      //                 color: Color(0xFF8A97AD),
                      //                 fontWeight: FontWeight.w600,
                      //               ),
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //       const SizedBox(height: 8),
                      //       // Divider
                      //       const Divider(height: 1, color: Color(0xFFE4EBF8)),
                      //       const SizedBox(height: 8),
                      //       // Ticket title
                      //       Text(
                      //         ticketTitle,
                      //         style: const TextStyle(
                      //           fontSize: 14,
                      //           fontWeight: FontWeight.w800,
                      //           color: Color.fromARGB(255, 58, 30, 30),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // const SizedBox(height: 14),

                      // ── Info note ──────────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.info_outline_rounded,
                              size: 14, color: Color(0xFF8A97AD)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'An IT agent will be assigned and respond as soon as possible.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A97AD),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Buttons ────────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0060A6),
                                side: const BorderSide(
                                    color: Color(0xFFC4C4C4), width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: const Text('Cancel',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1565C0),
                                    Color(0xFF003580),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(ctx, true),
                                icon: const Icon(Icons.send_rounded,
                                    color: Colors.white, size: 15),
                                label: const Text(
                                  'Submit Ticket',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  elevation: 0,
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
