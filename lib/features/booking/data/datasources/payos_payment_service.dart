import 'package:cloud_functions/cloud_functions.dart';

class PayOSPaymentLink {
  const PayOSPaymentLink({
    required this.paymentId,
    required this.checkoutUrl,
    required this.status,
    required this.orderCode,
    required this.paymentLinkId,
  });

  final String paymentId;
  final String checkoutUrl;
  final String status;
  final int orderCode;
  final String paymentLinkId;
}

class PayOSPaymentService {
  PayOSPaymentService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  Future<PayOSPaymentLink> createPaymentLink({
    required String bookingId,
    required int amount,
  }) async {
    final callable = _functions.httpsCallable('createPayOSPayment');
    final result = await callable.call<Map<String, dynamic>>({
      'bookingId': bookingId,
      'amount': amount,
    });
    final data = result.data;

    return PayOSPaymentLink(
      paymentId: data['paymentId'] as String,
      checkoutUrl: data['checkoutUrl'] as String,
      status: data['status'] as String,
      orderCode: data['orderCode'] as int,
      paymentLinkId: data['paymentLinkId'] as String,
    );
  }
}
