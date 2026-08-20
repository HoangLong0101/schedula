import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedula/core/errors/failure.dart';
import 'package:schedula/features/customer/domain/entities/customer.dart';
import 'package:schedula/features/customer/domain/repositories/customer_repository.dart';
import 'package:schedula/features/customer/domain/usecases/create_customer_usecase.dart';
import 'package:schedula/features/customer/domain/usecases/delete_customer_usecase.dart';
import 'package:schedula/features/customer/domain/usecases/update_customer_usecase.dart';
import 'package:schedula/features/customer/domain/usecases/watch_customers_usecase.dart';
import 'package:schedula/features/customer/presentation/cubit/customer_management_cubit.dart';
import 'package:schedula/features/equipment/domain/entities/equipment.dart';
import 'package:schedula/features/equipment/domain/repositories/equipment_repository.dart';
import 'package:schedula/features/equipment/domain/usecases/create_equipment_usecase.dart';
import 'package:schedula/features/equipment/domain/usecases/delete_equipment_usecase.dart';
import 'package:schedula/features/equipment/domain/usecases/update_equipment_usecase.dart';
import 'package:schedula/features/equipment/domain/usecases/watch_equipment_usecase.dart';
import 'package:schedula/features/equipment/presentation/cubit/equipment_management_cubit.dart';
import 'package:schedula/features/staff/domain/entities/staff_member.dart';
import 'package:schedula/features/staff/domain/repositories/staff_repository.dart';
import 'package:schedula/features/staff/domain/usecases/add_staff_leave_usecase.dart';
import 'package:schedula/features/staff/domain/usecases/create_staff_usecase.dart';
import 'package:schedula/features/staff/domain/usecases/delete_staff_usecase.dart';
import 'package:schedula/features/staff/domain/usecases/send_staff_password_reset_usecase.dart';
import 'package:schedula/features/staff/domain/usecases/set_staff_access_role_usecase.dart';
import 'package:schedula/features/staff/domain/usecases/update_staff_usecase.dart';
import 'package:schedula/features/staff/domain/usecases/watch_staff_usecase.dart';
import 'package:schedula/features/staff/presentation/cubit/staff_management_cubit.dart';

const _failure = ServerFailure('write failed');

class FakeCustomerRepository implements CustomerRepository {
  FakeCustomerRepository({this.fail = false});
  final bool fail;

  @override
  Stream<Either<Failure, List<Customer>>> watchCustomers(String tenantId) =>
      Stream.value(const Right([]));

  @override
  Future<Either<Failure, Customer>> createCustomer(
    String tenantId,
    Customer customer,
  ) async => fail ? const Left(_failure) : Right(customer);

  @override
  Future<Either<Failure, void>> updateCustomer(Customer customer) async =>
      fail ? const Left(_failure) : const Right(null);

  @override
  Future<Either<Failure, void>> deleteCustomer(String id) async =>
      fail ? const Left(_failure) : const Right(null);
}

class FakeEquipmentRepository implements EquipmentRepository {
  FakeEquipmentRepository({this.fail = false});
  final bool fail;

  @override
  Stream<Either<Failure, List<Equipment>>> watchEquipment(String tenantId) =>
      Stream.value(const Right([]));

  @override
  Future<Either<Failure, Equipment>> createEquipment(
    String tenantId,
    Equipment equip,
  ) async => fail ? const Left(_failure) : Right(equip);

  @override
  Future<Either<Failure, void>> updateEquipment(Equipment equip) async =>
      fail ? const Left(_failure) : const Right(null);

  @override
  Future<Either<Failure, void>> deleteEquipment(String id) async =>
      fail ? const Left(_failure) : const Right(null);
}

class FakeStaffRepository implements StaffRepository {
  FakeStaffRepository({this.fail = false});
  final bool fail;

  @override
  Stream<Either<Failure, List<StaffMember>>> watchStaff(String tenantId) =>
      Stream.value(const Right([]));

  @override
  Future<Either<Failure, CreatedStaff>> createStaff(
    String tenantId,
    StaffMember staff,
  ) async => fail
      ? const Left(_failure)
      : Right((staff: staff, temporaryPassword: 'Temp123!'));

  @override
  Future<Either<Failure, void>> updateStaff(StaffMember staff) async =>
      fail ? const Left(_failure) : const Right(null);

  @override
  Future<Either<Failure, void>> deleteStaff(
    String id, {
    required bool cancelFuture,
    String? reassignTo,
  }) async => fail ? const Left(_failure) : const Right(null);

  @override
  Future<Either<Failure, String>> resetPassword(String id) async =>
      fail ? const Left(_failure) : const Right('Temp456!');

  @override
  Future<Either<Failure, void>> setAccessRole(String id, String role) async =>
      fail ? const Left(_failure) : const Right(null);

  @override
  Future<Either<Failure, void>> addLeave({
    required String tenantId,
    required String staffId,
    required DateTime start,
    required DateTime end,
  }) async => fail ? const Left(_failure) : const Right(null);
}

const customer = Customer(
  id: 'customer-1',
  name: 'Customer',
  phone: '0900000000',
  email: '',
  lastVisit: '2026-08-12',
  avatar: 'C',
  color: '#22AFC2',
);

const equipment = Equipment(
  id: 'equipment-1',
  name: 'Laser',
  status: EquipmentStatus.available,
  location: 'Room 1',
  lastMaintenance: '2026-08-12',
);

const staff = StaffMember(
  id: 'staff-1',
  name: 'Staff',
  role: 'Therapist',
  status: StaffStatus.available,
  color: '#148A9C',
  email: 'staff@example.com',
);

void main() {
  test('customer mutations return repository failures to the UI', () async {
    final repository = FakeCustomerRepository(fail: true);
    final cubit = CustomerManagementCubit(
      WatchCustomersUseCase(repository),
      CreateCustomerUseCase(repository),
      UpdateCustomerUseCase(repository),
      DeleteCustomerUseCase(repository),
    )..init('tenant-1');

    expect(await cubit.addCustomer(customer), 'write failed');
    expect(await cubit.updateCustomer(customer), 'write failed');
    expect(await cubit.deleteCustomer(customer.id), 'write failed');
    await cubit.close();
  });

  test('equipment mutations return repository failures to the UI', () async {
    final repository = FakeEquipmentRepository(fail: true);
    final cubit = EquipmentManagementCubit(
      WatchEquipmentUseCase(repository),
      CreateEquipmentUseCase(repository),
      UpdateEquipmentUseCase(repository),
      DeleteEquipmentUseCase(repository),
    )..init('tenant-1');

    expect(await cubit.addEquipment(equipment), 'write failed');
    expect(await cubit.updateEquipment(equipment), 'write failed');
    expect(await cubit.deleteEquipment(equipment.id), 'write failed');
    await cubit.close();
  });

  test(
    'staff creation and password rotation return temporary passwords',
    () async {
      final repository = FakeStaffRepository();
      final cubit = StaffManagementCubit(
        WatchStaffUseCase(repository),
        CreateStaffUseCase(repository),
        UpdateStaffUseCase(repository),
        DeleteStaffUseCase(repository),
        AddStaffLeaveUseCase(repository),
        ResetStaffPasswordUseCase(repository),
        SetStaffAccessRoleUseCase(repository),
      )..init('tenant-1');

      expect((await cubit.addStaff(staff)).password, 'Temp123!');
      expect((await cubit.resetPassword(staff.id)).password, 'Temp456!');
      await cubit.close();
    },
  );

  test('staff mutation failures stay visible to the UI', () async {
    final repository = FakeStaffRepository(fail: true);
    final cubit = StaffManagementCubit(
      WatchStaffUseCase(repository),
      CreateStaffUseCase(repository),
      UpdateStaffUseCase(repository),
      DeleteStaffUseCase(repository),
      AddStaffLeaveUseCase(repository),
      ResetStaffPasswordUseCase(repository),
      SetStaffAccessRoleUseCase(repository),
    )..init('tenant-1');

    expect(await cubit.updateStaff(staff), 'write failed');
    expect(
      await cubit.deleteStaff(staff.id, cancelFuture: false),
      'write failed',
    );
    expect((await cubit.resetPassword(staff.id)).error, 'write failed');
    await cubit.close();
  });
}
