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
import 'package:schedula/features/customer/data/datasources/customer_datasource.dart'
    as _i478;
import 'package:schedula/features/customer/data/repositories/customer_repository_impl.dart'
    as _i847;
import 'package:schedula/features/customer/domain/repositories/customer_repository.dart'
    as _i489;
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
import 'package:schedula/features/staff/data/datasources/staff_datasource.dart'
    as _i821;
import 'package:schedula/features/staff/data/repositories/staff_repository_impl.dart'
    as _i1062;
import 'package:schedula/features/staff/domain/repositories/staff_repository.dart'
    as _i332;

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
    );
    gh.lazySingleton<_i24.BookingRealtimeDataSource>(
      () => _i24.BookingRealtimeDataSource(gh<_i345.FirebaseDatabase>()),
    );
    gh.lazySingleton<_i489.CustomerRepository>(
      () => _i847.CustomerRepositoryImpl(gh<_i478.CustomerDataSource>()),
    );
    gh.lazySingleton<_i677.FirebaseAuthDataSource>(
      () => _i677.FirebaseAuthDataSource(
        gh<_i59.FirebaseAuth>(),
        gh<_i116.GoogleSignIn>(),
      ),
    );
    gh.lazySingleton<_i1019.BookingDataSource>(
      () => _i1019.BookingDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i390.DashboardDataSource>(
      () => _i390.DashboardDataSource(gh<_i974.FirebaseFirestore>()),
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
    gh.lazySingleton<_i797.AuthRepository>(
      () => _i472.AuthRepositoryImpl(gh<_i677.FirebaseAuthDataSource>()),
    );
    gh.factory<_i184.GetDashboardStatsUseCase>(
      () => _i184.GetDashboardStatsUseCase(gh<_i220.DashboardRepository>()),
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
    );
    return this;
  }
}

class _$AppModule extends _i20.AppModule {}
