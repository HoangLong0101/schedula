class AuthAccessDeniedException implements Exception {
  const AuthAccessDeniedException();

  @override
  String toString() => 'This account is not allowed to access Schedula.';
}
