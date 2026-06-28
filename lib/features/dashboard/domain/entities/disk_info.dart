class DiskInfo {
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final String volumeName;
  final String mountPoint;

  const DiskInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    required this.volumeName,
    required this.mountPoint,
  });

  double get usedPercentage =>
      totalBytes > 0 ? (usedBytes / totalBytes) * 100 : 0.0;
  double get freePercentage =>
      totalBytes > 0 ? (freeBytes / totalBytes) * 100 : 0.0;
}
