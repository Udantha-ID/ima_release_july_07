import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Services/biometric_service.dart';

Future<void> showBiometricEnableDialogIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool('biometric_enabled') ?? false;
  if (enabled) return;

  final canUse = await BiometricService().canUseBiometric();
  if (!canUse) return;

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (_) => const _BiometricEnableDialog(),
  );
}

class _BiometricEnableDialog extends StatefulWidget {
  const _BiometricEnableDialog();

  @override
  State<_BiometricEnableDialog> createState() => _BiometricEnableDialogState();
}

class _BiometricEnableDialogState extends State<_BiometricEnableDialog> {
  bool _isEnabling = false;
  String? _errorMessage;
  final _biometricService = BiometricService();

  Future<void> _enable() async {
    setState(() {
      _isEnabling = true;
      _errorMessage = null;
    });

    try {
      final success = await _biometricService.authenticate();
      if (!mounted) return;

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('biometric_enabled', true);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            duration: const Duration(seconds: 3),
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Biometric login enabled successfully.",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        setState(() {
          _isEnabling = false;
          _errorMessage = "Authentication failed. Please try again.";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isEnabling = false;
          _errorMessage = "Something went wrong. Please try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final dialogW = (w * 0.92).clamp(280.0, 420.0);

    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(color: Colors.black.withValues(alpha: 0.15)),
        ),
        Center(
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: dialogW,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        Theme.of(context).platform == TargetPlatform.iOS
                            ? 'assets/faceId.png'
                            : 'assets/fingerId.png',
                        width: 46,
                        height: 46,
                        color: const Color(0xFF0060A6),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "Enable Biometric Login?",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Your device supports biometric authentication.\nEnable it now for faster and secure login next time.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.45,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isEnabling ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0060A6),
                              side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text(
                              "Not Now",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: _isEnabling
                                    ? null
                                    : const LinearGradient(
                                        colors: [Color(0xFF0060A6), Color(0xFF003580)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                borderRadius: BorderRadius.circular(12),
                                color: _isEnabling ? Colors.grey.shade300 : null,
                              ),
                              child: ElevatedButton(
                                onPressed: _isEnabling ? null : _enable,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isEnabling
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        "Enable",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
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
