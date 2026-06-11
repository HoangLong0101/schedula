import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/business_info.dart';
import '../../domain/usecases/update_business_info_usecase.dart';
import '../../domain/usecases/watch_business_info_usecase.dart';

@injectable
class AccountCubit extends Cubit<BusinessInfo> {
  AccountCubit(this._watchBusinessInfo, this._updateBusinessInfo)
      : super(const BusinessInfo(
    name: "Đang tải...", type: "", address: "", phone: "",
    website: "", hoursWeekday: "", hoursWeekend: "", description: "",
  ));

  final WatchBusinessInfoUseCase _watchBusinessInfo;
  final UpdateBusinessInfoUseCase _updateBusinessInfo;

  StreamSubscription? _subscription;
  String _currentTenantId = '';

  void init(String tenantId) {
    _currentTenantId = tenantId;
    _subscription?.cancel();
    _subscription = _watchBusinessInfo(tenantId).listen((either) {
      either.fold(
            (failure) => print('Lỗi tải thông tin Spa: ${failure.message}'),
            (info) => emit(info),
      );
    });
  }

  Future<void> updateBusinessInfo(BusinessInfo updatedInfo) async {
    await _updateBusinessInfo(_currentTenantId, updatedInfo);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}