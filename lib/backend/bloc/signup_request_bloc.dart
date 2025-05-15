import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/utils/error_handler.dart';
import '../controllers/signup_request_controller.dart';
import '../models/doctor/sign_up_data.dart';
import '../models/signup_request_model.dart';


// Events
abstract class SignupRequestEvent {}

class FetchAllSignupRequests extends SignupRequestEvent {}

class FetchSignupRequestsByStatus extends SignupRequestEvent {
  final String status;

  FetchSignupRequestsByStatus(this.status);
}

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
  final String googleEmail;

  CheckEmailsExistence({required this.email, required this.googleEmail});
}

// Add to the events in signup_request_bloc.dart
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

// States
abstract class SignupRequestState {}

class SignupRequestInitial extends SignupRequestState {}

class SignupRequestLoading extends SignupRequestState {}

class SignupRequestsLoaded extends SignupRequestState {
  final List<SignupRequest> requests;

  SignupRequestsLoaded(this.requests);
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

class SignupRequestRejected extends SignupRequestState {
  final String id;

  SignupRequestRejected(this.id);
}

class SignupRequestError extends SignupRequestState {
  final String message;
  final String? translationKey;
  final Map<String, String>? translationArgs;

  SignupRequestError(
      this.message, {
        this.translationKey,
        this.translationArgs,
      });
}

class EmailsExistenceChecked extends SignupRequestState {
  final Map<String, Map<String, bool>> result;

  EmailsExistenceChecked(this.result);

  bool get primaryEmailExistsInDoctors => result['primaryEmail']?['existsInDoctors'] ?? false;
  bool get primaryEmailExistsInSignupRequests => result['primaryEmail']?['existsInSignupRequests'] ?? false;
  bool get googleEmailExistsInDoctors => result['googleEmail']?['existsInDoctors'] ?? false;
  bool get googleEmailExistsInSignupRequests => result['googleEmail']?['existsInSignupRequests'] ?? false;

  bool get anyEmailExists =>
      primaryEmailExistsInDoctors ||
          primaryEmailExistsInSignupRequests ||
          googleEmailExistsInDoctors ||
          googleEmailExistsInSignupRequests;

  String getPrimaryEmailErrorMessage() {
    if (primaryEmailExistsInDoctors) {
      return 'This email is already registered in our system. Please log in instead.';
    } else if (primaryEmailExistsInSignupRequests) {
      return 'There is already a registration request with this email. Please contact support for '
          'assistance.';
    }
    return '';
  }

  String getGoogleEmailErrorMessage() {
    if (googleEmailExistsInDoctors) {
      return 'This Google email is already registered in our system. Please log in instead.';
    } else if (googleEmailExistsInSignupRequests) {
      return 'There is already a registration request with this Google email. Please contact support for '
          'assistance.';
    }
    return '';
  }

  String getCombinedErrorMessage() {
    if (primaryEmailExistsInDoctors || primaryEmailExistsInSignupRequests) {
      if (googleEmailExistsInDoctors || googleEmailExistsInSignupRequests) {
        return 'Both email addresses are already in use. Please use different email addresses or contact support.';
      }
      return getPrimaryEmailErrorMessage();
    } else if (googleEmailExistsInDoctors || googleEmailExistsInSignupRequests) {
      return getGoogleEmailErrorMessage();
    }
    return '';
  }
}

// BLoC
class SignupRequestBloc extends Bloc<SignupRequestEvent, SignupRequestState> {
  final SignupRequestController _controller;

  SignupRequestBloc({
    SignupRequestController? controller,
  }) : _controller = controller ?? SignupRequestController(),
        super(SignupRequestInitial()) {
    on<FetchAllSignupRequests>(_handleFetchAllSignupRequests);
    on<FetchSignupRequestsByStatus>(_handleFetchSignupRequestsByStatus);
    on<FetchSignupRequestById>(_handleFetchSignupRequestById);
    on<CreateSignupRequest>(_handleCreateSignupRequest);
    on<ApproveSignupRequestWithPassword>(_handleApproveSignupRequestWithPassword);
    on<RejectSignupRequestWithReason>(_handleRejectSignupRequestWithReason);
    on<CheckEmailsExistence>(_handleCheckEmailsExistence);
  }

  Future<void> _handleCheckEmailsExistence(
      CheckEmailsExistence event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final result = await _controller.checkDetailedEmailsExist(
        event.email,
        event.googleEmail,
      );
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

  Future<void> _handleCreateSignupRequest(
      CreateSignupRequest event,
      Emitter<SignupRequestState> emit,
      ) async {
    emit(SignupRequestLoading());

    try {
      final emailsExistenceResult = await _controller.checkDetailedEmailsExist(
        event.data.email,
        event.data.googleEmail,
      );

      final emailsState = EmailsExistenceChecked(emailsExistenceResult);
      if (emailsState.anyEmailExists) {
        emit(emailsState);
        return;
      }

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
}