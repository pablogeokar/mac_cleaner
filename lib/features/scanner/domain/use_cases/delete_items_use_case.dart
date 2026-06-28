import '../entities/scan_item.dart';
import '../repositories/file_scanner_repository.dart';

class DeleteItemsUseCase {
  final FileScannerRepository repository;

  DeleteItemsUseCase(this.repository);

  Future<void> call(List<ScanItem> items, {required bool permanent}) {
    return repository.deleteItems(items, permanent: permanent);
  }
}
