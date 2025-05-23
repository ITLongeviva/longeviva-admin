// lib/backend/bloc/simple_admin_auth_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/unified_auth_service.dart';
import '../models/admin_model.dart';
import '../../shared/utils/error_handler.dart';

// Simple Events
abstract class SimpleAdminAuthEvent {}

class LoginRequested extends SimpleAdminAuthEvent {
  final String email;
  final String password;
  final bool rememberMe;

  LoginRequested({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });
}

class LogoutRequested extends SimpleAdminAuthEvent {}

class CheckAuthRequested extends SimpleAdminAuthEvent {}

class PasswordResetRequested extends SimpleAdminAuthEvent {
  final String email;
  PasswordResetRequested(this.email);
}

// Simple States
abstract class SimpleAdminAuthState {}

class AuthInitial extends SimpleAdminAuthState {}

class AuthLoading extends SimpleAdminAuthState {}

class AuthSuccess extends SimpleAdminAuthState {
  final Admin admin;
  AuthSuccess(this.admin);
}

class AuthFailure extends SimpleAdminAuthState {
  final String message;
  AuthFailure(this.message);
}

class AuthUnauthenticated extends SimpleAdminAuthState {}

class PasswordResetSent extends SimpleAdminAuthState {
  final String email;
  PasswordResetSent(this.email);
}

// Simplified BLoC
class SimpleAdminAuthBloc extends Bloc<SimpleAdminAuthEvent, SimpleAdminAuthState> {
  final UnifiedAuthService _authService = UnifiedAuthService();

  SimpleAdminAuthBloc() : super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthRequested>(_onCheckAuthRequested);
    on<PasswordResetRequested>(_onPasswordResetRequested);
  }

  // Get current admin (useful for accessing from other parts of the app)
  Admin? get currentAdmin => _authService.currentAdmin;

  Future<void> _onLoginRequested(
      LoginRequested event,
      Emitter<SimpleAdminAuthState> emit,
      ) async {
    emit(AuthLoading());

    try {
      ErrorHandler.logDebug('SimpleAdminAuthBloc: Processing login request');

      final result = await _authService.login(
        email: event.email,
        password: event.password,
        rememberMe: event.rememberMe,
      );

      if (result.isSuccess && result.admin != null) {
        ErrorHandler.logDebug('Login successful for: ${result.admin!.email}');
        emit(AuthSuccess(result.admin!));
      } else {
        ErrorHandler.logWarning('Login failed: ${result.error}');
        emit(AuthFailure(result.error ?? 'Login failed'));
      }
    } catch (e) {
      ErrorHandler.logError('Login exception', e);
      emit(AuthFailure('Login error: ${e.toString()}'));
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event,
      Emitter<SimpleAdminAuthState> emit,
      ) async {
    emit(AuthLoading());

    try {
      await _authService.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      ErrorHandler.logError('Logout error', e);
      // Even if logout fails, consider user logged out
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onCheckAuthRequested(
      CheckAuthRequested event,
      Emitter<SimpleAdminAuthState> emit,
      ) async {
    // Don't emit loading for auth checks to avoid UI flicker
    try {
      ErrorHandler.logDebug('SimpleAdminAuthBloc: Checking auth status');

      final result = await _authService.checkAuthStatus();

      switch (result.status) {
        case AuthStatus.authenticated:
          if (result.admin != null) {
            ErrorHandler.logDebug('Auth check successful: ${result.admin!.email}');
            emit(AuthSuccess(result.admin!));
          } else {
            emit(AuthUnauthenticated());
          }
          break;
        case AuthStatus.unauthenticated:
          ErrorHandler.logDebug('Auth check: user not authenticated');
          emit(AuthUnauthenticated());
          break;
        case AuthStatus.error:
          ErrorHandler.logWarning('Auth check error: ${result.error}');
          emit(AuthFailure(result.error ?? 'Authentication check failed'));
          break;
      }
    } catch (e) {
      ErrorHandler.logError('Auth check exception', e);
      emit(AuthFailure('Authentication check error: ${e.toString()}'));
    }
  }

  Future<void> _onPasswordResetRequested(
      PasswordResetRequested event,
      Emitter<SimpleAdminAuthState> emit,
      ) async {
    emit(AuthLoading());

    try {
      await _authService.sendPasswordReset(event.email);
      emit(PasswordResetSent(event.email));
    } catch (e) {
      ErrorHandler.logError('Password reset error', e);
      emit(AuthFailure('Failed to send password reset email: ${e.toString()}'));
    }
  }
}