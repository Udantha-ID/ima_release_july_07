import 'dart:ui';
import 'package:flutter/material.dart';

enum ReceiptExistsAction { open, regenerate }

// ─────────────────────────────────────────────────────────────────────────────
//  EXISTING RECEIPT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

/// Shows when a PDF receipt already exists on the server.
/// Returns [ReceiptExistsAction.open], [ReceiptExistsAction.regenerate],
/// or `null` if dismissed.
Future<ReceiptExistsAction?> showReceiptExistsDialog({
  required BuildContext context,
  required String reference,
  required String pdfUrl,
}) {
  return showDialog<ReceiptExistsAction>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.15),
    builder: (ctx) => _ReceiptExistsDialog(
      reference: reference,
      pdfUrl: pdfUrl,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  NO RECEIPT — GENERATE CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────────────────────

/// Shows when no receipt exists yet and the user taps "Create PDF".
/// Returns `true` to proceed with generation, `false` / `null` to cancel.
Future<bool> showReceiptGenerateConfirmDialog({
  required BuildContext context,
  required String reference,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.15),
    builder: (ctx) => _GenerateConfirmDialog(reference: reference),
  );
  return result == true;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _blue1     = Color(0xFF1565C0);
const _blue2     = Color(0xFF003580);
const _textDark  = Color(0xFF0F172A);
const _textMuted = Color(0xFF64748B);
const _cardBg    = Color(0xFFF1F5F9);
const _cardBorder = Color(0xFFE2E8F0);

// ─────────────────────────────────────────────────────────────────────────────
//  EXISTING RECEIPT WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _ReceiptExistsDialog extends StatelessWidget {
  final String reference;
  final String pdfUrl;

  const _ReceiptExistsDialog({required this.reference, required this.pdfUrl});

  String _extractFileName(String url) {
    try {
      return Uri.parse(url).pathSegments.last;
    } catch (_) {
      return url;
    }
  }

  // String _extractDateFromFileName(String fileName) {
  //   final match = RegExp(r'(\d{8})(\d{6})').firstMatch(fileName);
  //   if (match == null) return '';
  //   final dateStr = match.group(1)!;
  //   final timeStr = match.group(2)!;
  //   try {
  //     final y  = dateStr.substring(0, 4);
  //     final mo = dateStr.substring(4, 6);
  //     final d  = dateStr.substring(6, 8);
  //     final h  = int.parse(timeStr.substring(0, 2));
  //     final mi = timeStr.substring(2, 4);
  //     const months = [
  //       'Jan','Feb','Mar','Apr','May','Jun',
  //       'Jul','Aug','Sep','Oct','Nov','Dec',
  //     ];
  //     final monthName = months[int.parse(mo) - 1];
  //     final hour = h % 12 == 0 ? 12 : h % 12;
  //     final ampm = h >= 12 ? 'PM' : 'AM';
  //     return '$d $monthName $y  $hour:$mi $ampm';
  //   } catch (_) {
  //     return '';
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final dialogW =
        (MediaQuery.of(context).size.width * 0.90).clamp(300.0, 420.0);
    final fileName    = _extractFileName(pdfUrl);
    // final generatedAt = _extractDateFromFileName(fileName);

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
            child: SizedBox(
              width: dialogW,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded,
                              color: _blue2, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receipt Already Exists',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _textDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'A saved PDF was found for this booking.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(null),
                          child: const Icon(Icons.close_rounded,
                              color: _textMuted, size: 20),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Receipt info card ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.confirmation_number_rounded,
                            label: 'Reference',
                            value: reference,
                            valueColor: _blue2,
                          ),
                          // if (generatedAt.isNotEmpty) ...[
                          //   const _Divider(),
                          //   _InfoRow(
                          //     icon: Icons.access_time_rounded,
                          //     label: 'Generated',
                          //     value: generatedAt,
                          //   ),
                          // ],
                          const _Divider(),
                          _InfoRow(
                            icon: Icons.insert_drive_file_rounded,
                            label: 'File',
                            value: fileName,
                            valueColor: _textMuted,
                            smallValue: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Simple note ────────────────────────────────────────
                    const _NoteRow(
                      icon: Icons.open_in_new_rounded,
                      text: 'Open — View the saved receipt PDF...',
                    ),
                    const SizedBox(height: 4),
                    const _NoteRow(
                      icon: Icons.refresh_rounded,
                      text:
                          'Re-generate — Create a new PDF...',
                    ),

                    const SizedBox(height: 16),

                    // ── Buttons ────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context)
                                .pop(ReceiptExistsAction.regenerate),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Re-generate'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _blue1,
                              side: const BorderSide(
                                  color: Color(0xFFC4D4EE), width: 1.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_blue1, _blue2],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.of(context)
                                    .pop(ReceiptExistsAction.open),
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 16, color: Colors.white),
                                label: const Text(
                                  'Open',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GENERATE CONFIRM WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _GenerateConfirmDialog extends StatelessWidget {
  final String reference;
  const _GenerateConfirmDialog({required this.reference});

  @override
  Widget build(BuildContext context) {
    final dialogW =
        (MediaQuery.of(context).size.width * 0.90).clamp(300.0, 420.0);

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
            child: SizedBox(
              width: dialogW,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded,
                              color: _blue2, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Generate Receipt',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _textDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'No saved receipt found for this booking.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(false),
                          child: const Icon(Icons.close_rounded,
                              color: _textMuted, size: 20),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Info card ──────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: _InfoRow(
                        icon: Icons.confirmation_number_rounded,
                        label: 'Reference',
                        value: reference,
                        valueColor: _blue2,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const _NoteRow(
                      icon: Icons.info_outline_rounded,
                      text:
                          'A new PDF receipt will be created and saved to the server.',
                    ),

                    const SizedBox(height: 16),

                    // ── Buttons ────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textMuted,
                              side: const BorderSide(
                                  color: Color(0xFFCBD5E1), width: 1.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_blue1, _blue2],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                icon: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    size: 16,
                                    color: Colors.white),
                                label: const Text(
                                  'Generate',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
      );
}

class _NoteRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NoteRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: _textMuted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              color: _textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool smallValue;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: _textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: smallValue ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? _textDark,
            ),
          ),
        ),
      ],
    );
  }
}
