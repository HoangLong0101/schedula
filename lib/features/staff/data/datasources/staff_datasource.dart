import 'package:injectable/injectable.dart';

import '../models/staff_model.dart';

@lazySingleton
class StaffDataSource {
  const StaffDataSource();

  Future<List<StaffModel>> fetchStaff() async => const <StaffModel>[];
}
