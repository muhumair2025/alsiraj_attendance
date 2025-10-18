import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys for storing credentials
  static const String _emailKey = 'saved_email';
  static const String _passwordKey = 'saved_password';
  static const String _saveCredentialsKey = 'save_credentials';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricCredentialsKey = 'biometric_credentials';

  /// Save user credentials securely
  Future<void> saveCredentials(String email, String password) async {
    try {
      await _storage.write(key: _emailKey, value: email);
      // Hash the password before storing for extra security
      final hashedPassword = _hashPassword(password);
      await _storage.write(key: _passwordKey, value: hashedPassword);
      // Store original password for auto-fill (encrypted by secure storage)
      await _storage.write(key: '${_passwordKey}_autofill', value: password);
      await _storage.write(key: _saveCredentialsKey, value: 'true');
    } catch (e) {
      throw Exception('Failed to save credentials: $e');
    }
  }

  /// Get saved email
  Future<String?> getSavedEmail() async {
    try {
      return await _storage.read(key: _emailKey);
    } catch (e) {
      return null;
    }
  }

  /// Get saved password (returns hashed version)
  Future<String?> getSavedPassword() async {
    try {
      return await _storage.read(key: _passwordKey);
    } catch (e) {
      return null;
    }
  }

  /// Get saved password for auto-fill (returns original password)
  Future<String?> getSavedPasswordForAutoFill() async {
    try {
      // For auto-fill, we need to store the original password separately
      return await _storage.read(key: '${_passwordKey}_autofill');
    } catch (e) {
      return null;
    }
  }

  /// Check if credentials should be saved
  Future<bool> shouldSaveCredentials() async {
    try {
      final value = await _storage.read(key: _saveCredentialsKey);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Clear saved credentials
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _passwordKey);
      await _storage.delete(key: '${_passwordKey}_autofill');
      await _storage.delete(key: _saveCredentialsKey);
    } catch (e) {
      throw Exception('Failed to clear credentials: $e');
    }
  }

  /// Save credentials for biometric authentication
  Future<void> saveBiometricCredentials(String email, String password) async {
    try {
      final credentials = {
        'email': email,
        'password': password,
      };
      final credentialsJson = json.encode(credentials);
      await _storage.write(key: _biometricCredentialsKey, value: credentialsJson);
      await _storage.write(key: _biometricEnabledKey, value: 'true');
    } catch (e) {
      throw Exception('Failed to save biometric credentials: $e');
    }
  }

  /// Get biometric credentials
  Future<Map<String, String>?> getBiometricCredentials() async {
    try {
      final credentialsJson = await _storage.read(key: _biometricCredentialsKey);
      if (credentialsJson != null) {
        final credentials = json.decode(credentialsJson) as Map<String, dynamic>;
        return {
          'email': credentials['email'] as String,
          'password': credentials['password'] as String,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if biometric authentication is enabled
  Future<bool> isBiometricEnabled() async {
    try {
      final value = await _storage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    try {
      await _storage.delete(key: _biometricEnabledKey);
      await _storage.delete(key: _biometricCredentialsKey);
    } catch (e) {
      throw Exception('Failed to disable biometric authentication: $e');
    }
  }

  /// Verify if the provided password matches the saved hashed password
  bool verifyPassword(String inputPassword, String hashedPassword) {
    return _hashPassword(inputPassword) == hashedPassword;
  }

  /// Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Clear all stored data
  Future<void> clearAllData() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw Exception('Failed to clear all data: $e');
    }
  }
}
