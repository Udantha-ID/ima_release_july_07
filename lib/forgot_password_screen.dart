import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:test_app/Services/api_service.dart';
import 'login_screen.dart';
import 'Leaves/top_banner.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _recoveryKeyController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureRecovery = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Individual error messages for each field (only for validation issues, not empty)
  String? _emailError;
  String? _recoveryKeyError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  String? _generalError; // General error shown at bottom for empty fields
  bool _isSubmitting = false; // Show loading state while submitting

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintStyle: TextStyle(color: Colors.grey.shade600),
      labelStyle: TextStyle(color: Colors.grey.shade700),
      prefixIcon: Icon(icon, color: Colors.grey.shade700),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.blue, width: 1.2),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _recoveryKeyController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clear all previous errors
    setState(() {
      _emailError = null;
      _recoveryKeyError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
      _generalError = null;
    });

    final email = _emailController.text.trim();
    final recoveryKey = _recoveryKeyController.text.trim();
    final newPassword = _newPassController.text.trim();
    final confirmPassword = _confirmPassController.text.trim();

    // Check if any field is empty - show general error at bottom
    if (email.isEmpty || recoveryKey.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _generalError = "All fields are required. Please fill in all fields.";
      });
      return;
    }

    bool hasError = false;

    // Validate email format (only if not empty)
    if (!email.contains('@')) {
      setState(() {
        _emailError = "Please enter a valid email address.";
      });
      hasError = true;
    }

    // Validate new password (only if not empty)
    if (newPassword.length < 6) {
      setState(() {
        _newPasswordError = "Password must be at least 6 characters.";
      });
      hasError = true;
    } else if (newPassword == "Test@123") {
      setState(() {
        _newPasswordError = "Cannot use default password. Please choose a different password.";
      });
      hasError = true;
    }

    // Validate confirm password matches (only if not empty)
    if (newPassword != confirmPassword) {
      setState(() {
        _confirmPasswordError = "Passwords do not match. Please check and try again.";
      });
      hasError = true;
    }

    if (hasError) return;

    // Also validate form
    if (!_formKey.currentState!.validate()) return;

    try {
      // Start loading state
      setState(() {
        _isSubmitting = true;
      });

      // Call API
      final res = await ApiService.forgotPassword(
        email: email,
        recoveryKey: recoveryKey,
        newPassword: newPassword,
      );

      if (!mounted) return;

      if (res["success"] == true) {

        TopBanner.show(
          context,
          title: "Success",
          message: "Password updated successfully! Please login again.",
          icon: Icons.check_circle,
          rightButtonText: "OK",
        );

        // Brief loading delay so user can see success, then navigate
        await Future.delayed(const Duration(milliseconds: 900));

        // Go back to a fresh login screen (clear stack) with username pre-filled
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              initialUsername: email,
            ),
          ),
          (route) => false,
        );
      } else {
        // Show API error - check if it's email/user related or recovery key related
        final errorMsg = res["message"]?.toString().toLowerCase() ?? "";
        final errorMsgOriginal = res["message"]?.toString() ?? "Failed to update password. Please check your information and try again.";
        
        // Check if error is related to user/email not found
        if (errorMsg.contains("user not found") || 
            errorMsg.contains("email not found") || 
            errorMsg.contains("user does not exist") ||
            errorMsg.contains("invalid email") ||
            errorMsg.contains("email")) {
          setState(() {
            _emailError = errorMsgOriginal;
            _isSubmitting = false;
          });
        } else {
          // Otherwise show on recovery key field (recovery key mismatch)
          setState(() {
            _recoveryKeyError = errorMsgOriginal;
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Show generic connectivity error at the bottom (not under a single field)
        _generalError = "Unable to reset password right now. Please check your internet connection and try again.";
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // responsive values (same as login screen)
    final horizontalPad = w > 600 ? 32.0 : 24.0;
    final logoWidth = (w * 0.65).clamp(200.0, 320.0);
    final topGap = (h * 0.08).clamp(30.0, 80.0);
    final sectionGap = (h * 0.01).clamp(12.0, 28.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: topGap),

                        //Logo
                        Center(
                          child: Image.asset(
                            'assets/ExploreHoldingLogo.png',
                            width: logoWidth,
                            fit: BoxFit.contain,
                          ),
                        ),

                        SizedBox(height: (h * 0.06).clamp(20.0, 60.0)),

                        SizedBox(height: sectionGap),

                        Text(
                          "Reset Password",
                          style: GoogleFonts.actor(
                            fontSize: (w * 0.07).clamp(22.0, 28.0),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF003863),
                          ),
                        ),

                        SizedBox(height: sectionGap),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {
                            if (_emailError != null || _generalError != null) {
                              setState(() {
                                _emailError = null;
                                _generalError = null;
                              });
                            }
                          },
                          decoration: _inputDecoration("Email Address", Icons.email_outlined),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return "Email is required";
                            if (!value.contains('@')) return "Please enter a valid email";
                            return null;
                          },
                        ),
                        if (_emailError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _emailError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Recovery Key Field
                        TextFormField(
                          controller: _recoveryKeyController,
                          style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                          obscureText: _obscureRecovery,
                          onChanged: (_) {
                            if (_recoveryKeyError != null || _generalError != null) {
                              setState(() {
                                _recoveryKeyError = null;
                                _generalError = null;
                              });
                            }
                          },
                          decoration: _inputDecoration(
                            "Recovery Key",
                            Icons.key_outlined,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureRecovery ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () => setState(() => _obscureRecovery = !_obscureRecovery),
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return "Recovery key is required";
                            return null;
                          },
                        ),
                        if (_recoveryKeyError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _recoveryKeyError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // New Password Field
                        TextFormField(
                          controller: _newPassController,
                          style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                          obscureText: _obscureNew,
                          onChanged: (_) {
                            if (_newPasswordError != null || _generalError != null) {
                              setState(() {
                                _newPasswordError = null;
                                _generalError = null;
                              });
                            }
                          },
                          decoration: _inputDecoration(
                            "New Password",
                            Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () => setState(() => _obscureNew = !_obscureNew),
                            ),
                          ),
                          validator: (v) {
                          final value = (v ?? '').trim();

                          if (value.isEmpty) {
                            return "New password is required";
                          }

                          if (value.length < 6) {
                            return "Password must be at least 6 characters";
                          }

                          if (!RegExp(r'[A-Z]').hasMatch(value)) {
                            return "Must contain at least one uppercase letter";
                          }

                          if (!RegExp(r'[a-z]').hasMatch(value)) {
                            return "Must contain at least one lowercase letter";
                          }

                          if (!RegExp(r'[0-9]').hasMatch(value)) {
                            return "Must contain at least one number";
                          }

                          if (!RegExp(r'[!@#\$&*~^%()_+\-=\[\]{};:"\\|,.<>\/?]').hasMatch(value)) {
                            return "Must contain at least one special character";
                          }

                          if (value == "Test@123") {
                            return "Cannot use default password";
                          }

                          return null;
                        },
                        ),
                        if (_newPasswordError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _newPasswordError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Confirm Password Field
                        TextFormField(
                          controller: _confirmPassController,
                          style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                          obscureText: _obscureConfirm,
                          decoration: _inputDecoration(
                            "Confirm Password",
                            Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return "Confirm password is required";
                            if (value != _newPassController.text.trim()) {
                              return "Passwords do not match";
                            }
                            return null;
                          },
                          onChanged: (_) {
                            if (_confirmPasswordError != null || _generalError != null) {
                              setState(() {
                                _confirmPasswordError = null;
                                _generalError = null;
                              });
                            }
                          },
                        ),
                        if (_confirmPasswordError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _confirmPasswordError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // General error message at bottom (for empty fields) - simple style like login screen
                        if (_generalError != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _generalError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ] else
                          const SizedBox(height: 8),

                        SizedBox(height: sectionGap),

                        //Submit Button (same gradient style as login)
                        Center(
                          child: SizedBox(
                            width: (w * 0.45).clamp(150.0, 220.0),
                            height: 48,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0060A6),
                                    Color(0xFF003580),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Reset',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Short notice (same style as login)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Text(
                              'Contact your HR department to retrieve your recovery key. Make sure to create a strong password that only you know.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color.fromARGB(255, 101, 156, 182),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Footer (same as login)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: const [
                              Expanded(
                                child: Divider(
                                  color: Color(0xFF0060A6),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'Need Help',
                                  style: TextStyle(
                                    color: Color(0xFF0060A6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Color(0xFF0060A6),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
