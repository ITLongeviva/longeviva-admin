import 'dart:math';
import 'package:intl/intl.dart';

import '../../shared/utils/error_handler.dart';
import '../../shared/utils/secure_password_generator.dart';
import '../../shared/widgets/password_validation_widget.dart';
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

  // NEW: Get signup requests by role
  Future<List<SignupRequest>> getSignupRequestsByRole(String role) async {
    try {
      ErrorHandler.logDebug('Getting signup requests with role: $role');
      return await _repository.getSignupRequestsByRole(role);
    } catch (e) {
      ErrorHandler.logError('Error getting signup requests by role', e);
      throw AppException(
        'Error retrieving signup requests with role: $role',
        translationKey: 'errors.general.operation_failed',
        translationArgs: {'error': 'retrieve signup requests by role'},
        originalError: e,
      );
    }
  }

  // NEW: Get signup statistics by role
  Future<Map<String, int>> getSignupRequestsStatsByRole() async {
    try {
      ErrorHandler.logDebug('Getting signup requests statistics by role');
      return await _repository.getSignupRequestsStatsByRole();
    } catch (e) {
      ErrorHandler.logError('Error getting signup requests statistics', e);
      throw AppException(
        'Error retrieving signup requests statistics',
        translationKey: 'errors.general.operation_failed',
        translationArgs: {'error': 'retrieve signup statistics'},
        originalError: e,
      );
    }
  }

  // NEW: Get hourly fees statistics by role
  Future<Map<String, Map<String, double>>> getHourlyFeesStatsByRole() async {
    try {
      ErrorHandler.logDebug('Getting hourly fees statistics by role');
      return await _repository.getHourlyFeesStatsByRole();
    } catch (e) {
      ErrorHandler.logError('Error getting hourly fees statistics', e);
      throw AppException(
        'Error retrieving hourly fees statistics',
        translationKey: 'errors.general.operation_failed',
        translationArgs: {'error': 'retrieve hourly fees statistics'},
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

  // UPDATED: Enhanced validation for new SignupData structure including hourlyFees
  Future<SignupRequest> createSignupRequest(SignupData data) async {
    try {
      ErrorHandler.logDebug('Creating signup request for: ${data.email} with roles: ${data.roles} and hourlyFees: ${data.hourlyFees}');

      // UPDATED: Enhanced validation including hourlyFees
      _validateSignupData(data);

      final signupRequest = await _repository.createSignupRequest(data);

      // UPDATED: Send email with role and hourly fees information
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

  // UPDATED: Enhanced approval with role support
  Future<bool> approveSignupRequestWithPassword(String id, String temporaryPassword) async {
    try {
      ErrorHandler.logDebug('Approving signup request with ID: $id');

      final request = await _repository.getSignupRequestById(id);
      if (request == null) {
        throw AppException(
          'Signup request not found',
          translationKey: 'errors.signup.request_not_found',
        );
      }

      ErrorHandler.logDebug('Found signup request for email: ${request.email}');
      ErrorHandler.logDebug('Request status: ${request.status}');
      ErrorHandler.logDebug('Request roles: ${request.roles}');
      ErrorHandler.logDebug('Request hourly fees: ${request.formattedHourlyFees}');

      if (request.status != 'pending') {
        throw AppException(
          'Cannot approve a request that is not pending. Current status: ${request.status}',
          translationKey: 'errors.signup.request_not_pending',
        );
      }

      // Use unified password validation and generation
      String finalPassword = temporaryPassword.trim();

      if (finalPassword.isEmpty) {
        // Generate a new secure password using the unified helper
        finalPassword = PasswordValidationHelper.generateValidatedPassword(length: 12);
        ErrorHandler.logDebug('Empty temporary password provided, generated a secure validated one');
      } else {
        // Validate the provided password using the unified system
        final validation = SecurePasswordGenerator.validatePasswordForUI(finalPassword);
        if (!validation['isValid']) {
          // If provided password doesn't meet requirements, generate a new one
          finalPassword = PasswordValidationHelper.generateValidatedPassword(length: 12);
          ErrorHandler.logWarning('Provided password does not meet security requirements: ${validation['errorMessage']}');
          ErrorHandler.logDebug('Generated new secure password instead');
        }
      }

      // Double-check the final password with explicit validation
      final finalValidation = SecurePasswordGenerator.validatePasswordForUI(finalPassword);
      if (!finalValidation['isValid']) {
        throw AppException(
          'Critical error: Generated password failed validation - ${finalValidation['errorMessage']}',
          translationKey: 'errors.auth.password_generation_failed',
        );
      }

      ErrorHandler.logDebug('Using validated secure temporary password (length: ${finalPassword.length})');
      ErrorHandler.logDebug('Password strength: ${finalValidation['strengthDescription']} (${finalValidation['strength']}/100)');

      try {
        // Check if email already exists in Firebase Auth
        ErrorHandler.logDebug('Checking if email already exists in Firebase Auth');
        final signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(request.email);

        if (signInMethods.isNotEmpty) {
          ErrorHandler.logWarning('Email already exists in Firebase Auth with methods: $signInMethods');
          // Handle gracefully - update Firestore records but skip Firebase Auth creation
          final success = await _repository.approveSignupRequestWithPassword(id, finalPassword);
          if (success) {
            await _sendApprovalEmail(request, finalPassword);
          }
          return success;
        }

        ErrorHandler.logDebug('Email does not exist in Firebase Auth, proceeding with user creation');

        // Create Firebase Auth user with the validated secure password
        final userCredential = await _firebaseAuthService.createUserWithEmailAndPassword(
          email: request.email,
          password: finalPassword,
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

        ErrorHandler.logDebug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        ErrorHandler.logDebug('🔐 SETTING CUSTOM CLAIMS');
        ErrorHandler.logDebug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        final userRoles = _getUserRoles(request);
        ErrorHandler.logDebug('📋 Preparing custom claims:');
        ErrorHandler.logDebug('   🆔 UID: ${userCredential.user!.uid}');
        ErrorHandler.logDebug('   ✅ Approved: true');
        ErrorHandler.logDebug('   🎭 All Roles: $userRoles');

        try {
          // Prendi solo il primo ruolo (la Cloud Function accetta solo un ruolo singolo)
          final primaryRole = userRoles.isNotEmpty ? userRoles.first : 'NUTRITIONIST';
          ErrorHandler.logDebug('   🎯 Primary Role (sending to function): $primaryRole');

          ErrorHandler.logDebug('🔄 Calling Cloud Function: setUserApprovedClaim');

          final result = await _functions.httpsCallable('setUserApprovedClaim').call({
            'uid': userCredential.user!.uid,
            'approved': true,
            'role': primaryRole,
          });

          ErrorHandler.logDebug('✅ Cloud Function call completed successfully');
          ErrorHandler.logDebug('   📦 Function result: ${result.data}');

          // Verify claims were set
          ErrorHandler.logDebug('🔄 Verifying custom claims were set...');
          await Future.delayed(Duration(seconds: 2)); // Give Firebase time

          final idTokenResult = await userCredential.user!.getIdTokenResult(true);
          final claims = idTokenResult.claims ?? {};

          ErrorHandler.logDebug('✅ ID token refreshed');
          ErrorHandler.logDebug('   📋 Claims found: ${claims.keys.toList()}');

          final approvedClaim = claims['approved'] as bool?;
          final roleClaim = claims['role']; // Può essere stringa o array

          ErrorHandler.logDebug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          ErrorHandler.logDebug('🎯 VERIFICATION RESULTS:');
          ErrorHandler.logDebug('   ✅ Approved claim: ${approvedClaim ?? "NOT SET"}');
          ErrorHandler.logDebug('   🎭 Role claim: ${roleClaim ?? "NOT SET"}');

          if (approvedClaim == true && roleClaim != null) {
            ErrorHandler.logDebug('✅✅✅ CUSTOM CLAIMS VERIFIED SUCCESSFULLY! ✅✅✅');
          } else {
            ErrorHandler.logWarning('⚠️⚠️⚠️ CUSTOM CLAIMS NOT FOUND OR INCOMPLETE! ⚠️⚠️⚠️');
            ErrorHandler.logWarning('   User may have issues logging in!');
          }
          ErrorHandler.logDebug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        } catch (claimsError) {
          ErrorHandler.logError('❌❌❌ ERROR SETTING CUSTOM CLAIMS ❌❌❌', claimsError);
          ErrorHandler.logError('Error type: ${claimsError.runtimeType}', null);

          if (claimsError is FirebaseFunctionsException) {
            ErrorHandler.logError('  Code: ${claimsError.code}', null);
            ErrorHandler.logError('  Message: ${claimsError.message}', null);
            ErrorHandler.logError('  Details: ${claimsError.details}', null);
          }

          ErrorHandler.logWarning('⚠️ Continuing despite claims error (user may not be able to login!)');
        }

        // Update Firestore records
        final success = await _repository.approveSignupRequestWithPassword(id, finalPassword);

        if (success) {
          await _sendApprovalEmail(request, finalPassword);
          ErrorHandler.logDebug('Signup request approved successfully with secure validated password');
        } else {
          ErrorHandler.logError('Failed to update Firestore records after Firebase Auth creation', null);
        }

        return success;

      } catch (e) {
        if (e is FirebaseAuthException) {
          ErrorHandler.logError('Firebase Auth Exception during approval', e);

          if (e.code == 'email-already-in-use') {
            ErrorHandler.logWarning('User already exists in Firebase Auth, continuing with Firestore update');
            final success = await _repository.approveSignupRequestWithPassword(id, finalPassword);
            if (success) {
              await _sendApprovalEmail(request, finalPassword);
            }
            return success;
          }

          // Handle other Firebase Auth errors
          String errorMessage;
          switch (e.code) {
            case 'invalid-email':
              errorMessage = 'Invalid email address: ${request.email}';
              break;
            case 'weak-password':
            // This should NEVER happen with our new unified system
              errorMessage = 'CRITICAL: Generated password was rejected as weak by Firebase - this should not happen!';
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

  // UPDATED: Removed googleEmail parameter
  Future<Map<String, Map<String, bool>>> checkDetailedEmailsExist(String email) async {
    try {
      ErrorHandler.logDebug('Checking email existence for: $email');

      bool primaryEmailExistsInAuth = false;

      try {
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        primaryEmailExistsInAuth = methods.isNotEmpty;
      } catch (e) {
        ErrorHandler.logWarning('Error checking email in Firebase Auth: $e');
      }

      final firestoreResults = await _repository.checkDetailedEmailsExist(email);

      final result = {
        'primaryEmail': {
          ...firestoreResults['primaryEmail'] ?? {},
          'existsInFirebaseAuth': primaryEmailExistsInAuth,
        },
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

  // NEW: Batch approve multiple requests
  Future<List<String>> batchApproveSignupRequests(List<String> requestIds, String defaultPassword) async {
    try {
      ErrorHandler.logDebug('Batch approving ${requestIds.length} signup requests');
      return await _repository.batchApproveSignupRequests(requestIds, defaultPassword);
    } catch (e) {
      ErrorHandler.logError('Error in batch approval', e);
      throw AppException(
        'Error in batch approval process',
        translationKey: 'errors.signup.batch_approval_failed',
        originalError: e,
      );
    }
  }

  // UPDATED: Update professional information including hourlyFees
  Future<bool> updateSignupRequestProfessionalInfo(String requestId, Map<String, dynamic> professionalInfo) async {
    try {
      ErrorHandler.logDebug('Updating professional info for request: $requestId');

      // NEW: Validate hourly fees if being updated
      if (professionalInfo.containsKey('hourlyFees')) {
        final hourlyFeesValue = professionalInfo['hourlyFees'];
        if (hourlyFeesValue != null) {
          final validationError = _validateHourlyFeesValue(hourlyFeesValue);
          if (validationError != null) {
            throw AppException(validationError);
          }
        }
      }

      return await _repository.updateSignupRequestProfessionalInfo(requestId, professionalInfo);
    } catch (e) {
      ErrorHandler.logError('Error updating professional information', e);
      throw AppException(
        'Error updating professional information',
        translationKey: 'errors.signup.update_professional_info_failed',
        originalError: e,
      );
    }
  }

  // UPDATED: Get validation errors for signup data including hourlyFees
  List<String> getSignupDataValidationErrors(SignupData data) {
    final errors = <String>[];

    try {
      _validateSignupData(data);
    } catch (e) {
      if (e is AppException) {
        errors.add(e.message);
      }
    }

    // Additional validation errors from SignupData model
    errors.addAll(data.validationErrors);

    return errors;
  }

  // UPDATED: Enhanced approval email with role and hourly fees information
  Future<void> _sendApprovalEmail(SignupRequest request, String temporaryPassword) async {
    final passwordValidation = SecurePasswordGenerator.validatePasswordForUI(temporaryPassword);
    final roles = _getUserRoles(request);
    final rolesString = roles.join(', ');

    final subject = 'Your Longeviva Registration Request Has Been Approved';
    final body = '''
Dear ${request.name} ${request.surname},

We are pleased to inform you that your registration request for Longeviva has been approved.

LOGIN CREDENTIALS:
Email: ${request.email}
Temporary Password: $temporaryPassword

PROFESSIONAL ROLE(S): $rolesString

SECURITY INFORMATION:
✓ This password meets all security requirements
✓ Strength Level: ${passwordValidation['strengthDescription']} (${passwordValidation['strength']}/100)
✓ Contains: uppercase, lowercase, numbers, and special characters
✓ You MUST change this password on your first login

IMPORTANT SECURITY NOTICE:
- Keep these credentials secure and confidential
- Do not share your login information with anyone
- Delete this email after successfully logging in and changing your password
- Your temporary password will expire if not used within 30 days

Your Profile Summary:
- Role(s): $rolesString
- Specialty: ${request.specialty}
- City of Work: ${request.cityOfWork}
- Country: ${request.countryOfWork}
${request.hasHourlyFeesSet ? '- Hourly Rate: ${request.formattedHourlyFees}' : '- Hourly Rate: Not specified'}
${request.professionalRegistrationNumber != null ? '- Professional Registration: ${request.professionalRegistrationNumber}' : ''}

Next Steps:
1. Log in using your temporary credentials
2. Complete your profile setup
3. Change your password (required on first login)
4. ${request.hasHourlyFeesSet ? 'Review and adjust' : 'Set'} your hourly rates if needed
5. Begin using the platform securely

Based on your professional role(s), you will have access to the appropriate features and tools within the Longeviva platform.

Thank you for joining Longeviva. We look forward to supporting your healthcare practice with our secure platform.

Best regards,
The Longeviva Security Team

---
SECURITY REMINDER: For your protection, we generate strong passwords and require immediate password changes on first login.
If you encounter any issues, contact: info@longeviva.it
''';

    await _emailService.sendCustomEmail(
      to: request.email,
      subject: subject,
      body: body,
    );
  }

  Future<void> _sendRejectionEmail(SignupRequest request, String reason) async {
    final rolesString = _getUserRoles(request).join(', ');

    final subject = 'Your Longeviva Registration Request Update';
    final body = '''
Dear ${request.name} ${request.surname},

We regret to inform you that your registration request for Longeviva has been declined.

Application Details:
- Role(s): $rolesString
- Specialty: ${request.specialty}
- City of Work: ${request.cityOfWork}
- Application Date: ${DateFormat('MMMM d, yyyy').format(request.requestedAt)}
${request.hasHourlyFeesSet ? '- Requested Hourly Rate: ${request.formattedHourlyFees}' : ''}

Reason for Decline:
$reason

Next Steps:
If you believe this decision was made in error or would like to provide additional information, please contact our support team at info@longeviva.it .

You may also submit a new application with updated information if the circumstances have changed.

Best regards,
The Longeviva Team
''';

    await _emailService.sendCustomEmail(
      to: request.email,
      subject: subject,
      body: body,
    );
  }

  // NEW: Helper method to get user roles from request
  List<String> _getUserRoles(SignupRequest request) {
    // Try to get roles from new field first, fallback to legacy single role
    if (request.roles.isNotEmpty) {
      return request.roles;
    } else if (request.role != null && request.role!.isNotEmpty) {
      return [request.role!]; // Legacy single role
    }
    return ['UNKNOWN']; // Fallback
  }

  // UPDATED: Enhanced validation with role-specific requirements and hourlyFees
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

    if (data.name.isEmpty) {
      throw AppException(
        'Name is required',
        translationKey: 'errors.signup.name_required',
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

    if (data.fiscalCode.isEmpty) {
      throw AppException(
        'Fiscal code is required',
        translationKey: 'errors.signup.fiscal_code_required',
      );
    }

    // NEW: Role validation
    if (data.roles.isEmpty) {
      throw AppException(
        'At least one professional role must be selected',
        translationKey: 'errors.signup.roles_required',
      );
    }

    // NEW: Hourly fees validation
    _validateHourlyFees(data.hourlyFees);

    // NEW: Role-specific validation
    _validateRoleSpecificRequirements(data);

    // Location validation
    if (data.address.isEmpty) {
      throw AppException(
        'Address is required',
        translationKey: 'errors.signup.address_required',
      );
    }

    if (data.languagesSpoken.isEmpty) {
      throw AppException(
        'At least one language must be specified',
        translationKey: 'errors.signup.languages_required',
      );
    }

    // Common fields validation
    _validateCommonFields(data);

    // Business logic validation
    _validateBusinessLogic(data);
  }

  // NEW: Hourly fees validation
  void _validateHourlyFees(double hourlyFees) {
    if (hourlyFees < 0) {
      throw AppException(
        'Hourly fees cannot be negative',
        translationKey: 'errors.signup.hourly_fees_negative',
      );
    }

    if (hourlyFees > 1000) {
      throw AppException(
        'Hourly fees cannot exceed €1000',
        translationKey: 'errors.signup.hourly_fees_too_high',
      );
    }
  }

  // NEW: Validate hourly fees value from various input types
  String? _validateHourlyFeesValue(dynamic value) {
    if (value == null) return null;

    double? parsedValue;

    if (value is double) {
      parsedValue = value;
    } else if (value is int) {
      parsedValue = value.toDouble();
    } else if (value is String) {
      try {
        // Handle both comma and dot as decimal separator
        final cleanValue = value.replaceAll(',', '.');
        parsedValue = double.parse(cleanValue);
      } catch (e) {
        return 'Invalid hourly fees format. Please enter a valid number.';
      }
    } else {
      return 'Invalid hourly fees format. Expected a number.';
    }

    // Validate the parsed value
    if (parsedValue < 0) {
      return 'Hourly fees cannot be negative';
    }

    if (parsedValue > 1000) {
      return 'Hourly fees cannot exceed €1000';
    }

    if (parsedValue > 0 && parsedValue < 5) {
      return 'Hourly fees should be at least €5 if specified';
    }

    return null; // Valid
  }

  // NEW: Role-specific validation method
  void _validateRoleSpecificRequirements(SignupData data) {
    // Validate nutritionist and psychologist requirements
    if (data.isNutritionist || data.isPsychologist) {
      if (data.numero_iscrizione_albo == null || data.numero_iscrizione_albo!.isEmpty) {
        final roleNames = <String>[];
        if (data.isNutritionist) roleNames.add('Nutritionist');
        if (data.isPsychologist) roleNames.add('Psychologist');

        throw AppException(
          'Professional registration number (albo) is required for ${roleNames.join(" and ")} role(s)',
          translationKey: 'errors.signup.albo_registration_required',
          translationArgs: {'roles': roleNames.join(' and ')},
        );
      }

      if (data.issuer.isEmpty) {
        throw AppException(
          'Professional qualification issuer is required for albo-registered professionals',
          translationKey: 'errors.signup.issuer_required',
        );
      }

      // Validate surname for roles that require personal info
      if (data.surname.isEmpty) {
        throw AppException(
          'Surname is required for professional roles',
          translationKey: 'errors.signup.surname_required',
        );
      }

      if (data.sex.isEmpty) {
        throw AppException(
          'Sex is required for professional roles',
          translationKey: 'errors.signup.sex_required',
        );
      }

      if (!['M', 'F', 'Male', 'Female'].contains(data.sex)) {
        throw AppException(
          'Sex must be M, F, Male, or Female',
          translationKey: 'errors.signup.invalid_sex',
        );
      }
    }

    // Validate personal trainer requirements
    if (data.isPersonalTrainer) {
      if (data.numero_iscrizione_ente == null || data.numero_iscrizione_ente!.isEmpty) {
        throw AppException(
          'Professional registration number (ente) is required for Personal Trainer role',
          translationKey: 'errors.signup.ente_registration_required',
        );
      }

      if (data.issuer.isEmpty) {
        throw AppException(
          'Certifying organization is required for Personal Trainer role',
          translationKey: 'errors.signup.issuer_required',
        );
      }
    }

    // Validate specialty for certain roles
    if ((data.isNutritionist || data.isPsychologist) &&
        (data.specialty == null || data.specialty!.isEmpty)) {
      throw AppException(
        'Professional specialty is required for this role',
        translationKey: 'errors.signup.specialty_required_for_role',
      );
    }

    // VAT number validation for professional roles
    if ((data.isNutritionist || data.isPsychologist) && data.vatNumber.isEmpty) {
      throw AppException(
        'VAT number is required for professional roles',
        translationKey: 'errors.signup.vat_required',
      );
    }

    // Fiscal code format validation for Italian professionals
    if (data.fiscalCode.isNotEmpty &&
        !RegExp(r'^[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]$').hasMatch(data.fiscalCode.toUpperCase())) {
      throw AppException(
        'Invalid fiscal code format',
        translationKey: 'errors.signup.fiscal_code_invalid',
      );
    }
  }

  void _validateCommonFields(SignupData data) {
    // Phone number format validation (basic)
    if (!RegExp(r'^\+?[\d\s\-\(\)]{8,}$').hasMatch(data.phoneNumber)) {
      throw AppException(
        'Invalid phone number format',
        translationKey: 'errors.signup.phone_invalid',
      );
    }

    // Address validation
    if (data.address.length < 5) {
      throw AppException(
        'Address must be at least 5 characters',
        translationKey: 'errors.signup.address_too_short',
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

    // VAT number format validation (basic)
    if (data.vatNumber.isNotEmpty && data.vatNumber.length < 8) {
      throw AppException(
        'VAT number must be at least 8 characters',
        translationKey: 'errors.signup.vat_invalid_format',
      );
    }
  }

  void _validateBusinessLogic(SignupData data) {
    // Validate birthdate if provided
    if (data.birthdate != null) {
      final now = DateTime.now();
      final age = now.year - data.birthdate!.year;

      if (age < 18) {
        throw AppException(
          'Professional must be at least 18 years old',
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

    // Validate qualification validity if provided
    if (data.qualificationValidity != null) {
      final now = DateTime.now();
      if (data.qualificationValidity!.isBefore(now)) {
        throw AppException(
          'Professional qualification has expired',
          translationKey: 'errors.signup.qualification_expired',
        );
      }
    }
    // Validate role-specific business logic
    _validateRoleSpecificBusinessLogic(data);
  }

  // NEW: Role-specific business logic validation
  void _validateRoleSpecificBusinessLogic(SignupData data) {
    // Validate professional registration numbers format
    if (data.numero_iscrizione_albo != null && data.numero_iscrizione_albo!.isNotEmpty) {
      if (!_validateRegistrationNumber(data.numero_iscrizione_albo!, 'albo')) {
        throw AppException(
          'Invalid professional registration number (albo) format',
          translationKey: 'errors.signup.albo_number_invalid',
        );
      }
    }

    if (data.numero_iscrizione_ente != null && data.numero_iscrizione_ente!.isNotEmpty) {
      if (!_validateRegistrationNumber(data.numero_iscrizione_ente!, 'ente')) {
        throw AppException(
          'Invalid professional registration number (ente) format',
          translationKey: 'errors.signup.ente_number_invalid',
        );
      }
    }

    // Check for conflicting role requirements
    if (data.roles.length > 1) {
      // Ensure compatible roles are selected together
      final hasAlboRole = data.isNutritionist || data.isPsychologist;
      final hasEnteRole = data.isPersonalTrainer;

      if (hasAlboRole && hasEnteRole) {
        // Both albo and ente roles - ensure both registrations are provided
        if ((data.numero_iscrizione_albo == null || data.numero_iscrizione_albo!.isEmpty) ||
            (data.numero_iscrizione_ente == null || data.numero_iscrizione_ente!.isEmpty)) {
          throw AppException(
            'Multiple professional roles require all corresponding registration numbers',
            translationKey: 'errors.signup.multiple_roles_registration_required',
          );
        }
      }
    }
  }

  // NEW: Validate professional registration numbers
  bool _validateRegistrationNumber(String number, String type) {
    if (number.isEmpty) return false;

    switch (type) {
      case 'albo':
      // Basic validation for albo numbers (adjust based on actual requirements)
        return number.length >= 3 && RegExp(r'^[A-Z0-9]+$').hasMatch(number.toUpperCase());
      case 'ente':
      // Basic validation for ente numbers (adjust based on actual requirements)
        return number.length >= 3;
      default:
        return true;
    }
  }
}