import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AirportInvoiceResult {
  final bool status;
  final String message;
  final File? file;

  AirportInvoiceResult({
    required this.status,
    required this.message,
    this.file,
  });
}

class BookingResult {
  final bool status;
  final String message;
  final Map<String, dynamic>? data;

  BookingResult({required this.status, required this.message, this.data});
}

class UpdateSlotResult {
  final bool status;
  final String message;

  const UpdateSlotResult({required this.status, required this.message});
}

class CheckInResult {
  final bool status;
  final String message;

  const CheckInResult({required this.status, required this.message});
}

class CheckOutResult {
  final bool status;
  final String message;

  const CheckOutResult({required this.status, required this.message});
}

class CustomerStatusResult {
  final bool ok;
  final String message;
  final Map<String, dynamic>? data;

  const CustomerStatusResult({
    required this.ok,
    required this.message,
    this.data,
  });
}

class UpdateStatusResult {
  final bool status;
  final String message;
  final String? bookingStatus;

  const UpdateStatusResult({
    required this.status,
    required this.message,
    this.bookingStatus,
  });
}

class ReceiptCheckResult {
  final bool exists;
  final String? pdfUrl;
  final String message;

  const ReceiptCheckResult({
    required this.exists,
    required this.message,
    this.pdfUrl,
  });
}

class ReceiptSaveResult {
  final bool status;
  final String message;
  final String? receiptNo;
  final String? receiptPath;

  const ReceiptSaveResult({
    required this.status,
    required this.message,
    this.receiptNo,
    this.receiptPath,
  });
}

class PerDayRateResult {
  final bool status;
  final double? rate;
  final String message;

  const PerDayRateResult({
    required this.status,
    required this.message,
    this.rate,
  });
}

class TodayBooking {
  final String referenceNumber;
  final String name;
  final String startDate;
  final String endDate;
  final String totalPrice;

  const TodayBooking({
    required this.referenceNumber,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
  });

  factory TodayBooking.fromJson(Map<String, dynamic> json) => TodayBooking(
        referenceNumber: json['reference_number']?.toString() ?? '',
        name: json['name']?.toString() ?? '—',
        startDate: json['start_date']?.toString() ?? '',
        endDate: json['end_date']?.toString() ?? '',
        totalPrice: json['total_price']?.toString() ?? '0.00',
      );
}

class TodayBookingsResult {
  final bool status;
  final String message;
  final String fromDate;
  final String toDate;
  final int count;
  final List<TodayBooking> bookings;

  const TodayBookingsResult({
    required this.status,
    required this.message,
    required this.fromDate,
    required this.toDate,
    required this.count,
    required this.bookings,
  });
}

class AirportParkingService {
  // ── Switch here to toggle local ↔ production ──────────────────────────────
  //static const String _apiBase = "http://192.168.1.42/airport/api";
   static const String _apiBase = "https://airportparking.lk/api";
  // ─────────────────────────────────────────────────────────────────────────

  static const String _baseUrl =
      "https://exploresuite.lk/mobile-api/airport-parking/get-invoice.php";

  static const String _updateSlotUrl    = "$_apiBase/update_reserved_slot.php";
  static const String _getBookingUrl    = "$_apiBase/get-booking.php";
  static const String _updateStatusUrl  = "$_apiBase/update-booking-status.php";
  static const String _customerStatusUrl = "$_apiBase/get_customer_status.php";
  static const String _perDayRateUrl    = "$_apiBase/get-per-day-rate.php";
  static const String _todayBookingsUrl = "$_apiBase/get_today_bookings.php";
  static const String _checkReceiptUrl  = "$_apiBase/check_payment_receipt.php";
  static const String _saveReceiptUrl   = "$_apiBase/save_payment_receipt.php";

  /// Same URL [fetchInvoice] uses — safe to load in a [WebView] (no native PDF plugin).
  static Uri invoiceRequestUri(String reference) {
    final ref = reference.trim().toUpperCase();
    return Uri.parse(_baseUrl).replace(queryParameters: {'reference': ref});
  }

  /// Validate the reference format: [letters/numbers]-AP-[letters/numbers].
  static bool isValidReference(String reference) {
    // Accepts both old format (G8-AP-17) and new format (G5-AP-01-0626)
    final regex = RegExp(r'^[A-Z0-9]+-AP-[A-Z0-9]+(-[0-9]{4})?$');
    return regex.hasMatch(reference.trim().toUpperCase());
  }

  /// Download the invoice PDF for a given reference.
  /// Returns an [AirportInvoiceResult] indicating success/failure with a
  /// readable message and the downloaded [File] when available.
  static Future<AirportInvoiceResult> fetchInvoice(String reference) async {
    final ref = reference.trim().toUpperCase();

    if (ref.isEmpty) {
      return AirportInvoiceResult(
        status: false,
        message: "Please enter a reference number.",
      );
    }

    if (!isValidReference(ref)) {
      return AirportInvoiceResult(
        status: false,
        message: "Invalid reference format. Expected format: G7-AP-05 or ABC1-AP-05",
      );
    }

    try {
      final uri = invoiceRequestUri(ref);
      final response = await http.get(uri).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        return AirportInvoiceResult(
          status: false,
          message: "Server returned ${response.statusCode}. Please try again.",
        );
      }

      final contentType =
          (response.headers['content-type'] ?? '').toLowerCase();

      // The PHP endpoint returns plain-text errors with 200 status code
      // (e.g. "Folder not found", "No invoices found"). Detect them via
      // content-type or by inspecting the body bytes for the PDF magic.
      final isPdf = contentType.contains('application/pdf') ||
          _hasPdfMagic(response.bodyBytes);

      if (!isPdf) {
        final body = response.body.trim();
        return AirportInvoiceResult(
          status: false,
          message: body.isEmpty
              ? "Invoice not found for this reference."
              : body,
        );
      }

      // App support dir is more reliable for native PDF engines than cache/temp
      // (read permissions + stable path on Android).
      final dir = await getApplicationSupportDirectory();
      final safeName = ref.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final file = File('${dir.path}/airport_invoice_$safeName.pdf');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      return AirportInvoiceResult(
        status: true,
        message: "Invoice loaded successfully.",
        file: file,
      );
    } on SocketException {
      return AirportInvoiceResult(
        status: false,
        message: "No internet connection. Please check your network.",
      );
    } on HttpException {
      return AirportInvoiceResult(
        status: false,
        message: "Could not reach the invoice server.",
      );
    } catch (e) {
      return AirportInvoiceResult(
        status: false,
        message: "Something went wrong: $e",
      );
    }
  }

  /// Fetch booking details for a given [reference] from the airportparking.lk API.
  static Future<BookingResult> fetchBooking(String reference) async {
    final ref = reference.trim().toUpperCase();

    if (ref.isEmpty) {
      return BookingResult(
        status: false,
        message: "Please enter a reference number.",
      );
    }

    try {
      final uri = Uri.parse(_getBookingUrl)
          .replace(queryParameters: {'reference': ref});
      final response =
          await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return BookingResult(
          status: false,
          message:
              "Server returned ${response.statusCode}. Please try again.",
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (!json.containsKey('reference_number')) {
        final msg = (json['message'] as String?) ??
            (json['error'] as String?) ??
            'Booking not found for this reference.';
        return BookingResult(status: false, message: msg);
      }

      return BookingResult(
        status: true,
        message: 'Booking loaded.',
        data: json,
      );
    } on SocketException {
      return BookingResult(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return BookingResult(
        status: false,
        message: 'Could not reach the server.',
      );
    } catch (e) {
      return BookingResult(
        status: false,
        message: 'Something went wrong: $e',
      );
    }
  }

  /// Update the booking status (e.g. "confirmed") for [reference].
  /// [confirmedBy] is the name of the employee confirming the booking.
  static Future<UpdateStatusResult> updateBookingStatus({
    required String reference,
    required String status,
    required String confirmedBy,
  }) async {
    final ref = reference.trim().toUpperCase();

    try {
      final uri = Uri.parse(_updateStatusUrl).replace(queryParameters: {
        'reference': ref,
        'status': status,
        'confirmed_by': confirmedBy.trim(),
      });
      debugPrint('[updateBookingStatus] confirmed_by="${confirmedBy.trim()}" reference=$ref url=$uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return UpdateStatusResult(
          status: false,
          message:
              "Server error (${response.statusCode}). Please try again.",
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = json['status'] == 'success';
      final msg = (json['message'] as String?) ??
          (ok ? 'Status updated successfully.' : 'Update failed.');
      final newStatus = json['booking_status'] as String?;

      return UpdateStatusResult(
          status: ok, message: msg, bookingStatus: newStatus);
    } on SocketException {
      return const UpdateStatusResult(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return const UpdateStatusResult(
        status: false,
        message: 'Could not reach the server.',
      );
    } catch (e) {
      return UpdateStatusResult(
        status: false,
        message: 'Something went wrong: $e',
      );
    }
  }

  /// Fetch the company's current per-day parking rate from the database.
  static Future<PerDayRateResult> getPerDayRate() async {
    try {
      final response = await http
          .get(Uri.parse(_perDayRateUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return PerDayRateResult(
          status: false,
          message: 'Server error (${response.statusCode}).',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 'success') {
        return PerDayRateResult(
          status: false,
          message: (json['message'] as String?) ?? 'Failed to fetch rate.',
        );
      }

      final data = json['data'] as List?;
      if (data == null || data.isEmpty) {
        return const PerDayRateResult(
          status: false,
          message: 'No rate data found.',
        );
      }

      final rate = double.tryParse(data[0]['price']?.toString() ?? '');
      if (rate == null || rate <= 0) {
        return const PerDayRateResult(
          status: false,
          message: 'Invalid rate value in response.',
        );
      }

      return PerDayRateResult(status: true, rate: rate, message: 'OK');
    } on SocketException {
      return const PerDayRateResult(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return PerDayRateResult(
        status: false,
        message: 'Something went wrong: $e',
      );
    }
  }

  /// PDF files start with the bytes "%PDF" (0x25 0x50 0x44 0x46).
  static bool _hasPdfMagic(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  /// Check-in a customer by reference number and the staff member's name.
  static Future<CheckInResult> checkIn({
    required String reference,
    required String checkInByName,
  }) async {
    final ref = reference.trim().toUpperCase();

    if (ref.isEmpty) {
      return const CheckInResult(
        status: false,
        message: 'Reference number is required.',
      );
    }

    if (checkInByName.trim().isEmpty) {
      return const CheckInResult(
        status: false,
        message: 'Check-in staff name is required.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/customer_checkin.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'reference_number': ref,
              'check_in_by_name': checkInByName.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return CheckInResult(
          status: false,
          message: 'Server error (${response.statusCode}). Please try again.',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = json['status'] == true || json['success'] == true;
      final msg = (json['message'] as String?) ??
          (ok ? 'Check-in successful.' : 'Check-in failed.');

      return CheckInResult(status: ok, message: msg);
    } on SocketException {
      return const CheckInResult(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return const CheckInResult(
        status: false,
        message: 'Could not reach the server.',
      );
    } catch (e) {
      return CheckInResult(status: false, message: 'Something went wrong: $e');
    }
  }

  /// GET [reference] on-site check-in / check-out state from airportparking.lk.
  /// Response shape: `{ "status": true, "data": { "status": "check_in", ... } }`.
  static Future<CustomerStatusResult> getCustomerStatus(
      String reference) async {
    final ref = reference.trim().toUpperCase();

    if (ref.isEmpty) {
      return const CustomerStatusResult(
        ok: false,
        message: 'Reference number is required.',
      );
    }

    try {
      final uri = Uri.parse(_customerStatusUrl)
          .replace(queryParameters: {'reference_number': ref});
      final response =
          await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return CustomerStatusResult(
          ok: false,
          message: 'Server error (${response.statusCode}). Please try again.',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final topOk = json['status'] == true || json['success'] == true;
      if (!topOk) {
        final msg = (json['message'] as String?) ??
            (json['error'] as String?) ??
            'Could not load customer status.';
        return CustomerStatusResult(ok: false, message: msg);
      }

      final raw = json['data'];
      if (raw is! Map) {
        return const CustomerStatusResult(
          ok: false,
          message: 'Invalid customer status response.',
        );
      }

      return CustomerStatusResult(
        ok: true,
        message: 'OK',
        data: Map<String, dynamic>.from(raw),
      );
    } on SocketException {
      return const CustomerStatusResult(
        ok: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return const CustomerStatusResult(
        ok: false,
        message: 'Could not reach the server.',
      );
    } catch (e) {
      return CustomerStatusResult(
        ok: false,
        message: 'Something went wrong: $e',
      );
    }
  }

  /// Check-out: [checkOutTime] as `YYYY-MM-DD HH:MM:SS` (device local time).
  static Future<CheckOutResult> checkOut({
    required String reference,
    required String checkOutTime,
  }) async {
    final ref = reference.trim().toUpperCase();

    if (ref.isEmpty) {
      return const CheckOutResult(
        status: false,
        message: 'Reference number is required.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/customer_checkout.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'reference_number': ref,
              'check_out_time': checkOutTime,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return CheckOutResult(
          status: false,
          message: 'Server error (${response.statusCode}). Please try again.',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = json['status'] == true || json['success'] == true;
      final msg = (json['message'] as String?) ??
          (ok ? 'Check-out successful.' : 'Check-out failed.');

      return CheckOutResult(status: ok, message: msg);
    } on SocketException {
      return const CheckOutResult(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return const CheckOutResult(
        status: false,
        message: 'Could not reach the server.',
      );
    } catch (e) {
      return CheckOutResult(status: false, message: 'Something went wrong: $e');
    }
  }

  /// Late check-out: sends the updated end date + late fee breakdown to
  /// [_updateSlotUrl] (`update_reserved_slot.php`).
  /// Call this before [checkOut] to persist the fee data, then call [checkOut]
  /// to flip the customer status.
  static Future<UpdateSlotResult> lateCheckoutUpdate({
    required String reference,
    required String checkOutByName,
    required double totalPriceFinal,
    required String endDateEdited, // system time as 'YYYY-MM-DD HH:MM:SS'
    required double lateFeeAmount,
  }) async {
    final ref = reference.trim().toUpperCase();
    if (ref.isEmpty) {
      return const UpdateSlotResult(
        status: false,
        message: 'Reference number is required.',
      );
    }
    try {
      final response = await http
          .post(
            Uri.parse(_updateSlotUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'reference_number': ref,
              'check_out_by_name': checkOutByName.trim(),
              'total_price_final': totalPriceFinal,
              'end_date_edited': endDateEdited,
              'late_fee_amount': lateFeeAmount,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return UpdateSlotResult(
          status: false,
          message: 'Server error (${response.statusCode}). Please try again.',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = json['status'] == true;
      final msg = (json['message'] as String?) ??
          (ok ? 'Slot updated successfully.' : 'Slot update failed.');
      return UpdateSlotResult(status: ok, message: msg);
    } on SocketException {
      return const UpdateSlotResult(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return const UpdateSlotResult(
        status: false,
        message: 'Could not reach the server.',
      );
    } catch (e) {
      return UpdateSlotResult(
        status: false,
        message: 'Something went wrong: $e',
      );
    }
  }

  /// Update the [end_date] of an existing reserved slot.
  /// [reference] should be in the format "G7-AP-05".
  /// [endDate] should be formatted as "YYYY-MM-DD".
  static Future<UpdateSlotResult> updateReservedSlot({
    required String reference,
    required String endDate,
  }) async {
    final ref = reference.trim().toUpperCase();

    if (ref.isEmpty) {
      return const UpdateSlotResult(
        status: false,
        message: "Please enter a reference number.",
      );
    }

    if (!isValidReference(ref)) {
      return const UpdateSlotResult(
        status: false,
        message: "Invalid reference format. Expected format: G7-AP-05",
      );
    }

    if (endDate.isEmpty) {
      return const UpdateSlotResult(
        status: false,
        message: "Please select a new end date.",
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(_updateSlotUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'reference_number': ref,
              'end_date': endDate,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return UpdateSlotResult(
          status: false,
          message: "Server error (${response.statusCode}). Please try again.",
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = json['status'] == true;
      final msg = (json['message'] as String?) ?? (ok ? 'Updated successfully' : 'Update failed');

      return UpdateSlotResult(status: ok, message: msg);
    } on SocketException {
      return const UpdateSlotResult(
        status: false,
        message: "No internet connection. Please check your network.",
      );
    } on HttpException {
      return const UpdateSlotResult(
        status: false,
        message: "Could not reach the server.",
      );
    } catch (e) {
      return UpdateSlotResult(
        status: false,
        message: "Something went wrong: $e",
      );
    }
  }

  /// Download an existing receipt PDF from [pdfUrl] and save it locally.
  /// Returns the saved [File] so it can be opened with OpenFile.
  static Future<AirportInvoiceResult> downloadReceiptPdf({
    required String pdfUrl,
    required String reference,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(pdfUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return AirportInvoiceResult(
          status: false,
          message: 'Server returned ${response.statusCode}.',
        );
      }

      final isPdf = (response.headers['content-type'] ?? '')
              .toLowerCase()
              .contains('application/pdf') ||
          _hasPdfMagic(response.bodyBytes);

      if (!isPdf) {
        return AirportInvoiceResult(
          status: false,
          message: 'Downloaded file is not a valid PDF.',
        );
      }

      final dir = await getApplicationSupportDirectory();
      final safeName =
          reference.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final file =
          File('${dir.path}/receipt_$safeName.pdf');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      return AirportInvoiceResult(
        status: true,
        message: 'Receipt loaded.',
        file: file,
      );
    } on SocketException {
      return AirportInvoiceResult(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return AirportInvoiceResult(
        status: false,
        message: 'Could not download receipt: $e',
      );
    }
  }

  /// Check if a PDF receipt already exists on the server for [reference].
  /// Returns [ReceiptCheckResult.exists] == true and [pdfUrl] when found.
  static Future<ReceiptCheckResult> checkPaymentReceipt(
      String reference) async {
    try {
      final uri = Uri.parse(_checkReceiptUrl)
          .replace(queryParameters: {'reference': reference.trim()});
      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final exists = body['exists'] == true;
      return ReceiptCheckResult(
        exists: exists,
        pdfUrl: exists ? body['pdf_url'] as String? : null,
        message: body['message']?.toString() ?? '',
      );
    } catch (e) {
      return ReceiptCheckResult(
        exists: false,
        message: 'Could not check receipt: $e',
      );
    }
  }

  /// Upload [pdfBytes] to the server and save a record in payment_receipts.
  ///
  /// [reference]   — booking reference number (e.g. "G10-AP-06")
  /// [generatedBy] — full name of the logged-in employee
  /// [pdfBytes]    — raw bytes of the generated PDF
  static Future<ReceiptSaveResult> savePaymentReceipt({
    required String reference,
    required String generatedBy,
    required List<int> pdfBytes,
  }) async {
    try {
      final uri = Uri.parse(_saveReceiptUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['reference'] = reference.trim()
        ..fields['generated_by'] = generatedBy.trim()
        ..files.add(http.MultipartFile.fromBytes(
          'pdf',
          pdfBytes,
          filename: 'receipt-${reference.trim()}.pdf',
        ));

      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final body =
          jsonDecode(await streamed.stream.bytesToString()) as Map<String, dynamic>;

      final ok = body['status']?.toString().toLowerCase() == 'success';
      return ReceiptSaveResult(
        status: ok,
        message: body['message']?.toString() ?? '',
        receiptNo: body['receipt_no']?.toString(),
        receiptPath: body['receipt_path']?.toString(),
      );
    } catch (e) {
      return ReceiptSaveResult(
        status: false,
        message: 'Could not save receipt: $e',
      );
    }
  }

  /// Fetch today's bookings. Pass [date] as "YYYY-MM-DD" to query a specific
  /// date; omit it to default to today on the server.
  static Future<TodayBookingsResult> getTodayBookings({String? date}) async {
    try {
      final params = date != null ? {'date': date} : <String, String>{};
      final uri = Uri.parse(_todayBookingsUrl).replace(queryParameters: params.isEmpty ? null : params);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return TodayBookingsResult(
          status: false,
          message: 'Server error (${response.statusCode}).',
          fromDate: date ?? '',
          toDate: '',
          count: 0,
          bookings: [],
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = json['status']?.toString().toLowerCase() == 'success';
      if (!ok) {
        return TodayBookingsResult(
          status: false,
          message: (json['message'] as String?) ?? 'Failed to load bookings.',
          fromDate: json['from_date']?.toString() ?? '',
          toDate: json['to_date']?.toString() ?? '',
          count: 0,
          bookings: [],
        );
      }

      final rawList = json['bookings'] as List? ?? [];
      final bookings = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => TodayBooking.fromJson(e))
          .toList();

      return TodayBookingsResult(
        status: true,
        message: 'OK',
        fromDate: json['from_date']?.toString() ?? '',
        toDate: json['to_date']?.toString() ?? '',
        count: (json['count'] as num?)?.toInt() ?? bookings.length,
        bookings: bookings,
      );
    } on SocketException {
      return TodayBookingsResult(
        status: false,
        message: 'No internet connection.',
        fromDate: '',
        toDate: '',
        count: 0,
        bookings: [],
      );
    } catch (e) {
      return TodayBookingsResult(
        status: false,
        message: 'Something went wrong: $e',
        fromDate: '',
        toDate: '',
        count: 0,
        bookings: [],
      );
    }
  }
}
