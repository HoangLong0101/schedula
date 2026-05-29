import 'package:injectable/injectable.dart';

import '../models/dashboard_item_model.dart';

@lazySingleton
class DashboardDataSource {
  const DashboardDataSource();

  Future<List<DashboardItemModel>> fetchItems() async => const <DashboardItemModel>[];
}
