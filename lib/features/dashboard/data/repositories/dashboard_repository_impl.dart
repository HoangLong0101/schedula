import 'package:injectable/injectable.dart';

import '../../domain/entities/dashboard_item.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_datasource.dart';

@LazySingleton(as: DashboardRepository)
class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this._dataSource);

  final DashboardDataSource _dataSource;

  @override
  Future<List<DashboardItem>> getItems() async => await _dataSource.fetchItems();
}
