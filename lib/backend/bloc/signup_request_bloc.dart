import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../shared/utils/error_handler.dart';
import '../controllers/signup_request_controller.dart';
import '../models/doctor/sign_up_data.dart';
import '../models/signup_request_model.dart';
import '../repositories/audit_log_repository.dart';

// ===== EVENTS =====
abstract class SignupRequestEvent {}

class FetchAllSignupRequests extends SignupRequestEvent {}

class FetchSignupRequestsByStatus extends SignupRequestEvent {
  final String status;

  FetchSignupRequestsByStatus(this.status);
}

// NEW: Fetch signup requests by role
class FetchSignupRequestsByRole extends SignupRequestEvent {
  final String role;

  FetchSignupRequestsByRole(this.role);
}

// NEW: Fetch signup requests statistics by role
class FetchSignupRequestsStatsByRole extends SignupRequestEvent {}

class FetchSignupRequestById extends SignupRequestEvent {
  final String id;

  FetchSignupRequestById(this.id);
}

class CreateSignupRequest extends SignupRequestEvent {
  final SignupData data;

  CreateSignupRequest(this.data);
}

class CheckEmailsExistence extends SignupRequestEvent {
  final String email;

  CheckEmailsExistence({required this.email});
}

class ResetEmailsCheckState extends SignupRequestEvent {}

class RejectSignupRequestWithReason extends SignupRequestEvent {
  final String id;
  final String reason;

  RejectSignupRequestWithReason({required this.id, required this.reason});
}

class ApproveSignupRequestWithPassword extends SignupRequestEvent {
  final String id;
  final String temporaryPassword;

  ApproveSignupRequestWithPassword({
    required this.id,
    required this.temporaryPassword,
  });
}

// NEW: Batch approve multiple requests
class BatchApproveSignupRequests extends SignupRequestEvent {
  final List<String> requestIds;
  final String defaultPassword;

  BatchApproveSignupRequests({
    required this.requestIds,
    required this.defaultPassword,
  });
}

class BatchRejectSignupRequests extends SignupRequestEvent {
  final List<String> requestIds;
  final String reason;
  BatchRejectSignupRequests({required this.requestIds, required this.reason});
}

// NEW: Update professional information for a request
class UpdateSignupRequestProfessionalInfo extends SignupRequestEvent {
  final String requestId;
  final Map<String, dynamic> professionalInfo;

  UpdateSignupRequestProfessionalInfo({
    required this.requestId,
    required this.professionalInfo,
  });
}

// NEW: Validate signup data (for real-time validation)
class ValidateSignupData extends SignupRequestEvent {
  final SignupData data;

  ValidateSignupData(this.data);
}

// ===== STATES =====
abstract class SignupRequestState {}

class SignupRequestInitial extends SignupRequestState {}

class SignupRequestLoading extends SignupRequestState {}

class SignupRequestsLoaded extends SignupRequestState {
  final List<SignupRequest> requests;

  SignupRequestsLoaded(this.requests);
}

// NEW: State for signup requests statistics by role
class SignupRequestsStatsByRoleLoaded extends SignupRequestState {
  final Map<String, int> stats;

  SignupRequestsStatsByRoleLoaded(this.stats);
}

class SignupRequestLoaded extends SignupRequestState {
  final SignupRequest request;

  SignupRequestLoaded(this.request);
}

class SignupRequestCreated extends SignupRequestState {
  final SignupRequest request;

  SignupRequestCreated(this.request);
}

class SignupRequestApproved extends SignupRequestState {
  final String id;

  SignupRequestApproved(this.id);
}

// NEW: State for batch approval results
class SignupRequestsBatchApproved extends SignupRequestState {
  final List<String> successfulApprovals;
  final List<String> failedApprovals;

  SignupRequestsBatchApproved({
    required this.successfulApprovals,
    required this.failedApprovals,
  });

  int get totalSuccessful => successfulApprovals.length;
  int get totalFailed => failedApprovals.length;
  int get totalProcessed => totalSuccessful + totalFailed;
  bool get hasFailures => failedApprovals.isNotEmpty;
}

class SignupRequestsBatchRejected extends SignupRequestState {
  final List<String> successfulRejections;
  final List<String> failedRejections;
  SignupRequestsBatchRejected({
    required this.successfulRejections,
    required this.failedRejections,
  });
  int get totalSuccessful => successfulRejections.length;
  int get totalFailed => failedRejections.length;
  bool get hasFailures => failedRejections.isNotEmpty;
}

class SignupRequestRejected extends SignupRequestState {
  final String id;

  SignupRequestRejected(this.id);
}

// NEW: State for professional info update
class SignupRequestProfessionalInfoUpdated extends SignupRequestState {
  final String requestId;

  SignupRequestProfessionalInfoUpdated(this.requestId);
}

// ENHANCED: Better error state with validation support
class SignupRequestError extends SignupRequestState {
  final String message;
  final String? translationKey;
  final Map<String, String>? translationArgs;
  final List<String>? validationErrors; // NEW: For validation error lists

  SignupRequestError(
      this.message, {
        this.translationKey,
        this.translationArgs,
        this.validationErrors,
      });
}

// NEW: State for signup data validation results
class SignupDataValidated extends SignupRequestState {
  final List<String> validationErrors;
  final bool isValid;

  SignupDataValidated({
    required this.validationErrors,
    required this.isValid,
  });
}

// ENHANCED: Email existence check with better role awareness
// UPDATED: EmailsExistenceChecked without googleEmail references
class EmailsExistenceChecked extends SignupRequestState {
  final Map<String, Map<String, bool>> result;

  EmailsExistenceChecked(this.result);

  bool get primaryEmailExistsInDoctors => result['primaryEmail']?['existsInDoctors'] ?? false;
  bool get primaryEmailExistsInSignupRequests => result['primaryEmail']?['existsInSignupRequests'] ?? false;
  bool get primaryEmailExistsInFirebaseAuth => result['primaryEmail']?['existsInFirebaseAuth'] ?? false;

  bool get anyEmailExists =>
      primaryEmailExistsInDoctors ||
          primaryEmailExistsInSignupRequests ||
          primaryEmailExistsInFirebaseAuth;

  String getPrimaryEmailErrorMessage() {
    if (primaryEmailExistsInDoctors) {
      return 'This email is already registered in our system. Please log in instead.';
    } else if (primaryEmailExistsInSignupRequests) {
      return 'There is already a registration request with this email. Please contact support for assistance.';
    } else if (primaryEmailExistsInFirebaseAuth) {
      return 'This email is already registered in Firebase Auth. Please contact support.';
    }
    return '';
  }
}

// ===== BLOC =====
class SignupRequestBloc extends Bloc<SignupRequestEvent, SignupRequestState> {
  final SignupRequestController _controller;

  SignupRequestBloc({
    SignupRequestController? controller,
  }) : _controller = controller ?? SignupRequestController(),
        super(SignupRequestInitial()) {
    // Existing handlers
    on<FetchAllSignupRequests>(_handleFetchAllSignupRequests);
    on<FetchSignupRequestsByStatus>(_handleFetchSignupRequestsByStatus);
    on<FetchSignupRequestById>(_handleFetchSignupRequestById);
    on<CreateSignupRequest>(_handleCreateSignupRequest);
    on<ApproveSignupRequestWithPassword>(_handleApproveSignupRequestWithPassword);
    on<RejectSignupRequestWithReason>(_handleRejectSignupRequestWithReason);
    on<CheckEmailsExistence>(_handleCheckEmailsExistence);
    on<ResetEmailsCheckState>(_handleResetEmailsCheckState);

    // NEW: Handlers for new functionality
    on<FetchSignupRequestsByRole>(_handleFetchSignupRequestsByRole);
    on<FetchSignupRequestsStatsByRole>(_handleFetchSignupRequestsStatsByRole);
    on<BatchApproveSignupRequests>(_handleBatchApproveSignupRequests);
    on<UpdateSignupRequestProfessionalInfo>(_handleUpdateSignupRequestProfessionalInfo);
    on<ValidateSignupData>(_handleValidateSignupData);
    on<BatchRejectSignupRequests>(_handleBatchRejectSignupRequests);
  }

  // ===== EXISTING HANDLERS (Enhanced) =====

  // UPDATED: Check email existence without googleEmail
  Future<void> _handleCheckEmailsExistence(
      CheckEmailsExistence event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final result = await _controller.checkDetailedEmailsExist(event.email);
      emit(EmailsExistenceChecked(result));
    } catch (e) {
      ErrorHandler.logError('Error checking email existence', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.general.operation_failed',
          translationArgs: e.translationArgs ?? {'error': 'check email availability'},
        ));
      } else {
        emit(SignupRequestError(
          'Failed to check email availability',
          translationKey: 'errors.general.operation_failed',
          translationArgs: {'error': 'check email availability'},
        ));
      }
    }
  }

  Future<void> _handleResetEmailsCheckState(
      ResetEmailsCheckState event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestInitial());
  }

  Future<void> _handleApproveSignupRequestWithPassword(
      ApproveSignupRequestWithPassword event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    ErrorHandler.logDebug('Handling ApproveSignupRequestWithPassword event for id ${event.id} with password ${event.temporaryPassword}');

    try {
      final success = await _controller.approveSignupRequestWithPassword(
        event.id,
        event.temporaryPassword,
      );

      if (success) {
        emit(SignupRequestApproved(event.id));
        try {
          final user = firebase_auth.FirebaseAuth.instance.currentUser;
          await AuditLogRepository().logAction(
            adminEmail: user?.email ?? 'unknown',
            adminName: user?.displayName ?? user?.email ?? 'Admin',
            action: 'approve',
            requestId: event.id,
          );
        } catch (_) {}

        // Refresh the list
        final requests = await _controller.getAllSignupRequests();
        emit(SignupRequestsLoaded(requests));
      } else {
        emit(SignupRequestError(
          'Failed to approve signup request',
          translationKey: 'errors.signup.approval_failed',
        ));
      }
    } catch (e) {
      ErrorHandler.logError('Error approving signup request', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.signup.approval_failed',
          translationArgs: e.translationArgs,
        ));
      } else {
        emit(SignupRequestError(
          'Failed to approve signup request',
          translationKey: 'errors.signup.approval_failed',
        ));
      }
    }
  }

  Future<void> _handleRejectSignupRequestWithReason(
      RejectSignupRequestWithReason event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final success = await _controller.rejectSignupRequestWithReason(
        event.id,
        event.reason,
      );

      if (success) {
        emit(SignupRequestRejected(event.id));
        try {
          final user = firebase_auth.FirebaseAuth.instance.currentUser;
          await AuditLogRepository().logAction(
            adminEmail: user?.email ?? 'unknown',
            adminName: user?.displayName ?? user?.email ?? 'Admin',
            action: 'reject',
            requestId: event.id,
            notes: event.reason.isNotEmpty ? event.reason : null,
          );
        } catch (_) {}

        // Refresh the list
        final requests = await _controller.getAllSignupRequests();
        emit(SignupRequestsLoaded(requests));
      } else {
        emit(SignupRequestError(
          'Failed to reject signup request',
          translationKey: 'errors.signup.rejection_failed',
        ));
      }
    } catch (e) {
      ErrorHandler.logError('Error rejecting signup request', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.signup.rejection_failed',
          translationArgs: e.translationArgs,
        ));
      } else {
        emit(SignupRequestError(
          'Failed to reject signup request',
          translationKey: 'errors.signup.rejection_failed',
        ));
      }
    }
  }

  Future<void> _handleFetchAllSignupRequests(
      FetchAllSignupRequests event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final requests = await _controller.getAllSignupRequests();
      emit(SignupRequestsLoaded(requests));
    } catch (e) {
      ErrorHandler.logError('Error fetching all signup requests', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.general.operation_failed',
          translationArgs: e.translationArgs ?? {'error': 'load signup requests'},
        ));
      } else {
        emit(SignupRequestError(
          'Failed to load signup requests',
          translationKey: 'errors.general.operation_failed',
          translationArgs: {'error': 'load signup requests'},
        ));
      }
    }
  }

  Future<void> _handleFetchSignupRequestsByStatus(
      FetchSignupRequestsByStatus event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final requests = await _controller.getSignupRequestsByStatus(event.status);
      emit(SignupRequestsLoaded(requests));
    } catch (e) {
      ErrorHandler.logError('Error fetching signup requests by status', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.general.operation_failed',
          translationArgs: e.translationArgs ?? {'error': 'load signup requests'},
        ));
      } else {
        emit(SignupRequestError(
          'Failed to load signup requests',
          translationKey: 'errors.general.operation_failed',
          translationArgs: {'error': 'load signup requests'},
        ));
      }
    }
  }

  Future<void> _handleFetchSignupRequestById(
      FetchSignupRequestById event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final request = await _controller.getSignupRequestById(event.id);
      if (request != null) {
        emit(SignupRequestLoaded(request));
      } else {
        emit(SignupRequestError(
          'Signup request not found',
          translationKey: 'errors.signup.request_not_found',
        ));
      }
    } catch (e) {
      ErrorHandler.logError('Error fetching signup request by ID', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.general.operation_failed',
          translationArgs: e.translationArgs ?? {'error': 'load signup request'},
        ));
      } else {
        emit(SignupRequestError(
          'Failed to load signup request',
          translationKey: 'errors.general.operation_failed',
          translationArgs: {'error': 'load signup request'},
        ));
      }
    }
  }

  // ENHANCED: Better validation and error handling for create request
  // ENHANCED: Better validation and error handling for create request
  Future<void> _handleCreateSignupRequest(
      CreateSignupRequest event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      // ENHANCED: Validate signup data first
      final validationErrors = _controller.getSignupDataValidationErrors(event.data);
      if (validationErrors.isNotEmpty) {
        emit(SignupRequestError(
          'Validation failed',
          translationKey: 'errors.signup.validation_failed',
          validationErrors: validationErrors,
        ));
        return;
      }

      // UPDATED: Check email existence (removed googleEmail)
      final emailsExistenceResult = await _controller.checkDetailedEmailsExist(event.data.email);
      final emailsState = EmailsExistenceChecked(emailsExistenceResult);

      if (emailsState.anyEmailExists) {
        emit(emailsState);
        return;
      }

      // Create the request
      final request = await _controller.createSignupRequest(event.data);
      emit(SignupRequestCreated(request));
    } catch (e) {
      ErrorHandler.logError('Error creating signup request', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.general.operation_failed',
          translationArgs: e.translationArgs ?? {'error': 'create signup request'},
        ));
      } else {
        emit(SignupRequestError(
          'Failed to create signup request',
          translationKey: 'errors.general.operation_failed',
          translationArgs: {'error': 'create signup request'},
        ));
      }
    }
  }

  // ===== NEW HANDLERS =====

  Future<void> _handleFetchSignupRequestsByRole(
      FetchSignupRequestsByRole event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final requests = await _controller.getSignupRequestsByRole(event.role);
      emit(SignupRequestsLoaded(requests));
    } catch (e) {
      ErrorHandler.logError('Error fetching signup requests by role', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.general.operation_failed',
          translationArgs: e.translationArgs ?? {'error': 'load signup requests by role'},
        ));
      } else {
        emit(SignupRequestError(
          'Failed to load signup requests by role',
          translationKey: 'errors.general.operation_failed',
          translationArgs: {'error': 'load signup requests by role'},
        ));
      }
    }
  }

  Future<void> _handleFetchSignupRequestsStatsByRole(
      FetchSignupRequestsStatsByRole event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final stats = await _controller.getSignupRequestsStatsByRole();
      emit(SignupRequestsStatsByRoleLoaded(stats));
    } catch (e) {
      ErrorHandler.logError('Error fetching signup requests stats by role', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.general.operation_failed',
          translationArgs: e.translationArgs ?? {'error': 'load signup statistics'},
        ));
      } else {
        emit(SignupRequestError(
          'Failed to load signup statistics',
          translationKey: 'errors.general.operation_failed',
          translationArgs: {'error': 'load signup statistics'},
        ));
      }
    }
  }

  Future<void> _handleBatchApproveSignupRequests(
      BatchApproveSignupRequests event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final successfulApprovals = await _controller.batchApproveSignupRequests(
        event.requestIds,
        event.defaultPassword,
      );

      final failedApprovals = event.requestIds
          .where((id) => !successfulApprovals.contains(id))
          .toList();

      emit(SignupRequestsBatchApproved(
        successfulApprovals: successfulApprovals,
        failedApprovals: failedApprovals,
      ));
      try {
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        await AuditLogRepository().logAction(
          adminEmail: user?.email ?? 'unknown',
          adminName: user?.displayName ?? user?.email ?? 'Admin',
          action: 'batch_approve',
          batchCount: successfulApprovals.length,
          notes: 'Batch: ${successfulApprovals.length} approvate',
        );
      } catch (_) {}

      // Refresh the list
      final requests = await _controller.getAllSignupRequests();
      emit(SignupRequestsLoaded(requests));
    } catch (e) {
      ErrorHandler.logError('Error in batch approval', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.signup.batch_approval_failed',
          translationArgs: e.translationArgs,
        ));
      } else {
        emit(SignupRequestError(
          'Failed to approve signup requests in batch',
          translationKey: 'errors.signup.batch_approval_failed',
        ));
      }
    }
  }

  Future<void> _handleUpdateSignupRequestProfessionalInfo(
      UpdateSignupRequestProfessionalInfo event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final success = await _controller.updateSignupRequestProfessionalInfo(
        event.requestId,
        event.professionalInfo,
      );

      if (success) {
        emit(SignupRequestProfessionalInfoUpdated(event.requestId));

        // Refresh the specific request
        final request = await _controller.getSignupRequestById(event.requestId);
        if (request != null) {
          emit(SignupRequestLoaded(request));
        }
      } else {
        emit(SignupRequestError(
          'Failed to update professional information',
          translationKey: 'errors.signup.update_professional_info_failed',
        ));
      }
    } catch (e) {
      ErrorHandler.logError('Error updating professional information', e);

      if (e is AppException) {
        emit(SignupRequestError(
          e.message,
          translationKey: e.translationKey ?? 'errors.signup.update_professional_info_failed',
          translationArgs: e.translationArgs,
        ));
      } else {
        emit(SignupRequestError(
          'Failed to update professional information',
          translationKey: 'errors.signup.update_professional_info_failed',
        ));
      }
    }
  }

  Future<void> _handleValidateSignupData(
      ValidateSignupData event,
      Emitter<SignupRequestState> emit,
      ) async {
    try {
      final validationErrors = _controller.getSignupDataValidationErrors(event.data);
      emit(SignupDataValidated(
        validationErrors: validationErrors,
        isValid: validationErrors.isEmpty,
      ));
    } catch (e) {
      ErrorHandler.logError('Error validating signup data', e);
      emit(SignupRequestError(
        'Failed to validate signup data',
        translationKey: 'errors.signup.validation_failed',
      ));
    }
  }

  Future<void> _handleBatchRejectSignupRequests(
      BatchRejectSignupRequests event,
      Emitter<SignupRequestState> emit,
  ) async {
    emit(SignupRequestLoading());
    try {
      final successfulRejections = await _controller.batchRejectSignupRequests(
        event.requestIds,
        event.reason,
      );
      final failedRejections = event.requestIds
          .where((id) => !successfulRejections.contains(id))
          .toList();
      emit(SignupRequestsBatchRejected(
        successfulRejections: successfulRejections,
        failedRejections: failedRejections,
      ));
      try {
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        await AuditLogRepository().logAction(
          adminEmail: user?.email ?? 'unknown',
          adminName: user?.displayName ?? user?.email ?? 'Admin',
          action: 'batch_reject',
          batchCount: successfulRejections.length,
          notes: event.reason.isNotEmpty ? event.reason : null,
        );
      } catch (_) {}
      final requests = await _controller.getAllSignupRequests();
      emit(SignupRequestsLoaded(requests));
    } catch (e) {
      ErrorHandler.logError('Error in batch rejection', e);
      emit(SignupRequestError('Failed to reject signup requests in batch'));
    }
  }
}