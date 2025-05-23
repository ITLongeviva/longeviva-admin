// lib/backend/controllers/admin_controller.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  static const String _adminIdKey = 'admin_id';
  static const String _adminNameKey = 'admin_name';

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

      // Store admin info for Windows platform (since custom claims don't work)
      if (defaultTargetPlatform == TargetPlatform.windows || rememberMe) {
        await _storeAdminInfo(admin, rememberMe);
      }

      ErrorHandler.logDebug('Admin logged in successfully: $email');
      return admin;
    } catch (e) {
      ErrorHandler.logError('Admin login error', e);
      rethrow;
    }
  }

  Future<void> _storeAdminInfo(Admin admin, bool persistent) async {
    try {
      if (persistent) {
        // Store for long-term persistence
        final expireDate = DateTime.now().add(const Duration(days: 7)).toIso8601String();
        await _secureStorage.write(key: _adminExpireKey, value: expireDate);
      }

      // Always store for Windows compatibility
      await _secureStorage.write(key: _adminEmailKey, value: admin.email);
      await _secureStorage.write(key: _adminIdKey, value: admin.id);
      await _secureStorage.write(key: _adminNameKey, value: admin.name);

      ErrorHandler.logDebug('Admin info stored securely');
    } catch (e) {
      ErrorHandler.logError('Error storing admin info', e);
    }
  }

  Future<void> logoutAdmin() async {
    try {
      ErrorHandler.logDebug('Logging out admin');

      // Clear stored credentials
      await _secureStorage.delete(key: _adminEmailKey);
      await _secureStorage.delete(key: _adminIdKey);
      await _secureStorage.delete(key: _adminNameKey);
      await _secureStorage.delete(key: _adminExpireKey);

      // Sign out from Firebase
      await _firebaseAuth.signOut();

      ErrorHandler.logDebug('Admin logged out successfully');
    } catch (e) {
      ErrorHandler.logError('Admin logout error', e);
      rethrow;
    }
  }

  Future<Admin?> checkAdminAuth() async {
    try {
      ErrorHandler.logDebug('Checking admin authentication status');

      // Check if we have a currently authenticated Firebase user
      final currentUser = _firebaseAuth.currentUser;

      if (currentUser != null) {
        ErrorHandler.logDebug('Firebase user found: ${currentUser.email}');

        // For Windows, always verify against stored admin info and Firestore
        if (defaultTargetPlatform == TargetPlatform.windows) {
          return await _checkWindowsAdminAuth(currentUser);
        }

        // For other platforms, try custom claims first
        try {
          final idTokenResult = await currentUser.getIdTokenResult(true);
          final approved = idTokenResult.claims?['admin'] as bool? ?? false;

          if (approved) {
            // Get admin profile
            final adminData = await _adminRepository.getAdminProfile(currentUser.uid);
            if (adminData != null) {
              return Admin(
                id: currentUser.uid,
                email: currentUser.email ?? '',
                name: adminData['name'] ?? 'Admin User',
                password: '',
              );
            }
          }
        } catch (e) {
          ErrorHandler.logWarning('Custom claims check failed, trying Firestore: $e');
        }

        // Fallback to direct Firestore verification
        return await _verifyAdminDirectly(currentUser);
      }

      // No Firebase user, check stored credentials for Windows
      if (defaultTargetPlatform == TargetPlatform.windows) {
        return await _checkStoredAdminAuth();
      }

      ErrorHandler.logDebug('No authenticated user found');
      return null;

    } catch (e) {
      ErrorHandler.logError('Check admin auth error', e);
      return null;
    }
  }

  Future<Admin?> _checkWindowsAdminAuth(User user) async {
    try {
      // Get stored admin info
      final storedEmail = await _secureStorage.read(key: _adminEmailKey);
      final storedId = await _secureStorage.read(key: _adminIdKey);
      final storedName = await _secureStorage.read(key: _adminNameKey);

      if (storedEmail != null && storedId != null && storedName != null) {
        // Verify the stored info matches current user
        if (user.email == storedEmail && user.uid == storedId) {
          ErrorHandler.logDebug('Windows admin auth verified from stored info');
          return Admin(
            id: storedId,
            email: storedEmail,
            name: storedName,
            password: '',
          );
        }
      }

      // If stored info doesn't match or doesn't exist, verify directly
      return await _verifyAdminDirectly(user);
    } catch (e) {
      ErrorHandler.logError('Error checking Windows admin auth', e);
      return null;
    }
  }

  Future<Admin?> _checkStoredAdminAuth() async {
    try {
      final storedEmail = await _secureStorage.read(key: _adminEmailKey);
      final storedId = await _secureStorage.read(key: _adminIdKey);
      final storedName = await _secureStorage.read(key: _adminNameKey);
      final expireStr = await _secureStorage.read(key: _adminExpireKey);

      if (storedEmail == null || storedId == null || storedName == null) {
        ErrorHandler.logDebug('No stored admin credentials found');
        return null;
      }

      // Check if credentials are expired (if expiration was set)
      if (expireStr != null) {
        final expireDate = DateTime.parse(expireStr);
        if (DateTime.now().isAfter(expireDate)) {
          ErrorHandler.logDebug('Stored admin credentials expired');
          await logoutAdmin(); // Clean up expired credentials
          return null;
        }
      }

      ErrorHandler.logDebug('Using stored admin credentials for Windows');
      return Admin(
        id: storedId,
        email: storedEmail,
        name: storedName,
        password: '',
      );
    } catch (e) {
      ErrorHandler.logError('Error checking stored admin auth', e);
      return null;
    }
  }

  Future<Admin?> _verifyAdminDirectly(User user) async {
    try {
      // Direct Firestore verification
      final adminData = await _adminRepository.getAdminProfile(user.uid);
      if (adminData != null) {
        final admin = Admin(
          id: user.uid,
          email: user.email ?? '',
          name: adminData['name'] ?? 'Admin User',
          password: '',
        );

        // Store for future Windows compatibility
        if (defaultTargetPlatform == TargetPlatform.windows) {
          await _storeAdminInfo(admin, false);
        }

        return admin;
      }

      // If not found in admin_profiles, check other collections
      // This is the same logic from the repository
      final firestoreDb = FirebaseFirestore.instance;

      final adminQuery = await firestoreDb
          .collection('admins')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        final adminData = adminQuery.docs.first.data();
        final admin = Admin(
          id: user.uid,
          email: user.email ?? '',
          name: adminData['name'] ?? 'Admin User',
          password: '',
        );

        if (defaultTargetPlatform == TargetPlatform.windows) {
          await _storeAdminInfo(admin, false);
        }

        return admin;
      }

      return null;
    } catch (e) {
      ErrorHandler.logError('Error verifying admin directly', e);
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

  // ... rest of your existing methods remain the same
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