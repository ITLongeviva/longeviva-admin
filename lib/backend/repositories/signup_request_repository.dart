import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/utils/error_handler.dart';
import '../models/doctor/sign_up_data.dart';
import '../models/signup_request_model.dart';

class SignupRequestRepository {
  final FirebaseFirestore _firestore;
  static const String _collectionPath = 'signup_requests';

  SignupRequestRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get all signup requests
  Future<List<SignupRequest>> getAllSignupRequests() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionPath)
          .orderBy('requestedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return SignupRequest.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      ErrorHandler.logError('Error fetching signup requests', e);
      throw AppException(
          'Error fetching signup requests: ${e.toString()}',
          originalError: e
      );
    }
  }

  /// Get signup requests filtered by status
  Future<List<SignupRequest>> getSignupRequestsByStatus(String status) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionPath)
          .where('status', isEqualTo: status)
          .orderBy('requestedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return SignupRequest.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      ErrorHandler.logError('Error fetching signup requests by status', e);
      throw AppException(
          'Error fetching signup requests by status: ${e.toString()}',
          originalError: e
      );
    }
  }

  /// Get a specific signup request by ID
  Future<SignupRequest?> getSignupRequestById(String id) async {
    try {
      final docSnapshot = await _firestore
          .collection(_collectionPath)
          .doc(id)
          .get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        return null;
      }

      return SignupRequest.fromJson(docSnapshot.data()!, docSnapshot.id);
    } catch (e) {
      ErrorHandler.logError('Error fetching signup request by ID', e);
      throw AppException(
          'Error fetching signup request by ID: ${e.toString()}',
          originalError: e
      );
    }
  }

  /// Create a new signup request
  Future<SignupRequest> createSignupRequest(SignupData data) async {
    try {
      ErrorHandler.logDebug('Creating signup request for: ${data.email}');

      // Check if a request with this email or Google email already exists
      final existingRequests = await _firestore
          .collection(_collectionPath)
          .where(Filter.or(
          Filter('email', isEqualTo: data.email),
          Filter('googleEmail', isEqualTo: data.googleEmail)
      ))
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequests.docs.isNotEmpty) {
        throw AppException('A pending signup request already exists for this email or Google email');
      }

      // Create a new document reference to get an ID
      final docRef = _firestore.collection(_collectionPath).doc();

      // Prepare the data with server timestamp
      final requestData = {
        'id': docRef.id,
        'role': data.role,
        'name': data.name,
        'surname': data.surname,
        'sex': data.sex,
        'birthdate': data.birthdate?.toIso8601String(),
        'specialty': data.specialty,
        'phoneNumber': data.phoneNumber,
        'cityOfWork': data.cityOfWork,
        'email': data.email,
        'googleEmail': data.googleEmail,
        'vatNumber': data.vatNumber,
        'fiscalCode': data.fiscalCode,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      };

      // Save the data to Firestore
      await docRef.set(requestData);

      // Get the document to retrieve the server timestamp
      final savedDoc = await docRef.get();
      final savedData = savedDoc.data();

      if (savedData == null) {
        throw AppException('Failed to retrieve saved signup request');
      }

      return SignupRequest.fromJson(savedData, docRef.id);
    } catch (e) {
      ErrorHandler.logError('Error creating signup request', e);
      if (e is AppException) {
        rethrow;
      }
      throw AppException(
          'Error creating signup request: ${e.toString()}',
          originalError: e
      );
    }
  }

  Future<bool> approveSignupRequestWithPassword(String requestId, String temporaryPassword) async {
    try {
      ErrorHandler.logDebug('Approving signup request with ID and temporary password: $requestId');

      // Get the signup request
      final requestDoc = await _firestore
          .collection(_collectionPath)
          .doc(requestId)
          .get();

      if (!requestDoc.exists || requestDoc.data() == null) {
        ErrorHandler.logWarning('Request not found: $requestId');
        return false;
      }

      final requestData = requestDoc.data()!;
      ErrorHandler.logDebug('Found request data for ID: $requestId');

      // Validate the temporary password
      if (temporaryPassword.isEmpty) {
        temporaryPassword = 'temp${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
        ErrorHandler.logWarning('Empty temporary password provided, generated a random one: $temporaryPassword');
      }

      ErrorHandler.logDebug('Using temporary password for approval: $temporaryPassword');

      // Start a batch write
      final batch = _firestore.batch();

      // 1. Update request status to approved
      batch.update(
          _firestore.collection(_collectionPath).doc(requestId),
          {
            'status': 'approved',
            'processedAt': FieldValue.serverTimestamp(),
            'deleteAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
            'temporaryPassword': temporaryPassword,
          }
      );

      // 2. Create doctor/clinic record based on the request
      final doctorsCollection = _firestore.collection('doctors');
      final newDoctorRef = doctorsCollection.doc(); // Auto-generate ID

      // Common fields that apply to both doctor and clinic
      final commonFields = {
        'createdAt': FieldValue.serverTimestamp(),
        'signupRequestId': requestId,
        'signupApprovalDate': FieldValue.serverTimestamp(),
        'requiredPasswordChange': true, // Flag to indicate first login needs password change
        'googleEmail': requestData['googleEmail'] ?? '', // Include the Google email
      };

      ErrorHandler.logDebug('Setting requiredPasswordChange to true and storing temporary password: $temporaryPassword');

      if (requestData['role'] == 'DOCTOR') {
        batch.set(newDoctorRef, {
          'name': requestData['name'] ?? '',
          'surname': requestData['surname'] ?? '',
          'sex': requestData['sex'] ?? '',
          'phoneNumber': requestData['phoneNumber'] ?? '',
          'birthdate': requestData['birthdate'],
          'specialty': requestData['specialty'] ?? '',
          'email': requestData['email'] ?? '',
          'placeOfWork': '',
          'cityOfWork': requestData['cityOfWork'] ?? '',
          'areaOfInterest': '',
          'role': 'DOCTOR',
          'licenseNumber': '',
          'vatNumber': requestData['vatNumber'] ?? '',
          'fiscalCode': requestData['fiscalCode'] ?? '', // Include fiscal code
          'hourlyFees': 0.0,
          'isDoctor': true,
          ...commonFields,
        });
      } else if (requestData['role'] == 'CLINIC') {
        batch.set(newDoctorRef, {
          'name': requestData['name'] ?? '',
          'surname': '',
          'sex': '',
          'phoneNumber': requestData['phoneNumber'] ?? '',
          'birthdate': null,
          'specialty': requestData['specialty'] ?? '',
          'email': requestData['email'] ?? '',
          'placeOfWork': '',
          'cityOfWork': requestData['cityOfWork'] ?? '',
          'areaOfInterest': '',
          'role': 'CLINIC',
          'licenseNumber': '',
          'vatNumber': '',
          'fiscalCode': requestData['fiscalCode'] ?? '', // Include fiscal code
          'hourlyFees': 0.0,
          'isDoctor': false,
          ...commonFields,
        });
      }

      // Commit the batch
      await batch.commit();
      ErrorHandler.logDebug('Batch committed successfully with password: $temporaryPassword');

      // Create Firebase Auth user
      await _createFirebaseAuthUser(
        requestData['email'],
        temporaryPassword,
        requestData['name'],
        requestData['role'],
      );

      return true;
    } catch (e) {
      ErrorHandler.logError('Error approving signup request with password', e);
      return false;
    }
  }

  Future<bool> rejectSignupRequestWithReason(String requestId, String reason) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(requestId)
          .update({
        'status': 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'deleteAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'rejectionReason': reason,
      });

      return true;
    } catch (e) {
      ErrorHandler.logError('Error rejecting signup request with reason', e);
      return false;
    }
  }

  /// Check if emails exist
  Future<Map<String, Map<String, bool>>> checkDetailedEmailsExist(
      String email, String googleEmail) async {
    try {
      final result = {
        'primaryEmail': await _checkDetailedEmailExists(email),
        'googleEmail': await _checkDetailedEmailExists(googleEmail, isGoogleEmail: true)
      };

      return result;
    } catch (e) {
      ErrorHandler.logError('Error checking detailed email existence', e);
      throw AppException(
          'Unable to verify email availability. Please try again later.',
          originalError: e
      );
    }
  }

  Future<void> _createFirebaseAuthUser(
      String email,
      String password,
      String displayName,
      String role
      ) async {
    try {
      // Store the request to create a Firebase Auth user in a separate collection
      // that will trigger a Cloud Function (safer approach)
      await _firestore.collection('auth_creation_requests').add({
        'email': email,
        'password': password,
        'displayName': displayName,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending'
      });

      ErrorHandler.logDebug('Requested Firebase Auth user creation for: $email with role: $role and password: $password');

      // We don't create the Firebase Auth user directly from the client
      // as it would require Firebase Admin SDK privileges
    } catch (e) {
      ErrorHandler.logError('Error requesting Firebase Auth user creation', e);
      throw AppException('Failed to request Firebase Auth user creation: ${e.toString()}');
    }
  }

  /// Helper method to check if an email exists
  Future<Map<String, bool>> _checkDetailedEmailExists(String email, {bool isGoogleEmail = false}) async {
    try {
      // Normalize the email to lowercase for consistent checks
      final normalizedEmail = email.toLowerCase().trim();
      final fieldToCheck = isGoogleEmail ? 'googleEmail' : 'email';

      ErrorHandler.logDebug('Checking if ${isGoogleEmail ? "Google " : ""}email exists: $normalizedEmail');

      final result = {
        'existsInDoctors': false,
        'existsInSignupRequests': false
      };

      // Check in doctors collection
      final doctorQuerySnapshot = await _firestore
          .collection('doctors')
          .where(fieldToCheck, isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (doctorQuerySnapshot.docs.isNotEmpty) {
        ErrorHandler.logDebug('Found existing ${isGoogleEmail ? "Google " : ""}email in doctors collection');
        result['existsInDoctors'] = true;
      }

      // Check in signup_requests collection for pending requests
      final anyRequestsQuery = await _firestore
          .collection(_collectionPath)
          .where(fieldToCheck, isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (anyRequestsQuery.docs.isNotEmpty) {
        ErrorHandler.logDebug('Found existing ${isGoogleEmail ? "Google " : ""}email in signup requests');
        result['existsInSignupRequests'] = true;
      }

      return result;
    } catch (e) {
      ErrorHandler.logError('Unexpected error checking email', e);
      throw AppException(
          'Error checking email availability: ${e.toString()}',
          originalError: e
      );
    }
  }
}