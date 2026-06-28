import '../../../core/utils/shell_runner.dart';
import '../domain/entities/disk_info.dart';
import '../domain/repositories/disk_info_repository.dart';

class DiskInfoRepositoryImpl implements DiskInfoRepository {
  @override
  Future<DiskInfo> getDiskInfo() async {
    final result = await ShellRunner.run('df', ['-k', '/']);
    if (result.exitCode != 0) {
      throw Exception('Failed to execute df command: ${result.stderr}');
    }

    final lines = result.stdout.toString().trim().split('\n');
    if (lines.length < 2) {
      throw Exception('Unexpected df output structure: $lines');
    }

    // Line 0 is header, Line 1 is the root mount filesystem data
    final dataLine = lines[1];
    final parts = dataLine.split(RegExp(r'\s+'));

    if (parts.length < 6) {
      throw Exception('Failed to split df columns: $parts');
    }

    final fileSystem = parts[0];
    final totalKb = int.tryParse(parts[1]) ?? 0;
    final usedKb = int.tryParse(parts[2]) ?? 0;
    final freeKb = int.tryParse(parts[3]) ?? 0;
    final mountPoint = parts.last;

    return DiskInfo(
      totalBytes: totalKb * 1024,
      usedBytes: usedKb * 1024,
      freeBytes: freeKb * 1024,
      volumeName: fileSystem,
      mountPoint: mountPoint,
    );
  }
}
