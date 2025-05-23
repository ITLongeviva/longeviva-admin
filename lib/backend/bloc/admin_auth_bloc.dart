// lib/backend/bloc/admin_auth_bloc.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
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

class RefreshAdminAuth extends AdminAuthEvent {}

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
  bool _isProcessingLogin = false; // Separate flag for login
  DateTime? _lastSuccessfulAuth;
  DateTime? _lastAuthCheck;
  Timer? _authCheckTimer;
  Completer<Admin?>? _ongoingAuthCheck;

  AdminAuthBloc({required this.adminController}) : super(AdminAuthInitial()) {
    on<AdminLoginRequested>(_handleAdminLoginRequested);
    on<AdminLogoutRequested>(_handleAdminLogoutRequested);
    on<CheckAdminAuthStatus>(_handleCheckAdminAuthStatus);
    on<AdminRequestPasswordReset>(_handleAdminRequestPasswordReset);
    on<RefreshAdminAuth>(_handleRefreshAdminAuth);
  }

  Admin? get currentAdmin => _currentAdmin;

  @override
  Future<void> close() {
    _authCheckTimer?.cancel();
    _ongoingAuthCheck?.complete(null);
    return super.close();
  }

  Future<void> _handleAdminLoginRequested(
      AdminLoginRequested event,
      Emitter<AdminAuthState> emit,
      ) async {
    if (_isProcessingLogin) {
      ErrorHandler.logDebug('AdminAuthBloc: Login already in progress, ignoring');
      return;
    }

    _isProcessingLogin = true;
    ErrorHandler.logDebug('AdminAuthBloc: Processing login request for ${event.email}');

    // Cancel any ongoing auth checks during login
    _cancelOngoingAuthCheck();

    emit(AdminAuthLoading());

    try {
      final admin = await adminController.loginAdmin(
        email: event.email,
        password: event.password,
        rememberMe: event.rememberMe,
      );

      if (admin != null) {
        _currentAdmin = admin;
        _lastSuccessfulAuth = DateTime.now();
        _lastAuthCheck = DateTime.now();

        ErrorHandler.logDebug('AdminAuthBloc: Login successful, emitting AdminAuthAuthenticated');
        emit(AdminAuthAuthenticated(admin: admin));

        // For Windows, set up a periodic auth refresh to maintain session
        if (defaultTargetPlatform == TargetPlatform.windows) {
          _setupPeriodicAuthRefresh();
        }
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
      _isProcessingLogin = false;
    }
  }

  Future<void> _handleAdminLogoutRequested(
      AdminLogoutRequested event,
      Emitter<AdminAuthState> emit,
      ) async {
    if (_isProcessingAuth || _isProcessingLogin) return;

    _isProcessingAuth = true;
    _cancelOngoingAuthCheck();

    ErrorHandler.logDebug('AdminAuthBloc: Processing logout request');
    emit(AdminAuthLoading());

    try {
      await adminController.logoutAdmin();
      _currentAdmin = null;
      _lastSuccessfulAuth = null;
      _lastAuthCheck = null;
      _authCheckTimer?.cancel();
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

    // Don't check auth if we're in the middle of login
    if (_isProcessingLogin) {
      ErrorHandler.logDebug('AdminAuthBloc: Login in progress, skipping auth check');
      return;
    }

    // If we're already authenticated and it's recent, don't check again
    if (_currentAdmin != null &&
        _lastSuccessfulAuth != null &&
        DateTime.now().difference(_lastSuccessfulAuth!).inMinutes < 5) {
      ErrorHandler.logDebug('AdminAuthBloc: Using cached admin (recent auth): ${_currentAdmin!.email}');
      emit(AdminAuthAuthenticated(admin: _currentAdmin!));
      return;
    }

    if (_isProcessingAuth) {
      ErrorHandler.logDebug('AdminAuthBloc: Auth check already in progress, waiting...');

      // Wait for the ongoing auth check to complete
      if (_ongoingAuthCheck != null) {
        final result = await _ongoingAuthCheck!.future;
        if (result != null) {
          emit(AdminAuthAuthenticated(admin: result));
        } else {
          emit(AdminAuthUnauthenticated());
        }
      }
      return;
    }

    // Prevent too frequent auth checks
    if (_lastAuthCheck != null &&
        DateTime.now().difference(_lastAuthCheck!).inSeconds < 3) {
      ErrorHandler.logDebug('AdminAuthBloc: Skipping auth check - too recent (${DateTime.now().difference(_lastAuthCheck!).inSeconds}s ago)');

      // If we have a current admin, use cached state
      if (_currentAdmin != null) {
        ErrorHandler.logDebug('AdminAuthBloc: Using cached admin: ${_currentAdmin!.email}');
        emit(AdminAuthAuthenticated(admin: _currentAdmin!));
        return;
      }
    }

    _isProcessingAuth = true;
    _lastAuthCheck = DateTime.now();
    _ongoingAuthCheck = Completer<Admin?>();

    ErrorHandler.logDebug('AdminAuthBloc: Checking admin auth status');

    // Only emit loading if we don't have a cached admin
    if (_currentAdmin == null) {
      emit(AdminAuthLoading());
    }

    try {
      ErrorHandler.logDebug('AdminAuthBloc: Starting controller.checkAdminAuth()');

      // Reduced timeout to prevent interfering with login flow
      final admin = await Future.any([
        adminController.checkAdminAuth(),
        Future.delayed(const Duration(seconds: 8), () {
          ErrorHandler.logWarning('AdminAuthBloc: Auth check timed out after 8 seconds');
          return null;
        }),
      ]);

      ErrorHandler.logDebug('AdminAuthBloc: Auth check completed, result: ${admin?.email ?? 'null'}');

      if (admin != null) {
        _currentAdmin = admin;
        _lastSuccessfulAuth = DateTime.now();
        ErrorHandler.logDebug('AdminAuthBloc: Auth check successful, emitting AdminAuthAuthenticated for: ${admin.email}');

        _ongoingAuthCheck?.complete(admin);
        emit(AdminAuthAuthenticated(admin: admin));

        // For Windows, set up a periodic auth refresh to maintain session
        if (defaultTargetPlatform == TargetPlatform.windows) {
          _setupPeriodicAuthRefresh();
        }
      } else {
        // For Windows, if we had a successful auth recently, don't fail immediately
        if (defaultTargetPlatform == TargetPlatform.windows &&
            _currentAdmin != null &&
            _lastSuccessfulAuth != null &&
            DateTime.now().difference(_lastSuccessfulAuth!).inMinutes < 30) {
          ErrorHandler.logWarning('AdminAuthBloc: Auth check failed but keeping Windows session alive');
          _ongoingAuthCheck?.complete(_currentAdmin);
          emit(AdminAuthAuthenticated(admin: _currentAdmin!));
        } else {
          _currentAdmin = null;
          _lastSuccessfulAuth = null;
          ErrorHandler.logDebug('AdminAuthBloc: Auth check failed, emitting AdminAuthUnauthenticated');
          _ongoingAuthCheck?.complete(null);
          emit(AdminAuthUnauthenticated());
        }
      }
    } catch (e) {
      ErrorHandler.logError('AdminAuthBloc: Auth check error', e);

      // For Windows, if we had a successful auth recently, don't fail immediately
      if (defaultTargetPlatform == TargetPlatform.windows &&
          _currentAdmin != null &&
          _lastSuccessfulAuth != null &&
          DateTime.now().difference(_lastSuccessfulAuth!).inMinutes < 60) {
        ErrorHandler.logWarning('AdminAuthBloc: Auth check failed but keeping Windows session alive');
        _ongoingAuthCheck?.complete(_currentAdmin);
        emit(AdminAuthAuthenticated(admin: _currentAdmin!));
      } else {
        _currentAdmin = null;
        _lastSuccessfulAuth = null;
        ErrorHandler.logDebug('AdminAuthBloc: Auth check error, emitting AdminAuthUnauthenticated');
        _ongoingAuthCheck?.complete(null);
        emit(AdminAuthUnauthenticated());
      }
    } finally {
      _isProcessingAuth = false;
      _ongoingAuthCheck = null;
    }
  }

  Future<void> _handleRefreshAdminAuth(
      RefreshAdminAuth event,
      Emitter<AdminAuthState> emit,
      ) async {
    if (_currentAdmin == null || _isProcessingAuth || _isProcessingLogin) return;

    try {
      ErrorHandler.logDebug('AdminAuthBloc: Refreshing admin auth');

      final admin = await adminController.checkAdminAuth();
      if (admin != null) {
        _currentAdmin = admin;
        _lastSuccessfulAuth = DateTime.now();
        ErrorHandler.logDebug('AdminAuthBloc: Auth refresh successful');
        // Don't emit new state unless it changes to avoid unnecessary rebuilds
      } else {
        ErrorHandler.logWarning('AdminAuthBloc: Auth refresh failed, logging out');
        _currentAdmin = null;
        _lastSuccessfulAuth = null;
        emit(AdminAuthUnauthenticated());
      }
    } catch (e) {
      ErrorHandler.logError('AdminAuthBloc: Auth refresh error', e);
      // Don't logout on refresh error for Windows, just log the warning
      if (defaultTargetPlatform != TargetPlatform.windows) {
        _currentAdmin = null;
        _lastSuccessfulAuth = null;
        emit(AdminAuthUnauthenticated());
      }
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

  void _cancelOngoingAuthCheck() {
    _ongoingAuthCheck?.complete(null);
    _ongoingAuthCheck = null;
    _authCheckTimer?.cancel();
  }

  void _setupPeriodicAuthRefresh() {
    _authCheckTimer?.cancel();
    _authCheckTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (_currentAdmin != null && !_isProcessingAuth && !_isProcessingLogin) {
        add(RefreshAdminAuth());
      }
    });
  }

  /// Force refresh auth state (useful for debugging)
  void forceRefreshAuthState() {
    ErrorHandler.logDebug('AdminAuthBloc: Force refreshing auth state');
    _lastSuccessfulAuth = null; // Reset to force check
    _lastAuthCheck = null;
    add(CheckAdminAuthStatus());
  }

  /// Get current state info for debugging
  String getStateInfo() {
    return 'Current State: ${state.runtimeType}, Cached Admin: ${_currentAdmin?.email ?? 'null'}, Processing Auth: $_isProcessingAuth, Processing Login: $_isProcessingLogin, Last Auth: $_lastSuccessfulAuth, Last Check: $_lastAuthCheck';
  }
}