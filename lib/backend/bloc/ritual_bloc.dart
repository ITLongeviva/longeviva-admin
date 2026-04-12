import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/ritual_model.dart';
import '../repositories/ritual_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class RitualEvent {}

class LoadRitualAnalytics extends RitualEvent {}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class RitualState {}

class RitualInitial extends RitualState {}

class RitualLoading extends RitualState {}

class RitualLoaded extends RitualState {
  final List<Ritual> rituals;
  RitualLoaded(this.rituals);
}

class RitualError extends RitualState {
  final String message;
  RitualError(this.message);
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class RitualBloc extends Bloc<RitualEvent, RitualState> {
  final RitualRepository _repository;

  RitualBloc({RitualRepository? repository})
      : _repository = repository ?? RitualRepository(),
        super(RitualInitial()) {
    on<LoadRitualAnalytics>(_onLoad);
  }

  Future<void> _onLoad(LoadRitualAnalytics event, Emitter<RitualState> emit) async {
    emit(RitualLoading());
    try {
      final rituals = await _repository.getAllRituals();
      emit(RitualLoaded(rituals));
    } catch (e) {
      emit(RitualError('Errore nel caricamento dei rituali: $e'));
    }
  }
}
