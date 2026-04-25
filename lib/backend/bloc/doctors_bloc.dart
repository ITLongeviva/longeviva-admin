import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/doctor/doctor_model.dart';
import '../repositories/doctors_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class DoctorsEvent {}

class LoadDoctors extends DoctorsEvent {}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class DoctorsState {}

class DoctorsInitial extends DoctorsState {}

class DoctorsLoading extends DoctorsState {}

class DoctorsLoaded extends DoctorsState {
  final List<Doctor> doctors;
  DoctorsLoaded(this.doctors);
}

class DoctorsError extends DoctorsState {
  final String message;
  DoctorsError(this.message);
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class DoctorsBloc extends Bloc<DoctorsEvent, DoctorsState> {
  final DoctorsRepository _repository;

  DoctorsBloc({DoctorsRepository? repository})
      : _repository = repository ?? DoctorsRepository(),
        super(DoctorsInitial()) {
    on<LoadDoctors>(_onLoad);
  }

  Future<void> _onLoad(
    LoadDoctors event,
    Emitter<DoctorsState> emit,
  ) async {
    emit(DoctorsLoading());
    try {
      final doctors = await _repository.loadAll();
      emit(DoctorsLoaded(doctors));
    } catch (e) {
      emit(DoctorsError('Errore nel caricamento dei dottori: $e'));
    }
  }
}
