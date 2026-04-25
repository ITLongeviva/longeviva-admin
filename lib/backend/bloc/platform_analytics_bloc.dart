import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/platform_analytics_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class PlatformAnalyticsEvent {}

class LoadPlatformAnalytics extends PlatformAnalyticsEvent {}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class PlatformAnalyticsState {}

class PlatformAnalyticsInitial extends PlatformAnalyticsState {}

class PlatformAnalyticsLoading extends PlatformAnalyticsState {}

class PlatformAnalyticsLoaded extends PlatformAnalyticsState {
  final PlatformAnalyticsData data;
  PlatformAnalyticsLoaded(this.data);
}

class PlatformAnalyticsError extends PlatformAnalyticsState {
  final String message;
  PlatformAnalyticsError(this.message);
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class PlatformAnalyticsBloc
    extends Bloc<PlatformAnalyticsEvent, PlatformAnalyticsState> {
  final PlatformAnalyticsRepository _repository;

  PlatformAnalyticsBloc({PlatformAnalyticsRepository? repository})
      : _repository = repository ?? PlatformAnalyticsRepository(),
        super(PlatformAnalyticsInitial()) {
    on<LoadPlatformAnalytics>(_onLoad);
  }

  Future<void> _onLoad(
    LoadPlatformAnalytics event,
    Emitter<PlatformAnalyticsState> emit,
  ) async {
    emit(PlatformAnalyticsLoading());
    try {
      final data = await _repository.loadAll();
      emit(PlatformAnalyticsLoaded(data));
    } catch (e) {
      emit(PlatformAnalyticsError('Errore nel caricamento delle analytics: $e'));
    }
  }
}
