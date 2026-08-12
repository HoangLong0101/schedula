typedef JsonMap = Map<Object?, Object?>;

class WorkspaceFilter {
  const WorkspaceFilter({
    required this.start,
    required this.end,
    this.province = '',
    this.businessType = '',
    this.plan = '',
    this.subscriptionStatus = '',
    this.transactionStatus = '',
    this.query = '',
  });

  factory WorkspaceFilter.last30Days() {
    final end = DateTime.now();
    return WorkspaceFilter(
      start: end.subtract(const Duration(days: 29)),
      end: end,
    );
  }

  final DateTime start;
  final DateTime end;
  final String province;
  final String businessType;
  final String plan;
  final String subscriptionStatus;
  final String transactionStatus;
  final String query;

  Map<String, Object?> toMap() => {
    'startAt': start.toUtc().toIso8601String(),
    'endAt': end.toUtc().toIso8601String(),
    if (province.isNotEmpty) 'province': province,
    if (businessType.isNotEmpty) 'businessType': businessType,
    if (plan.isNotEmpty) 'plan': plan,
    if (subscriptionStatus.isNotEmpty) 'subscriptionStatus': subscriptionStatus,
    if (transactionStatus.isNotEmpty) 'transactionStatus': transactionStatus,
    if (query.trim().isNotEmpty) 'query': query.trim(),
  };

  WorkspaceFilter copyWith({
    DateTime? start,
    DateTime? end,
    String? province,
    String? businessType,
    String? plan,
    String? subscriptionStatus,
    String? transactionStatus,
    String? query,
  }) => WorkspaceFilter(
    start: start ?? this.start,
    end: end ?? this.end,
    province: province ?? this.province,
    businessType: businessType ?? this.businessType,
    plan: plan ?? this.plan,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    transactionStatus: transactionStatus ?? this.transactionStatus,
    query: query ?? this.query,
  );
}

class PlatformWorkspace {
  const PlatformWorkspace({
    required this.generatedAt,
    required this.actor,
    required this.metrics,
    required this.businesses,
    required this.transactions,
    required this.plans,
    required this.analytics,
    required this.auditEvents,
    required this.webhookEvents,
    required this.admins,
    required this.businessesTruncated,
    required this.transactionsTruncated,
  });

  factory PlatformWorkspace.fromMap(JsonMap data) {
    final limits = _map(data['limits']);
    return PlatformWorkspace(
      generatedAt: _date(data['generatedAt']) ?? DateTime.now(),
      actor: PlatformActor.fromMap(_map(data['actor'])),
      metrics: PlatformSaasMetrics.fromMap(_map(data['metrics'])),
      businesses: _list(data['businesses'], PlatformBusinessRecord.fromMap),
      transactions: _list(data['transactions'], PlatformTransaction.fromMap),
      plans: _list(data['plans'], PlatformPlan.fromMap),
      analytics: PlatformAnalytics.fromMap(_map(data['analytics'])),
      auditEvents: _list(data['auditEvents'], PlatformEvent.fromMap),
      webhookEvents: _list(data['webhookEvents'], PlatformEvent.fromMap),
      admins: _list(data['admins'], PlatformAdminRecord.fromMap),
      businessesTruncated: limits['businessesTruncated'] == true,
      transactionsTruncated: limits['transactionsTruncated'] == true,
    );
  }

  final DateTime generatedAt;
  final PlatformActor actor;
  final PlatformSaasMetrics metrics;
  final List<PlatformBusinessRecord> businesses;
  final List<PlatformTransaction> transactions;
  final List<PlatformPlan> plans;
  final PlatformAnalytics analytics;
  final List<PlatformEvent> auditEvents;
  final List<PlatformEvent> webhookEvents;
  final List<PlatformAdminRecord> admins;
  final bool businessesTruncated;
  final bool transactionsTruncated;
}

class PlatformActor {
  const PlatformActor({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.permissions,
  });

  factory PlatformActor.fromMap(JsonMap data) => PlatformActor(
    uid: _string(data['uid']),
    email: _string(data['email']),
    name: _string(data['name']),
    role: _string(data['role'], 'analyst'),
    permissions: (data['permissions'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet(),
  );

  final String uid;
  final String email;
  final String name;
  final String role;
  final Set<String> permissions;

  bool can(String permission) => permissions.contains(permission);
}

class PlatformSaasMetrics {
  const PlatformSaasMetrics({
    required this.totalRevenue,
    required this.previousRevenue,
    required this.revenueChangePercent,
    required this.mrr,
    required this.arr,
    required this.arpu,
    required this.activeBusinesses,
    required this.newBusinesses,
    required this.activeSubscriptions,
    required this.trialBusinesses,
    required this.failedPayments,
    required this.failedPaymentAmount,
    required this.churnedBusinesses,
    required this.transactionSuccessRate,
    required this.topProvince,
  });

  factory PlatformSaasMetrics.fromMap(JsonMap data) => PlatformSaasMetrics(
    totalRevenue: _int(data['totalRevenue']),
    previousRevenue: _int(data['previousRevenue']),
    revenueChangePercent: _double(data['revenueChangePercent']),
    mrr: _int(data['mrr']),
    arr: _int(data['arr']),
    arpu: _int(data['arpu']),
    activeBusinesses: _int(data['activeBusinesses']),
    newBusinesses: _int(data['newBusinesses']),
    activeSubscriptions: _int(data['activeSubscriptions']),
    trialBusinesses: _int(data['trialBusinesses']),
    failedPayments: _int(data['failedPayments']),
    failedPaymentAmount: _int(data['failedPaymentAmount']),
    churnedBusinesses: _int(data['churnedBusinesses']),
    transactionSuccessRate: _double(data['transactionSuccessRate']),
    topProvince: _string(data['topProvince']),
  );

  final int totalRevenue;
  final int previousRevenue;
  final double revenueChangePercent;
  final int mrr;
  final int arr;
  final int arpu;
  final int activeBusinesses;
  final int newBusinesses;
  final int activeSubscriptions;
  final int trialBusinesses;
  final int failedPayments;
  final int failedPaymentAmount;
  final int churnedBusinesses;
  final double transactionSuccessRate;
  final String topProvince;
}

class PlatformBusinessRecord {
  const PlatformBusinessRecord({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.businessType,
    required this.province,
    required this.address,
    required this.phone,
    required this.planTier,
    required this.subscriptionStatus,
    required this.status,
    required this.createdAt,
    required this.lastActiveAt,
    required this.planExpiresAt,
  });

  factory PlatformBusinessRecord.fromMap(JsonMap data) =>
      PlatformBusinessRecord(
        id: _string(data['id']),
        name: _string(data['name']),
        ownerName: _string(data['ownerName']),
        ownerEmail: _string(data['ownerEmail']),
        ownerPhone: _string(data['ownerPhone']),
        businessType: _string(data['businessType']),
        province: _string(data['province']),
        address: _string(data['address']),
        phone: _string(data['phone']),
        planTier: _string(data['planTier'], 'basic'),
        subscriptionStatus: _string(data['subscriptionStatus'], 'trial'),
        status: _string(data['status'], 'active'),
        createdAt: _date(data['createdAt']),
        lastActiveAt: _date(data['lastActiveAt']),
        planExpiresAt: _date(data['planExpiresAt']),
      );

  final String id;
  final String name;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String businessType;
  final String province;
  final String address;
  final String phone;
  final String planTier;
  final String subscriptionStatus;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  final DateTime? planExpiresAt;
}

class PlatformTransaction {
  const PlatformTransaction({
    required this.id,
    required this.orderCode,
    required this.tenantId,
    required this.businessName,
    required this.province,
    required this.planTier,
    required this.billingPeriod,
    required this.amount,
    required this.provider,
    required this.method,
    required this.status,
    required this.providerStatus,
    required this.reconciliationStatus,
    required this.investigationStatus,
    required this.internalNote,
    required this.checkoutUrl,
    required this.createdAt,
    required this.completedAt,
  });

  factory PlatformTransaction.fromMap(JsonMap data) => PlatformTransaction(
    id: _string(data['id']),
    orderCode: data['orderCode']?.toString() ?? '',
    tenantId: _string(data['tenantId']),
    businessName: _string(data['businessName']),
    province: _string(data['province']),
    planTier: _string(data['planTier']),
    billingPeriod: _string(data['billingPeriod']),
    amount: _int(data['amount']),
    provider: _string(data['provider']),
    method: _string(data['method']),
    status: _string(data['status'], 'pending'),
    providerStatus: _string(data['providerStatus']),
    reconciliationStatus: _string(data['reconciliationStatus'], 'unchecked'),
    investigationStatus: _string(data['investigationStatus']),
    internalNote: _string(data['internalNote']),
    checkoutUrl: _string(data['checkoutUrl']),
    createdAt: _date(data['createdAt']),
    completedAt: _date(data['completedAt']),
  );

  final String id;
  final String orderCode;
  final String tenantId;
  final String businessName;
  final String province;
  final String planTier;
  final String billingPeriod;
  final int amount;
  final String provider;
  final String method;
  final String status;
  final String providerStatus;
  final String reconciliationStatus;
  final String investigationStatus;
  final String internalNote;
  final String checkoutUrl;
  final DateTime? createdAt;
  final DateTime? completedAt;
}

class PlatformPlan {
  const PlatformPlan({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.trialDays,
    required this.description,
    required this.features,
    required this.status,
  });

  factory PlatformPlan.fromMap(JsonMap data) => PlatformPlan(
    id: _string(data['id']),
    name: _string(data['name']),
    monthlyPrice: _int(data['price']),
    annualPrice: _int(data['yearlyPrice']),
    trialDays: _int(data['trialDays']),
    description: _string(data['description']),
    features: (data['features'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
    status: _string(data['status'], 'active'),
  );

  final String id;
  final String name;
  final int monthlyPrice;
  final int annualPrice;
  final int trialDays;
  final String description;
  final List<String> features;
  final String status;
}

class PlatformAnalytics {
  const PlatformAnalytics({
    required this.revenueByDay,
    required this.revenueByPlan,
    required this.revenueByProvince,
    required this.revenueByBusinessType,
    required this.transactionStatus,
    required this.subscriptionStatus,
    required this.businessesByProvince,
  });

  factory PlatformAnalytics.fromMap(JsonMap data) => PlatformAnalytics(
    revenueByDay: _numberMap(data['revenueByDay']),
    revenueByPlan: _numberMap(data['revenueByPlan']),
    revenueByProvince: _numberMap(data['revenueByProvince']),
    revenueByBusinessType: _numberMap(data['revenueByBusinessType']),
    transactionStatus: _numberMap(data['transactionStatus']),
    subscriptionStatus: _numberMap(data['subscriptionStatus']),
    businessesByProvince: _numberMap(data['businessesByProvince']),
  );

  final Map<String, num> revenueByDay;
  final Map<String, num> revenueByPlan;
  final Map<String, num> revenueByProvince;
  final Map<String, num> revenueByBusinessType;
  final Map<String, num> transactionStatus;
  final Map<String, num> subscriptionStatus;
  final Map<String, num> businessesByProvince;
}

class PlatformEvent {
  const PlatformEvent({
    required this.id,
    required this.action,
    required this.status,
    required this.actor,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    required this.data,
  });

  factory PlatformEvent.fromMap(JsonMap data) => PlatformEvent(
    id: _string(data['id']),
    action: _string(data['action']),
    status: _string(data['status']),
    actor: _string(data['actorEmail'], _string(data['actorId'])),
    entityType: _string(data['entityType']),
    entityId: _string(data['entityId']),
    createdAt: _date(data['createdAt']),
    data: data,
  );

  final String id;
  final String action;
  final String status;
  final String actor;
  final String entityType;
  final String entityId;
  final DateTime? createdAt;
  final JsonMap data;
}

class PlatformAdminRecord {
  const PlatformAdminRecord({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.active,
  });

  factory PlatformAdminRecord.fromMap(JsonMap data) => PlatformAdminRecord(
    id: _string(data['id']),
    email: _string(data['email']),
    name: _string(data['name']),
    role: _string(data['role'], 'super_admin'),
    active: data['active'] == true,
  );

  final String id;
  final String email;
  final String name;
  final String role;
  final bool active;
}

JsonMap _map(Object? value) =>
    value is Map ? Map<Object?, Object?>.from(value) : <Object?, Object?>{};

List<T> _list<T>(Object? value, T Function(JsonMap) fromMap) =>
    (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => fromMap(Map<Object?, Object?>.from(item)))
        .toList(growable: false);

String _string(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;
int _int(Object? value) => value is num ? value.round() : 0;
double _double(Object? value) => value is num ? value.toDouble() : 0;
DateTime? _date(Object? value) =>
    value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;

Map<String, num> _numberMap(Object? value) => _map(
  value,
).map((key, number) => MapEntry(key.toString(), number is num ? number : 0));
