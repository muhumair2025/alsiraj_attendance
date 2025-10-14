import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Sign in with email and password
  Future<UserModel?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        final user = await getUserData(credential.user!.uid);
        
        // Check if user account is active
        if (user != null && !user.isActive) {
          await _auth.signOut();
          throw 'Your account has been deactivated. Please contact the administrator.';
        }
        
        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('deactivated')) {
        rethrow;
      }
      throw 'An error occurred. Please try again.';
    }
  }

  // Register with email and password
  Future<UserModel?> register(String email, String password, String name) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user document with default 'student' role
        final user = UserModel(
          uid: credential.user!.uid,
          email: email,
          name: name,
          role: 'student',
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(user.toMap());
        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An error occurred. Please try again.';
    }
  }

  // Create admin or teacher account (for initial setup)
  Future<UserModel?> createSpecialAccount(
    String email, 
    String password, 
    String name, 
    String role,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = UserModel(
          uid: credential.user!.uid,
          email: email,
          name: name,
          role: role, // 'admin' or 'teacher'
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(user.toMap());
        
        // Sign out after creating special account
        await _auth.signOut();
        
        return user;
      }
      return null;
    } catch (e) {
      print('Error creating special account: $e');
      return null;
    }
  }

  // Create user by admin (without logging out admin)
  Future<void> createUserByAdmin({
    required String email,
    required String password,
    required String name,
    required String role,
    String? courseId, // Optional single course ID for backward compatibility
    List<String>? courseIds, // Optional multiple course IDs for students
  }) async {
    try {
      print('Creating new user: $email with role: $role');
      
      // Import at top: import 'package:firebase_core/firebase_core.dart';
      // Create a secondary Firebase app instance for user creation
      FirebaseApp secondaryApp;
      
      try {
        // Try to get existing secondary app
        secondaryApp = Firebase.app('SecondaryApp');
      } catch (e) {
        // Create secondary app if it doesn't exist
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
      }
      
      // Create auth instance for secondary app
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      
      // Create the new user using secondary auth (won't affect admin session)
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Determine which course IDs to use
        List<String> finalCourseIds = [];
        if (courseIds != null && courseIds.isNotEmpty) {
          finalCourseIds = courseIds;
        } else if (courseId != null && courseId.isNotEmpty) {
          finalCourseIds = [courseId]; // Backward compatibility
        }

        // Create user document in Firestore
        final user = UserModel(
          uid: credential.user!.uid,
          email: email,
          name: name,
          role: role,
          createdAt: DateTime.now(),
          selectedCourseIds: finalCourseIds, // Set courses for students
        );

        await _firestore.collection('users').doc(user.uid).set(user.toMap());
        print('User document created for: ${user.email}');
        
        // Sign out from secondary auth (doesn't affect admin)
        await secondaryAuth.signOut();
        print('New user signed out from secondary app');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'This email is already registered in Firebase Authentication. If you deleted this user, the email still exists in Auth. Please use a different email or contact support to fully remove the user.';
      }
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Error creating user: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Check if admin/teacher accounts exist
  Future<bool> checkIfDefaultAccountsExist() async {
    try {
      final adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();
      
      return adminQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Initialize default accounts
  Future<void> initializeDefaultAccounts() async {
    try {
      final exists = await checkIfDefaultAccountsExist();
      if (!exists) {
        // Create admin account
        await createSpecialAccount(
          'admin@alsiraj.com',
          'admin123',
          'Admin User',
          'admin',
        );

        // Create teacher account
        await createSpecialAccount(
          'teacher@alsiraj.com',
          'teacher123',
          'Teacher User',
          'teacher',
        );
      }
    } catch (e) {
      print('Error initializing default accounts: $e');
    }
  }

  // Update user profile name
  Future<void> updateUserName(String uid, String newName) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'name': newName,
      });
    } catch (e) {
      throw 'Failed to update name: $e';
    }
  }


  // Change password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No user logged in';

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to change password: $e';
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'invalid-email':
        return 'The email address is invalid.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}

