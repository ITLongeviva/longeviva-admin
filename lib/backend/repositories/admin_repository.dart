// lib/backend/repositories/admin_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../shared/utils/error_handler.dart';
import '../models/admin_model.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  AdminRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) :
        _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Login admin using Firebase Authentication with Windows-optimized approach
  Future<Admin?> loginAdmin(String email, String password) async {
    try {
      ErrorHandler.logDebug('Attempting admin login for: $email on platform: ${defaultTargetPlatform.name}');

      // Authenticate with Firebase Auth
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password
      );

      if (userCredential.user == null) {
        ErrorHandler.logWarning('No Firebase user returned for admin login: $email');
        return null;
      }

      final user = userCredential.user!;

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
        await _firebaseAuth.signOut();
        ErrorHandler.logWarning('User is not an admin: $email');
        return null;
      }

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

  /// Windows-optimized admin verification using only Firestore
  Future<Admin?> _verifyAdminInFirestore(String uid, String email) async {
    try {
      ErrorHandler.logDebug('Verifying admin status in Firestore for UID: $uid');

      // Check if user exists in admin_profiles collection
      final adminDoc = await _firestore.collection('admin_profiles').doc(uid).get();

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

      // Alternative: Check in a generic admins collection
      final adminQuery = await _firestore
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

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

      // Check if user has admin role in any user collection
      final doctorQuery = await _firestore
          .collection('doctors')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'ADMIN')
          .limit(1)
          .get();

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

    } catch (e) {
      ErrorHandler.logError('Error verifying admin status in Firestore', e);
      return null;
    }
  }

  /// Handle custom claims with Firestore fallback (for non-Windows platforms)
  Future<Admin?> _handleCustomClaimsWithFirestoreFallback(User user, String email) async {
    try {
      ErrorHandler.logDebug('Checking custom claims for non-Windows platform');

      // Try to get custom claims (this works on mobile/web)
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims ?? {};

      ErrorHandler.logDebug('Retrieved claims: ${claims.keys.toList()}');

      // Check for admin claim
      final isAdmin = claims['admin'] == true;

      if (isAdmin) {
        // Get admin profile from Firestore
        final adminData = await getAdminProfile(user.uid);

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

    } catch (e) {
      ErrorHandler.logError('Error checking custom claims, falling back to Firestore', e);
      return await _verifyAdminInFirestore(user.uid, email);
    }
  }

  /// Get admin profile data from Firestore
  Future<Map<String, dynamic>?> getAdminProfile(String uid) async {
    try {
      final docSnapshot = await _firestore.collection('admin_profiles').doc(uid).get();
      return docSnapshot.exists ? docSnapshot.data() : null;
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

  // ... rest of your existing methods remain the same
  Future<List<Map<String, dynamic>>> getSignupRequests() async {
    try {
      final querySnapshot = await _firestore
          .collection('signup_requests')
          .orderBy('requestedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
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
      await _firestore.collection('signup_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp().toString(),
      });
      return true;
    } catch (e) {
      ErrorHandler.logError('Error rejecting signup request', e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      // Get doctors
      final doctorSnapshot = await _firestore.collection('doctors').get();
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

      // Get patients
      final patientSnapshot = await _firestore.collection('patients').get();
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
      await _firestore.collection(collection).doc(userId).delete();
      return true;
    } catch (e) {
      ErrorHandler.logError('Error deleting user', e);
      return false;
    }
  }
}