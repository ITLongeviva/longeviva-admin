import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/utils/error_handler.dart';
import '../models/admin_model.dart';
import '../repositories/admin_repository.dart';

class AdminController {
  final AdminRepository _adminRepository;
  final FirebaseAuth _firebaseAuth;
  final FlutterSecureStorage _secureStorage;
  static const String _adminTokenKey = 'admin_token';
  static const String _adminEmailKey = 'admin_email';
  static const String _adminExpireKey = 'admin_expire';

  AdminController({
    AdminRepository? adminRepository,
    FirebaseAuth? firebaseAuth,
    FlutterSecureStorage? secureStorage,
  }) :
        _adminRepository = adminRepository ?? AdminRepository(),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<Admin?> loginAdmin({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      ErrorHandler.logDebug('Attempting admin login for: $email');

      if (email.isEmpty) {
        throw AppException(
          'Email is required',
          translationKey: 'errors.auth.email_required',
        );
      }
      if (password.isEmpty) {
        throw AppException(
          'Password is required',
          translationKey: 'errors.auth.password_required',
        );
      }

      final admin = await _adminRepository.loginAdmin(email, password);

      if (admin == null) {
        throw AppException(
          'Invalid admin credentials',
          translationKey: 'errors.auth.invalid_admin_credentials',
        );
      }

      if (rememberMe) {
        await _secureStorage.write(key: _adminEmailKey, value: email);
      }

      ErrorHandler.logDebug('Admin logged in successfully: $email');
      return admin;
    } catch (e) {
      ErrorHandler.logError('Admin login error', e);
      rethrow;
    }
  }

  Future<void> logoutAdmin() async {
    try {
      ErrorHandler.logDebug('Logging out admin');
      await _firebaseAuth.signOut();
      await _secureStorage.delete(key: _adminEmailKey);
      ErrorHandler.logDebug('Admin logged out successfully');
    } catch (e) {
      ErrorHandler.logError('Admin logout error', e);
      rethrow;
    }
  }

  Future<Admin?> checkAdminAuth() async {
    try {
      // Check if we have a currently authenticated user
      final currentUser = _firebaseAuth.currentUser;

      if (currentUser != null) {
        // Verify the user has admin claim
        final idTokenResult = await currentUser.getIdTokenResult(true);
        final isAdmin = idTokenResult.claims?['admin'] == true;

        if (isAdmin) {
          // Get admin profile
          final adminData = await _adminRepository.getAdminProfile(currentUser.uid);

          return Admin(
            id: currentUser.uid,
            email: currentUser.email ?? '',
            name: adminData?['name'] ?? 'Admin User',
            password: '',
          );
        }
      }

      return null;
    } catch (e) {
      ErrorHandler.logError('Check admin auth error', e);
      return null;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      ErrorHandler.logDebug('Sending password reset email to admin: $email');

      if (email.isEmpty) {
        throw AppException(
          'Email is required',
          translationKey: 'errors.auth.email_required',
        );
      }

      // Use Firebase Auth to send a password reset email
      await _firebaseAuth.sendPasswordResetEmail(email: email);

      ErrorHandler.logDebug('Password reset email sent to: $email');
    } catch (e) {
      ErrorHandler.logError('Error sending password reset email', e);

      if (e is FirebaseAuthException) {
        // Handle specific Firebase Auth errors
        switch (e.code) {
          case 'user-not-found':
            throw AppException(
              'No admin account found with this email',
              translationKey: 'errors.auth.email_not_found',
            );
          case 'invalid-email':
            throw AppException(
              'Invalid email format',
              translationKey: 'errors.auth.invalid_email',
            );
          default:
            throw AppException(
              'Failed to send password reset email: ${e.message}',
              translationKey: 'errors.auth.password_reset_failed',
            );
        }
      }

      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSignupRequests() async {
    try {
      return await _adminRepository.getSignupRequests();
    } catch (e) {
      ErrorHandler.logError('Error getting signup requests', e);
      rethrow;
    }
  }

  Future<bool> rejectSignupRequest(String requestId) async {
    try {
      return await _adminRepository.rejectSignupRequest(requestId);
    } catch (e) {
      ErrorHandler.logError('Error rejecting signup request', e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      return await _adminRepository.getAllUsers();
    } catch (e) {
      ErrorHandler.logError('Error getting all users', e);
      rethrow;
    }
  }

  Future<bool> deleteUser(String userId, String userType) async {
    try {
      return await _adminRepository.deleteUser(userId, userType);
    } catch (e) {
      ErrorHandler.logError('Error deleting user', e);
      return false;
    }
  }
}