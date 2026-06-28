import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

class SettingsState {
  final int largeFileMinSizeBytes;
  final int tempFileMinAgeHours;
  final bool launchOnStartup;
  final bool weeklyAutoScan;
  final List<String> whitelistedPaths;

  const SettingsState({
    required this.largeFileMinSizeBytes,
    required this.tempFileMinAgeHours,
    required this.launchOnStartup,
    required this.weeklyAutoScan,
    required this.whitelistedPaths,
  });

  SettingsState copyWith({
    int? largeFileMinSizeBytes,
    int? tempFileMinAgeHours,
    bool? launchOnStartup,
    bool? weeklyAutoScan,
    List<String>? whitelistedPaths,
  }) {
    return SettingsState(
      largeFileMinSizeBytes:
          largeFileMinSizeBytes ?? this.largeFileMinSizeBytes,
      tempFileMinAgeHours: tempFileMinAgeHours ?? this.tempFileMinAgeHours,
      launchOnStartup: launchOnStartup ?? this.launchOnStartup,
      weeklyAutoScan: weeklyAutoScan ?? this.weeklyAutoScan,
      whitelistedPaths: whitelistedPaths ?? this.whitelistedPaths,
    );
  }
}

@riverpod
class Settings extends _$Settings {
  @override
  SettingsState build() {
    return const SettingsState(
      largeFileMinSizeBytes: 500 * 1024 * 1024,
      tempFileMinAgeHours: 48,
      launchOnStartup: false,
      weeklyAutoScan: false,
      whitelistedPaths: [],
    );
  }

  void updateLargeFileMinSizeBytes(int bytes) {
    state = state.copyWith(largeFileMinSizeBytes: bytes);
  }

  void updateTempFileMinAgeHours(int hours) {
    state = state.copyWith(tempFileMinAgeHours: hours);
  }

  void toggleLaunchOnStartup(bool value) {
    state = state.copyWith(launchOnStartup: value);
  }

  void toggleWeeklyAutoScan(bool value) {
    state = state.copyWith(weeklyAutoScan: value);
  }

  void addWhitelistedPath(String path) {
    if (!state.whitelistedPaths.contains(path)) {
      state = state.copyWith(
        whitelistedPaths: [...state.whitelistedPaths, path],
      );
    }
  }

  void removeWhitelistedPath(String path) {
    state = state.copyWith(
      whitelistedPaths: state.whitelistedPaths.where((p) => p != path).toList(),
    );
  }
}
