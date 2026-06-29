# Schedula

**Booking management for spa & clinic businesses in Vietnam.**

Schedula is a Flutter mobile application that replaces phone/Zalo/Facebook booking
for small-to-medium spa and clinic operators. It provides real-time slot management,
staff scheduling, customer profiles, and automated appointment reminders — built
specifically for the Vietnamese SME market.

---

## Contents

- [What this app does](#what-this-app-does)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Getting started](#getting-started)
- [Running the app](#running-the-app)
- [Environment setup](#environment-setup)
- [Firebase architecture](#firebase-architecture)
- [Data model](#data-model)
- [Project model UML](docs/PROJECT_MODEL_UML.md)
- [Roles & permissions](#roles--permissions)
- [MVP feature scope](#mvp-feature-scope)
- [Sprint plan](#sprint-plan)
- [Contributing](#contributing)
- [Key documents](#key-documents)

---

## What this app does

**Problem:** Spa and clinic owners in Vietnam manage bookings through informal channels
(Zalo, phone, Facebook DM). This causes double-bookings, missed appointments, and no
centralised data — directly hurting revenue.

**Solution:** A focused booking platform with three user roles:

| Role | Who | Core job in the app |
|------|-----|---------------------|
| **Owner** | Spa/clinic proprietor | Full access — settings, staff, analytics, all bookings |
| **Receptionist** | Front desk | Create and manage bookings, customer profiles |
| **Staff** | Therapists / technicians | View own schedule, update booking status |

**Core features (MVP):**
- Real-time booking grid with conflict prevention
- Automated FCM push reminders (24h and 1h before appointment)
- Staff schedule management and manual override
- Lightweight customer CRM (history, visit count, notes)
- Owner analytics dashboard (bookings, cancellation rate, busiest hours)

**Out of scope in MVP:** web booking portal, payments, AI insights, multi-branch UI.

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| Mobile framework | Flutter 3.44.0 (Dart 3.4+) — stable channel |
| Architecture | Clean Architecture (data / domain / presentation) |
| State management | `flutter_bloc` — BLoC for features, Cubit for simple state |
| Dependency injection | `get_it` + `injectable` (annotation-driven, code-generated) |
| Navigation | `go_router` with auth guards |
| Database | Cloud Firestore (real-time streams) |
| Auth | Firebase Authentication — email/password + custom claims for roles |
| Push notifications | Firebase Cloud Messaging (FCM) |
| Scheduled jobs | Firebase Cloud Functions (TypeScript) — reminder triggers |
| Error handling | `dartz` — `Either<Failure, T>` across all use cases |
| Secure storage | `flutter_secure_storage` — FCM tokens, auth tokens |
| Calendar UI | `table_calendar` — booking grid |
| IDE | VS Code with Flutter + Dart extensions |
| CI/CD | GitHub Actions → Firebase App Distribution (staging) |
| Version pinning | FVM (Flutter Version Manager) |

---

## Project structure

```
lib/
├── core/
│   ├── di/               # GetIt service locator (injection.dart + generated config)
│   ├── router/           # go_router definitions and auth guards (app_router.dart)
│   ├── theme/            # AppTheme — colors, typography, component styles
│   ├── utils/            # Shared utilities (DateUtils, StringUtils)
│   └── constants/        # App-wide constants
│
├── features/
│   ├── auth/             # Sign-in, session management, role-based routing
│   ├── booking/          # Booking creation, grid, conflict prevention, status
│   ├── staff/            # Staff profiles, working hours, assignment
│   ├── customer/         # Customer CRM — profiles, history, search
│   └── dashboard/        # Owner analytics — KPIs, heatmap, cancellation rate
│
└── main.dart             # Entry point — Firebase init, DI, flavor selection

functions/                # Firebase Cloud Functions (TypeScript)
├── src/
│   ├── auth/             # setUserRole callable function
│   └── notifications/    # Scheduled reminder triggers (24h + 1h)
└── package.json

test/
├── unit/                 # Use case and repository unit tests
└── widget/               # Widget tests

.vscode/
├── launch.json           # One-click run configs for dev / staging / prod flavors
├── settings.json         # Dart formatter, FVM path, file nesting
├── tasks.json            # build_runner, analyze, test tasks
└── extensions.json       # Recommended extensions for the team

.github/
└── workflows/
    ├── ci.yml            # PR gate: analyze + test + build Android + build iOS
    └── deploy.yml        # Merge to main: staging APK → Firebase App Distribution
```

Each feature follows the same internal structure:

```
features/{name}/
├── data/
│   ├── datasources/      # Firebase data source (Firestore queries)
│   ├── models/           # DTOs with fromFirestore() / toMap()
│   └── repositories/     # Concrete repository implementations
├── domain/
│   ├── entities/         # Pure Dart business objects (no Firebase imports)
│   ├── repositories/     # Abstract repository interfaces
│   └── usecases/         # One file per use case, returns Either<Failure, T>
└── presentation/
    ├── bloc/             # BLoC / Cubit, Event, State (sealed classes)
    ├── pages/            # Full screens
    └── widgets/          # Feature-scoped reusable widgets
```

---

## Getting started

### Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Flutter | 3.22.3 stable | Pinned via FVM |
| Dart | 3.4+ | Bundled with Flutter |
| FVM | latest | `dart pub global activate fvm` |
| Node.js | 18 LTS | For Firebase CLI and Cloud Functions |
| Firebase CLI | 13+ | `npm install -g firebase-tools` |
| Xcode | 15.3+ | macOS only, for iOS builds |
| CocoaPods | 1.15+ | `sudo gem install cocoapods` |

### Clone and set up

```bash
git clone https://github.com/your-org/schedula.git
cd schedula

# Use the pinned Flutter version
fvm use

# Install dependencies
flutter pub get

# Generate DI config (required before first run)
dart run tool/bootstrap_firebase_config.dart --config-file .firebase-config.dev.json
```

### VS Code setup

Open the project in VS Code. When prompted:
- **"Do you trust this workspace?"** → Yes
- **"Install recommended extensions?"** → Install All

The `.vscode/extensions.json` file installs the correct Flutter, BLoC, Firebase Explorer,
GitHub Actions, and linting extensions automatically.

---

## Running the app

### Via VS Code (recommended)

Open the **Run & Debug panel** (`Ctrl+Shift+D` / `Cmd+Shift+D`), select a flavor from
the dropdown, and press **F5**.

| Config name | Firebase project | Use for |
|-------------|-----------------|---------|
| `Schedula (dev)` | schedula-dev | Daily development |
| `Schedula (staging)` | schedula-staging | QA and testing |
| `Schedula (prod — profile)` | schedula-prod | Performance profiling only |

### Via terminal

```bash
# Development (default)
flutter run --flavor dev --dart-define=FLAVOR=dev

# Staging
flutter run --flavor staging --dart-define=FLAVOR=staging

# Makefile shortcuts
make run-dev
make run-staging
```

---

## Environment setup

Three isolated environments — each with its own Firebase project, Firestore database,
and FCM configuration.

| Environment | Firebase project | Purpose |
|-------------|-----------------|---------|
| `dev` | `schedula-dev` | Local development. Safe to break. Seeded test data. |
| `staging` | `schedula-staging` | QA and internal testing. Rules match production. |
| `prod` | `schedula-prod` | Live production. Strict rules + error alerting. |

The correct Firebase project is selected at build time via `--dart-define=FLAVOR=dev`.
`main.dart` switches between `firebase_options_dev.dart`, `firebase_options_staging.dart`,
and `firebase_options_prod.dart` accordingly.

Firebase config now comes from an ignored JSON file such as `.firebase-config.dev.json`
or `.firebase-config.staging.json`. Use `firebase-config.example.json` as the template,
copy it to the environment-specific file you need, then run:

```bash
dart run tool/bootstrap_firebase_config.dart --config-file .firebase-config.dev.json
flutter run --flavor dev --dart-define-from-file=.firebase-config.dev.json
```

The generator writes `android/app/google-services.json` on demand, so the Firebase API
key and client metadata stay out of source control while Android builds still work.

> ⚠️ **Never run the dev flavor against the prod Firebase project.**
> One accidental `flutter run` can corrupt live customer data.

### Code generation

The DI wiring (`injection.config.dart`) is generated by `build_runner`. Run it after
adding or changing any `@injectable` annotation:

```bash
# One-time
make gen

# Watch mode (run in a dedicated terminal panel during active development)
dart run build_runner watch --delete-conflicting-outputs
```

---

## Firebase architecture

### Services used in MVP

| Service | Purpose |
|---------|---------|
| Cloud Firestore | Primary database — real-time streams for bookings and slots |
| Firebase Auth | Email/password sign-in + custom claims for role/tenantId |
| Cloud Messaging (FCM) | Push reminders and booking alerts |
| Cloud Functions | Scheduled notification triggers (24h + 1h before appointment) |

### Reminder delivery configuration

The scheduled `sendReminders` function sends:

- Staff reminder: FCM push + in-app notification 1 hour before a confirmed booking.
- Customer reminder: email via Resend + Zalo ZNS message 24 hours before a confirmed booking.

Configure these before deploying notification delivery:

```bash
firebase functions:secrets:set RESEND_API_KEY
firebase functions:secrets:set ZALO_ZNS_ACCESS_TOKEN
```

Set non-secret parameters in the functions environment, for example
`functions/.env.<project-id>`:

```bash
REMINDER_MAIL_FROM="Schedula <no-reply@example.com>"
ZALO_ZNS_TEMPLATE_ID="your_zns_template_id"
```

The Zalo ZNS template must contain variables named `customer_name`,
`appointment_time`, `service_name`, and `staff_name`.

### Multi-tenancy

Every Firestore document carries a `tenantId` field. Firestore Security Rules enforce
tenant isolation — a user can only read/write documents whose `tenantId` matches
the one in their Firebase Auth custom claim. This pattern supports future multi-branch
expansion without schema migration.

### Roles as custom claims

Roles are stored in the Firebase Auth JWT as custom claims — **not in Firestore**.
This means Security Rules can enforce role-based access without an extra database read.

```dart
// Read role after sign-in (always force-refresh to get latest claims)
final token = await user.getIdTokenResult(true);
final role     = token.claims?['role']     as String?; // 'owner' | 'receptionist' | 'staff'
final tenantId = token.claims?['tenantId'] as String?;
```

Roles are assigned by the `setUserRole` Cloud Function — only an existing owner can
call it, enforced at the function level.

---

## Data model

```
tenants/{tenantId}
  name, plan, timezone, createdAt

users/{userId}
  tenantId, role, name, email
  fcmToken, fcmUpdatedAt
  workingHours: { mon: {start, end}, ... }

services/{serviceId}
  tenantId, name, durationMin, price, isActive

bookings/{bookingId}                   ← real-time .snapshots() stream
  tenantId, staffId, customerId, serviceId
  startTime (Timestamp), endTime (Timestamp)
  status: pending | confirmed | in_progress | completed | cancelled | no_show
  notes, createdBy
  reminder24Sent (bool), reminder1hSent (bool)
  createdAt, updatedAt

customers/{customerId}
  tenantId, name, phone (unique per tenant), email
  visitCount, lastVisit, notes

slots/{date}_{staffId}                 ← real-time .snapshots() stream
  tenantId, staffId, date
  intervals: [ { start, end, bookingId? } ]

notifications/{notifId}                ← Cloud Functions write only
  tenantId, bookingId, type (24h | 1h | assigned | cancelled)
  scheduledAt, sentAt, status
```

### Composite indexes (required)

These indexes must exist in Firestore before the booking queries will run:

| Collection | Fields |
|------------|--------|
| `bookings` | `tenantId` ASC · `startTime` ASC |
| `bookings` | `tenantId` ASC · `staffId` ASC · `startTime` ASC |
| `bookings` | `tenantId` ASC · `status` ASC · `startTime` ASC |
| `customers` | `tenantId` ASC · `name` ASC |
| `slots` | `tenantId` ASC · `staffId` ASC · `date` ASC |
| `notifications` | `tenantId` ASC · `bookingId` ASC · `scheduledAt` ASC |

---

## Roles & permissions

| Action | Owner | Receptionist | Staff |
|--------|:-----:|:------------:|:-----:|
| Create / edit booking | ✅ | ✅ | ❌ |
| Cancel booking | ✅ | ✅ | ❌ |
| Update booking status (own) | ✅ | ✅ | ✅ |
| View all bookings | ✅ | ✅ | Own only |
| Manage staff profiles | ✅ | ❌ | ❌ |
| View analytics dashboard | ✅ | ❌ | ❌ |
| Customer CRM read | ✅ | ✅ | Read only |
| Customer CRM write | ✅ | ✅ | ❌ |

---

## MVP feature scope

| Feature | Sprint | Status |
|---------|--------|--------|
| Auth — sign-in, role guard, route protection | 1 | Planned |
| Booking — grid, create, cancel, status | 2 | Planned |
| Staff — profiles, working hours, assignment | 3 | Planned |
| Customer CRM — profiles, history, search | 3 | Planned |
| Notifications — FCM 24h + 1h reminders | 4 | Planned |
| Dashboard — owner KPIs, heatmap, cancellation rate | 5 | Planned |

**Deferred to Phase 2+** (do not build during MVP):

- Web booking portal for customers
- Payment / billing integration
- AI insights and recommendations
- Multi-branch management UI
- Advanced CRM (segments, tags, campaigns)

---

## Sprint plan

| Sprint | Duration | Focus |
|--------|----------|-------|
| 0 — Foundation | 1 week | Flutter init · Firebase · CI/CD · VS Code workspace |
| 1 — Auth & Core | 1 week | Firebase Auth · role claims · go_router guards · DI wiring |
| 2 — Booking | 2 weeks | Booking grid · create flow · conflict prevention · real-time sync |
| 3 — Staff & CRM | 1.5 weeks | Staff profiles · working hours · customer profiles |
| 4 — Notifications | 1 week | FCM setup · Cloud Functions · reminder triggers |
| 5 — Dashboard & Polish | 1.5 weeks | Owner analytics · Firestore aggregation · UI refinement |
| 6 — QA & Release | 1 week | Integration tests · load testing · App Store prep |
| **Total** | **~9 weeks** | **Shippable MVP** |

---

## Contributing

### Branch strategy

| Branch | Purpose | Protected |
|--------|---------|-----------|
| `main` | Production-ready. Triggers staging deploy on merge. | ✅ PR + CI required |
| `develop` | Integration branch. CI runs on every push. | ✅ CI required |
| `feature/*` | Feature work. PR targets `develop`. | ❌ |
| `fix/*` | Bug fixes. PR targets `develop` or `main`. | ❌ |

### Before opening a PR

```bash
# All of these must pass
flutter analyze       # zero issues
flutter test          # all tests pass
make gen              # no pending build_runner changes
dart format --set-exit-if-changed lib/   # no unformatted files
```

### CI gate

Every PR triggers:
1. `flutter analyze` — zero issues required
2. `flutter test` — all unit tests pass
3. `Build Android` — APK compiles (dev flavor, debug)
4. `Build iOS` — no-codesign build succeeds (dev flavor, debug)

Merging to `main` additionally triggers a staging build distributed via
Firebase App Distribution to the `internal-testers` group.

### Agent usage

This project is configured for AI agent assistance. Before starting any task, agents must
read `CLAUDE.md` in the project root. It defines architecture rules, forbidden patterns,
naming conventions, and the complete command reference. **Do not generate code that
violates the rules in `CLAUDE.md`.**

---

## Key documents

| Document | Location | Contents |
|----------|---------|---------|
| Agent control rules | `CLAUDE.md` | Architecture rules, forbidden patterns, commands — read before every task |
| Software Requirements Specification | `docs/SRS_MVP.docx` | Full functional/non-functional requirements, FR list, NFR list |
| Architecture diagrams | `docs/Architecture_Diagrams.html` | System architecture, booking flow, data model, role matrix |
| Project model UML | `docs/PROJECT_MODEL_UML.md` | Current Dart entities, Firestore DTOs, repository boundaries, and relationships |
| Design system | `docs/DESIGN_SYSTEM.md` | Colors, typography, spacing, component rules *(Sprint 1)* |
| Setup guide | `docs/Sprint0_Setup_Guide.docx` | Step-by-step setup for all 4 Sprint 0 tasks |

---

*Schedula · Flutter MVP · Vietnam spa & clinic market · May 2026*
