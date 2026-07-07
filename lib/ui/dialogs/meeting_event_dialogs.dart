import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Confirm Event / Meeting creation dialog
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showMeetingSubmitDialog({
  required BuildContext context,
  required String type,
  required String title,
  required String dateTxt,
  required String startTimeTxt,
  required String endTimeTxt,
  required String duration,
  required String location,
  required int    participantCount,
  String?         attachmentName,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      final dialogW =
          (MediaQuery.of(ctx).size.width * 0.92).clamp(280.0, 420.0);
      return Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withValues(alpha: 0.15)),
          ),
          Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: SizedBox(
                width: dialogW,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Title row ─────────────────────────────────────────
                      Row(
                        children: [
                          const Icon(Icons.event_outlined,
                              color: Color(0xFF1565C0)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Confirm Event',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),

                      const Text(
                        'Please review the details before creating.',
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5),
                      ),

                      const SizedBox(height: 14),

                      // ── Type badge ────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _typeColor(type).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _typeColor(type)),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── Summary box ───────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC4C4C4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _row('Title',    title),
                            const SizedBox(height: 6),
                            _row('Date',     dateTxt),
                            const SizedBox(height: 6),
                            _row('Start',    startTimeTxt),
                            const SizedBox(height: 6),
                            _row('End',      endTimeTxt),
                            const SizedBox(height: 6),
                            _row('Duration', duration),
                            const SizedBox(height: 6),
                            _row('Location', location),
                            const SizedBox(height: 6),
                            _row('Members',  '$participantCount selected'),
                            if (attachmentName != null) ...[
                              const SizedBox(height: 6),
                              _row('File', attachmentName),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        'Are you sure you want to create this event?\nInvitations will be sent to all selected members.',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),

                      const SizedBox(height: 16),

                      // ── Buttons ───────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1565C0),
                                side: const BorderSide(
                                    color: Color(0xFFC4C4C4), width: 1.2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Go Back'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
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
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    onConfirm();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Create',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _typeColor(String type) {
  switch (type.toLowerCase()) {
    case 'training': return const Color(0xFF6A1B9A);
    case 'event':    return const Color(0xFF00796B);
    default:         return const Color(0xFF1565C0);
  }
}

Widget _row(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 72,
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E2A3A)),
        ),
      ),
    ],
  );
}
