import 'dart:math';

class FileSizeFormatter {
  /// Formats bytes into a human-readable string.
  static String format(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    final i = (log(bytes) / log(1024)).floor();
    final num = bytes / pow(1024, i);

    // For single bytes or small files, show integer. For larger files, show 1 decimal place.
    if (i == 0) {
      return '${bytes.toString()} B';
    }
    return '${num.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
