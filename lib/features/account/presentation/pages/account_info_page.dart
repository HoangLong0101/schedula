import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/user_profile.dart';
import '../cubit/account_info_cubit.dart';

class AccountInfoPage extends StatelessWidget {
  const AccountInfoPage({super.key});

  static const routePath = '/account/info';

  @override
  Widget build(BuildContext context) {
    // Lấy email thực tế từ AuthBloc để truyền vào Cubit
    final authState = context.read<AuthBloc>().state;
    final email = authState is Authenticated ? authState.user.email : '';

    return BlocProvider(
      create: (_) => AccountInfoCubit(defaultEmail: email),
      child: const _AccountInfoView(),
    );
  }
}

class _AccountInfoView extends StatefulWidget {
  const _AccountInfoView();

  @override
  State<_AccountInfoView> createState() => _AccountInfoViewState();
}

class _AccountInfoViewState extends State<_AccountInfoView> {
  static const _tealColor = Color(0xFF148a9c);
  static const _tealGradient = LinearGradient(
    colors: [Color(0xFF22AFC2), Color(0xFF148a9c)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  bool _isSavingProfile = false;
  bool _profileSaved = false;

  bool _showPassword = false;
  bool _isSavingPw = false;
  bool _pwSaved = false;

  final _oldPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  @override
  void dispose() {
    _oldPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  bool get _canSavePw {
    return _oldPwCtrl.text.length >= 4 &&
        _newPwCtrl.text.length >= 6 &&
        _newPwCtrl.text == _confirmPwCtrl.text;
  }

  void _handleSaveProfile(BuildContext context) async {
    setState(() => _isSavingProfile = true);
    final success = await context.read<AccountInfoCubit>().saveProfile();
    setState(() {
      _isSavingProfile = false;
      _profileSaved = success;
    });
    if (success) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _profileSaved = false);
      });
    }
  }

  void _handleSavePw(BuildContext context) async {
    if (!_canSavePw) return;
    setState(() => _isSavingPw = true);
    final success = await context.read<AccountInfoCubit>().changePassword(_oldPwCtrl.text, _newPwCtrl.text);
    setState(() {
      _isSavingPw = false;
      _pwSaved = success;
    });
    if (success) {
      _oldPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _pwSaved = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _IconButton(
                    icon: Icons.chevron_left,
                    onTap: () => context.pop(),
                  ),
                  const Text(
                    'Tài khoản & Bảo mật',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  const SizedBox(width: 36), // Cân bằng layout
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: BlocBuilder<AccountInfoCubit, UserProfile>(
                  builder: (context, profile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar Section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      gradient: _tealGradient,
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
                                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -4,
                                    right: -4,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 16, color: _tealColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(profile.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 2),
                              const Text('Chủ cơ sở', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Personal Info Section
                        const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('Thông tin cá nhân', style: TextStyle(fontSize: 12, color: Colors.grey))),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
                          child: Column(
                            children: [
                              _FieldInput(
                                icon: Icons.person_outline,
                                label: 'Tên chủ cơ sở',
                                initialValue: profile.name,
                                onChanged: (val) => context.read<AccountInfoCubit>().updateProfileField(name: val),
                              ),
                              Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                              _FieldInput(
                                icon: Icons.phone_outlined,
                                label: 'Số điện thoại',
                                initialValue: profile.phone,
                                keyboardType: TextInputType.phone,
                                onChanged: (val) => context.read<AccountInfoCubit>().updateProfileField(phone: val),
                              ),
                              Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                              _FieldInput(
                                icon: Icons.mail_outline,
                                label: 'Email',
                                initialValue: profile.email,
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (val) => context.read<AccountInfoCubit>().updateProfileField(email: val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PrimaryButton(
                          label: _profileSaved ? 'Đã lưu' : 'Lưu thông tin',
                          icon: _profileSaved ? Icons.check : Icons.edit_outlined,
                          isLoading: _isSavingProfile,
                          onTap: () => _handleSaveProfile(context),
                        ),
                        const SizedBox(height: 24),

                        // Security Section
                        const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('Bảo mật', style: TextStyle(fontSize: 12, color: Colors.grey))),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: const Color(0xFFe0f8fc), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.lock_outline, size: 16, color: _tealColor),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Đổi mật khẩu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      Text('Cập nhật định kỳ để bảo vệ tài khoản', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _PwInput(
                                controller: _oldPwCtrl,
                                placeholder: 'Mật khẩu hiện tại',
                                isVisible: _showPassword,
                                onToggleVisibility: () => setState(() => _showPassword = !_showPassword),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 10),
                              _PwInput(
                                controller: _newPwCtrl,
                                placeholder: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                                isVisible: _showPassword,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 10),
                              _PwInput(
                                controller: _confirmPwCtrl,
                                placeholder: 'Xác nhận mật khẩu mới',
                                isVisible: _showPassword,
                                onChanged: (_) => setState(() {}),
                              ),
                              if (_confirmPwCtrl.text.isNotEmpty && _newPwCtrl.text != _confirmPwCtrl.text)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8, left: 4),
                                  child: Align(alignment: Alignment.centerLeft, child: Text('Mật khẩu xác nhận không khớp', style: TextStyle(color: Colors.red, fontSize: 12))),
                                ),
                              const SizedBox(height: 14),
                              _PrimaryButton(
                                label: _pwSaved ? 'Đã cập nhật' : 'Cập nhật mật khẩu',
                                icon: _pwSaved ? Icons.check : Icons.lock_outline,
                                isLoading: _isSavingPw,
                                isDisabled: !_canSavePw,
                                onTap: () => _handleSavePw(context),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Biometrics
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Sinh trắc học', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    Text('Đăng nhập nhanh và an toàn bằng khuôn mặt hoặc vân tay', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              _ToggleRow(
                                icon: Icons.face_retouching_natural,
                                label: 'Face ID',
                                hint: 'Mở khoá ứng dụng bằng khuôn mặt',
                                value: profile.faceIdEnabled,
                                onChanged: (v) => context.read<AccountInfoCubit>().toggleFaceId(v),
                              ),
                              Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                              _ToggleRow(
                                icon: Icons.fingerprint,
                                label: 'Vân tay',
                                hint: 'Xác nhận giao dịch bằng vân tay',
                                value: profile.fingerprintEnabled,
                                onChanged: (v) => context.read<AccountInfoCubit>().toggleFingerprint(v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2FA
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: const Color(0xFFe0f8fc), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.security, size: 16, color: _tealColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Xác thực 2 lớp (2FA)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                          Text('Yêu cầu mã xác thực khi đăng nhập thiết bị mới', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: profile.twoFaEnabled,
                                      onChanged: (v) => context.read<AccountInfoCubit>().toggleTwoFa(v),
                                      activeColor: Colors.white,
                                      activeTrackColor: _tealColor,
                                      inactiveTrackColor: Colors.grey.shade300,
                                    ),
                                  ],
                                ),
                              ),
                              if (profile.twoFaEnabled)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Phương thức nhận mã', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                      const SizedBox(height: 8),
                                      _MethodOption(
                                        icon: Icons.smartphone,
                                        label: 'Tin nhắn SMS',
                                        hint: 'Gửi mã 6 số đến số điện thoại',
                                        isSelected: profile.twoFaMethod == 'sms',
                                        onTap: () => context.read<AccountInfoCubit>().updateTwoFaMethod('sms'),
                                      ),
                                      const SizedBox(height: 8),
                                      _MethodOption(
                                        icon: Icons.mail_outline,
                                        label: 'Email',
                                        hint: 'Gửi mã đến email đã đăng ký',
                                        isSelected: profile.twoFaMethod == 'email',
                                        onTap: () => context.read<AccountInfoCubit>().updateTwoFaMethod('email'),
                                      ),
                                      const SizedBox(height: 8),
                                      _MethodOption(
                                        icon: Icons.verified_user_outlined,
                                        label: 'Ứng dụng Authenticator',
                                        hint: 'Google Authenticator / Authy',
                                        isSelected: profile.twoFaMethod == 'app',
                                        onTap: () => context.read<AccountInfoCubit>().updateTwoFaMethod('app'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CÁC WIDGET PHỤ TRỢ (HELPER WIDGETS) ---

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
        child: Icon(icon, size: 20, color: Colors.grey.shade700),
      ),
    );
  }
}

class _FieldInput extends StatelessWidget {
  final IconData icon;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  const _FieldInput({required this.icon, required this.label, required this.initialValue, required this.onChanged, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFe0f8fc), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 16, color: const Color(0xFF148a9c)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                TextFormField(
                  initialValue: initialValue,
                  onChanged: onChanged,
                  keyboardType: keyboardType,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(top: 4, bottom: 4),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PwInput extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;
  final ValueChanged<String> onChanged;

  const _PwInput({required this.controller, required this.placeholder, required this.isVisible, this.onToggleVisibility, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF22AFC2))),
        suffixIcon: onToggleVisibility != null
            ? IconButton(
          icon: Icon(isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: Colors.grey.shade400),
          onPressed: onToggleVisibility,
        )
            : null,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.icon, required this.label, required this.hint, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFe0f8fc), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 16, color: const Color(0xFF148a9c)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                Text(hint, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF148a9c),
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodOption({required this.icon, required this.label, required this.hint, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final teal = const Color(0xFF148a9c);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFe0f8fc) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF22AFC2) : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isSelected ? teal : Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade400),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  Text(hint, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check, size: 18, color: teal),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.icon, this.isLoading = false, this.isDisabled = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isDisabled || isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isDisabled || isLoading ? null : const LinearGradient(colors: [Color(0xFF22AFC2), Color(0xFF148a9c)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}