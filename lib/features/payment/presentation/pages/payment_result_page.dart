import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../account/presentation/pages/account_page.dart';
import '../../../auth/presentation/pages/login_page.dart';

class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage.success({super.key, this.orderCode})
    : isSuccess = true;

  const PaymentResultPage.cancelled({super.key, this.orderCode})
    : isSuccess = false;

  static const successRoutePath = '/payment/success';
  static const cancelRoutePath = '/payment/cancel';

  final bool isSuccess;
  final String? orderCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isSuccess
        ? const Color(0xFF14B8A6)
        : const Color(0xFFF97316);
    final soft = isSuccess ? const Color(0xFFE7F8F5) : const Color(0xFFFFF3E8);
    final title = isSuccess ? 'Thanh toán thành công' : 'Thanh toán đã hủy';
    final message = isSuccess
        ? 'PayOS đã ghi nhận giao dịch. Gói dịch vụ sẽ được cập nhật sau khi webhook xác nhận.'
        : 'Giao dịch PayOS chưa hoàn tất. Bạn có thể quay lại tài khoản để tạo lại thanh toán.';

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      isSuccess
                          ? Icons.verified_outlined
                          : Icons.cancel_outlined,
                      color: accent,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.45,
                    ),
                  ),
                  if (orderCode != null && orderCode!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Mã đơn: $orderCode',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A94A6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => context.go(AccountPage.routePath),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Về trang tài khoản'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go(LoginPage.routePath),
                    child: const Text('Đăng nhập lại nếu cần'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
