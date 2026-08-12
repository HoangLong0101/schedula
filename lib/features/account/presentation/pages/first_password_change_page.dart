import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../cubit/first_password_change_cubit.dart';

class FirstPasswordChangePage extends StatelessWidget {
  const FirstPasswordChangePage({super.key});

  static const routePath = '/first-password-change';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<FirstPasswordChangeCubit>(),
      child: const _FirstPasswordChangeView(),
    );
  }
}

class _FirstPasswordChangeView extends StatefulWidget {
  const _FirstPasswordChangeView();

  @override
  State<_FirstPasswordChangeView> createState() =>
      _FirstPasswordChangeViewState();
}

class _FirstPasswordChangeViewState extends State<_FirstPasswordChangeView> {
  final _temporaryPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _temporaryPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    if (_newPassword.text.length < 8 ||
        _newPassword.text != _confirmation.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu mới phải có ít nhất 8 ký tự và khớp nhau.'),
        ),
      );
      return;
    }
    final error = await context.read<FirstPasswordChangeCubit>().change(
      email: authState.user.email,
      temporaryPassword: _temporaryPassword.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.read<AuthBloc>().add(const AuthStarted());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset_outlined,
                        color: Color(0xFF148A9C),
                        size: 42,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Đổi mật khẩu lần đầu',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nhập mật khẩu tạm do chủ cơ sở cung cấp, sau đó chọn mật khẩu riêng của bạn.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _PasswordField(
                        controller: _temporaryPassword,
                        label: 'Mật khẩu tạm',
                        visible: _visible,
                      ),
                      const SizedBox(height: 12),
                      _PasswordField(
                        controller: _newPassword,
                        label: 'Mật khẩu mới',
                        visible: _visible,
                      ),
                      const SizedBox(height: 12),
                      _PasswordField(
                        controller: _confirmation,
                        label: 'Nhập lại mật khẩu mới',
                        visible: _visible,
                        onSubmitted: (_) => _submit(),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _visible,
                        title: const Text('Hiện mật khẩu'),
                        onChanged: (value) =>
                            setState(() => _visible = value ?? false),
                      ),
                      const SizedBox(height: 8),
                      BlocBuilder<FirstPasswordChangeCubit, bool>(
                        builder: (context, saving) => FilledButton(
                          onPressed: saving ? null : _submit,
                          child: saving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Đổi mật khẩu'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool visible;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
