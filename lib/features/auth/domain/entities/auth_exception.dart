class AuthAccessDeniedException implements Exception {
  const AuthAccessDeniedException();

  @override
  String toString() => 'Tài khoản chưa được cấp quyền truy cập Schedula.';
}

class AuthProfileSetupRequiredException implements Exception {
  const AuthProfileSetupRequiredException();

  @override
  String toString() => 'Tài khoản cần thiết lập thông tin cơ sở.';
}
