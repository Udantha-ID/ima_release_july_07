import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_app/Services/api_service.dart';
import 'login_screen.dart';
import 'Leaves/top_banner.dart';

class CreateNewPasswordScreen extends StatefulWidget {
  final String? userEmail;
  final String? userName;
  final Map<String, dynamic>? userData;
  
  const CreateNewPasswordScreen({
    super.key,
    this.userEmail,
    this.userName,
    this.userData,
  });

  @override
  State<CreateNewPasswordScreen> createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _recoveryKeyController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false; // Show loading state while submitting

  @override
  void dispose() {
    _newPassController.dispose();
    _confirmPassController.dispose();
    _recoveryKeyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final newPassword = _newPassController.text.trim();
    final confirmPassword = _confirmPassController.text.trim();
    final recoveryKey = _recoveryKeyController.text.trim();

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newPassword == "Test@123") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please choose a different password. You cannot use the default password."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Must have email from previous screen
    final email = (widget.userEmail ?? "").trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User email not found. Please login again."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Start loading state
      setState(() {
        _isSubmitting = true;
      });

      // Call API
      final res = await ApiService.updatePassword(
        email: email,
        newPassword: newPassword,
        recoveryKey: recoveryKey,
      );

      if (!mounted) return;

        if (res["success"] == true) {
          TopBanner.show(
            context,
            title: "Success",
            message: (res["message"] ??
                "Password updated successfully! Please login again."),
            icon: Icons.check_circle,
            isSuccess: true,
            rightButtonText: "OK",
          );

          // keep your delay
          await Future.delayed(const Duration(milliseconds: 900));

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LoginScreen(initialUsername: email),
            ),
            (route) => false,
          );
        } else {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res["message"] ?? "Failed to update password"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating password: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // responsive values (same style as your login)
    final horizontalPad = w > 600 ? 32.0 : 24.0;
    final topGap = (h * 0.05).clamp(18.0, 40.0);
    final sectionGap = (h * 0.02).clamp(14.0, 28.0);
    final logoWidth = (w * 0.65).clamp(200.0, 320.0);


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

                          SizedBox(height: 40),


                        Text(
                          "Set a new password",
                          style: GoogleFonts.actor(
                            fontSize: (w * 0.07).clamp(22.0, 28.0),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF003863),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.userEmail != null
                              ? "This is your first login. Please create a new secure password to continue."
                              : "Your new password must be different from previous one.",
                          style: GoogleFonts.actor(
                            fontSize: 13,
                            color: const Color.fromARGB(255, 101, 156, 182),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: sectionGap),

                        // Recovery Key (styled similar to login fields, but with uppercase only)
                        TextFormField(
                          controller: _recoveryKeyController,
                          style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                          textCapitalization: TextCapitalization.none,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                            TextInputFormatter.withFunction((oldValue, newValue) {
                              return newValue.copyWith(
                                text: newValue.text.toUpperCase(),
                                selection: newValue.selection,
                              );
                            }),
                          ],
                          decoration: _inputDecoration(
                            "Recovery Name",
                            Icons.vpn_key_outlined,
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Recovery key is required';
                            if (!RegExp(r'^[A-Z]{6,}$').hasMatch(value)) return 'Use only capital letters (minimum 6)';
                            return null;
                          },
                        ),
                            const SizedBox(height: 6),
                            Text(
                              'Important: Please remember this recovery key. If you forget your password later, you must use this key to reset and log in again.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: const Color.fromARGB(255, 216, 108, 108),
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),

                        const SizedBox(height: 10),

                        // New Password (styled similar to login fields)
                        TextFormField(
                          controller: _newPassController,
                          style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                          obscureText: _obscureNew,
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

                        const SizedBox(height: 8),

                        // Confirm Password (styled similar to login fields)
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
                        ),

                        SizedBox(height: sectionGap),

                        //Submit Button (match login gradient but keep same size)
                        Center(
                          child: SizedBox(
                            width: (w * 0.70).clamp(220.0, 360.0),
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
                                  elevation: 0,
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Update Password',
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

                        const Spacer(),

                        // Info notice about strong password (card at bottom)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Card(
                              color: const Color(0xFFF5F9FF),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFFCCE0F4),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.lock_outline,
                                      size: 20,
                                      color: Color(0xFF0060A6),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Create a secure password',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF003863),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Use a password that only you know. Avoid using your employee ID, phone number, or the default password again.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF4A4A4A),
                                              height: 1.4,
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
                        ),

                        const Spacer(),

                        // Footer (same style)
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
                                  'Explore Holdings',
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
