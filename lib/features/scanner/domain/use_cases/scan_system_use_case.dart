import '../entities/scan_category.dart';
import '../entities/scan_progress.dart';
import '../repositories/file_scanner_repository.dart';

class ScanSystemUseCase {
  final FileScannerRepository repository;

  ScanSystemUseCase(this.repository);

  Stream<ScanProgress> call(
    ScanCategoryType category, {
    int largeFileThresholdBytes = 500 * 1024 * 1024,
    int tempFileAgeHours = 48,
    int systemCacheAgeDays = 7,
  }) {
    return repository.scanCategory(
      category,
      largeFileThresholdBytes: largeFileThresholdBytes,
      tempFileAgeHours: tempFileAgeHours,
      systemCacheAgeDays: systemCacheAgeDays,
    );
  }
}
