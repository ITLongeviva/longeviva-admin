import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../shared/utils/error_handler.dart';
import '../models/doctor/doctor_model.dart' as app_models;

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Singleton pattern
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  // Key constants for secure storage
  static const String _tokenKey = 'auth_token';
  static const String _emailKey = 'auth_email';
  static const String _expireKey = 'auth_expire';
  static const String _currentUserIdKey = 'current_user_id';

  // Get current Firebase user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<app_models.Doctor?> signInWithEmailPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      ErrorHandler.logDebug('Attempting login for: $email');

      // Validate email and password
      if (email.isEmpty) {
        throw ArgumentError('Email is required');
      }
      if (password.isEmpty) {
        throw ArgumentError('Password is required');
      }

      // Authenticate with Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Authentication failed: No user returned');
      }

      // Get the custom claims to check if user is approved
      final idTokenResult = await user.getIdTokenResult(true);
      final approved = idTokenResult.claims?['approved'] as bool? ?? false;

      if (!approved) {
        // Sign out if not approved
        await _auth.signOut();
        throw Exception('Your account is pending approval. Please wait for administrator approval.');
      }

      // Get the doctor document from Firestore
      final doctorDoc = await _getDoctorDocumentByEmail(email);
      if (doctorDoc == null) {
        await _auth.signOut();
        throw Exception('Doctor profile not found. Please contact support.');
      }

      // Check for required password change
      final requiresPasswordChange = doctorDoc['requiredPasswordChange'] as bool? ?? false;

      // Create Doctor object
      final doctor = app_models.Doctor.fromJson({
        ...doctorDoc,
        'id': doctorDoc['id'] ?? '', // Ensure ID is present
      });

      // Store the user ID for potential key recovery
      await _secureStorage.write(key: _currentUserIdKey, value: doctor.id);
      await _secureStorage.write(key: 'current_user_email', value: email);

      if (rememberMe) {
        // Store credentials securely if "remember me" is checked
        final expireDate = DateTime.now().add(const Duration(days: 1)).toIso8601String();
        final token = await user.getIdToken();

        await _secureStorage.write(key: _emailKey, value: email);
        await _secureStorage.write(key: _tokenKey, value: token);
        await _secureStorage.write(key: _expireKey, value: expireDate);

        ErrorHandler.logDebug('Credentials stored for: $email until $expireDate');
      }

      return doctor;
    } on FirebaseAuthException catch (e) {
      ErrorHandler.logError('Firebase Auth error during login', e);
      String errorMessage;

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Email not found. Please check your email address or create an account.';
          break;
        case 'wrong-password':
          errorMessage = 'Invalid password. Please check your password and try again.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid credentials. Please check your email and password.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Please contact support.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many login attempts. Please try again later.';
          break;
        default:
          errorMessage = 'Authentication failed: ${e.message}';
      }

      throw ArgumentError(errorMessage);
    } catch (e) {
      ErrorHandler.logError('Generic error during login', e);
      if (e is ArgumentError) {
        rethrow;
      }
      throw ArgumentError('Login failed: ${e.toString()}');
    }
  }

  // Sign out user
  Future<void> signOut() async {
    try {
      ErrorHandler.logDebug('Logging out user');

      // Clear stored credentials
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _expireKey);

      // Sign out from Firebase
      await _auth.signOut();

      ErrorHandler.logDebug('User logged out successfully');
    } catch (e) {
      ErrorHandler.logError('Logout error', e);
      rethrow;
    }
  }

  // Create a new user account (used by admin when approving signup request)
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required bool requirePasswordChange,
  }) async {
    try {
      ErrorHandler.logDebug('Creating Firebase Auth user for email: $email');
      ErrorHandler.logDebug('Password length: ${password.length}');
      ErrorHandler.logDebug('Display name: $displayName');

      // Validate input parameters
      if (email.isEmpty || email.trim().isEmpty) {
        throw ArgumentError('Email cannot be empty');
      }

      if (password.isEmpty || password.length < 6) {
        throw ArgumentError('Password must be at least 6 characters long');
      }

      // Validate email format
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email.trim())) {
        throw ArgumentError('Invalid email format: $email');
      }

      ErrorHandler.logDebug('Input validation passed');

      // Create the user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password
      );

      final user = userCredential.user;
      if (user != null) {
        ErrorHandler.logDebug('Firebase user created successfully: ${user.uid}');

        // Set display name
        await user.updateDisplayName(displayName);
        ErrorHandler.logDebug('Display name updated successfully');

        // Get a fresh ID token to work with custom claims
        await user.getIdToken(true);
        ErrorHandler.logDebug('ID token refreshed successfully');
      } else {
        throw Exception('User creation returned null');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      ErrorHandler.logError('Firebase Auth Exception during user creation', e);
      ErrorHandler.logDebug('Firebase Auth Error Code: ${e.code}');
      ErrorHandler.logDebug('Firebase Auth Error Message: ${e.message}');

      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Email already in use: $email';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format: $email';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Must be at least 6 characters with good complexity.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password authentication is not enabled in Firebase Console';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error occurred. Please check your internet connection.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        default:
          errorMessage = 'Error creating account: ${e.message ?? e.code}';
      }

      throw Exception(errorMessage);
    } catch (e) {
      ErrorHandler.logError('Unexpected error creating account', e);
      ErrorHandler.logDebug('Error type: ${e.runtimeType}');
      ErrorHandler.logDebug('Error details: $e');
      throw Exception('Error creating account: ${e.toString()}');
    }
  }

  // Check if a user is already authenticated
  Future<app_models.Doctor?> checkAuth() async {
    try {
      // First check if we have a current Firebase user
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        // Check if the user is approved via custom claims
        final idTokenResult = await currentUser.getIdTokenResult(true);
        final approved = idTokenResult.claims?['approved'] as bool? ?? false;

        if (!approved) {
          await _auth.signOut();
          return null;
        }

        // Get the doctor profile
        final email = currentUser.email;
        if (email != null) {
          final doctorDoc = await _getDoctorDocumentByEmail(email);
          if (doctorDoc != null) {
            return app_models.Doctor.fromJson({
              ...doctorDoc,
              'id': doctorDoc['id'] ?? '',
            });
          }
        }

        // If we have a Firebase user but no doctor profile, something is wrong
        await _auth.signOut();
        return null;
      }

      // If no current user, check for stored credentials
      final email = await _secureStorage.read(key: _emailKey);
      final token = await _secureStorage.read(key: _tokenKey);
      final expireStr = await _secureStorage.read(key: _expireKey);

      if (email == null || token == null || expireStr == null) {
        ErrorHandler.logDebug('No stored credentials found');
        return null;
      }

      // Check if credentials are expired
      final expireDate = DateTime.parse(expireStr);
      if (DateTime.now().isAfter(expireDate)) {
        ErrorHandler.logDebug('Stored credentials expired');
        await signOut(); // Clean up expired credentials
        return null;
      }

      // Try to sign in with the stored token
      try {
        // Sign in with custom token is not directly supported in client SDKs
        // Instead, we'll try to get the user from Firestore based on email
        final doctorDoc = await _getDoctorDocumentByEmail(email);
        if (doctorDoc != null) {
          // Re-authenticate with Firebase
          await _auth.signInWithEmailAndPassword(
              email: email,
              password: doctorDoc['password'] ?? ''
          );

          ErrorHandler.logDebug('Re-authenticated user from stored credentials');
          return app_models.Doctor.fromJson({
            ...doctorDoc,
            'id': doctorDoc['id'] ?? '',
          });
        }
      } catch (e) {
        ErrorHandler.logWarning('Failed to re-authenticate with stored credentials: $e');
        await signOut();
        return null;
      }

      return null;
    } catch (e) {
      ErrorHandler.logError('Check auth error', e);
      return null;
    }
  }

  // Change password after first login
  Future<bool> changePasswordAfterFirstLogin(String doctorId, String newPassword) async {
    try {
      ErrorHandler.logDebug('Changing password after first login for user ID: $doctorId');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        ErrorHandler.logWarning('No current user found when updating password');
        return false;
      }

      // Update password in Firebase Auth
      await currentUser.updatePassword(newPassword);

      // Update password in Firestore and reset requiredPasswordChange flag
      await _firestore.collection('doctors').doc(doctorId).update({
        'requiredPasswordChange': false,
      });

      ErrorHandler.logDebug('Password changed successfully and requiredPasswordChange flag updated');
      return true;
    } catch (e) {
      ErrorHandler.logError('Error changing password after first login', e);
      throw AppException('Failed to change password: ${e.toString()}');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Use the basic version without ActionCodeSettings
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        // Remove the ActionCodeSettings parameter
      );

      ErrorHandler.logDebug('Password reset email sent to: $email');
    } catch (e) {
      ErrorHandler.logError('Error sending password reset email', e);

      // Format the error for better user feedback
      String errorMessage;
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No user found with this email address.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is invalid.';
            break;
          default:
            errorMessage = 'Failed to send password reset email: ${e.message}';
        }
        throw Exception(errorMessage);
      } else {
        throw Exception('Failed to send password reset email: ${e.toString()}');
      }
    }
  }

  // Helper method to get a doctor document by email
  Future<Map<String, dynamic>?> _getDoctorDocumentByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('doctors')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doctorData = querySnapshot.docs.first.data();
      final doctorId = querySnapshot.docs.first.id;

      return {
        ...doctorData,
        'id': doctorId,
      };
    } catch (e) {
      ErrorHandler.logError('Error retrieving doctor by email', e);
      return null;
    }
  }

  // Get the current user's ID token
  Future<String?> getIdToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      ErrorHandler.logError('Error getting ID token', e);
      return null;
    }
  }
}