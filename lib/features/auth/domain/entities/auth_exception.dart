class AuthAccessDeniedException implements Exception {
  const AuthAccessDeniedException();

  @override
  String toString() => 'Tài khoản chưa được cấp quyền truy cập Schedula.';
}
