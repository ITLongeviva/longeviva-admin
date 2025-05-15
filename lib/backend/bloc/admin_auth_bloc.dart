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

// Admin Auth States
abstract class AdminAuthState {}

class AdminAuthInitial extends AdminAuthState {}

class AdminAuthLoading extends AdminAuthState {}

class AdminAuthAuthenticated extends AdminAuthState {
  final Admin admin;

  AdminAuthAuthenticated({required this.admin});
}

class AdminAuthUnauthenticated extends AdminAuthState {}

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

// Admin Auth BLoC
class AdminAuthBloc extends Bloc<AdminAuthEvent, AdminAuthState> {
  final AdminController adminController;
  Admin? _currentAdmin;
  bool _isProcessingAuth = false;

  AdminAuthBloc({required this.adminController}) : super(AdminAuthInitial()) {
    on<AdminLoginRequested>(_handleAdminLoginRequested);
    on<AdminLogoutRequested>(_handleAdminLogoutRequested);
    on<CheckAdminAuthStatus>(_handleCheckAdminAuthStatus);
  }

  Admin? get currentAdmin => _currentAdmin;

  Future<void> _handleAdminLoginRequested(
      AdminLoginRequested event,
      Emitter<AdminAuthState> emit,
      ) async {
    if (_isProcessingAuth) return;
    _isProcessingAuth = true;

    emit(AdminAuthLoading());

    try {
      final admin = await adminController.loginAdmin(
        email: event.email,
        password: event.password,
        rememberMe: event.rememberMe,
      );

      if (admin != null) {
        _currentAdmin = admin;
        emit(AdminAuthAuthenticated(admin: admin));
      } else {
        emit(AdminAuthFailure(
          error: 'Invalid admin credentials',
          translationKey: 'errors.auth.invalid_admin_credentials',
        ));
      }
    } catch (e) {
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

    emit(AdminAuthLoading());

    try {
      await adminController.logoutAdmin();
      _currentAdmin = null;
      emit(AdminAuthUnauthenticated());
    } catch (e) {
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
    if (_isProcessingAuth) return;
    _isProcessingAuth = true;

    emit(AdminAuthLoading());

    try {
      final admin = await adminController.checkAdminAuth();

      if (admin != null) {
        _currentAdmin = admin;
        emit(AdminAuthAuthenticated(admin: admin));
      } else {
        print('AdminAuthBloc: auth check failed - emitting AdminAuthUnauthenticated');
        emit(AdminAuthUnauthenticated());
      }
    } catch (e) {
      print('AdminAuthBloc: auth check error - ${e.toString()}');
      emit(AdminAuthUnauthenticated());
    } finally {
      _isProcessingAuth = false;
    }
  }
}