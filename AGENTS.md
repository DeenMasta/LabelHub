# Repository Guidelines

Read `UI_DESIGN_RULES.md` before changing a Flutter layout or shared visual component.

## Project Structure & Module Organization

LabelHub is an Android-first, offline Flutter application. `lib/app/` owns the application root, GoRouter configuration, and theme. Shared, cross-feature code belongs in `lib/core/`: SQLite setup is in `core/database`, printer abstractions in `core/printing`, and shared calculations in `core/utilities`. Business capabilities live in `lib/features/<feature>/`. Keep feature UI under `presentation/`; put persistence and external-package integration in `data/`; put package-independent models, repository contracts, and use cases in `domain/` when a feature needs them.

Preserve the boundaries in the project plan: presentation must not issue SQL or generate printer commands; repositories own persistence; printer implementations satisfy `LabelPrinter`; label dimensions stay in millimetres until the PDF/printer rendering boundary. Keep import validation in a shared validation service so CSV and later Excel imports produce the same errors.

## Build, Test, and Development Commands

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
flutter test test/widget_test.dart
flutter build apk --debug
```

The debug APK is `build/app/outputs/flutter-apk/app-debug.apk`.

## Coding Style & Naming Conventions

Use `dart format` for every changed Dart file and keep `flutter analyze` clean; analysis uses `package:flutter_lints/flutter.yaml`. Use `lower_snake_case.dart` filenames, PascalCase types, and lowerCamelCase members. Prefer immutable `final` fields, `const` constructors/widgets, small focused types, and early returns over deeply nested control flow.

Before adding a helper, model, provider, or service, search the relevant feature and `core/` for an existing owner. Extend or rename the existing abstraction when it has the same responsibility; do not create parallel utilities, duplicate conversions, or feature-specific versions of shared rules. Add a dependency only when an existing package cannot serve the need, and keep package APIs behind a data or core adapter where practical.

## Agent Implementation Rules

Implement one coherent vertical slice at a time and avoid unrelated refactors. Keep public contracts small and explicit. Use Riverpod for application state and GoRouter for navigation; do not introduce alternative state or routing systems. Store structured records through the local database layer only; the app must remain usable offline. Validate barcode data before rendering or printing and surface invalid input instead of silently changing it. For a behavior change, update or add a focused `flutter_test` test, then run analysis and the relevant test command before handoff.
