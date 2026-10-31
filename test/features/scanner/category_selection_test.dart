import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mac_cleaner/features/scanner/data/repositories/file_scanner_repository_impl.dart';
import 'package:mac_cleaner/features/scanner/domain/entities/scan_category.dart';
import 'package:mac_cleaner/features/scanner/domain/entities/scan_item.dart';
import 'package:mac_cleaner/features/scanner/presentation/providers/scan_provider.dart';

ScanItem item(String name, ScanRiskLevel risk, {bool safeToDelete = true}) {
  return ScanItem(
    path: '/Users/test/Downloads/$name',
    fileName: name,
    sizeBytes: 100,
    lastModified: DateTime(2026),
    lastAccessed: DateTime(2026),
    type: ScanItemType.file,
    riskLevel: risk,
    isSafeToDelete: safeToDelete,
    isSelected: false,
  );
}

void main() {
  test(
    'category selection includes review items but excludes protected items',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(scannerNotifierProvider.notifier);
      notifier.updateCategoryItems(ScanCategoryType.duplicates, [
        item('safe', ScanRiskLevel.safe),
        item('review', ScanRiskLevel.caution),
        item('protected', ScanRiskLevel.protected),
      ]);

      var category = container
          .read(scannerNotifierProvider)
          .categories
          .firstWhere((cat) => cat.type == ScanCategoryType.duplicates);
      expect(category.isSelected, isFalse);

      notifier.selectAllInCategory(ScanCategoryType.duplicates, true);
      var state = container.read(scannerNotifierProvider);
      category = state.categories.firstWhere(
        (cat) => cat.type == ScanCategoryType.duplicates,
      );
      expect(category.items.map((entry) => entry.isSelected), [
        true,
        true,
        false,
      ]);
      expect(category.isSelected, isTrue);
      expect(state.totalSelectedFiles, 2);
      expect(state.totalSelectedBytes, 200);

      notifier.selectAllInCategory(ScanCategoryType.duplicates, false);
      state = container.read(scannerNotifierProvider);
      category = state.categories.firstWhere(
        (cat) => cat.type == ScanCategoryType.duplicates,
      );
      expect(category.items.every((entry) => !entry.isSelected), isTrue);
      expect(category.isSelected, isFalse);
      expect(state.totalSelectedFiles, 0);
    },
  );

  test('individual selection cannot select a protected item', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(scannerNotifierProvider.notifier);
    notifier.updateCategoryItems(ScanCategoryType.appResiduals, [
      item('review', ScanRiskLevel.caution),
      item('protected', ScanRiskLevel.protected, safeToDelete: false),
    ]);

    notifier.toggleItemSelection(
      ScanCategoryType.appResiduals,
      '/Users/test/Downloads/protected',
    );
    expect(container.read(scannerNotifierProvider).totalSelectedFiles, 0);

    notifier.toggleItemSelection(
      ScanCategoryType.appResiduals,
      '/Users/test/Downloads/review',
    );
    expect(container.read(scannerNotifierProvider).totalSelectedFiles, 1);
  });

  test('cleanup rejects protected items even if flagged safe', () async {
    final home = Platform.environment['HOME']!;
    final protectedItem = ScanItem(
      path: '$home/Downloads/protected-test',
      fileName: 'protected-test',
      sizeBytes: 100,
      lastModified: DateTime(2026),
      lastAccessed: DateTime(2026),
      type: ScanItemType.file,
      riskLevel: ScanRiskLevel.protected,
      isSafeToDelete: true,
      isSelected: true,
    );

    final result = await FileScannerRepositoryImpl().deleteItems([
      protectedItem,
    ], permanent: true);
    expect(result.removedCount, 0);
    expect(result.skippedCount, 1);
  });
}
