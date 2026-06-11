import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/equipment.dart';
import '../../domain/usecases/create_equipment_usecase.dart';
import '../../domain/usecases/delete_equipment_usecase.dart';
import '../../domain/usecases/update_equipment_usecase.dart';
import '../../domain/usecases/watch_equipment_usecase.dart';

@injectable
class EquipmentManagementCubit extends Cubit<List<Equipment>> {
  EquipmentManagementCubit(
      this._watchEquipment,
      this._createEquipment,
      this._updateEquipment,
      this._deleteEquipment,
      ) : super(const []);

  final WatchEquipmentUseCase _watchEquipment;
  final CreateEquipmentUseCase _createEquipment;
  final UpdateEquipmentUseCase _updateEquipment;
  final DeleteEquipmentUseCase _deleteEquipment;

  StreamSubscription? _subscription;
  String _currentTenantId = '';

  void init(String tenantId) {
    _currentTenantId = tenantId;
    _subscription?.cancel();
    _subscription = _watchEquipment(tenantId).listen((either) {
      either.fold(
            (failure) => print('Lỗi tải thiết bị: ${failure.message}'),
            (equipment) => emit(equipment),
      );
    });
  }

  Future<void> addEquipment(Equipment equip) async {
    await _createEquipment(_currentTenantId, equip);
  }

  Future<void> updateEquipment(Equipment equip) async {
    await _updateEquipment(equip);
  }

  Future<void> deleteEquipment(String id) async {
    await _deleteEquipment(id);
  }

  Future<void> updateStatus(String id, EquipmentStatus newStatus) async {
    final equip = state.firstWhere((e) => e.id == id);
    await _updateEquipment(equip.copyWith(status: newStatus));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}