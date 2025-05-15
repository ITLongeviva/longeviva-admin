import 'dart:math';
import '../../shared/utils/error_handler.dart';
import '../models/doctor/sign_up_data.dart';
import '../models/signup_request_model.dart';
import '../repositories/signup_request_repository.dart';
import '../services/email_service.dart';
import '../services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SignupRequestController {
  final SignupRequestRepository _repository;
  final EmailService _emailService;
  final FirebaseAuthService _firebaseAuthService;
  final FirebaseFunctions _functions;

  SignupRequestController({
    SignupRequestRepository? repository,
    EmailService? emailService,
    FirebaseAuthService? firebaseAuthService,
    FirebaseFunctions? functions,
  })  : _repository = repository ?? SignupRequestRepository(),
        _emailService = emailService ?? EmailService(),
        _firebaseAuthService = firebaseAuthService ?? FirebaseAuthService(),
        _functions = functions ?? FirebaseFunctions.instance;

  Future<List<SignupRequest>> getAllSignupRequests() async {
    try {
      ErrorHandler.logDebug('Getting all signup requests');
      return await _repository.getAllSignupRequests();
    } catch (e) {
      ErrorHandler.logError('Error getting all signup requests', e);
      throw AppException(
        'Error retrieving signup requests',
        translationKey: 'errors.general.operation_failed',
        translationArgs: {'error': 'retrieve signup requests'},
        originalError: e,
      );
    }
  }

  Future<List<SignupRequest>> getSignupRequestsByStatus(String status) async {
    try {
      ErrorHandler.logDebug('Getting signup requests with status: $status');
      return await _repository.getSignupRequestsByStatus(status);
    } catch (e) {
      ErrorHandler.logError('Error getting signup requests by status', e);
      throw AppException(
        'Error retrieving signup requests with status: $status',
        translationKey: 'errors.general.operation_failed',
        translationArgs: {'error': 'retrieve signup requests by status'},
        originalError: e,
      );
    }
  }

  Future<SignupRequest?> getSignupRequestById(String id) async {
    try {
      ErrorHandler.logDebug('Getting signup request with ID: $id');
      return await _repository.getSignupRequestById(id);
    } catch (e) {
      ErrorHandler.logError('Error getting signup request by ID', e);
      throw AppException(
        'Error retrieving signup request',
        translationKey: 'errors.general.operation_failed',
        translationArgs: {'error': 'retrieve signup request'},
        originalError: e,
      );
    }
  }

  Future<SignupRequest> createSignupRequest(SignupData data) async {
    try {
      ErrorHandler.logDebug('Creating signup request for: ${data.email}');
      _validateSignupData(data);
      final signupRequest = await _repository.createSignupRequest(data);
      await _emailService.sendSignupEmail(data);
      return signupRequest;
    } catch (e) {
      ErrorHandler.logError('Error creating signup request', e);
      if (e is AppException) {
        rethrow;
      }
      throw AppException(
        'Error creating signup request',
        translationKey: 'errors.general.operation_failed',
        translationArgs: {'error': 'create signup request'},
        originalError: e,
      );
    }
  }

  Future<bool> approveSignupRequestWithPassword(String id, String temporaryPassword) async {
    try {
      ErrorHandler.logDebug('Approving signup request with ID and temporary password: $id');

      final request = await _repository.getSignupRequestById(id);
      if (request == null) {
        throw AppException(
          'Signup request not found',
          translationKey: 'errors.signup.request_not_found',
        );
      }

      if (request.status != 'pending') {
        throw AppException(
          'Cannot approve a request that is not pending',
          translationKey: 'errors.signup.request_not_pending',
        );
      }

      if (temporaryPassword.isEmpty) {
        temporaryPassword = _generateRandomPassword(10);
        ErrorHandler.logWarning('Empty temporary password provided, generated a random one: $temporaryPassword');
      }

      ErrorHandler.logDebug('Using temporary password for approval: $temporaryPassword');

      try {
        final userCredential = await _firebaseAuthService.createUserWithEmailAndPassword(
          email: request.email,
          password: temporaryPassword,
          displayName: '${request.name} ${request.surname}',
          requirePasswordChange: true,
        );

        if (userCredential.user == null) {
          throw AppException(
            'Failed to create Firebase Auth user',
            translationKey: 'errors.auth.firebase_auth_user_creation_failed',
            translationArgs: {'error': 'User creation returned null'},
          );
        }

        try {
          await _functions.httpsCallable('setUserApprovedClaim').call({
            'uid': userCredential.user!.uid,
            'approved': true,
            'role': request.role,
          });

          ErrorHandler.logDebug('Set approved claim for user: ${userCredential.user!.uid}');
        } catch (e) {
          ErrorHandler.logError('Error setting custom claim', e);
        }

        final success = await _repository.approveSignupRequestWithPassword(id, temporaryPassword);

        if (success) {
          await _sendApprovalEmail(request, temporaryPassword);
        }

        return success;
      } catch (e) {
        if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
          ErrorHandler.logWarning('User already exists in Firebase Auth, continuing with Firestore update');
          final success = await _repository.approveSignupRequestWithPassword(id, temporaryPassword);
          if (success) {
            await _sendApprovalEmail(request, temporaryPassword);
          }
          return success;
        }
        rethrow;
      }
    } catch (e) {
      ErrorHandler.logError('Error approving signup request', e);
      if (e is AppException) {
        rethrow;
      }
      throw AppException(
        'Error approving signup request',
        translationKey: 'errors.signup.approval_failed',
        originalError: e,
      );
    }
  }

  Future<bool> rejectSignupRequestWithReason(String id, String reason) async {
    try {
      ErrorHandler.logDebug('Rejecting signup request with ID: $id');

      final request = await _repository.getSignupRequestById(id);
      if (request == null) {
        throw AppException(
          'Signup request not found',
          translationKey: 'errors.signup.request_not_found',
        );
      }

      if (request.status != 'pending') {
        throw AppException(
          'Cannot reject a request that is not pending',
          translationKey: 'errors.signup.request_not_pending',
        );
      }

      final success = await _repository.rejectSignupRequestWithReason(id, reason);

      if (success) {
        await _sendRejectionEmail(request, reason);
      }

      return success;
    } catch (e) {
      ErrorHandler.logError('Error rejecting signup request', e);
      if (e is AppException) {
        rethrow;
      }
      throw AppException(
        'Error rejecting signup request',
        translationKey: 'errors.signup.rejection_failed',
        originalError: e,
      );
    }
  }

  Future<Map<String, Map<String, bool>>> checkDetailedEmailsExist(String email, String googleEmail) async {
    try {
      ErrorHandler.logDebug('Checking email existence for: $email, $googleEmail');

      bool primaryEmailExistsInAuth = false;
      bool googleEmailExistsInAuth = false;

      try {
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        primaryEmailExistsInAuth = methods.isNotEmpty;

        if (email.toLowerCase() != googleEmail.toLowerCase()) {
          final googleMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(googleEmail);
          googleEmailExistsInAuth = googleMethods.isNotEmpty;
        } else {
          googleEmailExistsInAuth = primaryEmailExistsInAuth;
        }
      } catch (e) {
        ErrorHandler.logWarning('Error checking email in Firebase Auth: $e');
      }

      final firestoreResults = await _repository.checkDetailedEmailsExist(email, googleEmail);

      final result = {
        'primaryEmail': {
          ...firestoreResults['primaryEmail'] ?? {},
          'existsInFirebaseAuth': primaryEmailExistsInAuth,
        },
        'googleEmail': {
          ...firestoreResults['googleEmail'] ?? {},
          'existsInFirebaseAuth': googleEmailExistsInAuth,
        }
      };

      return result;
    } catch (e) {
      ErrorHandler.logError('Error checking email existence', e);
      if (e is AppException) {
        rethrow;
      }
      throw AppException(
        'Error checking email availability',
        translationKey: 'errors.general.operation_failed',
        translationArgs: {'error': 'check email availability'},
        originalError: e,
      );
    }
  }

  Future<void> _sendApprovalEmail(SignupRequest request, String temporaryPassword) async {
    final subject = 'Your Longeviva Registration Request Has Been Approved';
    final body = '''
Dear ${request.name} ${request.surname},

We are pleased to inform you that your registration request for Longeviva has been approved.

You can now log in to the platform using the following credentials:
Email: ${request.email}
Temporary Password: $temporaryPassword

Please note that you will be prompted to change your password upon your first login.

Thank you for joining Longeviva.

Best regards,
The Longeviva Team
''';

    await _emailService.sendCustomEmail(
      to: request.email,
      subject: subject,
      body: body,
    );

    if (request.googleEmail != request.email) {
      await _emailService.sendCustomEmail(
        to: request.googleEmail,
        subject: subject,
        body: body,
      );
    }
  }

  Future<void> _sendRejectionEmail(SignupRequest request, String reason) async {
    final subject = 'Your Longeviva Registration Request';
    final body = '''
Dear ${request.name} ${request.surname},

We regret to inform you that your registration request for Longeviva has been declined.

Reason: $reason

If you believe this decision was made in error or would like to provide additional information, please contact our support team.

Best regards,
The Longeviva Team
''';

    await _emailService.sendCustomEmail(
      to: request.email,
      subject: subject,
      body: body,
    );

    if (request.googleEmail != request.email) {
      await _emailService.sendCustomEmail(
        to: request.googleEmail,
        subject: subject,
        body: body,
      );
    }
  }

  void _validateSignupData(SignupData data) {
    if (data.email.isEmpty) {
      throw AppException(
        'Email is required',
        translationKey: 'errors.signup.email_required',
      );
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}').hasMatch(data.email)) {
      throw AppException(
        'Invalid email format',
        translationKey: 'errors.signup.invalid_email_format',
      );
    }

    if (data.googleEmail.isEmpty) {
      throw AppException(
        'Google email is required',
        translationKey: 'errors.signup.google_email_required',
      );
    }

    if (!data.googleEmail.toLowerCase().endsWith('@gmail.com')) {
      throw AppException(
        'Google email must be a Gmail address',
        translationKey: 'errors.signup.google_email_must_be_gmail',
      );
    }

    if (data.name.isEmpty) {
      throw AppException(
        'Name is required',
        translationKey: 'errors.signup.name_required',
      );
    }

    if (data.role != 'DOCTOR' && data.role != 'CLINIC') {
      throw AppException(
        'Role must be either DOCTOR or CLINIC',
        translationKey: 'errors.signup.role_invalid',
      );
    }

    if (data.role == 'DOCTOR') {
      if (data.surname.isEmpty) {
        throw AppException(
          'Surname is required for doctors',
          translationKey: 'errors.signup.surname_required',
        );
      }

      if (data.sex.isEmpty) {
        throw AppException(
          'Sex is required for doctors',
          translationKey: 'errors.signup.sex_required',
        );
      }

      if (data.vatNumber.isEmpty) {
        throw AppException(
          'VAT number is required for doctors',
          translationKey: 'errors.signup.vat_required',
        );
      }
    } else {
      if (data.fiscalCode.isEmpty) {
        throw AppException(
          'Fiscal code is required for clinics',
          translationKey: 'errors.signup.fiscal_code_required',
        );
      }
    }

    if (data.specialty.isEmpty) {
      throw AppException(
        'Specialty is required',
        translationKey: 'errors.signup.specialty_required',
      );
    }

    if (data.phoneNumber.isEmpty) {
      throw AppException(
        'Phone number is required',
        translationKey: 'errors.signup.phone_required',
      );
    }

    if (data.cityOfWork.isEmpty) {
      throw AppException(
        'City of work is required',
        translationKey: 'errors.signup.city_required',
      );
    }
  }

  String _generateRandomPassword(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}