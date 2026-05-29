import 'package:firebase_database/firebase_database.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class BookingRealtimeDataSource {
  BookingRealtimeDataSource(this._database);

  final FirebaseDatabase _database;

  DatabaseReference get _root => _database.ref('booking_live');

  Stream<bool> watchTenantLive(String tenantId) {
    return _root.child('tenants/$tenantId/live').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  Future<void> setTenantLive({
    required String tenantId,
    required bool live,
  }) {
    return _root.child('tenants/$tenantId/live').set(live);
  }
}