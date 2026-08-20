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
      either.fold((_) {}, (equipment) => emit(equipment));
    });
  }

  Future<String?> addEquipment(Equipment equip) async {
    final result = await _createEquipment(_currentTenantId, equip);
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> updateEquipment(Equipment equip) async {
    final result = await _updateEquipment(equip);
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> deleteEquipment(String id) async {
    final result = await _deleteEquipment(id);
    return result.fold((failure) => failure.message, (_) => null);
  }

  Future<String?> updateStatus(String id, EquipmentStatus newStatus) async {
    final equip = state.firstWhere((e) => e.id == id);
    final result = await _updateEquipment(equip.copyWith(status: newStatus));
    return result.fold((failure) => failure.message, (_) => null);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
