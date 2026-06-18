import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/user_profile.dart';

class AccountInfoCubit extends Cubit<UserProfile> {
  AccountInfoCubit({required String defaultEmail})
      : super(
    UserProfile(
      name: "Minh Nguyễn",
      phone: "0901 234 567",
      email: defaultEmail.isNotEmpty ? defaultEmail : "minh@schedula.vn",
    ),
  );

  void updateProfileField({String? name, String? phone, String? email}) {
    emit(state.copyWith(name: name, phone: phone, email: email));
  }

  void toggleFaceId(bool value) => emit(state.copyWith(faceIdEnabled: value));

  void toggleFingerprint(bool value) => emit(state.copyWith(fingerprintEnabled: value));

  void toggleTwoFa(bool value) => emit(state.copyWith(twoFaEnabled: value));

  void updateTwoFaMethod(String method) => emit(state.copyWith(twoFaMethod: method));

  // Giả lập API call lưu thông tin
  Future<bool> saveProfile() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    return true; // Trả về true khi lưu thành công
  }

  // Giả lập API call đổi mật khẩu
  Future<bool> changePassword(String oldPw, String newPw) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    return true;
  }
}