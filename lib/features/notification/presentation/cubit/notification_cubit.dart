import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/mark_all_notifications_read_usecase.dart';
import '../../domain/usecases/mark_notification_read_usecase.dart';
import '../../domain/usecases/watch_notifications_usecase.dart';
import 'notification_state.dart';

@injectable
class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit(this._watchNotifications, this._markRead, this._markAllRead)
    : super(const NotificationState());

  final WatchNotificationsUseCase _watchNotifications;
  final MarkNotificationReadUseCase _markRead;
  final MarkAllNotificationsReadUseCase _markAllRead;
  StreamSubscription? _subscription;
  String _tenantId = '';
  String _userId = '';
  bool _staffOnly = false;

  void init({
    required String tenantId,
    required String userId,
    required bool staffOnly,
  }) {
    _tenantId = tenantId;
    _userId = userId;
    _staffOnly = staffOnly;
    _subscription?.cancel();
    _subscription =
        _watchNotifications(
          tenantId: tenantId,
          userId: userId,
          staffOnly: staffOnly,
        ).listen(
          (result) => result.fold(
            (failure) =>
                emit(state.copyWith(loading: false, error: failure.message)),
            (items) => emit(
              state.copyWith(items: items, loading: false, clearError: true),
            ),
          ),
        );
  }

  void setFilter(String filter) => emit(state.copyWith(filter: filter));

  Future<void> markRead(String id) async {
    final result = await _markRead(id);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) {},
    );
  }

  Future<void> markAllRead() async {
    final result = await _markAllRead(
      tenantId: _tenantId,
      userId: _userId,
      staffOnly: _staffOnly,
    );
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) {},
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
