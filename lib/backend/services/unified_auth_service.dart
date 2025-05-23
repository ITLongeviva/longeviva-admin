// lib/backend/services/unified_auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_model.dart';
import '../../shared/utils/error_handler.dart';

class UnifiedAuthService {
  static final UnifiedAuthService _instance = UnifiedAuthService._internal();
  factory UnifiedAuthService() => _instance;
  UnifiedAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Session management
  Admin? _currentAdmin;
  DateTime? _lastAuthTime;

  // Storage keys
  static const String _adminDataKey = 'admin_session_data';
  static const String _sessionExpireKey = 'session_expire_time';

  /// Get current authenticated admin
  Admin? get currentAdmin => _currentAdmin;

  /// Check if session is valid
  bool get hasValidSession {
    if (_currentAdmin == null || _lastAuthTime == null) return false;

    final sessionAge = DateTime.now().difference(_lastAuthTime!);
    return sessionAge.inHours < 8; // 8-hour session validity
  }

  /// Login with email and password
  Future<AuthResult> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      ErrorHandler.logDebug('UnifiedAuthService: Starting login for $email');

      // Clear any existing session
      await _clearSession();

      // Step 1: Firebase Authentication
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw AuthException('No user returned from Firebase Auth');
      }

      final user = userCredential.user!;
      ErrorHandler.logDebug('Firebase auth successful for: ${user.email}');

      // Step 2: Verify admin status
      final admin = await _verifyAdminStatus(user, email);

      if (admin == null) {
        await _auth.signOut();
        throw AuthException('User is not authorized as admin');
      }

      // Step 3: Set up session
      await _establishSession(admin, rememberMe);

      return AuthResult.success(admin);

    } on FirebaseAuthException catch (e) {
      ErrorHandler.logError('Firebase Auth error', e);
      return AuthResult.failure(_mapFirebaseError(e));
    } catch (e) {
      ErrorHandler.logError('Login error', e);
      return AuthResult.failure(e.toString());
    }
  }

  /// Check current authentication status
  Future<AuthResult> checkAuthStatus() async {
    try {
      ErrorHandler.logDebug('UnifiedAuthService: Checking auth status');

      // Step 1: Check cached session
      if (hasValidSession) {
        ErrorHandler.logDebug('Using valid cached session');
        return AuthResult.success(_currentAdmin!);
      }

      // Step 2: Check Firebase current user
      final user = _auth.currentUser;
      if (user == null) {
        // Check stored session
        final storedAdmin = await _loadStoredSession();
        if (storedAdmin != null) {
          return AuthResult.success(storedAdmin);
        }
        return AuthResult.unauthenticated();
      }

      // Step 3: Verify admin status
      final admin = await _verifyAdminStatus(user, user.email ?? '');

      if (admin == null) {
        await logout();
        return AuthResult.unauthenticated();
      }

      // Step 4: Update session
      await _establishSession(admin, false);

      return AuthResult.success(admin);

    } catch (e) {
      ErrorHandler.logError('Auth check error', e);
      return AuthResult.failure(e.toString());
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      ErrorHandler.logDebug('UnifiedAuthService: Logging out');

      await _clearSession();
      await _auth.signOut();

      ErrorHandler.logDebug('Logout completed');
    } catch (e) {
      ErrorHandler.logError('Logout error', e);
      // Don't throw - always clear local session
      await _clearSession();
    }
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      ErrorHandler.logDebug('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  /// Verify if user is admin
  Future<Admin?> _verifyAdminStatus(User user, String email) async {
    try {
      ErrorHandler.logDebug('Verifying admin status for: $email');

      // Method 1: Check admin_profiles collection
      final adminProfileDoc = await _firestore
          .collection('admin_profiles')
          .doc(user.uid)
          .get();

      if (adminProfileDoc.exists && adminProfileDoc.data() != null) {
        final data = adminProfileDoc.data()!;
        return Admin(
          id: user.uid,
          email: email,
          name: data['name'] ?? 'Admin User',
          password: '', // We don't store passwords
        );
      }

      // Method 2: Check admins collection
      final adminQuery = await _firestore
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        final data = adminQuery.docs.first.data();
        return Admin(
          id: user.uid,
          email: email,
          name: data['name'] ?? 'Admin User',
          password: '',
        );
      }

      // Method 3: Check custom claims (for non-Windows platforms)
      if (defaultTargetPlatform != TargetPlatform.windows) {
        try {
          final idToken = await user.getIdTokenResult(true);
          final isAdmin = idToken.claims?['admin'] == true;

          if (isAdmin) {
            return Admin(
              id: user.uid,
              email: email,
              name: user.displayName ?? 'Admin User',
              password: '',
            );
          }
        } catch (e) {
          ErrorHandler.logWarning('Custom claims check failed: $e');
        }
      }

      ErrorHandler.logWarning('User is not an admin: $email');
      return null;

    } catch (e) {
      ErrorHandler.logError('Error verifying admin status', e);
      return null;
    }
  }

  /// Establish authenticated session
  Future<void> _establishSession(Admin admin, bool rememberMe) async {
    _currentAdmin = admin;
    _lastAuthTime = DateTime.now();

    if (rememberMe) {
      await _storeSession(admin);
    }

    ErrorHandler.logDebug('Session established for: ${admin.email}');
  }

  /// Store session for persistence
  Future<void> _storeSession(Admin admin) async {
    try {
      final expireTime = DateTime.now().add(const Duration(days: 7));

      // Store admin data as simple string format: "id|||email|||name"
      final adminDataStr = '${admin.id}|||${admin.email}|||${admin.name}';

      await _storage.write(key: _adminDataKey, value: adminDataStr);
      await _storage.write(key: _sessionExpireKey, value: expireTime.toIso8601String());

      ErrorHandler.logDebug('Session stored for: ${admin.email}');
    } catch (e) {
      ErrorHandler.logError('Error storing session', e);
    }
  }

  /// Load stored session
  Future<Admin?> _loadStoredSession() async {
    try {
      final adminDataStr = await _storage.read(key: _adminDataKey);
      final expireTimeStr = await _storage.read(key: _sessionExpireKey);

      if (adminDataStr == null || expireTimeStr == null) {
        return null;
      }

      final expireTime = DateTime.parse(expireTimeStr);
      if (DateTime.now().isAfter(expireTime)) {
        await _clearSession();
        return null;
      }

      // Parse stored admin data (you'll need to implement proper JSON parsing)
      // This is simplified - implement proper JSON parsing based on your Admin model
      final adminData = _parseAdminData(adminDataStr);

      if (adminData != null) {
        _currentAdmin = adminData;
        _lastAuthTime = DateTime.now();
        ErrorHandler.logDebug('Loaded stored session for: ${adminData.email}');
      }

      return adminData;
    } catch (e) {
      ErrorHandler.logError('Error loading stored session', e);
      await _clearSession();
      return null;
    }
  }

  /// Parse admin data from stored string
  Admin? _parseAdminData(String dataStr) {
    try {
      // For this simple case, we'll store as comma-separated values
      // Format: "id,email,name"
      final parts = dataStr.split('|||');
      if (parts.length >= 3) {
        return Admin(
          id: parts[0],
          email: parts[1],
          name: parts[2],
          password: '', // We don't store passwords
        );
      }
      return null;
    } catch (e) {
      ErrorHandler.logError('Error parsing admin data', e);
      return null;
    }
  }

  /// Clear session data
  Future<void> _clearSession() async {
    _currentAdmin = null;
    _lastAuthTime = null;

    try {
      await _storage.delete(key: _adminDataKey);
      await _storage.delete(key: _sessionExpireKey);
    } catch (e) {
      ErrorHandler.logError('Error clearing session storage', e);
    }
  }

  /// Map Firebase Auth errors to user-friendly messages
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No admin account found with this email address.';
      case 'wrong-password':
        return 'Invalid password. Please try again.';
      case 'invalid-credential':
        return 'Invalid login credentials. Please check your email and password.';
      case 'user-disabled':
        return 'This admin account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Login failed: ${e.message ?? 'Unknown error'}';
    }
  }
}

/// Authentication result wrapper
class AuthResult {
  final bool isSuccess;
  final Admin? admin;
  final String? error;
  final AuthStatus status;

  AuthResult._({
    required this.isSuccess,
    this.admin,
    this.error,
    required this.status,
  });

  factory AuthResult.success(Admin admin) => AuthResult._(
    isSuccess: true,
    admin: admin,
    status: AuthStatus.authenticated,
  );

  factory AuthResult.failure(String error) => AuthResult._(
    isSuccess: false,
    error: error,
    status: AuthStatus.error,
  );

  factory AuthResult.unauthenticated() => AuthResult._(
    isSuccess: false,
    status: AuthStatus.unauthenticated,
  );
}

enum AuthStatus {
  authenticated,
  unauthenticated,
  error,
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}