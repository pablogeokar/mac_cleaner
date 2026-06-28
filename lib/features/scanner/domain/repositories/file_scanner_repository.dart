import '../entities/scan_category.dart';
import '../entities/scan_progress.dart';
import '../entities/scan_item.dart';

abstract class FileScannerRepository {
  /// Scans a specific category and yields real-time progress.
  Stream<ScanProgress> scanCategory(
    ScanCategoryType category, {
    int largeFileThresholdBytes = 500 * 1024 * 1024,
    int tempFileAgeHours = 48,
    int systemCacheAgeDays = 7,
  });

  /// Deletes selected items, either permanently or moving them to Trash.
  Future<void> deleteItems(List<ScanItem> items, {required bool permanent});
}
