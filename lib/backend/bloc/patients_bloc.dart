import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/patient_model.dart';
import '../repositories/patients_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class PatientsEvent {}

class LoadPatients extends PatientsEvent {}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class PatientsState {}

class PatientsInitial extends PatientsState {}

class PatientsLoading extends PatientsState {}

class PatientsLoaded extends PatientsState {
  final List<Patient> patients;
  PatientsLoaded(this.patients);
}

class PatientsError extends PatientsState {
  final String message;
  PatientsError(this.message);
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class PatientsBloc extends Bloc<PatientsEvent, PatientsState> {
  final PatientsRepository _repository;

  PatientsBloc({PatientsRepository? repository})
      : _repository = repository ?? PatientsRepository(),
        super(PatientsInitial()) {
    on<LoadPatients>(_onLoad);
  }

  Future<void> _onLoad(
    LoadPatients event,
    Emitter<PatientsState> emit,
  ) async {
    emit(PatientsLoading());
    try {
      final patients = await _repository.loadAll();
      emit(PatientsLoaded(patients));
    } catch (e) {
      emit(PatientsError('Errore nel caricamento dei pazienti: $e'));
    }
  }
}
