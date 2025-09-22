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

  /// NEW: Get signup requests filtered by role
  Future<List<SignupRequest>> getSignupRequestsByRole(String role) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionPath)
          .where('roles', arrayContains: role)
          .orderBy('requestedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return SignupRequest.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      ErrorHandler.logError('Error fetching signup requests by role', e);
      throw AppException(
          'Error fetching signup requests by role: ${e.toString()}',
          originalError: e
      );
    }
  }

  /// NEW: Get statistics about signup requests by role
  Future<Map<String, int>> getSignupRequestsStatsByRole() async {
    try {
      final stats = <String, int>{};

      // Get all pending requests
      final pendingRequests = await getSignupRequestsByStatus('pending');

      // Count by role
      for (final request in pendingRequests) {
        // Handle both old single role and new multiple roles format
        List<String> roles = request.roles.isNotEmpty ? request.roles : [request.role ?? ''];

        for (final role in roles) {
          if (role.isNotEmpty) {
            stats[role] = (stats[role] ?? 0) + 1;
          }
        }
      }

      return stats;
    } catch (e) {
      ErrorHandler.logError('Error getting signup requests stats by role', e);
      throw AppException(
          'Error getting signup requests statistics: ${e.toString()}',
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

  /// UPDATED: Create a new signup request with multiple roles and professional fields
  Future<SignupRequest> createSignupRequest(SignupData data) async {
    try {
      ErrorHandler.logDebug('Creating signup request for: ${data.email} with roles: ${data.roles}');

      // Check if a request with this email already exists
      final existingRequests = await _firestore
          .collection(_collectionPath)
          .where('email', isEqualTo: data.email)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequests.docs.isNotEmpty) {
        throw AppException('A pending signup request already exists for this email');
      }

      // Create a new document reference to get an ID
      final docRef = _firestore.collection(_collectionPath).doc();

      // UPDATED: Prepare the data with new multiple roles and professional fields
      final requestData = {
        'id': docRef.id,
        'roles': data.roles, // NEW: Multiple roles instead of single role
        'role': data.roles.isNotEmpty ? data.roles.first : null, // LEGACY: Backward compatibility
        'name': data.name,
        'surname': data.surname,
        'sex': data.sex,
        'birthdate': data.birthdate != null ? Timestamp.fromDate(data.birthdate!) : null, // Use Timestamp
        'specialty': data.specialty,
        'phoneNumber': data.phoneNumber,
        'cityOfWork': data.cityOfWork,
        'countryOfWork': data.countryOfWork, // NEW: Country of work
        'email': data.email,
        'vatNumber': data.vatNumber,
        'fiscalCode': data.fiscalCode,

        // Location and organization fields
        'address': data.address,
        'languagesSpoken': data.languagesSpoken,
        'organization': data.organization,
        'ragioneSociale': data.ragioneSociale,

        // NEW: Professional registration fields
        'numero_iscrizione_albo': data.numero_iscrizione_albo,
        'numero_iscrizione_ente': data.numero_iscrizione_ente,
        'issuer': data.issuer,

        // NEW: Optional professional fields
        'areaOfInterest': data.areaOfInterest,
        'qualificationValidity': data.qualificationValidity != null
            ? Timestamp.fromDate(data.qualificationValidity!)
            : null,

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

  /// UPDATED: Approve signup request with new Doctor model structure
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

      // 2. UPDATED: Create doctor record with new model structure and multiple roles
      final doctorsCollection = _firestore.collection('doctors');
      final newDoctorRef = doctorsCollection.doc(); // Auto-generate ID

      // UPDATED: Create doctor record compatible with new Doctor model
      final doctorData = {
        'name': requestData['name'] ?? '',
        'surname': requestData['surname'] ?? '',
        'sex': requestData['sex'] ?? '',
        'phoneNumber': requestData['phoneNumber'] ?? '',
        'birthdate': requestData['birthdate'], // Already a Timestamp
        'address': requestData['address'] ?? '',
        'cityOfWork': requestData['cityOfWork'] ?? '',
        'countryOfWork': requestData['countryOfWork'] ?? 'Italy',
        'fiscalCode': requestData['fiscalCode'] ?? '',
        'email': requestData['email'] ?? '',
        'vatNumber': requestData['vatNumber'] ?? '',

        // UPDATED: Multiple roles instead of single role
        'roles': requestData['roles'] ??
            (requestData['role'] != null ? [requestData['role']] : []), // Backward compatibility

        // Professional registration fields
        'numero_iscrizione_albo': requestData['numero_iscrizione_albo'],
        'numero_iscrizione_ente': requestData['numero_iscrizione_ente'],
        'issuer': requestData['issuer'] ?? '',

        // Optional professional fields
        'specialty': requestData['specialty'],
        'areaOfInterest': requestData['areaOfInterest'],
        'qualificationValidity': requestData['qualificationValidity'],

        // Location and organization fields
        'languagesSpoken': requestData['languagesSpoken'] ?? [],
        'organization': requestData['organization'] ?? '',
        'ragioneSociale': requestData['ragioneSociale'] ?? '',

        // Default values for new Doctor model
        'hourlyFees': 0.0,
        'requiredPasswordChange': true,
        'profilePictureUrl': '',
        'isActive': true,
        'isAlive': true,

        // Legacy compatibility fields
        'role': requestData['roles'] != null && (requestData['roles'] as List).isNotEmpty
            ? (requestData['roles'] as List).first
            : requestData['role'], // Backward compatibility
        'licenseNumber': '',
        'placeOfWork': '',
        'isDoctor': true, // Default to practitioner

        // Audit fields
        'createdAt': FieldValue.serverTimestamp(),
        'signupRequestId': requestId,
        'signupApprovalDate': FieldValue.serverTimestamp(),
      };

      batch.set(newDoctorRef, doctorData);

      // Commit the batch
      await batch.commit();
      ErrorHandler.logDebug('Batch committed successfully with password: $temporaryPassword');

      // UPDATED: Create Firebase Auth user with role information
      await _createFirebaseAuthUser(
        requestData['email'],
        temporaryPassword,
        '${requestData['name']} ${requestData['surname'] ?? ''}',
        requestData['roles'] ?? [requestData['role']], // Handle both new and old format
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

  /// UPDATED: Check if emails exist (removed googleEmail)
  Future<Map<String, Map<String, bool>>> checkDetailedEmailsExist(String email) async {
    try {
      final result = {
        'primaryEmail': await _checkDetailedEmailExists(email),
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

  /// NEW: Batch approve multiple signup requests
  Future<List<String>> batchApproveSignupRequests(
      List<String> requestIds,
      String defaultPassword
      ) async {
    try {
      final successfulApprovals = <String>[];

      for (final requestId in requestIds) {
        try {
          final success = await approveSignupRequestWithPassword(requestId, defaultPassword);
          if (success) {
            successfulApprovals.add(requestId);
          }
        } catch (e) {
          ErrorHandler.logWarning('Failed to approve request $requestId: $e');
        }
      }

      return successfulApprovals;
    } catch (e) {
      ErrorHandler.logError('Error in batch approval', e);
      throw AppException(
          'Error in batch approval: ${e.toString()}',
          originalError: e
      );
    }
  }

  /// NEW: Update signup request with additional professional information
  Future<bool> updateSignupRequestProfessionalInfo(
      String requestId,
      Map<String, dynamic> professionalInfo
      ) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(requestId)
          .update({
        ...professionalInfo,
        'lastModified': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      ErrorHandler.logError('Error updating signup request professional info', e);
      return false;
    }
  }

  /// UPDATED: Create Firebase Auth user with role support
  Future<void> _createFirebaseAuthUser(
      String email,
      String password,
      String displayName,
      dynamic roles // Can be List<String> or String for backward compatibility
      ) async {
    try {
      // Normalize roles to List<String>
      List<String> rolesList;
      if (roles is List) {
        rolesList = List<String>.from(roles);
      } else if (roles is String) {
        rolesList = [roles];
      } else {
        rolesList = ['UNKNOWN'];
      }

      // Store the request to create a Firebase Auth user in a separate collection
      await _firestore.collection('auth_creation_requests').add({
        'email': email,
        'password': password,
        'displayName': displayName,
        'roles': rolesList, // UPDATED: Store as list
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending'
      });

      ErrorHandler.logDebug('Requested Firebase Auth user creation for: $email with roles: $rolesList and password: $password');

    } catch (e) {
      ErrorHandler.logError('Error requesting Firebase Auth user creation', e);
      throw AppException('Failed to request Firebase Auth user creation: ${e.toString()}');
    }
  }

  /// UPDATED: Helper method to check if an email exists (removed googleEmail parameter)
  Future<Map<String, bool>> _checkDetailedEmailExists(String email) async {
    try {
      // Normalize the email to lowercase for consistent checks
      final normalizedEmail = email.toLowerCase().trim();
      const fieldToCheck = 'email';

      ErrorHandler.logDebug('Checking if email exists: $normalizedEmail');

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
        ErrorHandler.logDebug('Found existing email in doctors collection');
        result['existsInDoctors'] = true;
      }

      // Check in signup_requests collection for pending requests
      final anyRequestsQuery = await _firestore
          .collection(_collectionPath)
          .where(fieldToCheck, isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (anyRequestsQuery.docs.isNotEmpty) {
        ErrorHandler.logDebug('Found existing email in signup requests');
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

  /// NEW: Helper method to validate signup data based on roles
  bool _validateSignupData(Map<String, dynamic> requestData) {
    try {
      final roles = requestData['roles'] as List<dynamic>? ?? [];

      // Check if nutritionist or psychologist roles require albo registration
      if (roles.contains('NUTRITIONIST') || roles.contains('PSYCHOLOGIST')) {
        final numeroAlbo = requestData['numero_iscrizione_albo'] as String?;
        if (numeroAlbo == null || numeroAlbo.isEmpty) {
          ErrorHandler.logWarning('Missing numero_iscrizione_albo for nutritionist/psychologist role');
          return false;
        }
      }

      // Check if personal trainer role requires ente registration
      if (roles.contains('PERSONAL TRAINER')) {
        final numeroEnte = requestData['numero_iscrizione_ente'] as String?;
        if (numeroEnte == null || numeroEnte.isEmpty) {
          ErrorHandler.logWarning('Missing numero_iscrizione_ente for personal trainer role');
          return false;
        }
      }

      return true;
    } catch (e) {
      ErrorHandler.logError('Error validating signup data', e);
      return false;
    }
  }
}