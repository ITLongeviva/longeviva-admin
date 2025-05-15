import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/utils/error_handler.dart';
import '../models/admin_model.dart';

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Admin?> loginAdmin(String email, String password) async {
    try {
      // Query Firestore for an admin with matching email
      final querySnapshot = await _firestore
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        ErrorHandler.logWarning('No admin found with email: $email');
        return null;
      }

      final adminData = querySnapshot.docs.first.data();
      final adminId = querySnapshot.docs.first.id;

      // Check if password matches
      if (adminData['password'] != password) {
        ErrorHandler.logWarning('Invalid password for admin: $email');
        return null;
      }

      // Create and return the admin model
      return Admin.fromJson({
        ...adminData,
        'id': adminId, // Include the document ID
      });
    } catch (e) {
      ErrorHandler.logError('Error during admin login', e);
      throw AppException(
          'Error during admin login: ${e.toString()}',
          originalError: e
      );
    }
  }

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

      // Combine and return all users
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