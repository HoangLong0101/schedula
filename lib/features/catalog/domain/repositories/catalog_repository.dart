import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/service_item.dart';
import '../entities/product_item.dart';

abstract class CatalogRepository {
  Stream<Either<Failure, List<ServiceItem>>> watchServices(String tenantId);
  Stream<Either<Failure, List<ProductItem>>> watchProducts(String tenantId);

  Future<Either<Failure, void>> createService(ServiceItem service);
  Future<Either<Failure, void>> updateService(ServiceItem service);
  Future<Either<Failure, void>> deleteService(String id);

  Future<Either<Failure, void>> createProduct(ProductItem product);
  Future<Either<Failure, void>> updateProduct(ProductItem product);
  Future<Either<Failure, void>> deleteProduct(String id);
}