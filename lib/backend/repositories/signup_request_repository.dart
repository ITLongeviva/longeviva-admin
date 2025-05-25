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

  /// Create a new signup request with new fields
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

      // Prepare the data with server timestamp and new fields
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
        // New fields
        'address': data.address,
        'languagesSpoken': data.languagesSpoken,
        'organization': data.organization,
        'ragioneSociale': data.ragioneSociale,
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

      // 2. Create doctor/clinic record based on the request with new FHIR-compliant fields
      final doctorsCollection = _firestore.collection('doctors');
      final newDoctorRef = doctorsCollection.doc(); // Auto-generate ID

      // Common fields that apply to both doctor and clinic with FHIR compliance
      final commonFields = {
        'createdAt': FieldValue.serverTimestamp(),
        'signupRequestId': requestId,
        'signupApprovalDate': FieldValue.serverTimestamp(),
        'requiredPasswordChange': true, // Flag to indicate first login needs password change
        'googleEmail': requestData['googleEmail'] ?? '', // Include the Google email
        // New FHIR-compliant fields with sensible defaults
        'isActive': true,  // FHIR active boolean - new users are active by default
        'isAlive': true,   // FHIR deceased indicator - assume alive for new signups
        'address': requestData['address'] ?? '', // FHIR address
        'languagesSpoken': requestData['languagesSpoken'] ?? [], // FHIR communication.language
        'qualificationValidity': null, // FHIR qualification.period - to be set later by admin
        'issuer': '', // FHIR qualification.issuer - to be set later by admin
        'organizationPeriodValidity': null, // FHIR PractitionerRole.period - to be set later
        'organization': requestData['organization'] ?? '', // FHIR organization reference
        'profilePictureUrl': '', // FHIR photo - empty initially
      };

      ErrorHandler.logDebug('Setting requiredPasswordChange to true and storing temporary password: $temporaryPassword');

      if (requestData['role'] == 'DOCTOR') {
        // Create FHIR-compliant Doctor (Practitioner) record
        batch.set(newDoctorRef, {
          // Basic FHIR Practitioner fields
          'name': requestData['name'] ?? '',
          'surname': requestData['surname'] ?? '',
          'sex': requestData['sex'] ?? '', // FHIR gender
          'phoneNumber': requestData['phoneNumber'] ?? '', // FHIR telecom
          'birthdate': requestData['birthdate'], // FHIR birthDate
          'email': requestData['email'] ?? '', // FHIR telecom

          // FHIR Practitioner.identifier fields
          'vatNumber': requestData['vatNumber'] ?? '', // Business identifier
          'fiscalCode': requestData['fiscalCode'] ?? '', // National identifier
          'licenseNumber': '', // FHIR qualification.identifier - to be set later

          // FHIR PractitionerRole fields (specialty is role-specific)
          'specialty': requestData['specialty'] ?? '', // FHIR PractitionerRole.specialty
          'placeOfWork': '', // FHIR PractitionerRole.location - to be completed
          'cityOfWork': requestData['cityOfWork'] ?? '', // Part of location address
          'areaOfInterest': '', // Extension of specialty - to be set later

          // Application-specific fields
          'role': 'DOCTOR',
          'hourlyFees': 0.0, // To be set later
          'isDoctor': true,

          ...commonFields,
        });
      } else if (requestData['role'] == 'CLINIC') {
        // Create FHIR-compliant Organization record stored as Doctor entity
        // Note: In proper FHIR, this should be a separate Organization resource
        batch.set(newDoctorRef, {
          // Organization basic info
          'name': requestData['name'] ?? '',
          'surname': '', // Organizations don't have surnames
          'sex': '', // Organizations don't have gender
          'phoneNumber': requestData['phoneNumber'] ?? '', // FHIR Organization.telecom
          'birthdate': null, // Organizations don't have birthdates
          'email': requestData['email'] ?? '', // FHIR Organization.telecom

          // FHIR Organization.identifier fields
          'vatNumber': '', // Not applicable for clinics in this context
          'fiscalCode': requestData['fiscalCode'] ?? '', // Organization tax identifier
          'licenseNumber': requestData['ragioneSociale'] ?? '', // Business name stored as license

          // Service-related fields
          'specialty': requestData['specialty'] ?? '', // Services provided
          'placeOfWork': '', // To be completed
          'cityOfWork': requestData['cityOfWork'] ?? '', // FHIR Organization.address
          'areaOfInterest': '', // Service areas - to be set later

          // Application-specific fields
          'role': 'CLINIC',
          'hourlyFees': 0.0, // Service rates - to be set later
          'isDoctor': false, // This is an organization, not an individual practitioner

          ...commonFields,
        });
      }

      // Commit the batch
      await batch.commit();
      ErrorHandler.logDebug('Batch committed successfully with password: $temporaryPassword');

      // Create Firebase Auth user request (handled by Cloud Function)
      await _createFirebaseAuthUser(
        requestData['email'],
        temporaryPassword,
        '${requestData['name']} ${requestData['surname'] ?? ''}',
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

  /// Check if emails exist with enhanced validation
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

  /// Helper method to check if an email exists with enhanced validation
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

      // Check in doctors collection with timeout
      try {
        final doctorQuerySnapshot = await _firestore
            .collection('doctors')
            .where(fieldToCheck, isEqualTo: normalizedEmail)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));

        if (doctorQuerySnapshot.docs.isNotEmpty) {
          ErrorHandler.logDebug('Found existing ${isGoogleEmail ? "Google " : ""}email in doctors collection');
          result['existsInDoctors'] = true;
        }
      } catch (e) {
        ErrorHandler.logWarning('Error checking doctors collection: $e');
        // Continue with other checks even if this fails
      }

      // Check in signup_requests collection for any requests (not just pending)
      try {
        final anyRequestsQuery = await _firestore
            .collection(_collectionPath)
            .where(fieldToCheck, isEqualTo: normalizedEmail)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));

        if (anyRequestsQuery.docs.isNotEmpty) {
          ErrorHandler.logDebug('Found existing ${isGoogleEmail ? "Google " : ""}email in signup requests');
          result['existsInSignupRequests'] = true;
        }
      } catch (e) {
        ErrorHandler.logWarning('Error checking signup requests collection: $e');
        // Continue even if this check fails
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