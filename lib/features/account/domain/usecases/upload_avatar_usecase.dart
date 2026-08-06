import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/account_repository.dart';

@injectable
class UploadAvatarUseCase {
  const UploadAvatarUseCase(this._repository);

  final AccountRepository _repository;

  Future<Either<Failure, String>> call(
    String userId,
    Uint8List bytes,
    String contentType,
  ) {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      return Future.value(
        const Left(ValidationFailure('Ảnh phải nhỏ hơn 5 MB.')),
      );
    }
    if (!contentType.startsWith('image/')) {
      return Future.value(
        const Left(ValidationFailure('Tệp đã chọn không phải hình ảnh.')),
      );
    }
    return _repository.uploadAvatar(userId, bytes, contentType);
  }
}
