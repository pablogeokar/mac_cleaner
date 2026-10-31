import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mac_cleaner/features/scanner/domain/entities/cleanup_result.dart';
import 'package:mac_cleaner/features/scanner/domain/entities/scan_category.dart';
import 'package:mac_cleaner/features/scanner/domain/entities/scan_item.dart';
import 'package:mac_cleaner/features/scanner/domain/entities/scan_progress.dart';
import 'package:mac_cleaner/features/scanner/domain/repositories/file_scanner_repository.dart';
import 'package:mac_cleaner/features/scanner/presentation/providers/scan_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControlledScannerRepository implements FileScannerRepository {
  final controllers = {
    ScanCategoryType.systemCache: StreamController<ScanProgress>(),
    ScanCategoryType.systemLogs: StreamController<ScanProgress>(),
  };

  @override
  Stream<ScanProgress> scanCategory(
    ScanCategoryType category, {
    int largeFileThresholdBytes = 500 * 1024 * 1024,
    int tempFileAgeHours = 48,
    int systemCacheAgeDays = 7,
    List<String> excludedPaths = const [],
  }) => controllers[category]!.stream;

  @override
  Future<CleanupResult> deleteItems(
    List<ScanItem> items, {
    required bool permanent,
    List<String> excludedPaths = const [],
  }) => throw UnimplementedError();
}

ScanProgress progress(ScanCategoryType category, double value) => ScanProgress(
  category: category,
  progress: value,
  currentPath: 'Analisando...',
  itemsFound: 0,
  bytesFound: 0,
  isComplete: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('overall progress stays below 100% until every scan ends', () async {
    final repository = ControlledScannerRepository();
    final container = ProviderContainer(
      overrides: [fileScannerRepositoryProvider.overrideWithValue(repository)],
    );
    final listener = container.listen(scannerNotifierProvider, (_, _) {});
    addTearDown(() {
      listener.close();
      container.dispose();
    });
    final notifier = container.read(scannerNotifierProvider.notifier);

    final scan = notifier.startScan(quickScan: true);
    var state = container.read(scannerNotifierProvider);
    expect(state.scanTargets, [
      ScanCategoryType.systemCache,
      ScanCategoryType.systemLogs,
    ]);
    expect(state.overallProgress, 0);

    repository.controllers[ScanCategoryType.systemCache]!.add(
      progress(ScanCategoryType.systemCache, 1.0),
    );
    await Future<void>.delayed(Duration.zero);
    state = container.read(scannerNotifierProvider);
    expect(state.categoryProgresses[ScanCategoryType.systemCache], lessThan(1));
    expect(state.overallProgress, 0);

    await repository.controllers[ScanCategoryType.systemCache]!.close();
    state = container.read(scannerNotifierProvider);
    expect(state.categoryProgresses[ScanCategoryType.systemCache], 1);
    expect(state.overallProgress, 0.5);
    expect(state.status, ScannerStatus.scanning);

    await repository.controllers[ScanCategoryType.systemLogs]!.close();
    expect(await scan, isTrue);
    state = container.read(scannerNotifierProvider);
    expect(state.overallProgress, 1);
    expect(state.status, ScannerStatus.completed);
  });

  test(
    'a failed category is reported without a completed category bar',
    () async {
      final repository = ControlledScannerRepository();
      final container = ProviderContainer(
        overrides: [
          fileScannerRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final listener = container.listen(scannerNotifierProvider, (_, _) {});
      addTearDown(() {
        listener.close();
        container.dispose();
      });
      final scan = container
          .read(scannerNotifierProvider.notifier)
          .startScan(quickScan: true);

      repository.controllers[ScanCategoryType.systemCache]!.addError(
        StateError('sem acesso'),
      );
      await Future<void>.delayed(Duration.zero);
      final state = container.read(scannerNotifierProvider);
      expect(state.scanErrors, contains(ScanCategoryType.systemCache));
      expect(
        state.categoryProgresses[ScanCategoryType.systemCache],
        lessThan(1),
      );
      expect(state.overallProgress, 0.5);

      await repository.controllers[ScanCategoryType.systemLogs]!.close();
      await scan;
      expect(container.read(scannerNotifierProvider).scanErrors.length, 1);
    },
  );
}
