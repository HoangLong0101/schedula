# Makefile  (indent with TABS, not spaces)
.PHONY: gen clean test run-dev run-staging analyze rules firebase-config-dev firebase-config-staging
 
gen:
	dart run build_runner build --delete-conflicting-outputs

firebase-config-dev:
	dart run tool/bootstrap_firebase_config.dart --config-file .firebase-config.dev.json

firebase-config-staging:
	dart run tool/bootstrap_firebase_config.dart --config-file .firebase-config.staging.json
 
clean:
	flutter clean && flutter pub get && make gen
 
test:
	flutter test --coverage
 
run-dev:
	make firebase-config-dev && flutter run --flavor dev --dart-define-from-file=.firebase-config.dev.json
 
run-staging:
	make firebase-config-staging && flutter run --flavor staging --dart-define-from-file=.firebase-config.staging.json
 
analyze:
	flutter analyze && dart format --set-exit-if-changed lib/
 
rules:
	firebase use schedula-dev && firebase deploy --only firestore:rules
