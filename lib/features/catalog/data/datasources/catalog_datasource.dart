import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import '../models/product_model.dart';
import '../models/service_model.dart';

@lazySingleton
class CatalogDataSource {
  final FirebaseFirestore _firestore;
  CatalogDataSource(this._firestore);

  CollectionReference<Map<String, dynamic>> get _services => _firestore.collection('services');
  CollectionReference<Map<String, dynamic>> get _products => _firestore.collection('products');

  Stream<List<ServiceModel>> watchServices(String tenantId) {
    return _services.where('tenantId', isEqualTo: tenantId).snapshots().map(
            (snap) => snap.docs.map(ServiceModel.fromFirestore).toList());
  }

  Stream<List<ProductModel>> watchProducts(String tenantId) {
    return _products.where('tenantId', isEqualTo: tenantId).snapshots().map(
            (snap) => snap.docs.map(ProductModel.fromFirestore).toList());
  }

  Future<void> createService(ServiceModel s) async => await _services.doc().set(s.toFirestore());
  Future<void> updateService(ServiceModel s) async => await _services.doc(s.id).update(s.toFirestore());
  Future<void> deleteService(String id) async => await _services.doc(id).delete();

  Future<void> createProduct(ProductModel p) async => await _products.doc().set(p.toFirestore());
  Future<void> updateProduct(ProductModel p) async => await _products.doc(p.id).update(p.toFirestore());
  Future<void> deleteProduct(String id) async => await _products.doc(id).delete();
}