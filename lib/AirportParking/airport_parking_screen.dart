import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:screen_protector/screen_protector.dart';
import '../Constants/app_colors.dart';
import '../Leaves/top_banner.dart';
import '../Services/airport_parking_service.dart';
import '../ui/dialogs/receipt_exists_dialog.dart';
import '../ui/dialogs/update_slot_booking_dialog.dart';
import 'airport_parking_receipt_builder.dart';
import 'invoice_pdf_viewer_screen.dart';

class AirportParkingScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AirportParkingScreen({super.key, required this.user});

  @override
  State<AirportParkingScreen> createState() => _AirportParkingScreenState();
}

class _AirportParkingScreenState extends State<AirportParkingScreen> {
  final TextEditingController gNumberController = TextEditingController();
  final TextEditingController apNumberController = TextEditingController();
  final TextEditingController datePartController = TextEditingController();

  bool isLoading = false;
  bool isUpdatingStatus = false;
  bool isGeneratingPdf = false;
  bool isCheckingIn = false;
  bool isCheckingOut = false;
  bool isCheckedIn = false;
  bool isCheckedOut = false;
  String? errorMessage;
  File? invoiceFile;
  String? loadedReference;
  Map<String, dynamic>? bookingData;

  bool isTodayLoading = false;
  List<TodayBooking> todayBookings = [];
  String? todayBookingsError;
  String _fromDate = '';
  String _toDate = '';

  static const _blue1 = Color(0xFF1565C0);
  static const _blue2 = Color(0xFF003580);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    ScreenProtector.protectDataLeakageOff();
    _fetchTodayBookings();
  }

  Future<void> _fetchTodayBookings() async {
    setState(() {
      isTodayLoading = true;
      todayBookingsError = null;
    });
    final result = await AirportParkingService.getTodayBookings();
    if (!mounted) return;
    setState(() {
      isTodayLoading = false;
      _fromDate = result.fromDate;
      _toDate = result.toDate;
      if (result.status) {
        todayBookings = result.bookings;
      } else {
        todayBookingsError = result.message;
        todayBookings = [];
      }
    });
  }

  void _autofillFromTodayBooking(TodayBooking booking) {
    final ref = booking.referenceNumber.toUpperCase().trim();
    // Parse e.g. "G5-AP-01-0626" or "G8-AP-17"
    final parts = ref.split('-AP-');
    if (parts.length == 2) {
      gNumberController.text = parts[0];
      final rest = parts[1].split('-');
      apNumberController.text = rest[0];
      datePartController.text = rest.length > 1 ? rest[1] : '';
    }
    _search();
  }

  @override
  void dispose() {
    ScreenProtector.protectDataLeakageOn();
    gNumberController.dispose();
    apNumberController.dispose();
    datePartController.dispose();
    super.dispose();
  }

  String get _composedReference {
    final firstPart = gNumberController.text.trim().toUpperCase();
    final lastPart = apNumberController.text.trim().toUpperCase();
    final datePart = datePartController.text.trim().toUpperCase();
    // Date code is optional — supports both old (G8-AP-17) and new (G5-AP-01-0626) formats
    if (datePart.isEmpty) return "$firstPart-AP-$lastPart";
    return "$firstPart-AP-$lastPart-$datePart";
  }

  Future<void> _search() async {
    final g = gNumberController.text.trim();
    final ap = apNumberController.text.trim();

    if (g.isEmpty || ap.isEmpty) {
      setState(() {
        errorMessage = "Please fill in Slot and Number.";
        invoiceFile = null;
        loadedReference = null;
        bookingData = null;
        isCheckedIn = false;
        isCheckedOut = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      invoiceFile = null;
      loadedReference = null;
      bookingData = null;
      isCheckedIn = false;
      isCheckedOut = false;
    });

    final reference = _composedReference;

    // Fire both requests in parallel
    final bookingFuture = AirportParkingService.fetchBooking(reference);
    final invoiceFuture = AirportParkingService.fetchInvoice(reference);

    final bookingResult = await bookingFuture;
    final invoiceResult = await invoiceFuture;

    CustomerStatusResult? customerStatus;
    if (bookingResult.status && bookingResult.data != null) {
      customerStatus =
          await AirportParkingService.getCustomerStatus(reference);
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;

      if (bookingResult.status && bookingResult.data != null) {
        bookingData = bookingResult.data;
        loadedReference = reference;
        errorMessage = null;
        if (customerStatus?.ok == true && customerStatus!.data != null) {
          _applyCustomerStatusFromMap(customerStatus.data!);
        }
      } else {
        errorMessage = bookingResult.message;
      }

      if (invoiceResult.status && invoiceResult.file != null) {
        invoiceFile = invoiceResult.file;
        loadedReference = reference;
      }
    });
  }

  Future<void> _confirmBooking() async {
    if (loadedReference == null) return;

    final ref =
        bookingData?['reference_number'] as String? ?? loadedReference ?? '—';
    final name = bookingData?['name'] as String? ?? '—';
    final whatsapp = bookingData?['whatsapp_number'] as String? ?? '';

    // ── Confirmation dialog ───────────────────────────────────────────────────
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (ctx) {
        final dialogW =
            (MediaQuery.of(ctx).size.width * 0.90).clamp(300.0, 420.0);
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
                    borderRadius: BorderRadius.circular(14)),
                child: SizedBox(
                  width: dialogW,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: _blue2),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "Confirm Booking",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              icon: const Icon(Icons.close),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const Text(
                          "Please verify the details before confirming.",
                          style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5),
                        ),
                        const SizedBox(height: 14),
                        // Details box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: const Color(0xFFE8EDF5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailRow(Icons.confirmation_number_rounded,
                                  "Reference", ref),
                              const SizedBox(height: 8),
                              _detailRow(Icons.person_rounded,
                                  "Customer", name),
                              const SizedBox(height: 8),
                              _detailRow(
                                  Icons.phone_rounded,
                                  "WhatsApp",
                                  whatsapp.isNotEmpty
                                      ? '+$whatsapp'
                                      : '—'),
                              const SizedBox(height: 8),
                              _detailRow(
                                Icons.sync_alt_rounded,
                                "Status",
                                "Pending  →  Confirmed",
                                valueColor: const Color(0xFF166534),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0060A6),
                                  side: const BorderSide(
                                      color: Color(0xFFC4C4C4),
                                      width: 1.2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
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
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: const Text(
                                      "Yes, Confirm",
                                      style: TextStyle(
                                          color: Colors.white,
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

    if (!mounted) return;

    // ── User cancelled ────────────────────────────────────────────────────────
    if (agreed != true) {
      TopBanner.show(
        context,
        title: 'Cancelled',
        message: 'Booking confirmation was cancelled. No changes were made.',
        icon: Icons.cancel_outlined,
        isError: true,
      );
      return;
    }

    // ── Call API ──────────────────────────────────────────────────────────────
    setState(() => isUpdatingStatus = true);

    final result = await AirportParkingService.updateBookingStatus(
      reference: loadedReference!,
      status: 'confirmed',
      confirmedBy: _loggedInUserName,
    );

    if (!mounted) return;

    setState(() {
      isUpdatingStatus = false;
      if (result.status && bookingData != null) {
        bookingData = Map<String, dynamic>.from(bookingData!)
          ..['booking_status'] = result.bookingStatus ?? 'confirmed';
      }
    });

    if (result.status) {
      await _refreshCustomerStatus();
    }

    // ── Result banner ─────────────────────────────────────────────────────────
    TopBanner.show(
      context,
      title: result.status ? 'Booking Confirmed' : 'Update Failed',
      message: result.message,
      icon: result.status
          ? Icons.check_circle_rounded
          : Icons.error_outline_rounded,
      isSuccess: result.status,
      isError: !result.status,
    );
  }

  // Helper for detail rows inside the confirmation dialog
  static Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    const muted = Color(0xFF64748B);
    const dark = Color(0xFF0F172A);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: muted),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: muted)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? dark)),
        ),
      ],
    );
  }

  Future<void> _generateAndOpenReceipt() async {
    if (bookingData == null || loadedReference == null) return;
    setState(() => isGeneratingPdf = true);

    try {
      // ── 1. Check if a receipt already exists on the server ──────────────────
      final check = await AirportParkingService.checkPaymentReceipt(
          loadedReference!);

      if (!mounted) return;

      if (check.exists && check.pdfUrl != null) {
        final action = await showReceiptExistsDialog(
          context: context,
          reference: loadedReference!,
          pdfUrl: check.pdfUrl!,
        );
        if (!mounted) return;

        if (action == ReceiptExistsAction.open) {
          final dl = await AirportParkingService.downloadReceiptPdf(
            pdfUrl: check.pdfUrl!,
            reference: loadedReference!,
          );
          if (!mounted) return;
          if (dl.status && dl.file != null) {
            await OpenFile.open(dl.file!.path);
          } else {
            TopBanner.show(
              context,
              title: 'Could Not Open Receipt',
              message: dl.message,
              icon: Icons.error_outline_rounded,
              isError: true,
            );
          }
          return;
        }

        // User dismissed or tapped Re-generate — only regenerate proceeds,
        // no extra confirm dialog shown
        if (action != ReceiptExistsAction.regenerate) return;
      } else {
        // ── No existing receipt — confirm before generating ─────────────────
        final confirmed = await showReceiptGenerateConfirmDialog(
          context: context,
          reference: loadedReference!,
        );
        if (!mounted || !confirmed) return;
      }

      final file = await AirportParkingReceiptBuilder.generate(
        bookingData!,
        user: widget.user,
      );

      if (!mounted) return;

      // ── 3. Upload the PDF to the server ────────────────────────────────────
      final pdfBytes = await file.readAsBytes();
      final saveResult = await AirportParkingService.savePaymentReceipt(
        reference: loadedReference!,
        generatedBy: _loggedInUserName,
        pdfBytes: pdfBytes,
      );

      if (!mounted) return;

      if (!saveResult.status) {
        TopBanner.show(
          context,
          title: 'Receipt Not Saved',
          message: saveResult.message.isNotEmpty
              ? saveResult.message
              : 'PDF generated locally but could not be saved to the server.',
          icon: Icons.cloud_off_rounded,
          isError: true,
        );
      }

      // ── 4. Open the locally generated file ─────────────────────────────────
      await OpenFile.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not generate receipt: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => isGeneratingPdf = false);
    }
  }

  void _openFullScreen() {
    if (invoiceFile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePdfViewerScreen(
          file: invoiceFile!,
          reference: loadedReference ?? "",
        ),
      ),
    );
  }

  void _openUpdateScreen() {
    showUpdateSlotBookingDialog(
      context: context,
      reference: loadedReference ?? '',
    );
  }

  String get _loggedInUserName {
    final u = widget.user;
    final name = (u['preferred_name'] ??
            u['name'] ??
            u['full_name'] ??
            u['username'] ??
            '')
        .toString()
        .trim();
    return name.isEmpty ? 'Staff' : name;
  }

  void _applyCustomerStatusFromMap(Map<String, dynamic> data) {
    final outStr = (data['check_out_datetime']?.toString() ?? '').trim();
    final hasCheckout =
        outStr.isNotEmpty && outStr.toLowerCase() != 'null';

    final raw = (data['customer_status'] ?? data['status'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final isIn =
        raw == 'check_in' || raw == 'checked_in' || raw == 'checked in';

    isCheckedOut = hasCheckout;
    isCheckedIn = hasCheckout || isIn;
  }

  Future<void> _refreshCustomerStatus() async {
    final ref =
        (loadedReference ?? bookingData?['reference_number'] as String?)
            ?.trim();
    if (ref == null || ref.isEmpty) return;

    final res = await AirportParkingService.getCustomerStatus(ref);
    if (!mounted) return;
    if (res.ok && res.data != null) {
      setState(() => _applyCustomerStatusFromMap(res.data!));
    }
  }

  Future<bool> _showActionConfirm({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> details,
    required String confirmLabel,
    required List<Color> gradientColors,
  }) async {
    final theme = Theme.of(context);
    final dialogW =
        (MediaQuery.of(context).size.width * 0.90).clamp(300.0, 420.0);

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (ctx) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.transparent),
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
                      Row(
                        children: [
                          Icon(icon, color: iconColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: theme.textTheme.titleLarge?.color,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            icon: Icon(Icons.close,
                                color: theme.iconTheme.color),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFE8EDF5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: details,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                                    borderRadius: BorderRadius.circular(12)),
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
                                    colors: gradientColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    confirmLabel,
                                    style: const TextStyle(
                                        color: Colors.white,
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
      ),
    );
    return agreed == true;
  }

  Future<void> _checkIn() async {
    if (loadedReference == null || isCheckedOut) return;

    final ref = loadedReference!;
    final name = _loggedInUserName;

    final confirmed = await _showActionConfirm(
      icon: Icons.how_to_reg_rounded,
      iconColor: const Color(0xFF0891B2),
      title: 'Confirm Check-In',
      subtitle: 'Please verify before checking in.',
      details: [
        _detailRow(Icons.confirmation_number_rounded, 'Reference', ref),
        const SizedBox(height: 8),
        _detailRow(Icons.person_rounded, 'Check-in by', name),
      ],
      confirmLabel: 'Check In',
      gradientColors: const [Color(0xFF0891B2), Color(0xFF0E7490)],
    );

    if (!mounted || !confirmed) return;

    setState(() => isCheckingIn = true);

    final result = await AirportParkingService.checkIn(
      reference: ref,
      checkInByName: name,
    );

    if (!mounted) return;
    setState(() => isCheckingIn = false);

    if (result.status) {
      await _refreshCustomerStatus();
    }

    if (!mounted) return;
    TopBanner.show(
      context,
      title: result.status ? 'Check-In Successful' : 'Check-In Failed',
      message: result.message,
      icon: result.status
          ? Icons.how_to_reg_rounded
          : Icons.error_outline_rounded,
      isSuccess: result.status,
      isError: !result.status,
    );
  }

  Future<void> _checkOut() async {
    if (loadedReference == null || !isCheckedIn || isCheckedOut) return;

    debugPrint('Initiating check-out for reference: $loadedReference');

    final ref = loadedReference!;
    final now = DateTime.now();

    // If the booking already has a recorded checkout time (end_date_edited),
    // use that for late-fee calculation instead of the current device time.
    final existingCheckOutRaw =
        (bookingData?['end_date_edited']?.toString() ?? '').trim();
    DateTime effectiveNow = now;
    try {
      if (existingCheckOutRaw.isNotEmpty &&
          existingCheckOutRaw.toLowerCase() != 'null') {
        effectiveNow = DateTime.parse(
            existingCheckOutRaw.replaceFirst(' ', 'T'));
      }
    } catch (_) {}

    // System time string sent to the API (always current device time)
    final checkOutTime =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    // ── Parse booking start & end dates ──────────────────────────────────────
    final startDateRaw = (bookingData?['start_date'] as String? ?? '').trim();
    final endDateRaw = (bookingData?['end_date'] as String? ?? '').trim();
    DateTime? originalStartDate;
    DateTime? originalEndDate;
    try {
      if (startDateRaw.isNotEmpty) {
        originalStartDate = DateTime.parse(startDateRaw.replaceFirst(' ', 'T'));
      }
      if (endDateRaw.isNotEmpty) {
        originalEndDate = DateTime.parse(endDateRaw.replaceFirst(' ', 'T'));
      }
    } catch (_) {}

    // ── Parse original price ──────────────────────────────────────────────────
    final originalPrice =
        double.tryParse((bookingData?['total_price'] as String? ?? '0').trim()) ??
            0.0;

    // ── Fetch per-day rate from API; fall back to total_price ÷ days ─────────
    double perDayCharge = originalPrice;
    final rateResult = await AirportParkingService.getPerDayRate();
    if (rateResult.status && rateResult.rate != null) {
      perDayCharge = rateResult.rate!;
    } else if (originalStartDate != null && originalEndDate != null) {
      final bookedDays = originalEndDate.difference(originalStartDate).inDays;
      if (bookedDays > 0) perDayCharge = originalPrice / bookedDays;
    }

    // ── Late-fee calculation (% of per-day charge, not total price) ───────────
    double lateHours = 0;
    double lateFeeAmount = 0;
    double totalPriceFinal = originalPrice;
    String lateLabel = 'Waived Off';
    bool isLate = false;

    if (originalEndDate != null) {
      final diff = effectiveNow.difference(originalEndDate);
      if (diff.inMinutes > 0) {
        isLate = true;
        lateHours = diff.inMinutes / 60.0;
        if (lateHours <= 2) {
          lateLabel = 'Waived Off  (≤ 2 hrs)';
          lateFeeAmount = 0;
        } else if (lateHours <= 8) {
          lateLabel = '50% Surcharge  (2 – 8 hrs)';
          lateFeeAmount = perDayCharge * 0.5;
        } else {
          lateLabel = '100% Full Day Charge  (> 8 hrs)';
          lateFeeAmount = perDayCharge;
        }
        totalPriceFinal = originalPrice + lateFeeAmount;
      }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    String fmtLKR(double v) {
      final parts = v.toStringAsFixed(2).split('.');
      final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
      return 'LKR $intPart.${parts[1]}';
    }

    String fmtHours(double h) {
      final hh = h.floor();
      final mm = ((h - hh) * 60).round();
      if (hh == 0) return '$mm min';
      if (mm == 0) return '${hh}h';
      return '${hh}h ${mm}m';
    }

    // ── Display time (use recorded checkout time if available) ───────────────
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final displayDt = effectiveNow;
    final hour = displayDt.hour % 12 == 0 ? 12 : displayDt.hour % 12;
    final minute = displayDt.minute.toString().padLeft(2, '0');
    final ampm = displayDt.hour >= 12 ? 'PM' : 'AM';
    final displayTime =
        '${months[displayDt.month - 1]} ${displayDt.day}, ${displayDt.year}  $hour:$minute $ampm';

    // ── Confirmation dialog ───────────────────────────────────────────────────
    final confirmed = await _showActionConfirm(
      icon: Icons.logout_rounded,
      iconColor: AppColors.cancelButtonStart,
      title: 'Confirm Check-Out',
      subtitle: isLate
          ? 'Late check-out detected — surcharge applies.'
          : 'System time will be recorded as check-out time.',
      details: [
        _detailRow(Icons.confirmation_number_rounded, 'Reference', ref),
        const SizedBox(height: 8),
        _detailRow(Icons.access_time_rounded, 'Check-out', displayTime),
        if (originalEndDate != null) ...[
          const SizedBox(height: 8),
          _detailRow(
              Icons.event_rounded, 'Original End', _formatDateTime(endDateRaw)),
        ],
        if (isLate) ...[
          const SizedBox(height: 8),
          _detailRow(Icons.timer_outlined, 'Late By', fmtHours(lateHours)),
          const SizedBox(height: 8),
          _detailRow(Icons.percent_rounded, 'Surcharge', lateLabel),
          const SizedBox(height: 8),
          _detailRow(Icons.today_rounded, 'Per Day Rate', fmtLKR(perDayCharge)),
          const SizedBox(height: 8),
          _detailRow(
            Icons.add_circle_outline_rounded,
            'Late Fee',
            fmtLKR(lateFeeAmount),
            valueColor: const Color(0xFF991B1B),
          ),
        ],
        const SizedBox(height: 8),
        _detailRow(
          Icons.payments_rounded,
          'Total Price',
          fmtLKR(totalPriceFinal),
          valueColor: isLate ? const Color(0xFF991B1B) : null,
        ),
      ],
      confirmLabel: 'Check Out',
      gradientColors: const [
        AppColors.cancelButtonStart,
        AppColors.cancelButtonEnd,
      ],
    );

    if (!mounted || !confirmed) return;

    setState(() => isCheckingOut = true);

    final result = await AirportParkingService.lateCheckoutUpdate(
      reference: ref,
      checkOutByName: _loggedInUserName,
      totalPriceFinal: totalPriceFinal,
      endDateEdited: checkOutTime,
      lateFeeAmount: lateFeeAmount,
    );

    if (!mounted) return;
    setState(() => isCheckingOut = false);

    if (result.status) {
      if (bookingData != null) {
        setState(() {
          bookingData = Map<String, dynamic>.from(bookingData!)
            ..['total_price_final'] = totalPriceFinal.toStringAsFixed(2)
            ..['late_fee_amount'] = lateFeeAmount.toStringAsFixed(2);
        });
      }
      await _refreshCustomerStatus();
    }

    if (!mounted) return;
    TopBanner.show(
      context,
      title: result.status ? 'Check-Out Successful' : 'Check-Out Failed',
      message: result.message,
      icon: result.status
          ? Icons.check_circle_rounded
          : Icons.error_outline_rounded,
      isSuccess: result.status,
      isError: !result.status,
    );
  }

  // ──────────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────────

  String _formatDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw.trim().replaceFirst(' ', 'T'));
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[dt.month - 1];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$month ${dt.day}, ${dt.year}  $hour:$minute $ampm';
    } catch (_) {
      return raw;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'confirmed':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        icon = Icons.check_circle_rounded;
        label = 'Confirmed';
        break;
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        icon = Icons.hourglass_empty_rounded;
        label = 'Pending';
        break;
      case 'cancelled':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        icon = Icons.cancel_rounded;
        label = 'Cancelled';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = _textMuted;
        icon = Icons.info_outline_rounded;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _textMuted),
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: _textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: _textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  TODAY'S BOOKINGS CARD
  // ──────────────────────────────────────────────
  String _fmtShortDate(String ymd) {
    try {
      final dt = DateTime.parse(ymd);
      return '${_monthNames[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return ymd;
    }
  }

  Widget _buildTodayBookingsCard() {
    final now = DateTime.now();
    final todayLabel = (_fromDate.isNotEmpty && _toDate.isNotEmpty)
        ? '${_fmtShortDate(_fromDate)} – ${_fmtShortDate(_toDate)}, ${now.year}'
        : '${_monthNames[now.month - 1]} ${now.day}, ${now.year}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF003580)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.today_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Upcoming Bookings",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        todayLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isTodayLoading)
                  GestureDetector(
                    onTap: _fetchTodayBookings,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          size: 16, color: _textMuted),
                    ),
                  ),
                if (!isTodayLoading && todayBookings.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${todayBookings.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── Content ──
          if (isTodayLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _blue2,
                  ),
                ),
              ),
            )
          else if (todayBookingsError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: _textMuted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      todayBookingsError!,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: _textMuted,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else if (todayBookings.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.event_busy_rounded,
                          size: 26, color: _textMuted),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "No bookings today",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "There are no arrivals scheduled for today.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              itemCount: todayBookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final b = todayBookings[index];
                return _buildTodayBookingTile(b);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTodayBookingTile(TodayBooking booking) {
    final initials = booking.name.trim().isNotEmpty
        ? booking.name.trim().split(' ').take(2).map((w) => w[0]).join()
        : '?';

    return InkWell(
      onTap: () => _autofillFromTodayBooking(booking),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF003580)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name + reference
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.confirmation_number_rounded,
                          size: 11, color: _textMuted),
                      const SizedBox(width: 3),
                      Text(
                        booking.referenceNumber,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Price + tap hint
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'LKR ${booking.totalPrice}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _blue2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // ──────────────────────────────────────────────
  //  SEARCH INPUT CARD
  // ──────────────────────────────────────────────
  Widget _buildInputCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/airportparking.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Airport Parking",
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Enter a reference number to view booking & invoice",
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 8),

          const Text(
            "Enter Reference Number",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Slot (e.g. G5) ──
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: gNumberController,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(8),
                    _UpperCaseTextFormatter(),
                  ],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    labelText: "Slot",
                    hintText: "G5",
                    labelStyle:
                        const TextStyle(color: _textMuted, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _blue1, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 14),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Text("–AP–",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _textDark)),
              ),
              // ── Number (e.g. 01) ──
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: apNumberController,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(4),
                    _UpperCaseTextFormatter(),
                  ],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    labelText: "No.",
                    hintText: "01",
                    labelStyle:
                        const TextStyle(color: _textMuted, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _blue1, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 14),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Text("–",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _textDark)),
              ),
              // ── Date code (e.g. 0626) ──
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: datePartController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    labelText: "Date Code",
                    hintText: "0626",
                    labelStyle:
                        const TextStyle(color: _textMuted, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _blue2, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 14),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              "Example: G5-AP-01-0626  or  G8-AP-17",
              style: TextStyle(
                fontSize: 11.5,
                color: _textMuted.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLoading
                    ? [
                        const Color(0xFF1565C0).withOpacity(0.5),
                        const Color(0xFF003580).withOpacity(0.5),
                      ]
                    : const [Color(0xFF1565C0), Color(0xFF003580)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : _search,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Search Booking",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  ERROR CARD
  // ──────────────────────────────────────────────
  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  EMPTY STATE CARD
  // ──────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/airportparking.png',
              height: 64,
              width: 64,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "No Booking Yet",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Enter a reference number above and\ntap Search Booking to view details.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFFFC107).withOpacity(0.45)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF8A2C00),
                  size: 22,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "New format: G5-AP-01-0626  |  Existing format: G8-AP-17",
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFF8A2C00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Green "Create PDF" on the confirmed booking card (height 48; width from parent).
  Widget _buildConfirmedCreatePdfButton() {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF16A34A), Color(0xFF166534)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF166534).withOpacity(0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: isGeneratingPdf ? null : _generateAndOpenReceipt,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: isGeneratingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 17,
                ),
          label: Text(
            isGeneratingPdf ? "Generating..." : "Create PDF",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  BOOKING DETAILS CARD
  // ──────────────────────────────────────────────
  Widget _buildBookingCard() {
    final d = bookingData!;
    final status = (d['booking_status'] as String? ?? '').toLowerCase();
    final name = d['name'] as String? ?? '—';
    final email = d['email'] as String? ?? '—';
    final whatsapp = d['whatsapp_number'] as String? ?? '—';
    final vehicle = d['vehicle_number'] as String? ?? '';
    final startDate = _formatDateTime(d['start_date'] as String?);
    final endDate = _formatDateTime(d['end_date'] as String?);
    final price = d['total_price'] as String? ?? '—';
    final reference = d['reference_number'] as String? ?? loadedReference ?? '—';
    final isPending = status == 'pending';
    final isConfirmed = status == 'confirmed';

    // Late-fee breakdown — works for both API-loaded data and post-checkout state
    final origPrice =
        double.tryParse((d['total_price'] as String? ?? '0').trim()) ?? 0.0;
    final finalPriceRaw = (d['total_price_final'] as String?)?.trim();
    final finalPrice = finalPriceRaw != null
        ? (double.tryParse(finalPriceRaw) ?? origPrice)
        : origPrice;
    final cardLateFee = (finalPrice - origPrice).clamp(0.0, double.infinity);
    final hasFee = cardLateFee > 0.01;
    String fmtCardLKR(double v) {
      final parts = v.toStringAsFixed(2).split('.');
      final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
      return 'LKR $intPart.${parts[1]}';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Booking Details",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reference,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(d['booking_status'] as String? ?? status),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── Customer Info ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Customer",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.person_rounded, "Name", name),
                if (vehicle.isNotEmpty)
                  _buildInfoRow(
                      Icons.directions_car_rounded, "Vehicle", vehicle),
                _buildInfoRow(Icons.email_rounded, "Email", email),
                _buildInfoRow(Icons.phone_rounded, "WhatsApp", whatsapp),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0),
              indent: 16, endIndent: 16),

          // ── Dates ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Duration",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Check-in",
                              style: TextStyle(
                                fontSize: 11,
                                color: _textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              startDate,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: _textDark,
                                fontWeight: FontWeight.w800,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: _blue2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Check-out",
                              style: TextStyle(
                                fontSize: 11,
                                color: _textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              endDate,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: _textDark,
                                fontWeight: FontWeight.w800,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0),
              indent: 16, endIndent: 16),

          // ── Price ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: hasFee
                // ── Late-fee breakdown ─────────────────────────────────────
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.receipt_long_rounded,
                                  size: 18, color: Color(0xFFC62828)),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Price Breakdown",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _textDark),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFCDD2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                "Late Fee",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFC62828)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFFFFCDD2), height: 1),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text("Original Price",
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: _textMuted,
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Text(fmtCardLKR(origPrice),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: _textDark,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Text("Late Fee Added",
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFFC62828),
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text("+ ${fmtCardLKR(cardLateFee)}",
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFFC62828),
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: Color(0xFFFFCDD2), height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text("Total Price",
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: _textDark,
                                    fontWeight: FontWeight.w800)),
                            const Spacer(),
                            Text(fmtCardLKR(finalPrice),
                                style: const TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFFC62828),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3)),
                          ],
                        ),
                      ],
                    ),
                  )
                // ── Simple price row ───────────────────────────────────────
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          size: 20,
                          color: Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Total Price",
                        style: TextStyle(
                          fontSize: 13.5,
                          color: _textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "LKR $price",
                        style: const TextStyle(
                          fontSize: 17,
                          color: _textDark,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),

          // ── Action Buttons ──
          const Divider(height: 1, color: Color(0xFFE2E8F0),
              indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: isPending
                // ── Pending: Confirm button only (full width) ──────────────
                ? SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_blue1, _blue2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _blue2.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed:
                            isUpdatingStatus ? null : _confirmBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: isUpdatingStatus
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                        label: Text(
                          isUpdatingStatus ? "Confirming..." : "Confirm Booking",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  )
                // ── Confirmed: status → Check In *or* Check Out (one) | Create PDF
                : isConfirmed
                    ? Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: !isCheckedIn
                                  ? DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: (isCheckingIn ||
                                                  isCheckedOut)
                                              ? [
                                                  const Color(0xFF0891B2)
                                                      .withOpacity(0.45),
                                                  const Color(0xFF0E7490)
                                                      .withOpacity(0.45),
                                                ]
                                              : const [
                                                  Color(0xFF0891B2),
                                                  Color(0xFF0E7490),
                                                ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0E7490)
                                                .withOpacity(0.28),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: (isCheckingIn ||
                                                isCheckedOut)
                                            ? null
                                            : _checkIn,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          elevation: 0,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        icon: isCheckingIn
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.how_to_reg_rounded,
                                                color: Colors.white,
                                                size: 17,
                                              ),
                                        label: Text(
                                          isCheckingIn
                                              ? "Checking In..."
                                              : "Check In",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    )
                                  : DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: (isCheckedOut ||
                                                  isCheckingOut)
                                              ? [
                                                  AppColors.cancelButtonStart
                                                      .withValues(alpha: 0.45),
                                                  AppColors.cancelButtonEnd
                                                      .withValues(alpha: 0.45),
                                                ]
                                              : const [
                                                  AppColors.cancelButtonStart,
                                                  AppColors.cancelButtonEnd,
                                                ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.cancelButtonEnd
                                                .withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: (isCheckedOut ||
                                                isCheckingOut)
                                            ? null
                                            : _checkOut,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          disabledForegroundColor: Colors.white
                                              .withValues(alpha: 0.92),
                                          elevation: 0,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        icon: isCheckingOut
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Icon(
                                                isCheckedOut
                                                    ? Icons.check_rounded
                                                    : Icons.logout_rounded,
                                                color: Colors.white,
                                                size: 17,
                                              ),
                                        label: Text(
                                          isCheckingOut
                                              ? "Checking Out..."
                                              : isCheckedOut
                                                  ? "Checked Out"
                                                  : "Check Out",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _buildConfirmedCreatePdfButton()),
                        ],
                      )
                    // ── Cancelled / other: Update End Date only ────────────
                    : SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _openUpdateScreen,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _blue2,
                            side: const BorderSide(
                                color: Color(0xFFBFD7F5), width: 1.4),
                            backgroundColor: const Color(0xFFF0F6FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.edit_calendar_rounded,
                              size: 19, color: _blue2),
                          label: const Text(
                            "Update Booking End Date",
                            style: TextStyle(
                              color: _blue2,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  INVOICE PDF CARD
  // ──────────────────────────────────────────────
  Widget _buildInvoiceCard() {
    final fileSize = _formatFileSize(_safeFileSize(invoiceFile));
    final reference = loadedReference ?? "Invoice";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_blue1, _blue2]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _blue2.withOpacity(0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Invoice Ready",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Tap below to open, share or download.",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FD),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  "PDF",
                  style: TextStyle(
                    color: _blue2,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _openFullScreen,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: _blue2,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reference,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "PDF Document · $fileSize",
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _blue2,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_blue1, _blue2]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _blue2.withOpacity(0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _openFullScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(
                  Icons.visibility_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  "Open Invoice",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _safeFileSize(File? file) {
    try {
      return file?.lengthSync() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "—";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  // ──────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showEmpty =
        !isLoading && errorMessage == null && bookingData == null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Airport Parking",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: RefreshIndicator(
        color: Colors.blue,
        backgroundColor: Colors.white,
        onRefresh: () async {
          await _fetchTodayBookings();
          if (loadedReference != null) await _search();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputCard(),
            const SizedBox(height: 16),

            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(
                    color: _blue2,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else ...[
              if (errorMessage != null) _buildErrorCard(),
              if (showEmpty) _buildEmptyState(),
              if (bookingData != null) _buildBookingCard(),
              if (invoiceFile != null) ...[
                const SizedBox(height: 14),
                _buildInvoiceCard(),
              ],
            ],
            const SizedBox(height: 16),
            _buildTodayBookingsCard(),
          ],
        ),
      ),
    ),
    );
  }
}


class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
