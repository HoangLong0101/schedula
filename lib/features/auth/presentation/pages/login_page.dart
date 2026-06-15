import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../dashboard/presentation/pages/home_page.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const routePath = '/login';
  static const routeName = 'login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng điền đầy đủ thông tin.';
      });
      return;
    }

    setState(() => _errorMessage = '');
    context.read<AuthBloc>().add(
      AuthSignInRequested(email: email, password: password),
    );
  }

  void _signInWithGoogle(BuildContext context) {
    setState(() => _errorMessage = '');
    context.read<AuthBloc>().add(const AuthGoogleSignInRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          context.go(HomePage.routePath);
          return;
        }

        if (state is AuthFailure) {
          setState(() {
            _errorMessage = state.message;
          });
          return;
        }

        if (state is AuthLoading) {
          setState(() => _errorMessage = '');
        }
      },
      child: Scaffold(
        backgroundColor: _LoginColors.background,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = math.min(constraints.maxWidth, 430.0);

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          const _LoginHero(),
                          const _WaveDivider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(33, 20, 33, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_errorMessage.isNotEmpty) ...[
                                  _ErrorBanner(message: _errorMessage),
                                  const SizedBox(height: 16),
                                ],
                                const _FormLabel('Email'),
                                const SizedBox(height: 9),
                                _InputField(
                                  controller: _emailController,
                                  hintText: 'email@example.com',
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  icon: Icons.mail_outline_rounded,
                                  onSubmitted: (_) => _submit(context),
                                ),
                                const SizedBox(height: 21),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const _FormLabel('Mật khẩu'),
                                    GestureDetector(
                                      onTap: () {},
                                      child: const Text(
                                        'Quên mật khẩu?',
                                        style: TextStyle(
                                          color: _LoginColors.tealDark,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 9),
                                _InputField(
                                  controller: _passwordController,
                                  hintText: 'Nhập mật khẩu',
                                  obscureText: !_showPassword,
                                  textInputAction: TextInputAction.done,
                                  icon: Icons.lock_outline_rounded,
                                  onSubmitted: (_) => _submit(context),
                                  trailing: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _showPassword = !_showPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: _LoginColors.icon,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    final loading = state is AuthLoading;
                                    return _PrimaryLoginButton(
                                      loading: loading,
                                      onPressed: loading
                                          ? null
                                          : () => _submit(context),
                                    );
                                  },
                                ),
                                const SizedBox(height: 19),
                                const _DividerRow(),
                                const SizedBox(height: 15),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    final loading = state is AuthLoading;

                                    return Row(
                                      children: [
                                        Expanded(
                                          child: _SocialButton(
                                            label: 'Google',
                                            icon: const _GoogleIcon(),
                                            loading: loading,
                                            onPressed: loading
                                                ? null
                                                : () => _signInWithGoogle(
                                                    context,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: _SocialButton(
                                            label: 'Facebook',
                                            icon: const _FacebookIcon(),
                                            loading: loading,
                                            onPressed: loading
                                                ? null
                                                : () {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Đăng nhập Facebook chưa được hỗ trợ.',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 42),
                                _FooterLinkRow(
                                  prompt: 'Chưa có tài khoản?',
                                  actionLabel: 'Đăng ký ngay',
                                  onPressed: () =>
                                      context.go(RegisterPage.routePath),
                                ),
                                const SizedBox(height: 16),
                                _AdminLoginButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Đăng nhập Admin chưa được triển khai.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 18),
                                const _HomeIndicator(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 270,
      padding: const EdgeInsets.fromLTRB(30, 54, 30, 0),
      decoration: const BoxDecoration(color: Colors.white),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'resource/schedula_logo.png',
                width: 182,
                height: 48,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 38),
              Text(
                'Chào mừng trở lại 👋',
                textAlign: TextAlign.center,
                style: GoogleFonts.bricolageGrotesque(
                  color: _LoginColors.title,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 11),
              const Text(
                'Đăng nhập để quản lý lịch hẹn của bạn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _LoginColors.subtle,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveDivider extends StatelessWidget {
  const _WaveDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      width: double.infinity,
      child: CustomPaint(painter: _WaveDividerPainter()),
    );
  }
}

class _WaveDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final whitePaint = Paint()..color = Colors.white;
    final tealPaint = Paint()..color = _LoginColors.background;

    final wavePath = Path()
      ..moveTo(0, size.height * 0.35)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.68,
        size.width * 0.49,
        size.height * 0.62,
        size.width * 0.72,
        size.height * 0.31,
      )
      ..cubicTo(
        size.width * 0.87,
        size.height * 0.12,
        size.width * 0.95,
        size.height * 0.18,
        size.width,
        size.height * 0.35,
      );

    final whitePath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.35)
      ..addPath(wavePath, Offset.zero)
      ..lineTo(size.width, 0)
      ..close();

    final tealPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.35)
      ..addPath(wavePath, Offset.zero)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(tealPath, tealPaint);
    canvas.drawPath(whitePath, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _LoginColors.subtle,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.onSubmitted,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String> onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 67,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _LoginColors.inputBorder, width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F148A9C),
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            color: Color(0xFF5B6473),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, size: 22, color: _LoginColors.icon),
            suffixIcon: trailing,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryLoginButton extends StatelessWidget {
  const _PrimaryLoginButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [_LoginColors.teal, _LoginColors.tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33148A9C),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 65,
        child: ElevatedButton(
          onPressed: onPressed,
          style:
              ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ).copyWith(
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return const Color(0x22000000);
                  }
                  return null;
                }),
              ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Đăng nhập',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }
}

class _DividerRow extends StatelessWidget {
  const _DividerRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: _LoginColors.inputBorder, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Hoặc tiếp tục với',
            style: TextStyle(color: _LoginColors.icon, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: _LoginColors.inputBorder, height: 1)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.loading,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 63,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: _LoginColors.inputBorder, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF566074),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 20,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}

class _FacebookIcon extends StatelessWidget {
  const _FacebookIcon();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'f',
      style: TextStyle(
        color: Color(0xFF1877F2),
        fontSize: 25,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}

class _FooterLinkRow extends StatelessWidget {
  const _FooterLinkRow({
    required this.prompt,
    required this.actionLabel,
    required this.onPressed,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: const TextStyle(fontSize: 15, color: _LoginColors.subtle),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: _LoginColors.tealDark,
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _AdminLoginButton extends StatelessWidget {
  const _AdminLoginButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0x143AADC0),
        side: const BorderSide(color: _LoginColors.inputBorder, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: _LoginColors.tealDark),
          SizedBox(width: 8),
          Text(
            'Đăng nhập Admin',
            style: TextStyle(
              fontSize: 13,
              color: _LoginColors.tealDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFF87171)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFEF4444),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 134,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0x3322AFC2),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _LoginColors {
  static const background = Color(0xFFF0F9FA);
  static const teal = Color(0xFF22AFC2);
  static const tealDark = Color(0xFF148A9C);
  static const title = Color(0xFF0E7490);
  static const subtle = Color(0xFF64A8B4);
  static const inputBorder = Color(0xFFD4EEF3);
  static const icon = Color(0xFF9ECFDA);
}
