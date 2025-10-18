import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/error_message.dart';
import '../../services/notification_service.dart';
import '../admin/admin_dashboard.dart';
import '../teacher/teacher_dashboard.dart';
import '../student/student_dashboard.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _saveCredentials = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final credentials = await authProvider.getSavedCredentials();
    
    if (credentials['email'] != null) {
      _emailController.text = credentials['email']!;
      setState(() {
        _saveCredentials = authProvider.saveCredentials;
      });
    }
    
    if (credentials['password'] != null) {
      _passwordController.text = credentials['password']!;
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
        shouldSaveCredentials: _saveCredentials,
      );

      if (mounted) {
        if (success) {
          // Initialize notifications for the logged-in user
          await NotificationService().initialize();
          
          // Navigate to appropriate dashboard based on role
          _navigateToDashboard(authProvider);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Login failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithBiometric();

    if (mounted) {
      if (success) {
        // Initialize notifications for the logged-in user
        await NotificationService().initialize();
        
        // Navigate to appropriate dashboard based on role
        _navigateToDashboard(authProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Biometric authentication failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBiometricSetupDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email and password first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final canEnable = await authProvider.canEnableBiometric();
    if (!canEnable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set up biometric authentication in your device settings first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Enable ${authProvider.biometricDisplayText} Login'),
          content: Text(
            'Would you like to enable ${authProvider.biometricDisplayText.toLowerCase()} authentication for quick login?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await authProvider.enableBiometric(
                  _emailController.text.trim(),
                  _passwordController.text,
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success 
                          ? '${authProvider.biometricDisplayText} authentication enabled successfully!'
                          : 'Failed to enable ${authProvider.biometricDisplayText.toLowerCase()} authentication',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Enable'),
            ),
          ],
        ),
      );
    }
  }

  void _navigateToDashboard(AuthProvider authProvider) {
    if (authProvider.currentUser == null) return;

    final role = authProvider.currentUser!.role;
    Widget dashboard;

    switch (role) {
      case 'admin':
        dashboard = const AdminDashboard();
        break;
      case 'teacher':
        dashboard = const TeacherDashboard();
        break;
      case 'student':
        dashboard = const StudentDashboard();
        break;
      default:
        return;
    }

    // Replace entire navigation stack with the dashboard
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => dashboard),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Al-Siraj Logo
                  Center(
                    child: Image.asset(
                      'assets/images/logo-alsiraj-light.png',
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to Al-Siraj Attendance System',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Error message
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      if (authProvider.errorMessage != null) {
                        return Column(
                          children: [
                            ErrorMessage(message: authProvider.errorMessage!),
                            const SizedBox(height: 16),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // Email field
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Save credentials checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _saveCredentials,
                        onChanged: (value) {
                          setState(() {
                            _saveCredentials = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Save credentials for next time',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return CustomButton(
                        text: 'Sign In',
                        onPressed: _handleLogin,
                        isLoading: authProvider.isLoading,
                        icon: Icons.login,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Biometric login section
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      if (!authProvider.biometricAvailable) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          // Divider with "OR" text
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Biometric login button or setup button
                          if (authProvider.biometricEnabled)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: authProvider.isLoading ? null : _handleBiometricLogin,
                                icon: const Icon(Icons.fingerprint, size: 24),
                                label: Text(
                                  'Sign in with ${authProvider.biometricDisplayText}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: Theme.of(context).primaryColor),
                                  foregroundColor: Theme.of(context).primaryColor,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: _showBiometricSetupDialog,
                                icon: const Icon(Icons.fingerprint, size: 20),
                                label: Text(
                                  'Enable ${authProvider.biometricDisplayText} Login',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Register',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
    );
  }
}

