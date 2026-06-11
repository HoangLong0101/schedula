// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:firebase_database/firebase_database.dart' as _i345;
import 'package:get_it/get_it.dart' as _i174;
import 'package:go_router/go_router.dart' as _i583;
import 'package:google_sign_in/google_sign_in.dart' as _i116;
import 'package:injectable/injectable.dart' as _i526;
import 'package:schedula/core/di/app_module.dart' as _i20;
import 'package:schedula/features/account/data/datasources/account_datasource.dart'
    as _i707;
import 'package:schedula/features/account/data/repositories/account_repository_impl.dart'
    as _i411;
import 'package:schedula/features/account/domain/repositories/account_repository.dart'
    as _i244;
import 'package:schedula/features/account/domain/usecases/update_business_info_usecase.dart'
    as _i648;
import 'package:schedula/features/account/domain/usecases/watch_business_info_usecase.dart'
    as _i901;
import 'package:schedula/features/account/presentation/cubit/account_cubit.dart'
    as _i702;
import 'package:schedula/features/auth/data/datasources/firebase_auth_data_source.dart'
    as _i677;
import 'package:schedula/features/auth/data/repositories/auth_repository_impl.dart'
    as _i472;
import 'package:schedula/features/auth/domain/repositories/auth_repository.dart'
    as _i797;
import 'package:schedula/features/auth/domain/usecases/sign_in_usecase.dart'
    as _i373;
import 'package:schedula/features/auth/domain/usecases/sign_in_with_google_usecase.dart'
    as _i1041;
import 'package:schedula/features/auth/domain/usecases/sign_out_usecase.dart'
    as _i652;
import 'package:schedula/features/auth/presentation/bloc/auth_bloc.dart'
    as _i561;
import 'package:schedula/features/booking/data/datasources/booking_datasource.dart'
    as _i1019;
import 'package:schedula/features/booking/data/datasources/booking_realtime_data_source.dart'
    as _i24;
import 'package:schedula/features/booking/data/repositories/booking_repository_impl.dart'
    as _i97;
import 'package:schedula/features/booking/domain/repositories/booking_repository.dart'
    as _i262;
import 'package:schedula/features/booking/domain/usecases/cancel_booking_usecase.dart'
    as _i1018;
import 'package:schedula/features/booking/domain/usecases/create_booking_usecase.dart'
    as _i480;
import 'package:schedula/features/booking/domain/usecases/update_booking_status_usecase.dart'
    as _i271;
import 'package:schedula/features/booking/domain/usecases/watch_bookings_usecase.dart'
    as _i59;
import 'package:schedula/features/booking/domain/usecases/watch_slots_usecase.dart'
    as _i436;
import 'package:schedula/features/booking/presentation/bloc/booking_bloc.dart'
    as _i455;
import 'package:schedula/features/booking/presentation/cubit/booking_filters_cubit.dart'
    as _i6;
import 'package:schedula/features/catalog/data/datasources/catalog_datasource.dart'
    as _i955;
import 'package:schedula/features/catalog/data/repositories/catalog_repository_impl.dart'
    as _i80;
import 'package:schedula/features/catalog/domain/repositories/catalog_repository.dart'
    as _i625;
import 'package:schedula/features/catalog/presentaion/cubit/catalog_cubit.dart'
    as _i967;
import 'package:schedula/features/customer/data/datasources/customer_datasource.dart'
    as _i478;
import 'package:schedula/features/customer/data/repositories/customer_repository_impl.dart'
    as _i847;
import 'package:schedula/features/customer/domain/repositories/customer_repository.dart'
    as _i489;
import 'package:schedula/features/customer/domain/usecases/create_customer_usecase.dart'
    as _i178;
import 'package:schedula/features/customer/domain/usecases/delete_customer_usecase.dart'
    as _i59;
import 'package:schedula/features/customer/domain/usecases/update_customer_usecase.dart'
    as _i121;
import 'package:schedula/features/customer/domain/usecases/watch_customers_usecase.dart'
    as _i1031;
import 'package:schedula/features/customer/presentation/cubit/customer_management_cubit.dart'
    as _i156;
import 'package:schedula/features/dashboard/data/datasources/dashboard_datasource.dart'
    as _i390;
import 'package:schedula/features/dashboard/data/repositories/dashboard_repository_impl.dart'
    as _i393;
import 'package:schedula/features/dashboard/domain/repositories/dashboard_repository.dart'
    as _i220;
import 'package:schedula/features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart'
    as _i184;
import 'package:schedula/features/dashboard/presentation/cubit/dashboard_cubit.dart'
    as _i658;
import 'package:schedula/features/equipment/data/datasources/equipment_datasource.dart'
    as _i514;
import 'package:schedula/features/equipment/data/repositories/equipment_repository_impl.dart'
    as _i378;
import 'package:schedula/features/equipment/domain/repositories/equipment_repository.dart'
    as _i71;
import 'package:schedula/features/equipment/domain/usecases/create_equipment_usecase.dart'
    as _i918;
import 'package:schedula/features/equipment/domain/usecases/delete_equipment_usecase.dart'
    as _i459;
import 'package:schedula/features/equipment/domain/usecases/update_equipment_usecase.dart'
    as _i476;
import 'package:schedula/features/equipment/domain/usecases/watch_equipment_usecase.dart'
    as _i13;
import 'package:schedula/features/equipment/presentation/cubit/equipment_management_cubit.dart'
    as _i324;
import 'package:schedula/features/staff/data/datasources/staff_datasource.dart'
    as _i821;
import 'package:schedula/features/staff/data/repositories/staff_repository_impl.dart'
    as _i1062;
import 'package:schedula/features/staff/domain/repositories/staff_repository.dart'
    as _i332;
import 'package:schedula/features/staff/domain/usecases/create_staff_usecase.dart'
    as _i1050;
import 'package:schedula/features/staff/domain/usecases/delete_staff_usecase.dart'
    as _i599;
import 'package:schedula/features/staff/domain/usecases/update_staff_usecase.dart'
    as _i122;
import 'package:schedula/features/staff/domain/usecases/watch_staff_usecase.dart'
    as _i4;
import 'package:schedula/features/staff/presentation/cubit/staff_management_cubit.dart'
    as _i23;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final appModule = _$AppModule();
    gh.factory<_i6.BookingFiltersCubit>(() => _i6.BookingFiltersCubit());
    gh.lazySingleton<_i59.FirebaseAuth>(() => appModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(() => appModule.firestore);
    gh.lazySingleton<_i345.FirebaseDatabase>(() => appModule.realtimeDatabase);
    gh.lazySingleton<_i116.GoogleSignIn>(() => appModule.googleSignIn);
    gh.lazySingleton<_i583.GoRouter>(() => appModule.router);
    gh.lazySingleton<_i478.CustomerDataSource>(
      () => const _i478.CustomerDataSource(),
    );
    gh.lazySingleton<_i821.StaffDataSource>(
      () => const _i821.StaffDataSource(),
    gh.lazySingleton<_i390.DashboardDataSource>(
      () => const _i390.DashboardDataSource(),
    );
    gh.lazySingleton<_i24.BookingRealtimeDataSource>(
      () => _i24.BookingRealtimeDataSource(gh<_i345.FirebaseDatabase>()),
    );
    gh.lazySingleton<_i677.FirebaseAuthDataSource>(
      () => _i677.FirebaseAuthDataSource(
        gh<_i59.FirebaseAuth>(),
        gh<_i116.GoogleSignIn>(),
      ),
    );
    gh.lazySingleton<_i707.AccountDataSource>(
      () => _i707.AccountDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i1019.BookingDataSource>(
      () => _i1019.BookingDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i390.DashboardDataSource>(
      () => _i390.DashboardDataSource(gh<_i974.FirebaseFirestore>()),
    gh.lazySingleton<_i955.CatalogDataSource>(
      () => _i955.CatalogDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i478.CustomerDataSource>(
      () => _i478.CustomerDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i514.EquipmentDataSource>(
      () => _i514.EquipmentDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i821.StaffDataSource>(
      () => _i821.StaffDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i332.StaffRepository>(
      () => _i1062.StaffRepositoryImpl(gh<_i821.StaffDataSource>()),
    );
    gh.lazySingleton<_i262.BookingRepository>(
      () => _i97.BookingRepositoryImpl(gh<_i1019.BookingDataSource>()),
    );
    gh.lazySingleton<_i220.DashboardRepository>(
      () => _i393.DashboardRepositoryImpl(gh<_i390.DashboardDataSource>()),
    );
    gh.lazySingleton<_i625.CatalogRepository>(
      () => _i80.CatalogRepositoryImpl(gh<_i955.CatalogDataSource>()),
    );
    gh.lazySingleton<_i797.AuthRepository>(
      () => _i472.AuthRepositoryImpl(gh<_i677.FirebaseAuthDataSource>()),
    );
    gh.factory<_i184.GetDashboardStatsUseCase>(
      () => _i184.GetDashboardStatsUseCase(gh<_i220.DashboardRepository>()),
    gh.factory<_i1050.CreateStaffUseCase>(
      () => _i1050.CreateStaffUseCase(gh<_i332.StaffRepository>()),
    );
    gh.factory<_i599.DeleteStaffUseCase>(
      () => _i599.DeleteStaffUseCase(gh<_i332.StaffRepository>()),
    );
    gh.factory<_i122.UpdateStaffUseCase>(
      () => _i122.UpdateStaffUseCase(gh<_i332.StaffRepository>()),
    );
    gh.factory<_i4.WatchStaffUseCase>(
      () => _i4.WatchStaffUseCase(gh<_i332.StaffRepository>()),
    );
    gh.factory<_i967.CatalogCubit>(
      () => _i967.CatalogCubit(gh<_i625.CatalogRepository>()),
    );
    gh.factory<_i373.SignInUseCase>(
      () => _i373.SignInUseCase(gh<_i797.AuthRepository>()),
    );
    gh.factory<_i1041.SignInWithGoogleUseCase>(
      () => _i1041.SignInWithGoogleUseCase(gh<_i797.AuthRepository>()),
    );
    gh.factory<_i652.SignOutUseCase>(
      () => _i652.SignOutUseCase(gh<_i797.AuthRepository>()),
    );
    gh.factory<_i1018.CancelBookingUseCase>(
      () => _i1018.CancelBookingUseCase(gh<_i262.BookingRepository>()),
    );
    gh.factory<_i480.CreateBookingUseCase>(
      () => _i480.CreateBookingUseCase(gh<_i262.BookingRepository>()),
    );
    gh.factory<_i271.UpdateBookingStatusUseCase>(
      () => _i271.UpdateBookingStatusUseCase(gh<_i262.BookingRepository>()),
    );
    gh.factory<_i59.WatchBookingsUseCase>(
      () => _i59.WatchBookingsUseCase(gh<_i262.BookingRepository>()),
    );
    gh.factory<_i436.WatchSlotsUseCase>(
      () => _i436.WatchSlotsUseCase(gh<_i262.BookingRepository>()),
    );
    gh.lazySingleton<_i244.AccountRepository>(
      () => _i411.AccountRepositoryImpl(gh<_i707.AccountDataSource>()),
    );
    gh.factory<_i648.UpdateBusinessInfoUseCase>(
      () => _i648.UpdateBusinessInfoUseCase(gh<_i244.AccountRepository>()),
    );
    gh.factory<_i901.WatchBusinessInfoUseCase>(
      () => _i901.WatchBusinessInfoUseCase(gh<_i244.AccountRepository>()),
    );
    gh.lazySingleton<_i71.EquipmentRepository>(
      () => _i378.EquipmentRepositoryImpl(gh<_i514.EquipmentDataSource>()),
    );
    gh.lazySingleton<_i489.CustomerRepository>(
      () => _i847.CustomerRepositoryImpl(gh<_i478.CustomerDataSource>()),
    );
    gh.factory<_i918.CreateEquipmentUseCase>(
      () => _i918.CreateEquipmentUseCase(gh<_i71.EquipmentRepository>()),
    );
    gh.factory<_i459.DeleteEquipmentUseCase>(
      () => _i459.DeleteEquipmentUseCase(gh<_i71.EquipmentRepository>()),
    );
    gh.factory<_i476.UpdateEquipmentUseCase>(
      () => _i476.UpdateEquipmentUseCase(gh<_i71.EquipmentRepository>()),
    );
    gh.factory<_i13.WatchEquipmentUseCase>(
      () => _i13.WatchEquipmentUseCase(gh<_i71.EquipmentRepository>()),
    );
    gh.lazySingleton<_i561.AuthBloc>(
      () => _i561.AuthBloc(
        gh<_i373.SignInUseCase>(),
        gh<_i1041.SignInWithGoogleUseCase>(),
        gh<_i652.SignOutUseCase>(),
      ),
    );
    gh.lazySingleton<_i455.BookingBloc>(
      () => _i455.BookingBloc(
        gh<_i59.WatchBookingsUseCase>(),
        gh<_i480.CreateBookingUseCase>(),
        gh<_i271.UpdateBookingStatusUseCase>(),
        gh<_i1018.CancelBookingUseCase>(),
      ),
    );
    gh.factory<_i658.DashboardCubit>(
      () => _i658.DashboardCubit(gh<_i184.GetDashboardStatsUseCase>()),
    gh.factory<_i324.EquipmentManagementCubit>(
      () => _i324.EquipmentManagementCubit(
        gh<_i13.WatchEquipmentUseCase>(),
        gh<_i918.CreateEquipmentUseCase>(),
        gh<_i476.UpdateEquipmentUseCase>(),
        gh<_i459.DeleteEquipmentUseCase>(),
      ),
    );
    gh.factory<_i23.StaffManagementCubit>(
      () => _i23.StaffManagementCubit(
        gh<_i4.WatchStaffUseCase>(),
        gh<_i1050.CreateStaffUseCase>(),
        gh<_i122.UpdateStaffUseCase>(),
        gh<_i599.DeleteStaffUseCase>(),
      ),
    );
    gh.factory<_i702.AccountCubit>(
      () => _i702.AccountCubit(
        gh<_i901.WatchBusinessInfoUseCase>(),
        gh<_i648.UpdateBusinessInfoUseCase>(),
      ),
    );
    gh.factory<_i178.CreateCustomerUseCase>(
      () => _i178.CreateCustomerUseCase(gh<_i489.CustomerRepository>()),
    );
    gh.factory<_i59.DeleteCustomerUseCase>(
      () => _i59.DeleteCustomerUseCase(gh<_i489.CustomerRepository>()),
    );
    gh.factory<_i121.UpdateCustomerUseCase>(
      () => _i121.UpdateCustomerUseCase(gh<_i489.CustomerRepository>()),
    );
    gh.factory<_i1031.WatchCustomersUseCase>(
      () => _i1031.WatchCustomersUseCase(gh<_i489.CustomerRepository>()),
    );
    gh.factory<_i156.CustomerManagementCubit>(
      () => _i156.CustomerManagementCubit(
        gh<_i1031.WatchCustomersUseCase>(),
        gh<_i178.CreateCustomerUseCase>(),
        gh<_i121.UpdateCustomerUseCase>(),
        gh<_i59.DeleteCustomerUseCase>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i20.AppModule {}
