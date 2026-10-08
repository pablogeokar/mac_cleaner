import '../entities/cleanup_result.dart';
import '../entities/scan_item.dart';
import '../repositories/file_scanner_repository.dart';

class DeleteItemsUseCase {
  final FileScannerRepository repository;

  DeleteItemsUseCase(this.repository);

  Future<CleanupResult> call(
    List<ScanItem> items, {
    required bool permanent,
    List<String> excludedPaths = const [],
  }) {
    return repository.deleteItems(
      items,
      permanent: permanent,
      excludedPaths: excludedPaths,
    );
  }
}
