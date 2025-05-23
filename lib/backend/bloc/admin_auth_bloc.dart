// lib/backend/bloc/admin_auth_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../controllers/admin_controller.dart';
import '../models/admin_model.dart';
import '../../shared/utils/error_handler.dart';

// Admin Auth Events
abstract class AdminAuthEvent {}

class AdminLoginRequested extends AdminAuthEvent {
  final String email;
  final String password;
  final bool rememberMe;

  AdminLoginRequested({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });
}

class AdminLogoutRequested extends AdminAuthEvent {}

class CheckAdminAuthStatus extends AdminAuthEvent {}

class AdminRequestPasswordReset extends AdminAuthEvent {
  final String email;

  AdminRequestPasswordReset({required this.email});
}

// Admin Auth States
abstract class AdminAuthState {}

class AdminAuthInitial extends AdminAuthState {}

class AdminAuthLoading extends AdminAuthState {}

class AdminAuthAuthenticated extends AdminAuthState {
  final Admin admin;

  AdminAuthAuthenticated({required this.admin});

  @override
  String toString() => 'AdminAuthAuthenticated: ${admin.email}';
}

class AdminAuthUnauthenticated extends AdminAuthState {
  @override
  String toString() => 'AdminAuthUnauthenticated';
}

class AdminAuthFailure extends AdminAuthState {
  final String error;
  final String? translationKey;
  final Map<String, String>? translationArgs;

  AdminAuthFailure({
    required this.error,
    this.translationKey,
    this.translationArgs,
  });

  @override
  String toString() => 'AdminAuthFailure: $error';
}

class AdminPasswordResetSent extends AdminAuthState {
  final String email;

  AdminPasswordResetSent({required this.email});
}

// Admin Auth BLoC
class AdminAuthBloc extends Bloc<AdminAuthEvent, AdminAuthState> {
  final AdminController adminController;
  Admin? _currentAdmin;
  bool _isProcessingAuth = false;

  AdminAuthBloc({required this.adminController}) : super(AdminAuthInitial()) {
    on<AdminLoginRequested>(_handleAdminLoginRequested);
    on<AdminLogoutRequested>(_handleAdminLogoutRequested);
    on<CheckAdminAuthStatus>(_handleCheckAdminAuthStatus);
    on<AdminRequestPasswordReset>(_handleAdminRequestPasswordReset);
  }

  Admin? get currentAdmin => _currentAdmin;

  Future<void> _handleAdminLoginRequested(
      AdminLoginRequested event,
      Emitter<AdminAuthState> emit,
      ) async {
    if (_isProcessingAuth) {
      ErrorHandler.logDebug('AdminAuthBloc: Login already in progress, ignoring');
      return;
    }

    _isProcessingAuth = true;
    ErrorHandler.logDebug('AdminAuthBloc: Processing login request for ${event.email}');

    emit(AdminAuthLoading());

    try {
      final admin = await adminController.loginAdmin(
        email: event.email,
        password: event.password,
        rememberMe: event.rememberMe,
      );

      if (admin != null) {
        _currentAdmin = admin;
        ErrorHandler.logDebug('AdminAuthBloc: Login successful, emitting AdminAuthAuthenticated');
        emit(AdminAuthAuthenticated(admin: admin));
      } else {
        ErrorHandler.logWarning('AdminAuthBloc: Login returned null admin');
        _currentAdmin = null;
        emit(AdminAuthFailure(
          error: 'Invalid admin credentials',
          translationKey: 'errors.auth.invalid_admin_credentials',
        ));
      }
    } catch (e) {
      ErrorHandler.logError('AdminAuthBloc: Login error', e);
      _currentAdmin = null;

      String errorMessage = e.toString();
      String? translationKey;
      Map<String, String>? translationArgs;

      if (e is AppException) {
        translationKey = e.translationKey;
        translationArgs = e.translationArgs;
      } else if (errorMessage.contains('Invalid argument(s):')) {
        errorMessage = errorMessage.split('Invalid argument(s):')[1].trim();
      }

      emit(AdminAuthFailure(
        error: errorMessage,
        translationKey: translationKey ?? 'errors.auth.authentication_failed',
        translationArgs: translationArgs,
      ));
    } finally {
      _isProcessingAuth = false;
    }
  }

  Future<void> _handleAdminLogoutRequested(
      AdminLogoutRequested event,
      Emitter<AdminAuthState> emit,
      ) async {
    if (_isProcessingAuth) return;
    _isProcessingAuth = true;

    ErrorHandler.logDebug('AdminAuthBloc: Processing logout request');
    emit(AdminAuthLoading());

    try {
      await adminController.logoutAdmin();
      _currentAdmin = null;
      ErrorHandler.logDebug('AdminAuthBloc: Logout successful, emitting AdminAuthUnauthenticated');
      emit(AdminAuthUnauthenticated());
    } catch (e) {
      ErrorHandler.logError('AdminAuthBloc: Logout error', e);
      emit(AdminAuthFailure(
        error: e.toString(),
        translationKey: 'errors.auth.logout_failed',
        translationArgs: {'error': e.toString()},
      ));
    } finally {
      _isProcessingAuth = false;
    }
  }

  Future<void> _handleCheckAdminAuthStatus(
      CheckAdminAuthStatus event,
      Emitter<AdminAuthState> emit,
      ) async {
    if (_isProcessingAuth) {
      ErrorHandler.logDebug('AdminAuthBloc: Auth check already in progress');
      return;
    }

    _isProcessingAuth = true;
    ErrorHandler.logDebug('AdminAuthBloc: Checking admin auth status');

    emit(AdminAuthLoading());

    try {
      // Check if we already have a cached admin
      if (_currentAdmin != null) {
        ErrorHandler.logDebug('AdminAuthBloc: Using cached admin: ${_currentAdmin!.email}');
        emit(AdminAuthAuthenticated(admin: _currentAdmin!));
        return;
      }

      // Check with controller
      final admin = await adminController.checkAdminAuth();

      if (admin != null) {
        _currentAdmin = admin;
        ErrorHandler.logDebug('AdminAuthBloc: Auth check successful, emitting AdminAuthAuthenticated for: ${admin.email}');
        emit(AdminAuthAuthenticated(admin: admin));
      } else {
        _currentAdmin = null;
        ErrorHandler.logDebug('AdminAuthBloc: Auth check failed, emitting AdminAuthUnauthenticated');
        emit(AdminAuthUnauthenticated());
      }
    } catch (e) {
      ErrorHandler.logError('AdminAuthBloc: Auth check error', e);
      _currentAdmin = null;
      ErrorHandler.logDebug('AdminAuthBloc: Auth check error, emitting AdminAuthUnauthenticated');
      emit(AdminAuthUnauthenticated());
    } finally {
      _isProcessingAuth = false;
    }
  }

  Future<void> _handleAdminRequestPasswordReset(
      AdminRequestPasswordReset event,
      Emitter<AdminAuthState> emit,
      ) async {
    try {
      ErrorHandler.logDebug('AdminAuthBloc: Processing password reset request for ${event.email}');
      emit(AdminAuthLoading());

      await adminController.sendPasswordResetEmail(event.email);

      ErrorHandler.logDebug('AdminAuthBloc: Password reset email sent successfully');
      emit(AdminPasswordResetSent(email: event.email));
    } catch (e) {
      ErrorHandler.logError('AdminAuthBloc: Password reset error', e);

      String errorMessage = e.toString();
      String? translationKey;
      Map<String, String>? translationArgs;

      if (e is AppException) {
        translationKey = e.translationKey;
        translationArgs = e.translationArgs;
      }

      emit(AdminAuthFailure(
        error: errorMessage,
        translationKey: translationKey ?? 'errors.auth.password_reset_failed',
        translationArgs: translationArgs,
      ));
    }
  }

  /// Force refresh auth state (useful for debugging)
  void forceRefreshAuthState() {
    ErrorHandler.logDebug('AdminAuthBloc: Force refreshing auth state');
    add(CheckAdminAuthStatus());
  }

  /// Get current state info for debugging
  String getStateInfo() {
    return 'Current State: ${state.runtimeType}, Cached Admin: ${_currentAdmin?.email ?? 'null'}, Processing: $_isProcessingAuth';
  }
}