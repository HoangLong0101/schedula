import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/update_user_profile_usecase.dart';
import '../../domain/usecases/upload_avatar_usecase.dart';
import '../../domain/usecases/watch_user_profile_usecase.dart';

class AccountInfoCubit extends Cubit<UserProfile> {
  AccountInfoCubit({
    required String userId,
    required String defaultEmail,
    required WatchUserProfileUseCase watchProfile,
    required this._updateProfile,
    required this._uploadAvatar,
    required this._changePassword,
  }) : _userId = userId,
       super(UserProfile(name: '', phone: '', email: defaultEmail)) {
    _subscription = watchProfile(
      userId,
      defaultEmail,
    ).listen((result) => result.fold((_) {}, emit));
  }

  final String _userId;
  final UpdateUserProfileUseCase _updateProfile;
  final UploadAvatarUseCase _uploadAvatar;
  final ChangePasswordUseCase _changePassword;
  StreamSubscription? _subscription;

  void updateProfileField({String? name, String? phone}) {
    emit(state.copyWith(name: name, phone: phone));
  }

  Future<bool> saveProfile() async {
    final result = await _updateProfile(_userId, state);
    return result.fold((_) => false, (_) => true);
  }

  Future<bool> uploadAvatar(Uint8List bytes, String contentType) async {
    final result = await _uploadAvatar(_userId, bytes, contentType);
    return result.fold((_) => false, (url) {
      emit(state.copyWith(avatarUrl: url));
      return true;
    });
  }

  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final result = await _changePassword(
      state.email,
      currentPassword,
      newPassword,
    );
    return result.fold((_) => false, (_) => true);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
