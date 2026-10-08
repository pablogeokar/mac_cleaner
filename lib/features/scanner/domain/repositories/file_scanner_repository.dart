import '../entities/scan_category.dart';
import '../entities/scan_progress.dart';
import '../entities/scan_item.dart';
import '../entities/cleanup_result.dart';

abstract class FileScannerRepository {
  /// Scans a specific category and yields real-time progress.
  Stream<ScanProgress> scanCategory(
    ScanCategoryType category, {
    int largeFileThresholdBytes = 500 * 1024 * 1024,
    int tempFileAgeHours = 48,
    int systemCacheAgeDays = 7,
    List<String> excludedPaths = const [],
  });

  /// Deletes selected items and reports each success, skip and failure.
  Future<CleanupResult> deleteItems(
    List<ScanItem> items, {
    required bool permanent,
    List<String> excludedPaths = const [],
  });
}
