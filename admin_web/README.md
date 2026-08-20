# Schedula Admin

The internal platform administration portal uses the same Firebase backend as
Schedula while keeping its deployment and authorization separate.

## Local setup

Create a Firebase Authentication user, then grant the platform claim from the
repository root:

```powershell
cd functions
npm run admin:grant -- FIREBASE_AUTH_UID
```

Run the portal with the same Firebase web values used by the tenant app:

```powershell
flutter run -d chrome --dart-define-from-file=../.firebase-config.dev.json
```

Deploy the isolated platform API and required indexes before using the portal:

```powershell
firebase deploy --project schedula-543b1 --only "functions:platform,firestore:indexes"
```

The PayOS transaction re-check uses the existing `PAYOS_CLIENT_ID` and
`PAYOS_API_KEY` Secret Manager values. No PayOS secret is compiled into the
web application.

## Hosting setup

Create a second Firebase Hosting site, then map it once:

```powershell
firebase target:apply hosting admin YOUR_ADMIN_HOSTING_SITE_ID
```

Build with the checked production script, then deploy without replacing the
tenant website:

```powershell
./tool/build_admin_web.ps1
firebase deploy --config firebase.admin.json --only hosting:admin
```
