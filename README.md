<p align="center">
  <img src="assets/mac_cleaner_logo.png" alt="MacCleaner logo" width="360">
</p>

# MacCleaner

MacCleaner is a Flutter macOS desktop app for finding files that may be safe to clean up, such as caches, logs, temporary downloads, trash contents, large files, duplicates, developer tool caches, app leftovers, and duplicated fonts.

The project is built as a native macOS Flutter app with a macOS-like interface, Riverpod state management, GoRouter routing, and a small native Swift bridge for moving files to the Trash.

## Current Status

This project is under active development. The app can build and run on macOS, scan real filesystem locations, move selected items to the Trash, and export debug scan logs for review. The cleanup logic should still be treated as experimental until the safety rules and tests are expanded.

Verified locally:

```bash
flutter analyze
flutter build macos
```

## Safety Notice

MacCleaner scans real files on your machine. Be careful before deleting anything.

Recommended while testing:

- Prefer "Move to Trash" instead of permanent deletion.
- Review selected files before cleaning.
- Avoid deleting developer caches or app residuals unless you understand the impact.
- Keep backups for important projects and user data.
- Do not treat detected "residual" or "duplicate" items as guaranteed safe until the safety rules are further hardened and covered by tests.

Some categories can affect development tools, simulators, package managers, Docker data, build caches, or app preferences.

## Features

- macOS-style desktop layout with a custom title bar and sidebar.
- Dashboard with disk usage summary.
- Full and quick scan flows.
- Dashboard category checkboxes that control which categories are scanned.
- Category-based scan results.
- File filtering and sorting in the results screen.
- Selection controls for categories and individual files.
- Cleanup confirmation dialog.
- Native macOS Trash integration through `NSWorkspace.recycle`.
- Settings screen for scan thresholds and excluded paths.
- Debug-only CSV scan log export, including a Finder reveal action.
- Native macOS app icon and bundle display name configured as MacCleaner.

## Scan Categories

MacCleaner currently includes category support for:

- System caches
- System and app logs
- Temporary files
- User Trash
- Developer and application caches
- Large files
- Duplicate files
- App residual files
- Duplicate fonts

Not every category is fully production-safe yet. Some detection rules are intentionally conservative in the UI, but the scanner still needs stronger validation before real-world cleanup use.

## Tech Stack

- Flutter 3.22+ for macOS desktop
- Dart 3.4+
- Riverpod 2 with code generation
- GoRouter
- Material 3
- `window_manager`
- Native macOS Swift bridge via `MethodChannel`
- Clean Architecture-style feature folders

## Project Structure

```text
lib/
  app/
    app.dart
    router.dart
    theme.dart
  core/
    constants/
    errors/
    utils/
  features/
    dashboard/
    scanner/
    results/
    report/
    settings/
macos/
  Runner/
```

## Requirements

- macOS 12 Monterey or newer
- Flutter stable
- Xcode with macOS desktop development support
- CocoaPods for macOS plugin dependencies

Check your local Flutter setup:

```bash
flutter doctor
flutter config --enable-macos-desktop
```

## Getting Started

Install dependencies:

```bash
flutter pub get
```

Generate Riverpod files if needed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run the app:

```bash
flutter run -d macos
```

Build a release app:

```bash
flutter build macos
```

The release bundle is generated at:

```text
build/macos/Build/Products/Release/MacCleaner.app
```

## Development Checks

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Note: unit tests still need to be added for the scanner use cases and deletion safety guard.

## macOS Permissions

The macOS app is configured for direct distribution style access, with sandbox disabled in the entitlements. The app also includes usage descriptions for Documents, Downloads, and Desktop access in `macos/Runner/Info.plist`.

For Mac App Store distribution, the permissions model would need to change to use a sandbox-compatible approach, such as user-selected access and security-scoped bookmarks.

## Known Gaps

- Scanner-heavy work is not yet isolated with `Isolate.run` or `compute`.
- Deletion safety needs stronger path normalization and test coverage.
- Permanent deletion needs stricter confirmation.
- Some settings UI is not fully wired to real macOS automation yet.
- App residual detection should use bundle IDs instead of approximate name matching.
- Duplicate font detection should use font metadata rather than file names.
- Duplicate file hashing should move off the UI isolate.
- Automated tests are not implemented yet.

## Roadmap

Safety and correctness:

- Add unit tests for deletion safety and scanner use cases.
- Harden cleanup rules by category.
- Make permanent deletion opt-in behind stronger double confirmation.
- Keep risky categories unselected by default, especially app residuals, duplicate fonts, Docker, Android AVDs, and simulator data.
- Add a dry-run report that explains why each item is considered safe or risky.
- Add category-specific allowlists and blocklists.
- Add path canonicalization and symlink-aware safety checks.

Scanner engine:

- Improve scan cancellation and progress accuracy.
- Move recursive scanning and duplicate hashing to isolates.
- Improve duplicate detection with staged hashing and collision-safe verification.
- Detect duplicate fonts using font metadata instead of file names.
- Improve duplicate and residual detection quality.
- Detect app residuals using installed app bundle identifiers.
- Improve Docker, simulator, Gradle, Maven, Homebrew, and Android cache detection with safer rules.

User experience:

- Add persistent cleanup history.
- Add a review screen grouped by risk level.
- Add a "Reveal in Finder" action for individual scan items.
- Add CSV export for normal release builds, not only debug scan logs.
- Add search by path, category, and risk level.
- Add better empty, loading, error, and partial-permission states.
- Add clearer feedback after cleanup, including skipped files and failed moves.

Settings and automation:

- Implement launch at login with a real LaunchAgent or macOS login item integration.
- Implement weekly automatic scans.
- Persist user settings with `shared_preferences` or SQLite.
- Add editable excluded paths with Finder folder picker support.
- Add per-category thresholds for file age and size.

Distribution:

- Add app signing and notarization workflow.
- Prepare a direct-download `.dmg` build.
- Investigate a sandbox-compatible Mac App Store variant using security-scoped bookmarks.
- Add CI for analysis, tests, and macOS builds.
