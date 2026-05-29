# CLAUDE.md — Schedula Agent Control File

> Read this file in full before every task. These rules are non-negotiable.
> When in doubt: ask before generating. A wrong architecture decision costs
> more to fix than a clarifying question costs to ask.

---

## 1. Project Identity

| Field | Value |
|-------|-------|
| App name | Schedula |
| Platform | Flutter (iOS + Android) |
| Language | Dart 3.4+ |
| Flutter version | 3.44.0 stable (FVM-pinned) |
| Backend | Firebase — Firestore · Auth · FCM · Cloud Functions |
| Architecture | Clean Architecture — 3 layers per feature |
| State management | flutter_bloc (BLoC + Cubit) |
| DI | GetIt + injectable (annotation-driven) |
| Navigation | go_router |
| Environments | dev · staging · prod (separate Firebase projects) |
| IDE | VS Code |

---

## 2. Architecture Rules — STRICT

### Layer boundaries (never cross these)

```
presentation  →  domain  →  data
     ↑                         ↑
  (BLoC/UI)             (Firestore/APIs)
```

- **Presentation layer** (`presentation/`): Widgets, Pages, BLoC, Cubit only.
  - ✅ May import: `flutter_bloc`, `go_router`, domain entities, use cases via DI
  - ❌ Never import: `cloud_firestore`, `firebase_auth`, repository impls, models
- **Domain layer** (`domain/`): Pure Dart. Zero Flutter or Firebase imports.
  - ✅ May import: `dartz`, `equatable`, other domain entities/repos
  - ❌ Never import: anything from `data/`, Flutter SDK, Firebase SDK
- **Data layer** (`data/`): Firestore, models, repository implementations.
  - ✅ May import: Firebase SDK, domain repository interfaces, `injectable`
  - ❌ Never import: presentation widgets, BLoC classes

### Use case pattern — always `Either<Failure, T>`

```dart
// domain/usecases/create_booking_usecase.dart
@injectable
class CreateBookingUseCase {
  final BookingRepository _repo;
  CreateBookingUseCase(this._repo);

  Future<Either<Failure, Booking>> call(CreateBookingParams params) =>
      _repo.createBooking(params);
}
```

- All use cases return `Either<Failure, T>` from `dartz`
- BLoC maps `Left` → error state, `Right` → success state
- Never throw exceptions from use cases — wrap in `Left(Failure(...))`

### Repository pattern

```dart
// domain/repositories/booking_repository.dart  ← abstract
abstract class BookingRepository {
  Future<Either<Failure, Booking>> createBooking(CreateBookingParams p);
  Stream<Either<Failure, List<Booking>>> watchBookings(String tenantId);
}

// data/repositories/booking_repository_impl.dart  ← concrete
@LazySingleton(as: BookingRepository)
class BookingRepositoryImpl implements BookingRepository { ... }
```

- Always define the abstract interface in `domain/`
- Always bind the concrete impl with `@LazySingleton(as: Interface)`
- After adding any `@injectable` annotation: run `make gen`

### BLoC pattern

```dart
// Events are sealed classes
sealed class BookingEvent extends Equatable {}
final class BookingCreateRequested extends BookingEvent {
  final CreateBookingParams params;
  const BookingCreateRequested(this.params);
  @override List<Object> get props => [params];
}

// States are sealed classes
sealed class BookingState extends Equatable {}
final class BookingInitial  extends BookingState { ... }
final class BookingLoading  extends BookingState { ... }
final class BookingSuccess  extends BookingState { final Booking booking; ... }
final class BookingFailure  extends BookingState { final String message; ... }
```

- Use `sealed class` for events and states (Dart 3.0+)
- Every field in events/states must be included in `props`
- Use `Cubit` only for simple toggle/counter state (e.g. DashboardCubit)
- Use `BLoC` for anything with multiple event types

---

## 3. Firestore Rules — Always Enforce

Every Firestore document written from client code **must** include `tenantId`.
Security rules reject any document missing this field on create.

```dart
// CORRECT
await _db.collection('bookings').add({
  'tenantId': tenantId,  // ← always first
  'staffId': staffId,
  // ...
});

// WRONG — will be rejected by Security Rules
await _db.collection('bookings').add({
  'staffId': staffId,    // ← missing tenantId → permission-denied
});
```

**Required fields per collection:**

| Collection | Required on create |
|------------|--------------------|
| `bookings` | `tenantId`, `staffId`, `customerId`, `serviceId`, `startTime`, `endTime`, `status` |
| `customers` | `tenantId`, `name`, `phone` |
| `users` | `tenantId`, `role`, `email` |
| `services` | `tenantId`, `name`, `durationMin`, `price` |
| `slots` | `tenantId`, `staffId`, `date` |

**Booking conflict prevention — always use Firestore transactions:**

```dart
// CORRECT — atomic conflict check
await _db.runTransaction((tx) async {
  final existing = await tx.get(slotRef);
  if (existing.data()?['booked'] == true) {
    throw Exception('Slot already taken');
  }
  tx.update(slotRef, {'booked': true});
  tx.set(bookingRef, bookingData);
});

// WRONG — race condition possible
final snap = await slotRef.get();
if (snap.data()?['booked'] == false) {
  await bookingRef.set(bookingData); // another client could write between these two lines
}
```

---

## 4. Naming Conventions

| Artifact | Convention | Example |
|----------|-----------|---------|
| Files | `snake_case.dart` | `booking_repository_impl.dart` |
| Classes | `PascalCase` | `BookingRepositoryImpl` |
| BLoC events | `PascalCase + verb + past/requested` | `BookingCreateRequested`, `BookingCancelRequested` |
| BLoC states | `PascalCase + noun + adjective` | `BookingLoading`, `BookingSuccess`, `BookingFailure` |
| Use cases | `PascalCase + UseCase` | `CreateBookingUseCase` |
| Repositories | `PascalCase + Repository` | `BookingRepository` (abstract), `BookingRepositoryImpl` (concrete) |
| Entities | `PascalCase` (no suffix) | `Booking`, `Customer`, `Staff` |
| Models (DTOs) | `PascalCase + Model` | `BookingModel`, `CustomerModel` |
| Firestore collections | `camelCase plural` | `bookings`, `customers`, `users` |
| Firestore fields | `camelCase` | `tenantId`, `startTime`, `fcmToken` |
| DI module methods | `get` + interface name | `getBookingRepository()` |

---

## 5. Feature Folder Structure

When creating a new feature, always create all three layers:

```
lib/features/{feature_name}/
├── data/
│   ├── datasources/        # {Feature}RemoteDataSource
│   ├── models/             # {Feature}Model  (fromFirestore / toMap)
│   └── repositories/       # {Feature}RepositoryImpl
├── domain/
│   ├── entities/           # {Feature}  (pure Dart)
│   ├── repositories/       # {Feature}Repository  (abstract)
│   └── usecases/           # One file per use case
└── presentation/
    ├── bloc/               # {Feature}Bloc, {Feature}Event, {Feature}State
    ├── pages/              # {Feature}Page
    └── widgets/            # Reusable widgets scoped to this feature
```

---

## 6. Dependency Injection Rules

- **Always** annotate with `@injectable`, `@lazySingleton`, or `@singleton`
- **Always** bind concrete to abstract: `@LazySingleton(as: AbstractClass)`
- **Never** call `GetIt.instance.get<X>()` inside widgets — inject via BLoC constructor
- **Never** manually write `injection.config.dart` — it is always generated
- After any annotation change: run `make gen` immediately

```dart
// Correct DI usage in BLoC
@injectable
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final CreateBookingUseCase _createBooking;
  final WatchBookingsUseCase _watchBookings;

  BookingBloc(this._createBooking, this._watchBookings) : super(BookingInitial());
}
```

---

## 7. Forbidden Patterns

These will be flagged in code review and must never be generated:

```dart
// ❌ setState in any file that has a BLoC
setState(() { ... });

// ❌ Direct Firestore call from a presentation widget or page
FirebaseFirestore.instance.collection('bookings').get();

// ❌ Direct Firebase Auth call from presentation layer
FirebaseAuth.instance.signInWithEmailAndPassword(...);

// ❌ Hardcoded colors — always use AppTheme
color: Color(0xFF1A7F7A)  // use AppTheme.primary

// ❌ SharedPreferences for tokens
SharedPreferences.setString('token', token)  // use flutter_secure_storage

// ❌ BuildContext across async gaps without mounted check
await someAsyncCall();
Navigator.of(context).push(...);  // add if (!mounted) return; before this

// ❌ Returning null from a use case instead of Either
Future<Booking?> createBooking(...)  // use Future<Either<Failure, Booking>>

// ❌ Writing to Firestore without tenantId
_db.collection('bookings').add({'staffId': id})  // always include tenantId

// ❌ Catching Exception without mapping to Failure
} catch (e) {
  return null;  // return Left(ServerFailure(e.toString())) instead
}
```

---

## 8. Commands Reference

```bash
# Run app (always include flavor + dart-define)
flutter run --flavor dev --dart-define=FLAVOR=dev         # dev
flutter run --flavor staging --dart-define=FLAVOR=staging # staging

# Or from VS Code: F5 with correct flavor selected in Run & Debug

# Code generation (run after any @injectable annotation change)
make gen
# expands to: dart run build_runner build --delete-conflicting-outputs

# Watch mode during active development (run in dedicated terminal)
dart run build_runner watch --delete-conflicting-outputs

# Tests
make test
# expands to: flutter test --coverage

# Static analysis (must return 0 issues before any commit)
flutter analyze

# Format (auto on save via settings.json, or manual)
dart format lib/

# Deploy Firestore rules (dev only during development)
firebase use schedula-dev && firebase deploy --only firestore:rules

# Makefile shortcuts
make gen          # build_runner
make clean        # flutter clean + pub get + gen
make test         # flutter test --coverage
make run-dev      # flutter run dev flavor
make run-staging  # flutter run staging flavor
make analyze      # flutter analyze + dart format check
make rules        # deploy firestore rules to dev
```

---

## 9. MVP Feature Scope

These are the **only** features in scope for MVP. Do not generate code for anything else.

| Module | Status | Key constraint |
|--------|--------|----------------|
| Auth (sign-in, role guard, route protection) | Sprint 1 | Roles via Firebase custom claims only |
| Booking (create, view grid, cancel, status update) | Sprint 2 | Conflict prevention via Firestore transaction |
| Staff (profiles, working hours, assignment) | Sprint 3 | Working hours block booking creation |
| Customer CRM (profiles, history, search) | Sprint 3 | Lightweight — no tags/segments in MVP |
| Notifications (FCM reminders 24h + 1h) | Sprint 4 | Cloud Functions scheduled trigger |
| Dashboard (owner KPIs, cancellation rate, heatmap) | Sprint 5 | Firestore aggregation queries only |

**Out of scope — do not generate code for:**
- Web booking portal
- Payment / billing integration
- AI insights features
- Multi-branch management UI
- Advanced CRM (segments, campaigns)

---

## 10. Role & Permission Model

| Action | Owner | Receptionist | Staff |
|--------|-------|-------------|-------|
| Create / edit booking | ✅ | ✅ | ❌ |
| Cancel booking | ✅ | ✅ | ❌ |
| Update own booking status | ✅ | ✅ | ✅ (own only) |
| View all bookings | ✅ | ✅ | Own only |
| Manage staff profiles | ✅ | ❌ | ❌ |
| View dashboard | ✅ | ❌ | ❌ |
| Customer CRM read | ✅ | ✅ | Read only |
| Customer CRM write | ✅ | ✅ | ❌ |

Roles are stored as **Firebase Auth custom claims** (`role`, `tenantId`).
Read claims after sign-in with `user.getIdTokenResult(forceRefresh: true)`.
Never read roles from Firestore — always from the JWT claim.

---

## 11. Firestore Data Model Reference

```
tenants/{tenantId}
  name, plan, timezone, createdAt

users/{userId}
  tenantId, role, name, email, fcmToken, fcmUpdatedAt, workingHours

services/{serviceId}
  tenantId, name, durationMin, price, isActive

bookings/{bookingId}           ← real-time stream
  tenantId, staffId, customerId, serviceId
  startTime, endTime, status, notes
  reminder24Sent, reminder1hSent
  createdAt, updatedAt, createdBy

customers/{customerId}
  tenantId, name, phone, email, visitCount, lastVisit, notes

slots/{date}_{staffId}         ← real-time stream
  tenantId, staffId, date, intervals[]

notifications/{notifId}        ← write: Cloud Functions only
  tenantId, bookingId, type, scheduledAt, sentAt, status
```

**Real-time collections** (`bookings`, `slots`) must always use `.snapshots()` streams in the repository — never `.get()` for data that the UI displays live.

---

## 12. Testing Requirements

- All use cases must have unit tests in `test/unit/`
- BLoC tests use `bloc_test` package with `blocTest<>()` helper
- Mock all dependencies with `@GenerateMocks([...])` from `mockito`
- Run `make gen` after adding `@GenerateMocks` to regenerate mocks
- Minimum coverage target: **80%** on domain and data layers
- CI blocks merge if `flutter analyze` returns any issue

```dart
// Canonical test structure
void main() {
  group('CreateBookingUseCase', () {
    late MockBookingRepository mockRepo;
    late CreateBookingUseCase useCase;

    setUp(() {
      mockRepo = MockBookingRepository();
      useCase = CreateBookingUseCase(mockRepo);
    });

    test('returns Right(Booking) on success', () async {
      when(mockRepo.createBooking(any))
          .thenAnswer((_) async => Right(tBooking));
      final result = await useCase(tParams);
      expect(result, Right(tBooking));
    });

    test('returns Left(Failure) on repository error', () async {
      when(mockRepo.createBooking(any))
          .thenAnswer((_) async => Left(ServerFailure('error')));
      final result = await useCase(tParams);
      expect(result, isA<Left>());
    });
  });
}
```

---

*Last updated: Sprint 0 — May 2026*
*Do not modify this file without Tech Lead approval.*
