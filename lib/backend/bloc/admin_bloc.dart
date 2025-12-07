import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/admin_controller.dart';

// Admin Operations Events
abstract class AdminOperationsEvent {}

class FetchAllUsers extends AdminOperationsEvent {}

class DeleteUser extends AdminOperationsEvent {
  final String userId;
  final String userType;

  DeleteUser({required this.userId, required this.userType});
}

// Admin Operations States
abstract class AdminOperationsState {}

class AdminOperationsInitial extends AdminOperationsState {}

class AdminOperationsLoading extends AdminOperationsState {}

class AllUsersLoaded extends AdminOperationsState {
  final List<Map<String, dynamic>> users;

  AllUsersLoaded({required this.users});
}

class OperationSuccess extends AdminOperationsState {
  final String message;
  final String? translationKey;

  OperationSuccess({required this.message, this.translationKey});
}

class OperationFailure extends AdminOperationsState {
  final String error;
  final String? translationKey;
  final Map<String, String>? translationArgs;

  OperationFailure({
    required this.error,
    this.translationKey,
    this.translationArgs,
  });
}

// Admin Operations BLoC
class AdminOperationsBloc extends Bloc<AdminOperationsEvent, AdminOperationsState> {
  final AdminController adminController;

  AdminOperationsBloc({required this.adminController}) : super(AdminOperationsInitial()) {
    on<FetchAllUsers>(_handleFetchAllUsers);
    on<DeleteUser>(_handleDeleteUser);
  }

  Future<void> _handleFetchAllUsers(
      FetchAllUsers event,
      Emitter<AdminOperationsState> emit,
      ) async {
    emit(AdminOperationsLoading());

    try {
      final users = await adminController.getAllUsers();
      emit(AllUsersLoaded(users: users));
    } catch (e) {
      emit(OperationFailure(
        error: 'Failed to load users: ${e.toString()}',
        translationKey: 'errors.admin.users_load_failed',
        translationArgs: {'error': e.toString()},
      ));
    }
  }

  Future<void> _handleDeleteUser(
      DeleteUser event,
      Emitter<AdminOperationsState> emit,
      ) async {
    emit(AdminOperationsLoading());

    try {
      final success = await adminController.deleteUser(event.userId, event.userType);

      if (success) {
        emit(OperationSuccess(
          message: 'User deleted successfully',
          translationKey: 'success.admin.user_deleted',
        ));

        // Refresh the list of users
        final users = await adminController.getAllUsers();
        emit(AllUsersLoaded(users: users));
      } else {
        emit(OperationFailure(
          error: 'Failed to delete user',
          translationKey: 'errors.admin.user_delete_failed',
        ));
      }
    } catch (e) {
      emit(OperationFailure(
        error: 'Error deleting user: ${e.toString()}',
        translationKey: 'errors.admin.user_delete_error',
        translationArgs: {'error': e.toString()},
      ));
    }
  }
}