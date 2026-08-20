import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_services.dart';
import 'admin_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.auth, super.key});

  final AdminAuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final emailKey = GlobalKey<FormFieldState<String>>();
  String? error;
  bool loading = false;
  bool resetting = false;
  bool showPassword = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate() || loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.auth.signIn(email.text, password.text);
    } on PlatformAccessException {
      error = 'Tài khoản này không có quyền quản trị hệ thống.';
    } on FirebaseAuthException catch (exception) {
      error = switch (exception.code) {
        'invalid-credential' => 'Email hoặc mật khẩu không đúng.',
        'too-many-requests' => 'Quá nhiều lần thử. Vui lòng thử lại sau.',
        _ => 'Không thể đăng nhập. Vui lòng thử lại.',
      };
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    if (resetting || emailKey.currentState?.validate() != true) return;
    setState(() {
      resetting = true;
      error = null;
    });
    try {
      await widget.auth.sendPasswordReset(email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi liên kết đặt lại mật khẩu qua email.'),
          ),
        );
      }
    } on FirebaseAuthException catch (exception) {
      error = switch (exception.code) {
        'user-not-found' => 'Không tìm thấy tài khoản với email này.',
        'too-many-requests' => 'Quá nhiều yêu cầu. Vui lòng thử lại sau.',
        _ => 'Không thể gửi email đặt lại mật khẩu.',
      };
    } finally {
      if (mounted) setState(() => resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 860;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(desktop ? 32 : 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: desktop ? 980 : 480,
                  minHeight: desktop ? 610 : 0,
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: desktop
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 410,
                              child: _LoginBrandPanel(),
                            ),
                            Expanded(child: _buildForm()),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _LoginBrandPanel(compact: true),
                            _buildForm(compact: true),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm({bool compact = false}) => Container(
    color: AdminTheme.surface,
    padding: EdgeInsets.fromLTRB(
      compact ? 24 : 52,
      compact ? 30 : 54,
      compact ? 24 : 52,
      compact ? 34 : 48,
    ),
    child: AutofillGroup(
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Đăng nhập quản trị',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sử dụng tài khoản đã được cấp quyền quản trị hệ thống.',
              style: TextStyle(color: AdminTheme.mutedInk, height: 1.45),
            ),
            const SizedBox(height: 30),
            const _FormLabel('Email'),
            const SizedBox(height: 8),
            TextFormField(
              key: emailKey,
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                hintText: 'admin@schedula.vn',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 18),
            const _FormLabel('Mật khẩu'),
            const SizedBox(height: 8),
            TextFormField(
              controller: password,
              obscureText: !showPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                hintText: 'Nhập mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  tooltip: showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                  onPressed: () => setState(() => showPassword = !showPassword),
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                ),
              ),
              onFieldSubmitted: (_) => submit(),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Nhập mật khẩu.';
                return value.length < 6
                    ? 'Mật khẩu phải có ít nhất 6 ký tự.'
                    : null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: resetting ? null : resetPassword,
                child: Text(resetting ? 'Đang gửi...' : 'Quên mật khẩu?'),
              ),
            ),
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AdminTheme.danger.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AdminTheme.danger,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(color: AdminTheme.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 10),
            _GradientLoginButton(loading: loading, onPressed: submit),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: AdminTheme.mutedInk,
                ),
                SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Phiên đăng nhập được bảo vệ bởi Firebase Authentication',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AdminTheme.mutedInk, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: compact ? 250 : 610),
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 28 : 48,
      vertical: compact ? 30 : 54,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFE4F7F9)],
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/Icon.png',
          width: compact ? 78 : 124,
          height: compact ? 78 : 124,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        SizedBox(height: compact ? 18 : 32),
        Text(
          'Chào mừng trở lại',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AdminTheme.tealDark,
            fontSize: compact ? 26 : 32,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Trung tâm điều hành dành cho đội ngũ quản trị Schedula.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AdminTheme.mutedInk,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
  );
}

class _GradientLoginButton extends StatelessWidget {
  const _GradientLoginButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AdminTheme.teal, AdminTheme.tealDark],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24127D8C),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: Text(loading ? 'Đang đăng nhập...' : 'Đăng nhập'),
    ),
  );
}

String? _validateEmail(String? value) {
  final input = value?.trim() ?? '';
  return !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input)
      ? 'Nhập email hợp lệ.'
      : null;
}
