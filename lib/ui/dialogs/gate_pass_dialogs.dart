import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Submit Gate Pass dialog
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showGatePassSubmitDialog({
  required BuildContext context,
  required String       dateTxt,
  required String       outTimeTxt,
  required String       returnTimeTxt,
  required String       vehicleNoTxt,
  required String       reason,
  required String       managerName,
  String?               companions,
  String?               remark,
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

                      // Title row
                      Row(children: [
                        const Icon(Icons.badge_outlined,
                            color: Color(0xFF1565C0)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Confirm Gate Pass',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                        ),
                      ]),

                      const Text(
                        'Please review your details before submitting.',
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5),
                      ),

                      const SizedBox(height: 14),

                      // Summary box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFC4C4C4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _row(ctx, 'Date',     dateTxt),
                            const SizedBox(height: 6),
                            _row(ctx, 'Out',      outTimeTxt),
                            const SizedBox(height: 6),
                            _row(ctx, 'Return',   returnTimeTxt),
                            const SizedBox(height: 6),
                            _row(ctx, 'Vehicle',  vehicleNoTxt),
                            const SizedBox(height: 6),
                            _row(ctx, 'Reason',   reason),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      const Text(
                        'Are you sure you want to submit this gate pass request?',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(children: [
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
                            child: const Text('Cancel'),
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
                                    Color(0xFF003580)
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
                                child: const Text('Submit',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                      ]),
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
// Cancel Gate Pass dialog
// ─────────────────────────────────────────────────────────────────────────────

Future<bool?> showGatePassCancelDialog({
  required BuildContext context,
  String? gatePassCode,
}) {
  return showDialog<bool>(
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

                      // Title row
                      Row(children: [
                        Icon(Icons.cancel_outlined,
                            color: Colors.red.shade700),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Cancel Request',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                        ),
                      ]),

                      const Text(
                        'This action cannot be undone.',
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5),
                      ),

                      const SizedBox(height: 14),

                      // Gate pass code pill (if approved / has code)
                      if (gatePassCode != null && gatePassCode.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC4C4C4)),
                          ),
                          child: _row(ctx, 'Request', gatePassCode),
                        ),
                        const SizedBox(height: 14),
                      ],

                      const Text(
                        'Are you sure you want to cancel this gate pass request?',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black54,
                              side: const BorderSide(
                                  color: Color(0xFFC4C4C4), width: 1.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('No, Keep It'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFD10A0A), Color(0xFF5B0000)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: const Text('Yes, Cancel',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                      ]),
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
// Check Out dialog
// ─────────────────────────────────────────────────────────────────────────────

Future<bool?> showGatePassCheckOutDialog({
  required BuildContext context,
  required String gatePassCode,
}) {
  return showDialog<bool>(
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

                      // Title row
                      Row(children: [
                        const Icon(Icons.logout_rounded,
                            color: Color(0xFF1565C0)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Confirm Check Out',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                        ),
                      ]),

                      const Text(
                        'Your departure time will be recorded now.',
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5),
                      ),

                      const SizedBox(height: 14),

                      // Gate pass code box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFB3C8F0)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.badge_outlined,
                              size: 16, color: Color(0xFF1565C0)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              gatePassCode,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1565C0)),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 14),
                      const Text(
                        'Are you sure you want to check out now?',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black54,
                              side: const BorderSide(
                                  color: Color(0xFFC4C4C4), width: 1.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
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
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: const Text('Check Out',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                      ]),
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
// Check In dialog
// ─────────────────────────────────────────────────────────────────────────────

Future<bool?> showGatePassCheckInDialog({
  required BuildContext context,
  required String       gatePassCode,
  String?               checkedOutAt,
}) {
  return showDialog<bool>(
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

                      // Title row
                      Row(children: [
                        const Icon(Icons.login_rounded, color: Colors.green),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Confirm Check In',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                        ),
                      ]),

                      const Text(
                        'Your return time will be recorded and the gate pass will be marked as Completed.',
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5),
                      ),

                      const SizedBox(height: 14),

                      // Gate pass code + optional checked-out time
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.badge_outlined,
                                  size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  gatePassCode,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.green),
                                ),
                              ),
                            ]),
                            if (checkedOutAt != null &&
                                checkedOutAt.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.logout_rounded,
                                    size: 14, color: Colors.black38),
                                const SizedBox(width: 6),
                                Text(
                                  'Checked out: $checkedOutAt',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black45),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      const Text(
                        'Are you sure you want to check in now?',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black54,
                              side: const BorderSide(
                                  color: Color(0xFFC4C4C4), width: 1.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
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
                                    Color(0xFF2E7D32),
                                    Color(0xFF1B5E20),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: const Text('Check In',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                      ]),
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
// Shared label–value row
// ─────────────────────────────────────────────────────────────────────────────

Widget _row(BuildContext context, String label, String value) {
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
