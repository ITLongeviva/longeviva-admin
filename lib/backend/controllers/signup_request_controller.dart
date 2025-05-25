import 'dart:math';
import 'package:intl/intl.dart';

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
      ErrorHandler.logDebug('Approving signup request with ID: $id');
      ErrorHandler.logDebug('Temporary password: $temporaryPassword');

      final request = await _repository.getSignupRequestById(id);
      if (request == null) {
        throw AppException(
          'Signup request not found',
          translationKey: 'errors.signup.request_not_found',
        );
      }

      ErrorHandler.logDebug('Found signup request for email: ${request.email}');
      ErrorHandler.logDebug('Request status: ${request.status}');
      ErrorHandler.logDebug('Request role: ${request.role}');

      if (request.status != 'pending') {
        throw AppException(
          'Cannot approve a request that is not pending. Current status: ${request.status}',
          translationKey: 'errors.signup.request_not_pending',
        );
      }

      // Validate temporary password
      if (temporaryPassword.isEmpty || temporaryPassword.length < 6) {
        temporaryPassword = _generateRandomPassword(10);
        ErrorHandler.logWarning('Invalid temporary password provided, generated a new one: $temporaryPassword');
      }

      ErrorHandler.logDebug('Using temporary password for approval: $temporaryPassword');

      try {
        // Check if email already exists in Firebase Auth
        ErrorHandler.logDebug('Checking if email already exists in Firebase Auth');
        final signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(request.email);

        if (signInMethods.isNotEmpty) {
          ErrorHandler.logWarning('Email already exists in Firebase Auth with methods: $signInMethods');
          // Instead of failing, let's handle this gracefully
          // We'll still create the Firestore records but skip Firebase Auth creation
          final success = await _repository.approveSignupRequestWithPassword(id, temporaryPassword);
          if (success) {
            await _sendApprovalEmail(request, temporaryPassword);
          }
          return success;
        }

        ErrorHandler.logDebug('Email does not exist in Firebase Auth, proceeding with user creation');

        // Create Firebase Auth user
        final userCredential = await _firebaseAuthService.createUserWithEmailAndPassword(
          email: request.email,
          password: temporaryPassword,
          displayName: '${request.name} ${request.surname}',
          requirePasswordChange: true,
        );

        if (userCredential.user == null) {
          throw AppException(
            'Failed to create Firebase Auth user - user credential is null',
            translationKey: 'errors.auth.firebase_auth_user_creation_failed',
          );
        }

        ErrorHandler.logDebug('Firebase Auth user created successfully: ${userCredential.user!.uid}');

        // Set custom claims using Cloud Function
        try {
          await _functions.httpsCallable('setUserApprovedClaim').call({
            'uid': userCredential.user!.uid,
            'approved': true,
            'role': request.role,
          });
          ErrorHandler.logDebug('Set approved claim for user: ${userCredential.user!.uid}');
        } catch (e) {
          ErrorHandler.logError('Error setting custom claim (non-fatal)', e);
          // Don't fail the entire process for this
        }

        // Update Firestore records
        final success = await _repository.approveSignupRequestWithPassword(id, temporaryPassword);

        if (success) {
          await _sendApprovalEmail(request, temporaryPassword);
          ErrorHandler.logDebug('Signup request approved successfully');
        } else {
          ErrorHandler.logError('Failed to update Firestore records after Firebase Auth creation', null);
        }

        return success;

      } catch (e) {
        if (e is FirebaseAuthException) {
          ErrorHandler.logError('Firebase Auth Exception during approval', e);
          ErrorHandler.logDebug('Firebase Auth Error Code: ${e.code}');
          ErrorHandler.logDebug('Firebase Auth Error Message: ${e.message}');

          if (e.code == 'email-already-in-use') {
            ErrorHandler.logWarning('User already exists in Firebase Auth, continuing with Firestore update');
            final success = await _repository.approveSignupRequestWithPassword(id, temporaryPassword);
            if (success) {
              await _sendApprovalEmail(request, temporaryPassword);
            }
            return success;
          }

          // For other Firebase Auth errors, provide specific error messages
          String errorMessage;
          switch (e.code) {
            case 'invalid-email':
              errorMessage = 'Invalid email address: ${request.email}';
              break;
            case 'weak-password':
              errorMessage = 'Generated password is too weak. Please try again.';
              break;
            case 'operation-not-allowed':
              errorMessage = 'Email/password authentication is not enabled in Firebase Console';
              break;
            case 'network-request-failed':
              errorMessage = 'Network error occurred. Please check your internet connection and try again.';
              break;
            default:
              errorMessage = 'Firebase Auth error: ${e.message ?? e.code}';
          }

          throw AppException(
            errorMessage,
            translationKey: 'errors.auth.firebase_auth_error',
            originalError: e,
          );
        }

        rethrow;
      }
    } catch (e) {
      ErrorHandler.logError('Error approving signup request', e);
      if (e is AppException) {
        rethrow;
      }
      throw AppException(
        'Error approving signup request: ${e.toString()}',
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

Your Profile Summary:
- Role: ${request.role}
- Specialty: ${request.specialty}
- Organization: ${request.organization}
- City of Work: ${request.cityOfWork}

Next Steps:
1. Log in using your temporary password
2. Complete your profile setup
3. Update your password
4. Begin using the platform

Thank you for joining Longeviva. We look forward to supporting your healthcare practice.

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
    final subject = 'Your Longeviva Registration Request Update';
    final body = '''
Dear ${request.name} ${request.surname},

We regret to inform you that your registration request for Longeviva has been declined.

Application Details:
- Role: ${request.role}
- Specialty: ${request.specialty}
- Organization: ${request.organization}
- Application Date: ${DateFormat('MMMM d, yyyy').format(request.requestedAt)}

Reason for Decline:
$reason

Next Steps:
If you believe this decision was made in error or would like to provide additional information, please contact our support team at longeviva.app@gmail.com.

You may also submit a new application with updated information if the circumstances have changed.

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
    // Basic field validation
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

    // Role-specific validation
    if (data.role == 'DOCTOR') {
      _validateDoctorFields(data);
    } else {
      _validateClinicFields(data);
    }

    // Common required fields
    _validateCommonFields(data);

    // New fields validation
    _validateNewFields(data);

    // Business logic validation
    _validateBusinessLogic(data);
  }

  void _validateDoctorFields(SignupData data) {
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

    if (!['M', 'F', 'Male', 'Female'].contains(data.sex)) {
      throw AppException(
        'Sex must be M, F, Male, or Female',
        translationKey: 'errors.signup.invalid_sex',
      );
    }

    if (data.vatNumber.isEmpty) {
      throw AppException(
        'VAT number is required for doctors',
        translationKey: 'errors.signup.vat_required',
      );
    }

    // VAT number format validation (basic)
    if (data.vatNumber.length < 8) {
      throw AppException(
        'VAT number must be at least 8 characters',
        translationKey: 'errors.signup.vat_invalid_format',
      );
    }

    if (data.fiscalCode.isEmpty) {
      throw AppException(
        'Fiscal code is required for doctors',
        translationKey: 'errors.signup.fiscal_code_required',
      );
    }

    // Italian fiscal code validation (basic)
    if (!RegExp(r'^[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]$').hasMatch(data.fiscalCode.toUpperCase())) {
      throw AppException(
        'Invalid fiscal code format',
        translationKey: 'errors.signup.fiscal_code_invalid',
      );
    }
  }

  void _validateClinicFields(SignupData data) {
    if (data.fiscalCode.isEmpty) {
      throw AppException(
        'Fiscal code is required for clinics',
        translationKey: 'errors.signup.fiscal_code_required',
      );
    }

    if (data.ragioneSociale.isEmpty) {
      throw AppException(
        'Business name (Ragione Sociale) is required for clinics',
        translationKey: 'errors.signup.ragione_sociale_required',
      );
    }

    if (data.ragioneSociale.length < 2) {
      throw AppException(
        'Business name must be at least 2 characters',
        translationKey: 'errors.signup.ragione_sociale_too_short',
      );
    }
  }

  void _validateCommonFields(SignupData data) {
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

    // Phone number format validation (basic)
    if (!RegExp(r'^\+?[\d\s\-\(\)]{8,}$').hasMatch(data.phoneNumber)) {
      throw AppException(
        'Invalid phone number format',
        translationKey: 'errors.signup.phone_invalid',
      );
    }

    if (data.cityOfWork.isEmpty) {
      throw AppException(
        'City of work is required',
        translationKey: 'errors.signup.city_required',
      );
    }
  }

  void _validateNewFields(SignupData data) {
    if (data.address.isEmpty) {
      throw AppException(
        'Address is required',
        translationKey: 'errors.signup.address_required',
      );
    }

    if (data.address.length < 10) {
      throw AppException(
        'Address must be at least 10 characters',
        translationKey: 'errors.signup.address_too_short',
      );
    }

    if (data.languagesSpoken.isEmpty) {
      throw AppException(
        'At least one language must be specified',
        translationKey: 'errors.signup.languages_required',
      );
    }

    // Validate language entries
    for (String language in data.languagesSpoken) {
      if (language.trim().isEmpty) {
        throw AppException(
          'Language entries cannot be empty',
          translationKey: 'errors.signup.languages_empty_entry',
        );
      }
      if (language.length < 2) {
        throw AppException(
          'Language entries must be at least 2 characters',
          translationKey: 'errors.signup.languages_too_short',
        );
      }
    }

    if (data.organization.isEmpty) {
      throw AppException(
        'Organization is required',
        translationKey: 'errors.signup.organization_required',
      );
    }

    if (data.organization.length < 2) {
      throw AppException(
        'Organization name must be at least 2 characters',
        translationKey: 'errors.signup.organization_too_short',
      );
    }
  }

  void _validateBusinessLogic(SignupData data) {
    // Validate birthdate if provided (for doctors)
    if (data.role == 'DOCTOR' && data.birthdate != null) {
      final now = DateTime.now();
      final age = now.year - data.birthdate!.year;

      if (age < 18) {
        throw AppException(
          'Doctor must be at least 18 years old',
          translationKey: 'errors.signup.age_too_young',
        );
      }

      if (age > 100) {
        throw AppException(
          'Please verify the birthdate',
          translationKey: 'errors.signup.age_too_old',
        );
      }

      if (data.birthdate!.isAfter(now)) {
        throw AppException(
          'Birthdate cannot be in the future',
          translationKey: 'errors.signup.birthdate_future',
        );
      }
    }

    // Check for reasonable language count
    if (data.languagesSpoken.length > 20) {
      throw AppException(
        'Maximum 20 languages can be specified',
        translationKey: 'errors.signup.too_many_languages',
      );
    }

    // Check for duplicate languages
    final uniqueLanguages = data.languagesSpoken.map((lang) => lang.trim().toLowerCase()).toSet();
    if (uniqueLanguages.length != data.languagesSpoken.length) {
      throw AppException(
        'Duplicate languages are not allowed',
        translationKey: 'errors.signup.duplicate_languages',
      );
    }
  }

  String _generateRandomPassword(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}