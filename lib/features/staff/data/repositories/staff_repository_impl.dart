import 'package:injectable/injectable.dart';

import '../../domain/entities/staff.dart';
import '../../domain/repositories/staff_repository.dart';
import '../datasources/staff_datasource.dart';

@LazySingleton(as: StaffRepository)
class StaffRepositoryImpl implements StaffRepository {
  const StaffRepositoryImpl(this._dataSource);

  final StaffDataSource _dataSource;

  @override
  Future<List<Staff>> getAllStaff() async => await _dataSource.fetchStaff();
}
