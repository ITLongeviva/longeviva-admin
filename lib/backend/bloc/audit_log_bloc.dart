import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/admin_action_model.dart';
import '../repositories/audit_log_repository.dart';

// Events
abstract class AuditLogEvent {}
class FetchRecentAdminActions extends AuditLogEvent {}

// States
abstract class AuditLogState {}
class AuditLogInitial extends AuditLogState {}
class AuditLogLoading extends AuditLogState {}

class AuditLogLoaded extends AuditLogState {
  final List<AdminAction> actions;
  AuditLogLoaded(this.actions);
}

class AuditLogError extends AuditLogState {
  final String message;
  AuditLogError(this.message);
}

// BLoC
class AuditLogBloc extends Bloc<AuditLogEvent, AuditLogState> {
  final AuditLogRepository _repository;

  AuditLogBloc({AuditLogRepository? repository})
      : _repository = repository ?? AuditLogRepository(),
        super(AuditLogInitial()) {
    on<FetchRecentAdminActions>(_handleFetch);
    add(FetchRecentAdminActions()); // auto-fetch on creation
  }

  Future<void> _handleFetch(
    FetchRecentAdminActions event,
    Emitter<AuditLogState> emit,
  ) async {
    emit(AuditLogLoading());
    final actions = await _repository.getRecentActions();
    emit(AuditLogLoaded(actions));
  }
}
