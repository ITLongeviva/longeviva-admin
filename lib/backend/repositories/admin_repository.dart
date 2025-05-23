// lib/backend/repositories/admin_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../shared/utils/error_handler.dart';
import '../models/admin_model.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  // Timeout configurations
  static const Duration _authTimeout = Duration(seconds: 6);
  static const Duration _firestoreTimeout = Duration(seconds: 5);

  AdminRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) :
        _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Login admin using Firebase Authentication with Windows-optimized approach
  Future<Admin?> loginAdmin(String email, String password) async {
    try {
      ErrorHandler.logDebug('Repository: Attempting admin login for: $email on platform: ${defaultTargetPlatform.name}');

      // Authenticate with Firebase Auth with timeout
      final userCredential = await Future.any([
        _firebaseAuth.signInWithEmailAndPassword(email: email, password: password),
        Future.delayed(_authTimeout, () => throw TimeoutException('Firebase auth timeout', _authTimeout)),
      ]);

      if (userCredential.user == null) {
        ErrorHandler.logWarning('No Firebase user returned for admin login: $email');
        return null;
      }

      final user = userCredential.user!;
      ErrorHandler.logDebug('Firebase auth successful for: $email, UID: ${user.uid}');

      // For Windows, skip custom claims and go directly to Firestore verification
      if (defaultTargetPlatform == TargetPlatform.windows) {
        ErrorHandler.logDebug('Windows platform detected, using Firestore-only admin verification');
        return await _verifyAdminInFirestore(user.uid, email);
      }

      // For other platforms, try custom claims first, then fallback to Firestore
      final admin = await _handleCustomClaimsWithFirestoreFallback(user, email);

      if (admin != null) {
        ErrorHandler.logDebug('Admin authentication successful for: $email');
        return admin;
      } else {
        // Sign out if not admin
        await _signOutWithTimeout();
        ErrorHandler.logWarning('User is not an admin: $email');
        return null;
      }

    } on TimeoutException catch (e) {
      ErrorHandler.logError('Admin login timeout', e);
      throw AppException(
          'Login is taking too long. Please check your connection and try again.',
          originalError: e
      );
    } on FirebaseAuthException catch (e) {
      ErrorHandler.logError('Firebase Auth error during admin login', e);
      throw AppException(
          _handleFirebaseAuthError(e),
          originalError: e
      );
    } catch (e) {
      ErrorHandler.logError('Error during admin login', e);
      throw AppException(
          'Error during admin login: ${e.toString()}',
          originalError: e
      );
    }
  }

  Future<void> _signOutWithTimeout() async {
    try {
      await Future.any([
        _firebaseAuth.signOut(),
        Future.delayed(const Duration(seconds: 5), () => null),
      ]);
    } catch (e) {
      ErrorHandler.logWarning('Sign out timeout or error: $e');
    }
  }

  /// Windows-optimized admin verification using only Firestore
  Future<Admin?> _verifyAdminInFirestore(String uid, String email) async {
    try {
      ErrorHandler.logDebug('Verifying admin status in Firestore for UID: $uid');

      // Check if user exists in admin_profiles collection with timeout
      final adminDoc = await Future.any([
        _firestore.collection('admin_profiles').doc(uid).get(),
        Future.delayed(_firestoreTimeout, () => throw TimeoutException('Admin profile timeout')),
      ]);

      if (adminDoc.exists && adminDoc.data() != null) {
        final adminData = adminDoc.data()!;
        ErrorHandler.logDebug('Found admin in admin_profiles collection');

        return Admin(
          id: uid,
          email: email,
          name: adminData['name'] ?? 'Admin User',
          password: '',
        );
      }

      // Alternative: Check in a generic admins collection with timeout
      final adminQuery = await Future.any([
        _firestore
            .collection('admins')
            .where('email', isEqualTo: email)
            .limit(1)
            .get(),
        Future.delayed(_firestoreTimeout, () => throw TimeoutException('Admins collection timeout')),
      ]);

      if (adminQuery.docs.isNotEmpty) {
        final adminData = adminQuery.docs.first.data();
        ErrorHandler.logDebug('Found admin in admins collection');

        return Admin(
          id: uid,
          email: email,
          name: adminData['name'] ?? 'Admin User',
          password: '',
        );
      }

      // Check if user has admin role in any user collection with timeout
      final doctorQuery = await Future.any([
        _firestore
            .collection('doctors')
            .where('email', isEqualTo: email)
            .where('role', isEqualTo: 'ADMIN')
            .limit(1)
            .get(),
        Future.delayed(_firestoreTimeout, () => throw TimeoutException('Doctors collection timeout')),
      ]);

      if (doctorQuery.docs.isNotEmpty) {
        final doctorData = doctorQuery.docs.first.data();
        ErrorHandler.logDebug('Found admin role in doctors collection');

        return Admin(
          id: uid,
          email: email,
          name: doctorData['name'] ?? 'Admin User',
          password: '',
        );
      }

      ErrorHandler.logWarning('Admin not found in any Firestore collections for: $email');
      return null;

    } on TimeoutException catch (e) {
      ErrorHandler.logError('Firestore verification timeout', e);
      return null;
    } catch (e) {
      ErrorHandler.logError('Error verifying admin status in Firestore', e);
      return null;
    }
  }

  /// Handle custom claims with Firestore fallback (for non-Windows platforms)
  Future<Admin?> _handleCustomClaimsWithFirestoreFallback(User user, String email) async {
    try {
      ErrorHandler.logDebug('Checking custom claims for non-Windows platform');

      // Try to get custom claims (this works on mobile/web) with timeout
      final idTokenResult = await Future.any([
        user.getIdTokenResult(true),
        Future.delayed(const Duration(seconds: 8), () => throw TimeoutException('Token claims timeout')),
      ]);

      final claims = idTokenResult.claims ?? {};
      ErrorHandler.logDebug('Retrieved claims: ${claims.keys.toList()}');

      // Check for admin claim
      final isAdmin = claims['admin'] == true;

      if (isAdmin) {
        // Get admin profile from Firestore with timeout
        final adminData = await Future.any([
          getAdminProfile(user.uid),
          Future.delayed(_firestoreTimeout, () => null),
        ]);

        return Admin(
          id: user.uid,
          email: email,
          name: adminData?['name'] ?? 'Admin User',
          password: '',
        );
      }

      // Fallback to Firestore verification
      ErrorHandler.logDebug('Custom claims not found, falling back to Firestore verification');
      return await _verifyAdminInFirestore(user.uid, email);

    } on TimeoutException catch (e) {
      ErrorHandler.logError('Custom claims check timeout, falling back to Firestore', e);
      return await _verifyAdminInFirestore(user.uid, email);
    } catch (e) {
      ErrorHandler.logError('Error checking custom claims, falling back to Firestore', e);
      return await _verifyAdminInFirestore(user.uid, email);
    }
  }

  /// Get admin profile data from Firestore
  Future<Map<String, dynamic>?> getAdminProfile(String uid) async {
    try {
      final docSnapshot = await Future.any([
        _firestore.collection('admin_profiles').doc(uid).get(),
        Future.delayed(_firestoreTimeout, () => throw TimeoutException('Admin profile timeout')),
      ]);
      return docSnapshot.exists ? docSnapshot.data() : null;
    } on TimeoutException catch (e) {
      ErrorHandler.logWarning('Admin profile fetch timeout: $e');
      return null;
    } catch (e) {
      ErrorHandler.logWarning('Error fetching admin profile: $e');
      return null;
    }
  }

  /// Handle Firebase Auth error messages for better user feedback
  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No admin account found with this email.';
      case 'wrong-password':
        return 'Invalid password. Please try again.';
      case 'invalid-credential':
        return 'Invalid admin credentials.';
      case 'user-disabled':
        return 'This admin account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // ... rest of your existing methods with timeout handling
  Future<List<Map<String, dynamic>>> getSignupRequests() async {
    try {
      final querySnapshot = await Future.any([
        _firestore
            .collection('signup_requests')
            .orderBy('requestedAt', descending: true)
            .get(),
        Future.delayed(_firestoreTimeout, () => throw TimeoutException('Signup requests timeout')),
      ]);

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } on TimeoutException catch (e) {
      ErrorHandler.logError('Signup requests fetch timeout', e);
      throw AppException(
          'Loading signup requests is taking too long. Please try again.',
          originalError: e
      );
    } catch (e) {
      ErrorHandler.logError('Error fetching signup requests', e);
      throw AppException(
          'Error fetching signup requests: ${e.toString()}',
          originalError: e
      );
    }
  }

  Future<bool> rejectSignupRequest(String requestId) async {
    try {
      await Future.any([
        _firestore.collection('signup_requests').doc(requestId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp().toString(),
        }),
        Future.delayed(_firestoreTimeout, () => throw TimeoutException('Reject request timeout')),
      ]);
      return true;
    } on TimeoutException catch (e) {
      ErrorHandler.logError('Reject signup request timeout', e);
      return false;
    } catch (e) {
      ErrorHandler.logError('Error rejecting signup request', e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      // Get doctors with timeout
      final doctorSnapshot = await Future.any([
        _firestore.collection('doctors').get(),
        Future.delayed(_firestoreTimeout, () => throw TimeoutException('Doctors fetch timeout')),
      ]);

      final doctors = doctorSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': 'doctor',
          'role': data['role'] ?? 'DOCTOR',
          'name': data['name'] ?? '',
          'surname': data['surname'] ?? '',
          'email': data['email'] ?? '',
          'specialty': data['specialty'] ?? '',
          'createdAt': data['createdAt'],
        };
      }).toList();

      // Get patients with timeout
      final patientSnapshot = await Future.any([
        _firestore.collection('patients').get(),
        Future.delayed(_firestoreTimeout, () => throw TimeoutException('Patients fetch timeout')),
      ]);

      final patients = patientSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': 'patient',
          'name': data['name'] ?? '',
          'surname': data['surname'] ?? '',
          'email': data['email'] ?? '',
          'createdAt': data['createdAt'],
        };
      }).toList();

      return [...doctors, ...patients];
    } on TimeoutException catch (e) {
      ErrorHandler.logError('Get all users timeout', e);
      throw AppException(
          'Loading users is taking too long. Please try again.',
          originalError: e
      );
    } catch (e) {
      ErrorHandler.logError('Error fetching all users', e);
      throw AppException(
          'Error fetching all users: ${e.toString()}',
          originalError: e
      );
    }
  }

  Future<bool> deleteUser(String userId, String userType) async {
    try {
      String collection = userType == 'doctor' ? 'doctors' : 'patients';
      await Future.any([
        _firestore.collection(collection).doc(userId).delete(),
        Future.delayed(_firestoreTimeout, () => throw TimeoutException('Delete user timeout')),
      ]);
      return true;
    } on TimeoutException catch (e) {
      ErrorHandler.logError('Delete user timeout', e);
      return false;
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