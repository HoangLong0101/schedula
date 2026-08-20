import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/change_password_usecase.dart';

@injectable
class FirstPasswordChangeCubit extends Cubit<bool> {
  FirstPasswordChangeCubit(this._changePassword) : super(false);

  final ChangePasswordUseCase _changePassword;

  Future<String?> change({
    required String email,
    required String temporaryPassword,
    required String newPassword,
  }) async {
    emit(true);
    final result = await _changePassword(email, temporaryPassword, newPassword);
    emit(false);
    return result.fold((failure) => failure.message, (_) => null);
  }
}
