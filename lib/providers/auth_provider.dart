import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';
import '../services/biometric_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SecureStorageService _secureStorage = SecureStorageService();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _saveCredentials = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _biometricDisplayText = 'Biometric';

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get saveCredentials => _saveCredentials;
  bool get biometricAvailable => _biometricAvailable;
  bool get biometricEnabled => _biometricEnabled;
  String get biometricDisplayText => _biometricDisplayText;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        _currentUser = await _authService.getUserData(user.uid);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
    
    // Initialize biometric and credential settings
    _initializeBiometric();
    _loadSavedSettings();
  }

  Future<void> _initializeBiometric() async {
    try {
      _biometricAvailable = await BiometricService.isBiometricAvailable();
      _biometricEnabled = await _secureStorage.isBiometricEnabled();
      _biometricDisplayText = await BiometricService.getBiometricDisplayText();
      notifyListeners();
    } catch (e) {
      _biometricAvailable = false;
      _biometricEnabled = false;
    }
  }

  Future<void> _loadSavedSettings() async {
    try {
      _saveCredentials = await _secureStorage.shouldSaveCredentials();
      notifyListeners();
    } catch (e) {
      _saveCredentials = false;
    }
  }

  Future<bool> signIn(String email, String password, {bool shouldSaveCredentials = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signIn(email, password);
      if (user != null) {
        _currentUser = user;
        
        // Save credentials if requested
        if (shouldSaveCredentials) {
          await _secureStorage.saveCredentials(email, password);
          _saveCredentials = true;
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.register(email, password, name);
      if (user != null) {
        _currentUser = user;
      }
      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> initializeDefaultAccounts() async {
    await _authService.initializeDefaultAccounts();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> updateCurrentUser(UserModel user) async {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    if (_currentUser != null) {
      _currentUser = await _authService.getUserData(_currentUser!.uid);
      notifyListeners();
    }
  }

  /// Get saved credentials for auto-fill
  Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final email = await _secureStorage.getSavedEmail();
      final password = await _secureStorage.getSavedPasswordForAutoFill();
      return {'email': email, 'password': password};
    } catch (e) {
      return {'email': null, 'password': null};
    }
  }

  /// Toggle save credentials setting
  void toggleSaveCredentials(bool value) {
    _saveCredentials = value;
    notifyListeners();
    
    if (!value) {
      // Clear saved credentials if disabled
      _secureStorage.clearCredentials();
    }
  }

  /// Sign in with biometric authentication
  Future<bool> signInWithBiometric() async {
    if (!_biometricAvailable || !_biometricEnabled) {
      _errorMessage = 'Biometric authentication is not available or enabled';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Authenticate with biometrics
      final authenticated = await BiometricService.authenticate(
        localizedReason: 'Please authenticate to sign in to Al-Siraj Attendance',
        biometricOnly: true,
      );

      if (authenticated) {
        // Get saved credentials
        final credentials = await _secureStorage.getBiometricCredentials();
        if (credentials != null) {
          final user = await _authService.signIn(
            credentials['email']!,
            credentials['password']!,
          );
          
          if (user != null) {
            _currentUser = user;
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Enable biometric authentication
  Future<bool> enableBiometric(String email, String password) async {
    if (!_biometricAvailable) {
      _errorMessage = 'Biometric authentication is not available on this device';
      notifyListeners();
      return false;
    }

    try {
      // Test biometric authentication first
      final authenticated = await BiometricService.authenticate(
        localizedReason: 'Please authenticate to enable biometric login',
        biometricOnly: true,
      );

      if (authenticated) {
        // Save credentials for biometric authentication
        await _secureStorage.saveBiometricCredentials(email, password);
        _biometricEnabled = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    try {
      await _secureStorage.disableBiometric();
      _biometricEnabled = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Check if biometric authentication can be enabled
  Future<bool> canEnableBiometric() async {
    if (!_biometricAvailable) return false;
    
    try {
      final hasEnrolled = await BiometricService.hasEnrolledBiometrics();
      return hasEnrolled;
    } catch (e) {
      return false;
    }
  }

  /// Refresh biometric availability
  Future<void> refreshBiometricStatus() async {
    await _initializeBiometric();
  }
}

