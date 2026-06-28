import '../entities/disk_info.dart';

abstract class DiskInfoRepository {
  Future<DiskInfo> getDiskInfo();
}
