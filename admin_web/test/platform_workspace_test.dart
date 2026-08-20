import 'package:flutter_test/flutter_test.dart';
import 'package:schedula_admin/src/platform_workspace.dart';

void main() {
  test('parses real SaaS metrics and PayOS reconciliation fields', () {
    final workspace = PlatformWorkspace.fromMap({
      'generatedAt': 1000,
      'actor': {
        'uid': 'admin-1',
        'email': 'admin@schedula.vn',
        'role': 'finance_admin',
        'permissions': ['dashboard.read', 'transaction.reconcile'],
      },
      'metrics': {
        'totalRevenue': 699000,
        'mrr': 699000,
        'arr': 8388000,
        'transactionSuccessRate': 100,
      },
      'businesses': const [],
      'transactions': [
        {
          'id': 'payment-1',
          'orderCode': 123,
          'amount': 699000,
          'provider': 'payos',
          'status': 'paid',
          'reconciliationStatus': 'verified',
        },
      ],
      'plans': const [],
      'analytics': const {},
      'auditEvents': const [],
      'admins': const [],
    });

    expect(workspace.actor.can('transaction.reconcile'), isTrue);
    expect(workspace.metrics.arr, 8388000);
    expect(workspace.transactions.single.provider, 'payos');
    expect(workspace.transactions.single.reconciliationStatus, 'verified');
  });
}
