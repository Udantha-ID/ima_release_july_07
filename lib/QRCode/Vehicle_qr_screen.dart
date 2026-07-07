import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Models/vehicle_q_model.dart';
import '../Services/vehicle_qr_service.dart';
import 'package:screen_protector/screen_protector.dart';

class VehicleQrScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const VehicleQrScreen({super.key, required this.user});

  @override
  State<VehicleQrScreen> createState() => _VehicleQrScreenState();
}

class _VehicleQrScreenState extends State<VehicleQrScreen> {
  final TextEditingController lettersController = TextEditingController();
  final TextEditingController numbersController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  VehicleQrData? vehicleData;

  static const _blue1 = Color(0xFF1565C0);
  static const _blue2 = Color(0xFF003580);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  // Fetch vehicle QR details from API
  Future<void> fetchVehicleQr() async {
    final letters = lettersController.text.trim().toUpperCase();
    final numbers = numbersController.text.trim();

    if (letters.isEmpty || numbers.isEmpty) {
      setState(() {
        errorMessage = "Please enter both vehicle letters and number.";
        vehicleData = null;
      });
      return;
    }

  //print("USER DATA: ${widget.user}");
    
  final fullVehicleNo = "$letters-$numbers";
  final employeeId = widget.user["employeeId"]?.toString() ?? "";
  final preferredName = widget.user["preferredName"]?.toString() ?? "";
    if (employeeId.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = "Employee ID not found.";
        vehicleData = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      vehicleData = null;
    });

    final result = await VehicleQrService.getVehicleDetailsWithLog(
      employeeId: employeeId,
      preferredName: preferredName,
      vehicleNumber: fullVehicleNo,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
      if (result.status && result.data != null) {
        vehicleData = result.data;
      } else {
        errorMessage = result.message;
      }
    });
  }

  Future<void> _enableProtection() async {
    await ScreenProtector.protectDataLeakageOn();
  }

  Future<void> _disableProtection() async {
    await ScreenProtector.protectDataLeakageOff();
  }

  @override
  void initState() {
    super.initState();
    _enableProtection();
  }

  @override
  void dispose() {
    _disableProtection();
    lettersController.dispose();
    numbersController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  //  QR POPUP DIALOG
  // ──────────────────────────────────────────────
  void _showQrPopup() {
    if (vehicleData == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        final qrSize = (w * 0.75).clamp(220.0, 320.0);

        return Stack(
          children: [
            // Blur backdrop
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.transparent),
            ),

            Center(
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_blue1, _blue2],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.qr_code_2_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicleData!.vehicleNumber,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _textDark,
                                  ),
                                ),
                                Text(
                                  vehicleData!.companyName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded,
                                color: _textMuted),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // QR image
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.network(
                          vehicleData!.image,
                          width: qrSize,
                          height: qrSize,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return SizedBox(
                              width: qrSize,
                              height: qrSize,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: _blue2,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => SizedBox(
                            width: qrSize,
                            height: qrSize,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_outlined,
                                      color: Colors.red, size: 36),
                                  SizedBox(height: 8),
                                  Text(
                                    "Unable to load QR image",
                                    style: TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        "Tap outside to close",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _textMuted.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

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
          // Banner row at the top of the card
          Row(
            children: [
              Container(

                child: const Icon(Icons.qr_code_2_rounded,
                    color: Color.fromARGB(255, 0, 0, 0), size: 44),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Vehicle QR Code",
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Search by vehicle number to view QR",
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
            "Enter Vehicle Number",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),

          const SizedBox(height: 16),

          // Letters + Number fields
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: lettersController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                    LengthLimitingTextInputFormatter(4),
                    UpperCaseTextFormatter(),
                  ],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    labelText: "Letters",
                    hintText: "ABC",
                    labelStyle:
                        const TextStyle(color: _textMuted, fontSize: 13),
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
                        horizontal: 14, vertical: 14),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  "–",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textMuted.withOpacity(0.6),
                  ),
                ),
              ),

              Expanded(
                child: TextFormField(
                  controller: numbersController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    labelText: "Number",
                    hintText: "1234",
                    labelStyle:
                        const TextStyle(color: _textMuted, fontSize: 13),
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
                        horizontal: 14, vertical: 14),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search button
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
              onPressed: isLoading ? null : fetchVehicleQr,
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
                          "Search Vehicle",
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
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.qr_code_2_rounded,
            size: 34,
            color: _blue2,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          "No QR Code Yet",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Enter a vehicle number above and\ntap Search to view the QR code.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: _textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),

        // Notice box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.45)),
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
                  "Notice: When you search a vehicle Fuel Pass QR, this search record will be saved in the system.",
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

  // ──────────────────────────────────────────────
  //  RESULT CARD (with tappable QR)
  // ──────────────────────────────────────────────
  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
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
        children: [
          // Vehicle info header strip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_blue1, _blue2]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleData!.vehicleNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        vehicleData!.companyName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Active",
                    style: TextStyle(
                      color: _blue2,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // QR preview — tappable
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showQrPopup,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.network(
                          vehicleData!.image,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              height: 240,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: _blue2,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => const SizedBox(
                            height: 240,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_outlined,
                                      color: Colors.red, size: 36),
                                  SizedBox(height: 8),
                                  Text(
                                    "Unable to load QR image",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // "Tap to expand" badge
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _blue2.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_full_rounded,
                                  color: Colors.white, size: 13),
                              SizedBox(width: 4),
                              Text(
                                "Tap to expand",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "Tap the QR code to view it in full screen",
                  style: TextStyle(
                    fontSize: 12,
                    color: _textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
          "Vehicle QR Code",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              _buildInputCard(),
            const SizedBox(height: 16),

            if (!isLoading) ...[
              if (errorMessage != null) _buildErrorCard(),
              if (errorMessage == null && vehicleData == null)
                _buildEmptyState(),
              if (vehicleData != null) _buildResultCard(),
            ],

            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(
                    color: _blue2,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
