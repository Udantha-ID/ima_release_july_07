import 'dart:ui';
import 'package:flutter/material.dart';

/// Shows the Mark-as-Resolved confirmation dialog.
///
/// Returns the resolution note string if the agent confirmed,
/// or `null` if they cancelled / dismissed.
/// An empty string means confirmed with no note.
Future<String?> showResolveTicketDialog({
  required BuildContext context,
  required String ticketTitle,
  required String employeeName,
}) async {
  final noteCtrl = TextEditingController();

  final result = await showDialog<String>(
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
                      // ── Header ─────────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.task_alt_rounded,
                              color: Color(0xFF2E7D32),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Mark as Resolved',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E2A3A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'This action cannot be undone',
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

                      // ── Resolution note ─────────────────────────────────
                      const Text(
                        'Resolution Note',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF1E2A3A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Briefly describe what was done to fix this issue (optional)',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF8A97AD)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 3,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1E2A3A)),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Reinstalled the software and verified access…',
                          hintStyle: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF4F7FC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF1565C0), width: 1.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Buttons ─────────────────────────────────────────
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
                                    Color(0xFF2E7D32),
                                    Color(0xFF1B5E20)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    Navigator.pop(ctx, noteCtrl.text.trim()),
                                icon: const Icon(Icons.task_alt_rounded,
                                    color: Colors.white, size: 15),
                                label: const Text(
                                  'Mark Resolved',
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

  WidgetsBinding.instance.addPostFrameCallback((_) => noteCtrl.dispose());
  return result;
}
