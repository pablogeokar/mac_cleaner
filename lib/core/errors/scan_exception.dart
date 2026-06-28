class ScanException implements Exception {
  final String message;
  final dynamic details;

  ScanException(this.message, [this.details]);

  @override
  String toString() =>
      'ScanException: $message${details != null ? ' ($details)' : ''}';
}
