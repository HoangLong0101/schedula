import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_in_with_google_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._signInUseCase,
    this._signInWithGoogleUseCase,
    this._signOutUseCase,
  ) : super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final SignInUseCase _signInUseCase;
  final SignInWithGoogleUseCase _signInWithGoogleUseCase;
  final SignOutUseCase _signOutUseCase;

  Future<void> _onStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const Unauthenticated());
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final user = await _signInUseCase(
      email: event.email,
      password: event.password,
    );

    if (user == null) {
      emit(const AuthFailure('Unable to sign in'));
      return;
    }

    emit(Authenticated(user));
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final user = await _signInWithGoogleUseCase();

    if (user == null) {
      emit(const AuthFailure('Google sign-in was cancelled or failed'));
      return;
    }

    emit(Authenticated(user));
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await _signOutUseCase();
    emit(const Unauthenticated());
  }
}