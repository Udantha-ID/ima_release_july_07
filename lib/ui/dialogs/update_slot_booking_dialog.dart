import 'dart:ui';
import 'package:flutter/material.dart';
import '../../Services/airport_parking_service.dart';

/// Shows the full "Update Booking End Date" form as an inline dialog.
/// The [reference] is pre-filled from the loaded invoice reference.
Future<void> showUpdateSlotBookingDialog({
  required BuildContext context,
  required String reference,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (ctx) => _UpdateSlotDialog(reference: reference),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stateful dialog widget
// ─────────────────────────────────────────────────────────────────────────────
class _UpdateSlotDialog extends StatefulWidget {
  final String reference;
  const _UpdateSlotDialog({required this.reference});

  @override
  State<_UpdateSlotDialog> createState() => _UpdateSlotDialogState();
}

class _UpdateSlotDialogState extends State<_UpdateSlotDialog> {
  static const _blue1 = Color(0xFF1565C0);
  static const _blue2 = Color(0xFF003580);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);
  static const _green = Color(0xFF16A34A);

  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isSuccess = false;
  String _resultMessage = '';

  // ── helpers ──────────────────────────────────────────────────────────────
  String _formatDisplay(DateTime d) {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  String _formatApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _blue2,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _isSuccess = false;
        _resultMessage = '';
      });
    }
  }

  // Shows an inline confirmation popup on top of this dialog.
  Future<bool> _confirmDialog() async {
    final theme = Theme.of(context);
    final w = MediaQuery.of(context).size.width;
    final dialogW = (w * 0.88).clamp(260.0, 400.0);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (ctx) => Center(
        child: Dialog(
          insetPadding: const EdgeInsets.all(20),
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
                  // header
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: _blue2),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Confirm Update",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: Icon(Icons.close, color: theme.iconTheme.color),
                      ),
                    ],
                  ),
                  Text(
                    "This action cannot be undone",
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // details box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8EDF5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(
                          icon: Icons.confirmation_number_rounded,
                          label: "Reference",
                          value: widget.reference,
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: "New End Date",
                          value: _formatDisplay(_selectedDate!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0060A6),
                            side: const BorderSide(
                                color: Color(0xFFC4C4C4), width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
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
                              gradient: const LinearGradient(
                                colors: [_blue1, _blue2],
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
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Confirm",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
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
    );
    return confirmed == true;
  }

  Future<void> _submit() async {
    if (_selectedDate == null) {
      setState(() {
        _resultMessage = 'Please select a new end date.';
        _isSuccess = false;
      });
      return;
    }

    // Show confirmation popup before proceeding
    final confirmed = await _confirmDialog();
    if (!mounted || !confirmed) return;

    setState(() {
      _isLoading = true;
      _resultMessage = '';
      _isSuccess = false;
    });

    final result = await AirportParkingService.updateReservedSlot(
      reference: widget.reference,
      endDate: _formatApi(_selectedDate!),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isSuccess = result.status;
      _resultMessage = result.message;
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final dialogW = (w * 0.92).clamp(280.0, 420.0);
    final theme = Theme.of(context);

    return Stack(
      children: [
        // blurred backdrop matching project dialogs
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(color: Colors.black.withOpacity(0.15)),
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
                    // ── header ─────────────────────────────────────────────
                    Row(
                      children: [
                        const Icon(
                          Icons.edit_calendar_rounded,
                          color: _blue2,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Update Booking End Date",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: theme.iconTheme.color,
                          ),
                        ),
                      ],
                    ),

                    Text(
                      "Change the end date for this booking.",
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── reference row (read-only) ──────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.confirmation_number_rounded,
                            color: _blue2,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Reference Number",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.reference,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: _textDark,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F4FD),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              "Read-only",
                              style: TextStyle(
                                color: _blue2,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── date picker row ────────────────────────────────────
                    const Text(
                      "New End Date",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _isLoading ? null : _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                color: _blue2, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedDate != null
                                    ? _formatDisplay(_selectedDate!)
                                    : 'Tap to select a date',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _selectedDate != null
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: _selectedDate != null
                                      ? _textDark
                                      : _textMuted,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              color: _textMuted.withOpacity(0.7),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── yellow notice ──────────────────────────────────────
                    // Container(
                    //   width: double.infinity,
                    //   padding: const EdgeInsets.symmetric(
                    //       horizontal: 10, vertical: 8),
                    //   decoration: BoxDecoration(
                    //     color: const Color(0xFFFFF7E6),
                    //     borderRadius: BorderRadius.circular(10),
                    //     border: Border.all(
                    //         color: const Color(0xFFFFC107).withOpacity(0.45)),
                    //   ),
                    //   child: const Row(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       Icon(Icons.info_outline_rounded,
                    //           color: Color(0xFF8A2C00), size: 17),
                    //       SizedBox(width: 7),
                    //       Expanded(
                    //         child: Text(
                    //           "Only the booking record will be updated. "
                    //           "Your existing PDF invoice will not change.",
                    //           style: TextStyle(
                    //             fontSize: 11.5,
                    //             height: 1.4,
                    //             color: Color(0xFF8A2C00),
                    //             fontWeight: FontWeight.w600,
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),

                    // ── result feedback (error or success) ─────────────────
                    if (_resultMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: _isSuccess
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isSuccess
                                ? _green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _isSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              color: _isSuccess ? _green : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _resultMessage,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _isSuccess ? _green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── buttons ────────────────────────────────────────────
                    if (_isSuccess)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _blue2,
                            side: const BorderSide(
                                color: Color(0xFFC4C4C4), width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Close",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _isLoading ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0060A6),
                                side: const BorderSide(
                                    color: Color(0xFFC4C4C4), width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
                                  gradient: LinearGradient(
                                    colors: _isLoading
                                        ? [
                                            _blue1.withOpacity(0.5),
                                            _blue2.withOpacity(0.5),
                                          ]
                                        : const [_blue1, _blue2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "Confirm Update",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared detail row used inside the confirmation popup
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF003580)),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
