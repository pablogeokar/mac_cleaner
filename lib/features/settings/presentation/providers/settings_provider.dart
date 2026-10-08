import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/scan_paths.dart';

part 'settings_provider.g.dart';

class SettingsState {
  final int largeFileMinSizeBytes;
  final int tempFileMinAgeHours;
  final int systemCacheMinAgeDays;
  final bool allowPermanentDeletion;
  final List<String> excludedPaths;

  const SettingsState({
    required this.largeFileMinSizeBytes,
    required this.tempFileMinAgeHours,
    required this.systemCacheMinAgeDays,
    required this.allowPermanentDeletion,
    required this.excludedPaths,
  });

  SettingsState copyWith({
    int? largeFileMinSizeBytes,
    int? tempFileMinAgeHours,
    int? systemCacheMinAgeDays,
    bool? allowPermanentDeletion,
    List<String>? excludedPaths,
  }) {
    return SettingsState(
      largeFileMinSizeBytes:
          largeFileMinSizeBytes ?? this.largeFileMinSizeBytes,
      tempFileMinAgeHours: tempFileMinAgeHours ?? this.tempFileMinAgeHours,
      systemCacheMinAgeDays:
          systemCacheMinAgeDays ?? this.systemCacheMinAgeDays,
      allowPermanentDeletion:
          allowPermanentDeletion ?? this.allowPermanentDeletion,
      excludedPaths: excludedPaths ?? this.excludedPaths,
    );
  }
}

@riverpod
class Settings extends _$Settings {
  static const _largeFileKey = 'large_file_min_size_bytes';
  static const _tempAgeKey = 'temp_file_min_age_hours';
  static const _cacheAgeKey = 'system_cache_min_age_days';
  static const _permanentDeletionKey = 'allow_permanent_deletion';
  static const _excludedPathsKey = 'excluded_paths';

  @override
  SettingsState build() {
    ref.keepAlive();
    unawaited(_load());
    return const SettingsState(
      largeFileMinSizeBytes: 500 * 1024 * 1024,
      tempFileMinAgeHours: 48,
      systemCacheMinAgeDays: 7,
      allowPermanentDeletion: false,
      excludedPaths: [],
    );
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      state = state.copyWith(
        largeFileMinSizeBytes:
            preferences.getInt(_largeFileKey) ?? state.largeFileMinSizeBytes,
        tempFileMinAgeHours:
            preferences.getInt(_tempAgeKey) ?? state.tempFileMinAgeHours,
        systemCacheMinAgeDays:
            preferences.getInt(_cacheAgeKey) ?? state.systemCacheMinAgeDays,
        allowPermanentDeletion:
            preferences.getBool(_permanentDeletionKey) ??
            state.allowPermanentDeletion,
        excludedPaths:
            preferences.getStringList(_excludedPathsKey) ?? state.excludedPaths,
      );
    } catch (_) {
      // Keep conservative defaults if preferences are unavailable.
    }
  }

  void updateLargeFileMinSizeBytes(int bytes) {
    state = state.copyWith(largeFileMinSizeBytes: bytes);
    unawaited(_saveInt(_largeFileKey, bytes));
  }

  void updateTempFileMinAgeHours(int hours) {
    state = state.copyWith(tempFileMinAgeHours: hours);
    unawaited(_saveInt(_tempAgeKey, hours));
  }

  void updateSystemCacheMinAgeDays(int days) {
    state = state.copyWith(systemCacheMinAgeDays: days);
    unawaited(_saveInt(_cacheAgeKey, days));
  }

  void togglePermanentDeletion(bool value) {
    state = state.copyWith(allowPermanentDeletion: value);
    unawaited(_saveBool(_permanentDeletionKey, value));
  }

  bool addExcludedPath(String path) {
    final normalized = p.normalize(ScanPaths.expandPath(path.trim()));
    if (!p.isAbsolute(normalized) || state.excludedPaths.contains(normalized)) {
      return false;
    }
    state = state.copyWith(excludedPaths: [...state.excludedPaths, normalized]);
    unawaited(_saveExcludedPaths());
    return true;
  }

  void removeExcludedPath(String path) {
    state = state.copyWith(
      excludedPaths: state.excludedPaths.where((item) => item != path).toList(),
    );
    unawaited(_saveExcludedPaths());
  }

  Future<void> _saveInt(String key, int value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(key, value);
    } catch (_) {
      // The in-memory value remains valid for the current session.
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, value);
    } catch (_) {
      // The in-memory value remains valid for the current session.
    }
  }

  Future<void> _saveExcludedPaths() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_excludedPathsKey, state.excludedPaths);
    } catch (_) {
      // The in-memory value remains valid for the current session.
    }
  }
}
