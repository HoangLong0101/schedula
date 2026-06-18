import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/get_dashboard_stats_usecase.dart';
import 'dashboard_state.dart';

@injectable
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._getDashboardStats) : super(const DashboardInitial());

  final GetDashboardStatsUseCase _getDashboardStats;

  Future<void> load(String tenantId, {bool forceRefresh = false}) async {
    if (state is! DashboardLoaded) {
      emit(const DashboardLoading());
    }
    final result = await _getDashboardStats(
      GetDashboardStatsParams(
        tenantId: tenantId,
        forceRefresh: forceRefresh,
      ),
    );
    result.fold(
      (failure) => emit(DashboardFailure(failure.message)),
      (stats) => emit(DashboardLoaded(stats)),
    );
  }
}
