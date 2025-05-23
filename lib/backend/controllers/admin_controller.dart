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

  // Timeout configurations
  static const Duration _authTimeout = Duration(seconds: 10);
  static const Duration _firestoreTimeout = Duration(seconds: 8);

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

      // Add timeout to login operation
      final admin = await Future.any([
        _adminRepository.loginAdmin(email, password),
        Future.delayed(_authTimeout, () => throw TimeoutException('Login timeout', _authTimeout)),
      ]);

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
    } on TimeoutException catch (e) {
      ErrorHandler.logError('Admin login timeout', e);
      throw AppException(
        'Login is taking too long. Please check your connection and try again.',
        translationKey: 'errors.auth.login_timeout',
      );
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

      // Sign out from Firebase with timeout
      await Future.any([
        _firebaseAuth.signOut(),
        Future.delayed(const Duration(seconds: 5), () => null), // Allow timeout for signOut
      ]);

      ErrorHandler.logDebug('Admin logged out successfully');
    } catch (e) {
      ErrorHandler.logError('Admin logout error', e);
      rethrow;
    }
  }

  Future<Admin?> checkAdminAuth() async {
    try {
      ErrorHandler.logDebug('Starting admin auth check with timeout');

      // Wrap the entire auth check in a timeout
      return await Future.any([
        _performAuthCheck(),
        Future.delayed(_authTimeout, () {
          ErrorHandler.logWarning('Auth check timed out after ${_authTimeout.inSeconds} seconds');
          return null;
        }),
      ]);

    } catch (e) {
      ErrorHandler.logError('Check admin auth error', e);
      return null;
    }
  }

  Future<Admin?> _performAuthCheck() async {
    try {
      ErrorHandler.logDebug('Checking admin authentication status');

      // Step 1: Check if we have a currently authenticated Firebase user (with timeout)
      User? currentUser;
      try {
        currentUser = await Future.any([
          Future.value(_firebaseAuth.currentUser),
          Future.delayed(const Duration(seconds: 3), () => null),
        ]);
        ErrorHandler.logDebug('Firebase currentUser check completed: ${currentUser?.email ?? 'null'}');
      } catch (e) {
        ErrorHandler.logWarning('Firebase currentUser check failed: $e');
        currentUser = null;
      }

      if (currentUser != null) {
        ErrorHandler.logDebug('Firebase user found: ${currentUser.email}');

        // For Windows, always verify against stored admin info and Firestore
        if (defaultTargetPlatform == TargetPlatform.windows) {
          return await _checkWindowsAdminAuth(currentUser);
        }

        // For other platforms, try custom claims first
        try {
          final idTokenResult = await Future.any([
            currentUser.getIdTokenResult(true),
            Future.delayed(const Duration(seconds: 5), () => throw TimeoutException('Token timeout')),
          ]);

          final approved = idTokenResult.claims?['admin'] as bool? ?? false;
          ErrorHandler.logDebug('Custom claims checked: admin=$approved');

          if (approved) {
            // Get admin profile with timeout
            final adminData = await Future.any([
              _adminRepository.getAdminProfile(currentUser.uid),
              Future.delayed(_firestoreTimeout, () => null),
            ]);

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
      ErrorHandler.logError('Auth check internal error', e);
      return null;
    }
  }

  Future<Admin?> _checkWindowsAdminAuth(User user) async {
    try {
      ErrorHandler.logDebug('Checking Windows admin auth for: ${user.email}');

      // Get stored admin info with timeout
      final storedData = await Future.any([
        _getStoredAdminData(),
        Future.delayed(const Duration(seconds: 3), () => <String, String?>{
          'email': null, 'id': null, 'name': null
        }),
      ]);

      final storedEmail = storedData['email'];
      final storedId = storedData['id'];
      final storedName = storedData['name'];

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

  Future<Map<String, String?>> _getStoredAdminData() async {
    try {
      final results = await Future.wait([
        _secureStorage.read(key: _adminEmailKey),
        _secureStorage.read(key: _adminIdKey),
        _secureStorage.read(key: _adminNameKey),
      ]);

      return {
        'email': results[0],
        'id': results[1],
        'name': results[2],
      };
    } catch (e) {
      ErrorHandler.logError('Error reading stored admin data', e);
      return {'email': null, 'id': null, 'name': null};
    }
  }

  Future<Admin?> _checkStoredAdminAuth() async {
    try {
      ErrorHandler.logDebug('Checking stored admin credentials');

      final storedData = await _getStoredAdminData();
      final storedEmail = storedData['email'];
      final storedId = storedData['id'];
      final storedName = storedData['name'];

      if (storedEmail == null || storedId == null || storedName == null) {
        ErrorHandler.logDebug('No stored admin credentials found');
        return null;
      }

      // Check if credentials are expired (if expiration was set)
      final expireStr = await _secureStorage.read(key: _adminExpireKey);
      if (expireStr != null) {
        final expireDate = DateTime.parse(expireStr);
        if (DateTime.now().isAfter(expireDate)) {
          ErrorHandler.logDebug('Stored admin credentials expired');
          await logoutAdmin(); // Clean up expired credentials
          return null;
        }
      }

      ErrorHandler.logDebug('Using stored admin credentials');
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
      ErrorHandler.logDebug('Verifying admin directly in Firestore for: ${user.email}');

      // Direct Firestore verification with timeout
      final adminData = await Future.any([
        _adminRepository.getAdminProfile(user.uid),
        Future.delayed(_firestoreTimeout, () => null),
      ]);

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

        ErrorHandler.logDebug('Admin verified directly from Firestore');
        return admin;
      }

      // If not found in admin_profiles, check other collections with timeout
      final firestoreDb = FirebaseFirestore.instance;

      final adminQuery = await Future.any([
        firestoreDb
            .collection('admins')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get(),
        Future.delayed(_firestoreTimeout, () => throw TimeoutException('Firestore timeout')),
      ]);

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

        ErrorHandler.logDebug('Admin verified from admins collection');
        return admin;
      }

      ErrorHandler.logDebug('Admin not found in any collection');
      return null;
    } on TimeoutException catch (e) {
      ErrorHandler.logError('Firestore verification timeout', e);
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

      // Use Firebase Auth to send a password reset email with timeout
      await Future.any([
        _firebaseAuth.sendPasswordResetEmail(email: email),
        Future.delayed(const Duration(seconds: 10), () => throw TimeoutException('Password reset timeout')),
      ]);

      ErrorHandler.logDebug('Password reset email sent to: $email');
    } on TimeoutException catch (e) {
      ErrorHandler.logError('Password reset timeout', e);
      throw AppException(
        'Password reset is taking too long. Please try again.',
        translationKey: 'errors.auth.password_reset_timeout',
      );
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

class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  TimeoutException(this.message, [this.timeout = const Duration(seconds: 10)]);

  @override
  String toString() => 'TimeoutException: $message (timeout: ${timeout.inSeconds}s)';
}