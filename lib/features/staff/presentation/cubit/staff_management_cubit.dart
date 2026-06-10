import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/staff_member.dart';
import '../../domain/usecases/create_staff_usecase.dart';
import '../../domain/usecases/delete_staff_usecase.dart';
import '../../domain/usecases/update_staff_usecase.dart';
import '../../domain/usecases/watch_staff_usecase.dart';

// State có thể cần mở rộng thêm StaffLoading, StaffError thay vì chỉ List<StaffMember>
// Nhưng nếu giữ nguyên List<StaffMember> theo UI cũ:

@injectable
class StaffManagementCubit extends Cubit<List<StaffMember>> {
  StaffManagementCubit(
      this._watchStaff,
      this._createStaff,
      this._updateStaff,
      this._deleteStaff,
      ) : super(const []);

  final WatchStaffUseCase _watchStaff;
  final CreateStaffUseCase _createStaff;
  final UpdateStaffUseCase _updateStaff;
  final DeleteStaffUseCase _deleteStaff;

  StreamSubscription? _subscription;
  String _currentTenantId = '';

  void init(String tenantId) {
    _currentTenantId = tenantId;
    _subscription?.cancel();
    _subscription = _watchStaff(WatchStaffParams(tenantId: tenantId)).listen((either) {
      either.fold(
            (failure) => print('Error loading staff: ${failure.message}'), // Xử lý lỗi
            (staffList) => emit(staffList), // Cập nhật danh sách mới từ Firestore
      );
    });
  }

  Future<void> addStaff(StaffMember staff) async {
    await _createStaff(CreateStaffParams(tenantId: _currentTenantId, staff: staff));
  }

  Future<void> updateStaff(StaffMember staff) async {
    await _updateStaff(UpdateStaffParams(staff: staff));
  }

  Future<void> deleteStaff(String id) async {
    await _deleteStaff(DeleteStaffParams(staffId: id));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}