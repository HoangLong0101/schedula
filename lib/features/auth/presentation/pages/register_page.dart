import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../dashboard/presentation/pages/home_page.dart';
import '../../domain/entities/user.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.googleSetup = false});

  static const routePath = '/register';
  static const routeName = 'register';
  static const googleSetupPath = '/google-setup';
  static const googleSetupRouteName = 'google-setup';

  final bool googleSetup;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _weekdayOpenController = TextEditingController(text: '08:00');
  final _weekdayCloseController = TextEditingController(text: '20:00');
  final _weekendOpenController = TextEditingController(text: '09:00');
  final _weekendCloseController = TextEditingController(text: '18:00');

  int _step = 0;
  int _selectedBusinessType = 0;
  bool _acceptedTerms = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  final _businessTypes = const [
    _BusinessType('💆', 'Spa & Làm đẹp'),
    _BusinessType('🏥', 'Phòng khám da liễu'),
    _BusinessType('💇', 'Salon tóc'),
    _BusinessType('💅', 'Nail & Thẩm mỹ'),
    _BusinessType('🧘', 'Massage & Thư giãn'),
    _BusinessType('🩺', 'Phòng khám đa khoa'),
    _BusinessType('🏋️', 'Yoga & Fitness'),
    _BusinessType('✨', 'Khác'),
  ];

  bool get _isGoogleSetup => widget.googleSetup;

  @override
  void initState() {
    super.initState();
    if (_isGoogleSetup) {
      final user = FirebaseAuth.instance.currentUser;
      _nameController.text = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : '';
      _emailController.text = user?.email ?? '';
    }
    for (final controller in [
      _weekdayOpenController,
      _weekdayCloseController,
      _weekendOpenController,
      _weekendCloseController,
    ]) {
      controller.addListener(_refreshHoursSummary);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _weekdayOpenController,
      _weekdayCloseController,
      _weekendOpenController,
      _weekendCloseController,
    ]) {
      controller.removeListener(_refreshHoursSummary);
    }
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _weekdayOpenController.dispose();
    _weekdayCloseController.dispose();
    _weekendOpenController.dispose();
    _weekendCloseController.dispose();
    super.dispose();
  }

  void _refreshHoursSummary() {
    if (_step == 3 && mounted) {
      setState(() {});
    }
  }

  bool _validateCurrentStep() {
    final message = switch (_step) {
      0 => _validateAccount(),
      1 =>
        _businessNameController.text.trim().isEmpty
            ? 'Vui lòng nhập tên doanh nghiệp.'
            : '',
      2 => _validateContact(),
      _ => _validateHours(),
    };

    setState(() => _errorMessage = message);
    return message.isEmpty;
  }

  String _validateAccount() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isGoogleSetup) {
      if (_nameController.text.trim().isEmpty || email.isEmpty) {
        return 'Vui lòng nhập đầy đủ thông tin tài khoản.';
      }
      if (!_acceptedTerms) {
        return 'Bạn cần đồng ý với điều khoản sử dụng.';
      }
      return '';
    }

    if (_nameController.text.trim().isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      return 'Vui lòng điền đầy đủ thông tin tài khoản.';
    }

    if (!email.contains('@') || !email.contains('.')) {
      return 'Email chưa đúng định dạng.';
    }

    if (password.length < 8) {
      return 'Mật khẩu cần tối thiểu 8 ký tự.';
    }

    if (password != _confirmPasswordController.text) {
      return 'Mật khẩu xác nhận chưa khớp.';
    }

    if (!_acceptedTerms) {
      return 'Bạn cần đồng ý với điều khoản sử dụng.';
    }

    return '';
  }

  String _validateContact() {
    if (_addressController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      return 'Vui lòng nhập địa chỉ và số điện thoại.';
    }

    return '';
  }

  String _validateHours() {
    final values = [
      _weekdayOpenController.text,
      _weekdayCloseController.text,
      _weekendOpenController.text,
      _weekendCloseController.text,
    ];

    final valid = values.every(
      (value) => RegExp(r'^\d{2}:\d{2}$').hasMatch(value.trim()),
    );

    return valid ? '' : 'Giờ hoạt động cần có định dạng HH:mm.';
  }

  void _nextStep() {
    if (_isSubmitting) {
      return;
    }

    if (!_validateCurrentStep()) {
      return;
    }

    if (_step == 3) {
      _submitRegistration();
      return;
    }

    setState(() {
      _step += 1;
      _errorMessage = '';
    });
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    User? createdUser;

    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      var email = _emailController.text.trim();
      final ownerName = _nameController.text.trim();
      final tenantRef = firestore.collection('tenants').doc();
      final planStartedAt = Timestamp.now();
      final planExpiresAt = Timestamp.fromDate(
        planStartedAt.toDate().add(const Duration(days: 30)),
      );
      final now = FieldValue.serverTimestamp();

      if (_isGoogleSetup) {
        createdUser = auth.currentUser;
      } else {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
        createdUser = credential.user;
      }

      if (createdUser == null) {
        throw FirebaseAuthException(
          code: 'user-create-failed',
          message: 'Không tạo được tài khoản.',
        );
      }

      if (_isGoogleSetup) {
        email = createdUser.email ?? email;
      }

      await createdUser.updateDisplayName(ownerName);

      final batch = firestore.batch();
      batch.set(tenantRef, {
        'tenantId': tenantRef.id,
        'name': _businessNameController.text.trim(),
        'type': _businessTypes[_selectedBusinessType].label,
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'website': _websiteController.text.trim(),
        'hoursWeekday':
            '${_weekdayOpenController.text.trim()} - ${_weekdayCloseController.text.trim()}',
        'hoursWeekend':
            '${_weekendOpenController.text.trim()} - ${_weekendCloseController.text.trim()}',
        'description': _descriptionController.text.trim(),
        'ownerUid': createdUser.uid,
        'planTier': 'basic',
        'planStartedAt': planStartedAt,
        'planExpiresAt': planExpiresAt,
        'createdAt': now,
        'updatedAt': now,
      });
      batch.set(firestore.collection('users').doc(createdUser.uid), {
        'tenantId': tenantRef.id,
        'role': 'owner',
        'name': ownerName,
        'email': email,
        'createdAt': now,
        'updatedAt': now,
      });

      await batch.commit();

      if (!mounted) {
        return;
      }

      if (_isGoogleSetup) {
        context.read<AuthBloc>().add(
          AuthProfileCompleted(
            AppUser(
              id: createdUser.uid,
              email: email,
              role: 'owner',
              tenantId: tenantRef.id,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thiết lập cơ sở thành công.')),
        );
        context.go(HomePage.routePath);
        return;
      }

      await auth.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng ký thành công. Vui lòng đăng nhập.'),
        ),
      );
      context.go(LoginPage.routePath);
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = switch (error.code) {
          'email-already-in-use' => 'Email này đã được đăng ký.',
          'invalid-email' => 'Email chưa đúng định dạng.',
          'weak-password' => 'Mật khẩu cần mạnh hơn.',
          _ => error.message ?? 'Đăng ký thất bại. Vui lòng thử lại.',
        };
      });
    } on FirebaseException catch (error) {
      debugPrint('register firestore failed: ${error.code} ${error.message}');
      if (createdUser != null && !_isGoogleSetup) {
        await createdUser.delete().catchError((_) {});
        await FirebaseAuth.instance.signOut();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Không lưu được thông tin doanh nghiệp (${error.code}). Vui lòng thử lại.';
      });
    } catch (error, stackTrace) {
      debugPrint('register unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Đăng ký thất bại. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _previousStep() {
    if (_step == 0) {
      context.go(LoginPage.routePath);
      return;
    }

    setState(() {
      _step -= 1;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RegisterColors.background,
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RegisterHero(step: _step, onBack: _previousStep),
                        const _WaveDivider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 18, 32, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_step > 0) ...[
                                _StepIndicator(step: _step),
                                const SizedBox(height: 24),
                              ],
                              if (_errorMessage.isNotEmpty) ...[
                                _ErrorBanner(message: _errorMessage),
                                const SizedBox(height: 16),
                              ],
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: KeyedSubtree(
                                  key: ValueKey(_step),
                                  child: _buildStep(),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildActions(),
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
    );
  }

  Widget _buildStep() {
    if (_step == 0 && _isGoogleSetup) {
      return _GoogleAccountStep(
        nameController: _nameController,
        emailController: _emailController,
        acceptedTerms: _acceptedTerms,
        onTermsChanged: (value) {
          setState(() => _acceptedTerms = value ?? false);
        },
        onSubmitted: (_) => _nextStep(),
      );
    }

    return switch (_step) {
      0 => _AccountStep(
        nameController: _nameController,
        emailController: _emailController,
        passwordController: _passwordController,
        confirmPasswordController: _confirmPasswordController,
        acceptedTerms: _acceptedTerms,
        showPassword: _showPassword,
        showConfirmPassword: _showConfirmPassword,
        onTermsChanged: (value) {
          setState(() => _acceptedTerms = value ?? false);
        },
        onTogglePassword: () {
          setState(() => _showPassword = !_showPassword);
        },
        onToggleConfirmPassword: () {
          setState(() => _showConfirmPassword = !_showConfirmPassword);
        },
        onSubmitted: (_) => _nextStep(),
      ),
      1 => _BusinessStep(
        businessNameController: _businessNameController,
        descriptionController: _descriptionController,
        selectedIndex: _selectedBusinessType,
        businessTypes: _businessTypes,
        onTypeSelected: (index) {
          setState(() => _selectedBusinessType = index);
        },
        onSubmitted: (_) => _nextStep(),
      ),
      2 => _ContactStep(
        addressController: _addressController,
        phoneController: _phoneController,
        websiteController: _websiteController,
        onSubmitted: (_) => _nextStep(),
      ),
      _ => _HoursStep(
        weekdayOpenController: _weekdayOpenController,
        weekdayCloseController: _weekdayCloseController,
        weekendOpenController: _weekendOpenController,
        weekendCloseController: _weekendCloseController,
      ),
    };
  }

  Widget _buildActions() {
    if (_step == 0) {
      return _PrimaryButton(
        label: _isGoogleSetup
            ? 'Tiếp tục thiết lập cơ sở →'
            : 'Đăng ký & Thiết lập doanh nghiệp →',
        onPressed: _isSubmitting ? null : _nextStep,
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 116,
          child: _SecondaryButton(
            label: 'Quay lại',
            onPressed: _isSubmitting ? null : _previousStep,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _PrimaryButton(
            label: _isSubmitting
                ? 'Đang tạo tài khoản...'
                : _step == 3
                ? 'Hoàn tất thiết lập →'
                : 'Tiếp theo ›',
            onPressed: _isSubmitting ? null : _nextStep,
          ),
        ),
      ],
    );
  }
}

class _RegisterHero extends StatelessWidget {
  const _RegisterHero({required this.step, required this.onBack});

  final int step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Tạo tài khoản mới ✨',
      'Doanh nghiệp của bạn',
      'Địa chỉ & liên hệ',
      'Giờ hoạt động',
    ];
    final subtitles = [
      'Quản lý lịch hẹn thông minh hơn với Schedula',
      'Cho chúng tôi biết về cơ sở của bạn',
      'Khách hàng sẽ tìm thấy bạn qua thông tin này',
      'Khi nào bạn mở cửa đón khách?',
    ];

    return Container(
      height: step == 0 ? 292 : 236,
      padding: EdgeInsets.fromLTRB(32, step == 0 ? 32 : 24, 32, 0),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step == 0) ...[_BackButton(onPressed: onBack), const Spacer()],
          Image.asset(
            'resource/schedula_logo.png',
            width: 158,
            height: 42,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          SizedBox(height: step == 0 ? 30 : 28),
          if (step > 0) ...[
            Text(
              'Bước $step / 3',
              style: const TextStyle(
                color: _RegisterColors.subtle,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            titles[step],
            style: GoogleFonts.bricolageGrotesque(
              color: _RegisterColors.title,
              fontSize: step == 0 ? 28 : 26,
              fontWeight: FontWeight.w800,
              height: 1.06,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitles[step],
            style: const TextStyle(
              color: _RegisterColors.subtle,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _GoogleAccountStep extends StatelessWidget {
  const _GoogleAccountStep({
    required this.nameController,
    required this.emailController,
    required this.acceptedTerms,
    required this.onTermsChanged,
    required this.onSubmitted,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final bool acceptedTerms;
  final ValueChanged<bool?> onTermsChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InfoBox(
          icon: Icons.g_mobiledata_rounded,
          text:
              'Tài khoản Google của bạn chưa có cơ sở trong Schedula. Vui lòng hoàn tất thông tin để bắt đầu sử dụng.',
        ),
        const SizedBox(height: 20),
        const _FormLabel('Họ và tên'),
        const SizedBox(height: 9),
        _InputField(
          controller: nameController,
          hintText: 'Nguyễn Văn A',
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 20),
        const _FormLabel('Email Google'),
        const SizedBox(height: 9),
        _InputField(
          controller: emailController,
          hintText: 'email@example.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 18),
        _TermsCheckbox(value: acceptedTerms, onChanged: onTermsChanged),
      ],
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.acceptedTerms,
    required this.showPassword,
    required this.showConfirmPassword,
    required this.onTermsChanged,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onSubmitted,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool acceptedTerms;
  final bool showPassword;
  final bool showConfirmPassword;
  final ValueChanged<bool?> onTermsChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormLabel('Họ và tên'),
        const SizedBox(height: 9),
        _InputField(
          controller: nameController,
          hintText: 'Nguyễn Văn A',
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 20),
        const _FormLabel('Email'),
        const SizedBox(height: 9),
        _InputField(
          controller: emailController,
          hintText: 'email@example.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 20),
        const _FormLabel('Mật khẩu'),
        const SizedBox(height: 9),
        _InputField(
          controller: passwordController,
          hintText: 'Tối thiểu 8 ký tự',
          icon: Icons.lock_outline_rounded,
          obscureText: !showPassword,
          textInputAction: TextInputAction.next,
          trailing: IconButton(
            onPressed: onTogglePassword,
            icon: Icon(
              showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _RegisterColors.icon,
              size: 20,
            ),
          ),
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 20),
        const _FormLabel('Xác nhận mật khẩu'),
        const SizedBox(height: 9),
        _InputField(
          controller: confirmPasswordController,
          hintText: 'Nhập lại mật khẩu',
          icon: Icons.lock_outline_rounded,
          obscureText: !showConfirmPassword,
          textInputAction: TextInputAction.done,
          trailing: IconButton(
            onPressed: onToggleConfirmPassword,
            icon: Icon(
              showConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _RegisterColors.icon,
              size: 20,
            ),
          ),
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: acceptedTerms,
                onChanged: onTermsChanged,
                activeColor: _RegisterColors.tealDark,
                side: const BorderSide(color: _RegisterColors.icon, width: 1.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tôi đồng ý với điều khoản sử dụng và chính sách bảo mật của Schedula',
                style: TextStyle(
                  color: _RegisterColors.subtle,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: _RegisterColors.tealDark,
            side: const BorderSide(color: _RegisterColors.icon, width: 1.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Tôi đồng ý với điều khoản sử dụng và chính sách bảo mật của Schedula',
            style: TextStyle(
              color: _RegisterColors.subtle,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessStep extends StatelessWidget {
  const _BusinessStep({
    required this.businessNameController,
    required this.descriptionController,
    required this.selectedIndex,
    required this.businessTypes,
    required this.onTypeSelected,
    required this.onSubmitted,
  });

  final TextEditingController businessNameController;
  final TextEditingController descriptionController;
  final int selectedIndex;
  final List<_BusinessType> businessTypes;
  final ValueChanged<int> onTypeSelected;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormLabel('Tên doanh nghiệp *'),
        const SizedBox(height: 9),
        _InputField(
          controller: businessNameController,
          hintText: 'Schedula Spa',
          icon: Icons.business_outlined,
          textInputAction: TextInputAction.next,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 20),
        const _FormLabel('Loại hình doanh nghiệp *'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: businessTypes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 74,
          ),
          itemBuilder: (context, index) {
            final item = businessTypes[index];
            return _BusinessTypeTile(
              item: item,
              selected: selectedIndex == index,
              onTap: () => onTypeSelected(index),
            );
          },
        ),
        const SizedBox(height: 20),
        const _FormLabel('Mô tả ngắn (tùy chọn)'),
        const SizedBox(height: 9),
        _TextArea(
          controller: descriptionController,
          hintText: 'Giới thiệu ngắn về doanh nghiệp của bạn',
        ),
      ],
    );
  }
}

class _ContactStep extends StatelessWidget {
  const _ContactStep({
    required this.addressController,
    required this.phoneController,
    required this.websiteController,
    required this.onSubmitted,
  });

  final TextEditingController addressController;
  final TextEditingController phoneController;
  final TextEditingController websiteController;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FormLabel('Địa chỉ *'),
        const SizedBox(height: 9),
        _InputField(
          controller: addressController,
          hintText: 'Số nhà, đường, quận, thành phố',
          icon: Icons.location_on_outlined,
          textInputAction: TextInputAction.next,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 20),
        const _FormLabel('Số điện thoại *'),
        const SizedBox(height: 9),
        _InputField(
          controller: phoneController,
          hintText: '028 xxxx xxxx hoặc 09xxxxxxxx',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 20),
        const _FormLabel('Website / Fanpage (tùy chọn)'),
        const SizedBox(height: 9),
        _InputField(
          controller: websiteController,
          hintText: 'website.com hoặc facebook.com/page',
          icon: Icons.language_rounded,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 20),
        const _InfoBox(
          icon: Icons.location_on_outlined,
          text:
              'Thông tin liên hệ sẽ được hiển thị cho khách hàng khi họ đặt lịch hoặc tra cứu doanh nghiệp của bạn.',
        ),
      ],
    );
  }
}

class _HoursStep extends StatelessWidget {
  const _HoursStep({
    required this.weekdayOpenController,
    required this.weekdayCloseController,
    required this.weekendOpenController,
    required this.weekendCloseController,
  });

  final TextEditingController weekdayOpenController;
  final TextEditingController weekdayCloseController;
  final TextEditingController weekendOpenController;
  final TextEditingController weekendCloseController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HoursCard(
          title: 'Thứ 2 — Thứ 6',
          subtitle: 'Ngày làm việc',
          openController: weekdayOpenController,
          closeController: weekdayCloseController,
        ),
        const SizedBox(height: 26),
        _HoursCard(
          title: 'Thứ 7 — Chủ nhật',
          subtitle: 'Cuối tuần',
          openController: weekendOpenController,
          closeController: weekendCloseController,
        ),
        const SizedBox(height: 26),
        _HoursSummary(
          weekdayOpen: weekdayOpenController.text,
          weekdayClose: weekdayCloseController.text,
          weekendOpen: weekendOpenController.text,
          weekendClose: weekendCloseController.text,
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepCircle(number: 1, complete: step > 1, active: step == 1),
        const Expanded(child: _StepLine(active: true)),
        _StepCircle(number: 2, complete: step > 2, active: step == 2),
        Expanded(child: _StepLine(active: step > 1)),
        _StepCircle(number: 3, complete: false, active: step == 3),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.number,
    required this.complete,
    required this.active,
  });

  final int number;
  final bool complete;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final filled = active || complete;

    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: filled ? _RegisterColors.tealDark : const Color(0xFFEAF8FA),
        shape: BoxShape.circle,
        boxShadow: active
            ? const [
                BoxShadow(
                  color: Color(0x4433B6C8),
                  blurRadius: 0,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: Center(
        child: complete
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 23)
            : Text(
                '$number',
                style: TextStyle(
                  color: filled ? Colors.white : _RegisterColors.icon,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: active ? _RegisterColors.teal : _RegisterColors.inputBorder,
    );
  }
}

class _BusinessTypeTile extends StatelessWidget {
  const _BusinessTypeTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _BusinessType item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? _RegisterColors.teal
                  : _RegisterColors.inputBorder,
              width: selected ? 2 : 1.4,
            ),
          ),
          child: Row(
            children: [
              Text(item.icon, style: const TextStyle(fontSize: 23)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF465167),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 10,
                  backgroundColor: _RegisterColors.teal,
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({
    required this.title,
    required this.subtitle,
    required this.openController,
    required this.closeController,
  });

  final String title;
  final String subtitle;
  final TextEditingController openController;
  final TextEditingController closeController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _RegisterColors.inputBorder, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFE9FAFC),
                child: Icon(
                  Icons.schedule_rounded,
                  color: _RegisterColors.tealDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF3E495E),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _RegisterColors.subtle,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _TimeInput(
                  label: 'Giờ mở cửa',
                  controller: openController,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _TimeInput(
                  label: 'Giờ đóng cửa',
                  controller: closeController,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeInput extends StatelessWidget {
  const _TimeInput({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _RegisterColors.subtle,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 57,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(
              color: _RegisterColors.title,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: _RegisterColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: _RegisterColors.inputBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: _RegisterColors.inputBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: _RegisterColors.teal,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _HoursSummary extends StatelessWidget {
  const _HoursSummary({
    required this.weekdayOpen,
    required this.weekdayClose,
    required this.weekendOpen,
    required this.weekendClose,
  });

  final String weekdayOpen;
  final String weekdayClose;
  final String weekendOpen;
  final String weekendClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F7FA),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _RegisterColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tóm tắt lịch hoạt động',
            style: TextStyle(
              color: _RegisterColors.subtle,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          _SummaryRow(label: 'T2 - T6:', value: '$weekdayOpen - $weekdayClose'),
          const SizedBox(height: 8),
          _SummaryRow(label: 'T7 - CN:', value: '$weekendOpen - $weekendClose'),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5D7282),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: _RegisterColors.tealDark,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
          border: Border.all(color: _RegisterColors.inputBorder, width: 1.4),
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
            prefixIcon: Icon(icon, size: 22, color: _RegisterColors.icon),
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

class _TextArea extends StatelessWidget {
  const _TextArea({required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 4,
      style: const TextStyle(
        color: Color(0xFF5B6473),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFFAAAAAA),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _RegisterColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _RegisterColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _RegisterColors.teal, width: 1.5),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [_RegisterColors.teal, _RegisterColors.tealDark],
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
        height: 65,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 65,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFEAF8FA),
          foregroundColor: _RegisterColors.subtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFEAF8FA),
          foregroundColor: _RegisterColors.tealDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _RegisterColors.inputBorder),
          ),
        ),
        icon: const Icon(Icons.chevron_left_rounded, size: 28),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F7FA),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _RegisterColors.inputBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFD4F4F8),
            child: Icon(icon, color: _RegisterColors.tealDark, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF5D7282),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _RegisterColors.subtle,
        fontSize: 15,
        fontWeight: FontWeight.w600,
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
    final tealPaint = Paint()..color = _RegisterColors.background;

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

class _BusinessType {
  const _BusinessType(this.icon, this.label);

  final String icon;
  final String label;
}

class _RegisterColors {
  static const background = Color(0xFFF0F9FA);
  static const teal = Color(0xFF22AFC2);
  static const tealDark = Color(0xFF148A9C);
  static const title = Color(0xFF0E7490);
  static const subtle = Color(0xFF64A8B4);
  static const inputBorder = Color(0xFFD4EEF3);
  static const icon = Color(0xFF9ECFDA);
}
