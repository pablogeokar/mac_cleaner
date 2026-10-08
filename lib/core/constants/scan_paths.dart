import 'dart:io';

class ScanPaths {
  // 1. System Cache Target Paths
  static const List<String> systemCachePaths = ['~/Library/Caches'];

  // 2. System and App Logs
  static const List<String> systemLogsPaths = ['~/Library/Logs'];
  static const List<String> appSupportLogWildcards = [
    '~/Library/Application Support/*/Logs',
  ];
  static const List<String> logExtensions = ['.log', '.crash', '.ips', '.diag'];

  // 3. Temporary Files
  static const List<String> temporaryPaths = [
    '/private/tmp',
    '/private/var/tmp',
  ];
  static const List<String> tempDownloadExtensions = [
    '.tmp',
    '.part',
    '.crdownload',
    '.download',
  ];

  // 4. Trash
  static const List<String> trashPaths = ['~/.Trash'];

  // 5. Specific App Caches
  static const Map<String, List<String>> appCachePaths = {
    'Xcode': [
      '~/Library/Developer/Xcode/DerivedData',
      '~/Library/Caches/com.apple.dt.Xcode',
      '~/Library/Developer/CoreSimulator/Caches',
    ],
    'npm': ['~/.npm/_cacache'],
    'yarn': ['~/Library/Caches/Yarn'],
    'pip': ['~/Library/Caches/pip'],
    'Gradle': ['~/.gradle/caches'],
    'Maven': ['~/.m2/repository'],
    'CocoaPods': ['~/Library/Caches/CocoaPods'],
  };

  // 6. Large and Duplicate Files (Search roots)
  static const List<String> userRoots = [
    '~/Downloads',
    '~/Desktop',
    '~/Documents',
  ];

  // 7. Residuals (App leftovers to scan when corresponding app in /Applications/ is missing)
  static const List<String> residualSearchPaths = [
    '~/Library/Application Support',
    '~/Library/Preferences',
    '~/Library/LaunchAgents',
    '~/Library/Containers',
  ];

  // 8. Fonts (Duplicate font locations)
  static const List<String> fontPaths = ['~/Library/Fonts', '/Library/Fonts'];
  static const String systemFontPath = '/System/Library/Fonts'; // READ-ONLY

  /// Expands `~` to the user's actual home directory path.
  static String expandPath(String path) {
    if (path.startsWith('~')) {
      final home = Platform.environment['HOME'] ?? '';
      if (path == '~') return home;
      return path.replaceFirst('~', home);
    }
    return path;
  }
}
