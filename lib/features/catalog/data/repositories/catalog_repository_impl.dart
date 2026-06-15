import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/product_item.dart';
import '../../domain/entities/service_item.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_datasource.dart';
import '../models/product_model.dart';
import '../models/service_model.dart';

@LazySingleton(as: CatalogRepository)
class CatalogRepositoryImpl implements CatalogRepository {
  final CatalogDataSource _dataSource;
  CatalogRepositoryImpl(this._dataSource);

  @override
  Stream<Either<Failure, List<ServiceItem>>> watchServices(String tenantId) {
    return _dataSource.watchServices(tenantId).transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(Right(data)),
        handleError: (_, _, sink) =>
            sink.add(const Left(ServerFailure('Không thể tải dịch vụ.'))),
      ),
    );
  }

  @override
  Stream<Either<Failure, List<ProductItem>>> watchProducts(String tenantId) {
    return _dataSource.watchProducts(tenantId).transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(Right(data)),
        handleError: (_, _, sink) =>
            sink.add(const Left(ServerFailure('Không thể tải sản phẩm.'))),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> createService(ServiceItem s) async {
    try {
      await _dataSource.createService(ServiceModel(id: '', tenantId: s.tenantId, name: s.name, price: s.price, duration: s.duration, category: s.category, resources: s.resources));
      return const Right(null);
    } catch (_) { return const Left(ServerFailure('Không thể tạo dịch vụ.')); }
  }

  @override
  Future<Either<Failure, void>> updateService(ServiceItem s) async {
    try {
      await _dataSource.updateService(ServiceModel(id: s.id, tenantId: s.tenantId, name: s.name, price: s.price, duration: s.duration, category: s.category, resources: s.resources));
      return const Right(null);
    } catch (_) { return const Left(ServerFailure('Không thể cập nhật dịch vụ.')); }
  }

  @override
  Future<Either<Failure, void>> deleteService(String id) async {
    try { await _dataSource.deleteService(id); return const Right(null); } catch (_) { return const Left(ServerFailure('Không thể xóa dịch vụ.')); }
  }

  @override
  Future<Either<Failure, void>> createProduct(ProductItem p) async {
    try {
      await _dataSource.createProduct(ProductModel(id: '', tenantId: p.tenantId, name: p.name, price: p.price, unit: p.unit, category: p.category));
      return const Right(null);
    } catch (_) { return const Left(ServerFailure('Không thể tạo sản phẩm.')); }
  }

  @override
  Future<Either<Failure, void>> updateProduct(ProductItem p) async {
    try {
      await _dataSource.updateProduct(ProductModel(id: p.id, tenantId: p.tenantId, name: p.name, price: p.price, unit: p.unit, category: p.category));
      return const Right(null);
    } catch (_) { return const Left(ServerFailure('Không thể cập nhật sản phẩm.')); }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try { await _dataSource.deleteProduct(id); return const Right(null); } catch (_) { return const Left(ServerFailure('Không thể xóa sản phẩm.')); }
  }
}
