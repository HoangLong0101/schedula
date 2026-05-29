# Makefile  (indent with TABS, not spaces)
.PHONY: gen clean test run-dev run-staging analyze rules
 
gen:
	dart run build_runner build --delete-conflicting-outputs
 
clean:
	flutter clean && flutter pub get && make gen
 
test:
	flutter test --coverage
 
run-dev:
	flutter run --flavor dev --dart-define=FLAVOR=dev
 
run-staging:
	flutter run --flavor staging --dart-define=FLAVOR=staging
 
analyze:
	flutter analyze && dart format --set-exit-if-changed lib/
 
rules:
	firebase use schedula-dev && firebase deploy --only firestore:rules
