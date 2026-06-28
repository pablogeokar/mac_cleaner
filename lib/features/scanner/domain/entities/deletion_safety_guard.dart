import 'dart:io';
import '../../../../core/constants/scan_paths.dart';

class DeletionSafetyGuard {
  /// Returns true if a path is safe to delete.
  static bool isSafeToDelete(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return false;

    // Expand home directories (~/)
    final expanded = ScanPaths.expandPath(trimmed);
    final normalized = Uri.parse(expanded).path;

    // Never delete root
    if (normalized == '/' || normalized == '') return false;

    // Check against standard blacklist
    if (isPathInBlacklist(trimmed)) return false;

    // Check if it's exactly the Home directory
    final home = Platform.environment['HOME'] ?? '';
    if (normalized == home) return false;

    // Double check it's not a root subfolder directly
    if (normalized == '/System' ||
        normalized == '/Library' ||
        normalized == '/usr' ||
        normalized == '/bin' ||
        normalized == '/sbin' ||
        normalized == '/Applications' ||
        normalized == '/Volumes' ||
        normalized == '$home/Library' ||
        normalized == '$home/Documents' ||
        normalized == '$home/Desktop' ||
        normalized == '$home/Pictures' ||
        normalized == '$home/Music' ||
        normalized == '$home/Movies') {
      return false;
    }

    return true;
  }

  /// Checks if the path belongs to the blacklisted items defined in ScanPaths.
  static bool isPathInBlacklist(String path) {
    return ScanPaths.isBlacklisted(path);
  }
}
