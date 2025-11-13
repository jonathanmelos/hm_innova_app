## HM INNOVA — Quick instructions for coding agents

Purpose: provide concise, actionable guidance so an AI coding agent can be immediately productive in this Flutter multi-platform app.

- Project shape
  - Flutter multi-platform app (mobile + desktop). Entry points: `lib/main.dart` and `lib/app.dart`.
  - Conventions: shared infrastructure lives under `lib/core/` (db, notifications, theme). Domain features live in `lib/features/<feature>/` with UI under `presentation`/`widgets`.
    - Example: `lib/features/attendance/presentation/home_page.dart` and `lib/features/attendance/widgets/timer_display.dart`.

- Bootstrapping and important side-effects (read before editing)
  - `lib/main.dart` performs platform-specific initialization:
    - Initializes `sqflite_common_ffi` for desktop (Windows/Linux/macOS): do not remove `sqfliteFfiInit()` / `databaseFactory = databaseFactoryFfi;` without confirming cross-platform DB behavior.
    - Calls `initializeDateFormatting('es')` and sets timezone using `timezone` package to `America/Guayaquil`.
    - Initializes notifications: `NotificationService.instance.init()` and schedules daily reminders with `scheduleMorningPlan()` (see `lib/core/notifications/notification_service.dart`). Changes here affect app behavior and must be tested on device.

- Database and persistence
  - Mobile uses `sqflite`; desktop uses `sqflite_common_ffi`. Look in `lib/core/db/` for DB helpers and migrations.
  - When changing DB schema: update migration logic (if present), test on both mobile and desktop (desktop uses the FFI backend configured in `main.dart`).

- Localization & UI
  - App forces Spanish locale in `lib/app.dart` (`Locale('es','ES')`). Keep this in mind when adding strings; search for hard-coded Spanish strings.

- Plugins & native integration
  - Key plugins in `pubspec.yaml`: `flutter_local_notifications`, `mobile_scanner`, `permission_handler`, `sqflite`, `path_provider`, `image_picker`. Native AND Dart-side changes may be required for permission/manifest updates.
  - For Android/iOS platform changes, inspect `android/` and `ios/Runner/Info.plist`.

- Developer workflows (how to build/test/debug)
  - Install deps: `flutter pub get`
  - Run on Windows: `flutter run -d windows` (desktop uses FFI DB). Run on Android: `flutter run -d <device-id>` or via Android Studio.
  - Run tests: `flutter test` (project includes `test/widget_test.dart`).
  - Lints & static analysis: `flutter analyze` (project uses `flutter_lints`).
  - Format: `dart format .` or `flutter format .`.

- Patterns & naming to follow
  - Singletons via `.instance` are used for services (e.g., `NotificationService.instance`). Prefer existing service APIs instead of re-creating globals.
  - Feature folders group by domain. Put UI under `presentation`/`widgets`, and shared utilities under `core/`.

- Safety notes and edge cases
  - Timezone and scheduled notifications are side-effects executed at app startup — changing them can alter scheduled reminders for users. Run manual testing on device/emulator.
  - DB backend differs between mobile and desktop (FFI). When writing DB-related code, ensure the code runs under both `sqflite` and `sqflite_common_ffi`.
  - Permissions (camera, notifications) need platform manifest/entitlements edits and runtime permission handling (see `main.dart` call to `ensurePermissionOnAndroid13()`).

- Useful files to inspect (examples)
  - `lib/main.dart` — platform initialization, timezone, notifications, SQLite FFI.
  - `lib/app.dart` — MaterialApp config and localization.
  - `lib/core/notifications/notification_service.dart` — notification setup and scheduled jobs.
  - `lib/core/db/` — local DB helpers (search this folder for DB helpers and migrations).
  - `lib/core/theme/app_theme.dart` — theme constants.
  - `lib/features/attendance/` — primary feature area; see `presentation` and `widgets` subfolders.

If anything above is unclear or you want more examples (e.g., where migrations live, or test coverage details), tell me which area to expand and I'll iterate.
