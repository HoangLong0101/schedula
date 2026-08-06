import 'package:equatable/equatable.dart';

import '../../domain/entities/app_notification.dart';

class NotificationState extends Equatable {
  const NotificationState({
    this.items = const [],
    this.filter = 'all',
    this.loading = true,
    this.error,
  });

  final List<AppNotification> items;
  final String filter;
  final bool loading;
  final String? error;

  List<AppNotification> get visible => filter == 'all'
      ? items
      : items.where((item) => item.type == filter).toList(growable: false);

  NotificationState copyWith({
    List<AppNotification>? items,
    String? filter,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationState(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [items, filter, loading, error];
}
