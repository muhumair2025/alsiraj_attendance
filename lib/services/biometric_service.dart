import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on the device
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Check if device has enrolled biometrics
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Authenticate using biometrics
  static Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access your account',
    bool biometricOnly = false,
  }) async {
    try {
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        throw Exception('Biometric authentication is not available');
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotAvailable':
          throw Exception('Biometric authentication is not available');
        case 'NotEnrolled':
          throw Exception('No biometrics enrolled on this device');
        case 'LockedOut':
          throw Exception('Too many failed attempts. Please try again later');
        case 'PermanentlyLockedOut':
          throw Exception('Biometric authentication is permanently disabled');
        case 'UserCancel':
          throw Exception('Authentication was cancelled by user');
        case 'UserFallback':
          throw Exception('User chose to use fallback authentication');
        case 'BiometricOnlyNotSupported':
          throw Exception('Biometric-only authentication is not supported');
        default:
          throw Exception('Authentication failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Authentication failed: $e');
    }
  }

  /// Get biometric type name for display
  static String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
      default:
        return 'Biometric';
    }
  }

  /// Get primary biometric type available
  static Future<BiometricType?> getPrimaryBiometricType() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return null;

      // Prioritize face recognition, then fingerprint, then others
      if (availableBiometrics.contains(BiometricType.face)) {
        return BiometricType.face;
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return BiometricType.fingerprint;
      } else if (availableBiometrics.contains(BiometricType.strong)) {
        return BiometricType.strong;
      } else {
        return availableBiometrics.first;
      }
    } catch (e) {
      return null;
    }
  }

  /// Get display text for biometric authentication
  static Future<String> getBiometricDisplayText() async {
    try {
      final primaryType = await getPrimaryBiometricType();
      if (primaryType == null) return 'Biometric';
      
      switch (primaryType) {
        case BiometricType.face:
          return 'Face ID';
        case BiometricType.fingerprint:
          return 'Fingerprint';
        case BiometricType.iris:
          return 'Iris';
        default:
          return 'Biometric';
      }
    } catch (e) {
      return 'Biometric';
    }
  }

  /// Get appropriate icon for biometric type
  static Future<String> getBiometricIcon() async {
    try {
      final primaryType = await getPrimaryBiometricType();
      if (primaryType == null) return '🔐';
      
      switch (primaryType) {
        case BiometricType.face:
          return '👤';
        case BiometricType.fingerprint:
          return '👆';
        case BiometricType.iris:
          return '👁️';
        default:
          return '🔐';
      }
    } catch (e) {
      return '🔐';
    }
  }
}
