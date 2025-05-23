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

  /// Login admin using Firebase Authentication with improved custom claims handling
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

      // Platform-specific custom claims handling
      final admin = await _handleCustomClaimsWithRetry(user, email);

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

  /// Handle custom claims with retry mechanism for Windows compatibility
  Future<Admin?> _handleCustomClaimsWithRetry(User user, String email) async {
    int maxRetries = 3;
    int retryDelay = 1; // seconds

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        ErrorHandler.logDebug('Checking custom claims, attempt $attempt of $maxRetries');

        // Force refresh the ID token
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
            password: '', // Never store the password
          );
        } else if (attempt < maxRetries) {
          // If not admin and we have retries left, wait and try again
          ErrorHandler.logDebug('Custom claims not found, retrying in ${retryDelay} seconds...');
          await Future.delayed(Duration(seconds: retryDelay));
          retryDelay *= 2; // Exponential backoff
        }

      } catch (e) {
        ErrorHandler.logError('Error checking custom claims on attempt $attempt', e);
        if (attempt == maxRetries) {
          throw e;
        }
        await Future.delayed(Duration(seconds: retryDelay));
        retryDelay *= 2;
      }
    }

    // Fallback: Check Firestore directly for admin status
    return await _checkAdminStatusInFirestore(user.uid, email);
  }

  /// Fallback method to check admin status directly in Firestore
  Future<Admin?> _checkAdminStatusInFirestore(String uid, String email) async {
    try {
      ErrorHandler.logDebug('Checking admin status in Firestore as fallback');

      // Check if user exists in admin_profiles collection
      final adminDoc = await _firestore.collection('admin_profiles').doc(uid).get();

      if (adminDoc.exists && adminDoc.data() != null) {
        final adminData = adminDoc.data()!;

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

        return Admin(
          id: uid,
          email: email,
          name: adminData['name'] ?? 'Admin User',
          password: '',
        );
      }

      ErrorHandler.logWarning('Admin not found in Firestore collections');
      return null;

    } catch (e) {
      ErrorHandler.logError('Error checking admin status in Firestore', e);
      return null;
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

  // ... rest of the existing methods remain the same
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

  /// Create a new admin account (to be used by super admin)
  Future<Admin?> createAdminAccount({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create user with Firebase Auth
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );

      if (userCredential.user == null) {
        throw AppException('Failed to create admin user');
      }

      // Create admin profile in Firestore
      await _firestore.collection('admin_profiles').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return Admin(
        id: userCredential.user!.uid,
        email: email,
        name: name,
        password: '',
      );
    } on FirebaseAuthException catch (e) {
      ErrorHandler.logError('Error creating admin account', e);
      throw AppException(_handleFirebaseAuthError(e), originalError: e);
    } catch (e) {
      ErrorHandler.logError('Error creating admin account', e);
      throw AppException('Error creating admin account: ${e.toString()}', originalError: e);
    }
  }
}