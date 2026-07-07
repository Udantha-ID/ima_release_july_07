import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_app/Services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'exceptions/app_exception.dart';
import 'create_new_password.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Services/biometric_service.dart';
import 'Services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  final String? initialUsername;

  const LoginScreen({Key? key, this.initialUsername}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _loginError; // message shown near the fields
  bool _isLoggingIn = false; // Show loading state while logging in

  final _biometricService = BiometricService();
  final _storage = const FlutterSecureStorage();

  bool _showBiometric = false;

    // Check biometric availability on init and show option if enabled and supported
    @override
    void initState() {
      super.initState();
      _usernameController.text = widget.initialUsername ?? '';
      _loadSavedCredentials();
      _checkBiometric();
    }

    Future<void> _loadSavedCredentials() async {
      final prefs = await SharedPreferences.getInstance();
      final rememberCredentials =
          prefs.getBool('remember_credentials_enabled') ?? false;
      if (!rememberCredentials) return;

      final savedEmail = await _storage.read(key: 'saved_email');
      final savedPassword = await _storage.read(key: 'saved_password');

      if (!mounted) return;
      if (savedEmail != null && savedPassword != null) {
        setState(() {
          _usernameController.text = savedEmail;
          _passwordController.text = savedPassword;
        });
      }
    }

    // Check if biometrics can be used and if user has enabled it in settings
    Future<void> _checkBiometric() async {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('biometric_enabled') ?? false;
      final canUse = await _biometricService.canUseBiometric();

      if (enabled && canUse) {
        if (mounted) setState(() => _showBiometric = true);
      }
    }

      // Biometric login flow
      Future<void> _biometricLogin() async {
      final success = await _biometricService.authenticate();
      if (!success) return;

      final email    = await _storage.read(key: 'email');
      final name     = await _storage.read(key: 'name');
      final userJson = await _storage.read(key: 'user');

      debugPrint("BIOMETRIC email: $email");
      debugPrint("BIOMETRIC name: $name");
      debugPrint("BIOMETRIC userJson: $userJson");

      if (email == null || userJson == null) {
        debugPrint("BIOMETRIC FAILED: missing data in storage");
        return;
      }

      final user = Map<String, dynamic>.from(jsonDecode(userJson));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            name: name ?? "User",
            user: user, 
            username: email,
            successMessage: "Login successful, $name!",
          ),
        ),
      );
    }
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

      InputDecoration _loginInputDecoration(String label, IconData icon, {Widget? suffix}) {
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



    Future<void> _loginApi() async {
      if (_usernameController.text.trim().isEmpty ||
          _passwordController.text.trim().isEmpty) {
        await _loadSavedCredentials();
      }

      final email = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // basic validation – show message near fields instead of snackbar
      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _loginError = "Please enter username and password.";
        });
        return;
      }

      try {
        // Start loading state
        setState(() {
          _isLoggingIn = true;
        });

        final data = await ApiService.login(email: email, password: password);

        debugPrint("LOGIN DATA: $data");

        if (data["success"] == true) {
          final user = Map<String, dynamic>.from(data["user"]);
          final name = user["name"] ?? "User";
          final prefs = await SharedPreferences.getInstance();
          final rememberCredentials =
              prefs.getBool('remember_credentials_enabled') ?? false;


          // Save entire user object as single JSON string
          await _storage.write(key: 'email', value: user["email"] ?? email);
          await _storage.write(key: 'name',  value: name);
          await _storage.write(key: 'user',  value: jsonEncode(user));

          if (rememberCredentials) {
            await _storage.write(key: 'saved_email', value: email);
            await _storage.write(key: 'saved_password', value: password);
          } else {
            await _storage.delete(key: 'saved_email');
            await _storage.delete(key: 'saved_password');
          }

          // clear any previous error
          setState(() {
            _loginError = null;
          });

          // Brief delay to show success, then navigate
          await Future.delayed(const Duration(milliseconds: 900));

          if (!mounted) return;

          // Request notification permission (required on iOS and Android 13+)
          await FirebaseMessaging.instance.requestPermission();

          // Save FCM token to server (non-critical — failure doesn't block login)
          try {
            final fcmToken = await FirebaseMessaging.instance.getToken();
            debugPrint("FCM getToken() result: $fcmToken");
            if (fcmToken != null) {
              NotificationService.saveFcmToken(
                employeeId: user["employeeId"].toString(),
                fcmToken: fcmToken,
              );
            } else {
              debugPrint("FCM: getToken() returned null — check google-services.json and Firebase setup");
            }
          } catch (e) {
            debugPrint("FCM: token fetch skipped — $e");
          }

          // Check if user is logging in with default HR password (first-time login)
          if (password == "Test@123") {
            // Redirect to create new password screen for first-time login
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CreateNewPasswordScreen(
                  userEmail: email,
                  userName: name,
                  userData: user,
                ),
              ),
            );
          } else {
            await _storage.write(key: 'email', value: email);
            await _storage.write(key: 'name', value: name);
            // Normal login - go to home screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  name: name,
                  user: user,
                  username: user["email"] ?? email,
                  successMessage: "Login successful, $name!",
                ),
              ),
            );
          }
          } else {
          // show server message (like wrong username/password) near fields
          setState(() {
            _isLoggingIn = false;
            _loginError =
                data["message"]?.toString() ?? "Invalid username or password. Please check and try again.";
          });
        }
      } catch (e) {
        debugPrint("LOGIN ERROR: $e");
        final err = AppException.handle(e);
        setState(() {
          _isLoggingIn = false;
          _loginError = err.message;
        });
      }
    }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    //responsive values
    final horizontalPad = w > 600 ? 32.0 : 24.0;
    final logoWidth = (w * 0.65).clamp(200.0, 320.0);
    final topGap = (h * 0.08).clamp(30.0, 80.0);
    final sectionGap = (h * 0.01).clamp(14.0, 28.0);

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

                      SizedBox(height: sectionGap),

                      //App Name
                      ShaderMask(
                        shaderCallback: (bounds) => RadialGradient(
                          center: const Alignment(0.0, 0.3), // move glow slightly downward
                          radius: 1.2,
                          colors: const [
                            Color(0xFF42A5F5), // light blue (center glow)
                            Color(0xFF0D47A1), // dark blue (edges)
                          ],
                          stops: const [0.2, 1.0],
                        ).createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        ),
                        child: Center(
                          child: Text(
                            'Enterprise Suite',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.alfaSlabOne(
                              fontSize: (w * 0.08).clamp(18.0, 34.0),
                              letterSpacing: 0.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),


                      if (_showBiometric) ...[
                        SizedBox(height: (h * 0.04).clamp(20.0, 60.0)),
                      ]
                      else ...[
                        SizedBox(height: (h * 0.08).clamp(20.0, 60.0)),
                      ],
                        SizedBox(height: sectionGap),

                      // Show biometric login option if enabled and supported
                      if (_showBiometric) ...[
                        Center(
                          child: GestureDetector(
                            onTap: _biometricLogin,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue.shade50,
                                  ),
                                  child: Image.asset(
                                    Theme.of(context).platform == TargetPlatform.iOS
                                        ? 'assets/faceId.png'
                                        : 'assets/fingerId.png',
                                    width: 42,
                                    height: 42,
                                    color: Colors.black,
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      //Username Field
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: _loginInputDecoration("Username", Icons.person_outline),
                      ),

                      const SizedBox(height: 16),

                      /// Password
                      TextField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                        obscureText: _obscurePassword,
                        onChanged: (_) {
                          if (_loginError != null) setState(() => _loginError = null);
                        },
                        decoration: _loginInputDecoration(
                          "Password",
                          Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      if (_loginError != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _loginError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: Navigate to Forgot Password screen
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ForgotPasswordScreen()));
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color.fromARGB(255, 216, 108, 108),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: sectionGap),

                      //Login Button
                      Center(
                        child: SizedBox(
                          width: (w * 0.45).clamp(150.0, 220.0),
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0060A6),Color(0xFF003580),],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoggingIn ? null : _loginApi,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoggingIn
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
                                      'Login',
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
                                     // Short notice so users understand the app
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Text(
                            'Please log in with your company username and password to access the Explore Holding ERP system.',
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

                      //Footer stays bottom on big screens, scrolls on small
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
            );
          },
        ),
      ),
    );
  }
}
