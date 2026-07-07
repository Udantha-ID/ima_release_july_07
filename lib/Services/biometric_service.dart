import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canUseBiometric() async {
    return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
  }

  Future<bool> authenticate() async {
    try {
      //final availableBiometrics = await _auth.getAvailableBiometrics();

      // biometrics aren't enrolled yet or fall back to PIN
      return await _auth.authenticate(
        localizedReason: 'Use biometric to login',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow PIN/pattern fallback
          stickyAuth: true,
        ),
      );
    } on Exception catch (e) {
      debugPrint("Biometric error: $e");
      return false;
    }
  }
}