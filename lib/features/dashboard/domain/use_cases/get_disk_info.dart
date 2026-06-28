import '../entities/disk_info.dart';
import '../repositories/disk_info_repository.dart';

class GetDiskInfo {
  final DiskInfoRepository repository;

  GetDiskInfo(this.repository);

  Future<DiskInfo> call() {
    return repository.getDiskInfo();
  }
}
