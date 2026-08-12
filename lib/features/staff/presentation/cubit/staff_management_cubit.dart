import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/staff_member.dart';
import '../../domain/usecases/create_staff_usecase.dart';
import '../../domain/usecases/delete_staff_usecase.dart';
import '../../domain/usecases/update_staff_usecase.dart';
import '../../domain/usecases/watch_staff_usecase.dart';
import '../../domain/usecases/add_staff_leave_usecase.dart';
import '../../domain/usecases/send_staff_password_reset_usecase.dart';
import '../../domain/usecases/set_staff_access_role_usecase.dart';

// State có thể cần mở rộng thêm StaffLoading, StaffError thay vì chỉ List<StaffMember>
// Nhưng nếu giữ nguyên List<StaffMember> theo UI cũ:

@injectable
class StaffManagementCubit extends Cubit<List<StaffMember>> {
  StaffManagementCubit(
    this._watchStaff,
    this._createStaff,
    this._updateStaff,
    this._deleteStaff,
    this._addLeave,
    this._resetPassword,
    this._setAccessRole,
  ) : super(const []);

  final WatchStaffUseCase _watchStaff;
  final CreateStaffUseCase _createStaff;
  final UpdateStaffUseCase _updateStaff;
  final DeleteStaffUseCase _deleteStaff;
  final AddStaffLeaveUseCase _addLeave;
  final ResetStaffPasswordUseCase _resetPassword;
  final SetStaffAccessRoleUseCase _setAccessRole;

  StreamSubscription? _subscription;
  String _currentTenantId = '';

  void init(String tenantId) {
    _currentTenantId = tenantId;
    _subscription?.cancel();
    _subscription = _watchStaff(WatchStaffParams(tenantId: tenantId)).listen((
      either,
    ) {
      either.fold(
        (_) {},
        (staffList) => emit(staffList), // Cập nhật danh sách mới từ Firestore
      );
    });
  }

  Future<({String? password, String? error})> addStaff(
    StaffMember staff,
  ) async {
    final result = await _createStaff(
      CreateStaffParams(tenantId: _currentTenantId, staff: staff),
    );
    return result.fold(
      (failure) => (password: null, error: failure.message),
      (created) => (password: created.temporaryPassword, error: null),
    );
  }

  Future<String?> updateStaff(StaffMember staff) async {
    final result = await _updateStaff(UpdateStaffParams(staff: staff));
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> deleteStaff(
    String id, {
    required bool cancelFuture,
    String? reassignTo,
  }) async {
    final result = await _deleteStaff(
      DeleteStaffParams(
        staffId: id,
        cancelFuture: cancelFuture,
        reassignTo: reassignTo,
      ),
    );
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<bool> addLeave(String staffId, DateTime start, DateTime end) async {
    final result = await _addLeave(
      tenantId: _currentTenantId,
      staffId: staffId,
      start: start,
      end: end,
    );
    return result.isRight();
  }

  Future<({String? password, String? error})> resetPassword(
    String staffId,
  ) async {
    final result = await _resetPassword(staffId);
    return result.fold(
      (failure) => (password: null, error: failure.message),
      (password) => (password: password, error: null),
    );
  }

  Future<bool> setAccessRole(String staffId, String role) async {
    final result = await _setAccessRole(staffId, role);
    return result.isRight();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
