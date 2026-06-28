import 'dart:io';

class ScanPaths {
  // 1. System Cache Target Paths
  static const List<String> systemCachePaths = [
    '~/Library/Caches',
    '/Library/Caches',
  ];

  // 2. System and App Logs
  static const List<String> systemLogsPaths = [
    '~/Library/Logs',
    '/Library/Logs',
    '/private/var/log',
    '/var/log/asl',
  ];
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
    'Docker': ['~/Library/Containers/com.docker.docker/Data'],
    'CocoaPods': ['~/Library/Caches/CocoaPods'],
    'Carthage': ['~/Carthage'],
    'Simulator iOS': ['~/Library/Developer/CoreSimulator/Devices'],
    'Android Studio': ['~/.android/avd'],
  };

  // Android Studio logs/caches can match a pattern like AndroidStudio*
  static const String androidStudioAppSupportPattern =
      '~/Library/Application Support/Google';

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
    '/Library/LaunchAgents',
    '/Library/LaunchDaemons',
    '~/Library/Containers',
  ];

  // 8. Fonts (Duplicate font locations)
  static const List<String> fontPaths = ['~/Library/Fonts', '/Library/Fonts'];
  static const String systemFontPath = '/System/Library/Fonts'; // READ-ONLY

  // Blacklist of folders that should NEVER be deleted under any circumstances
  static const List<String> deletionBlacklist = [
    '/System',
    '/System/',
    '/Library',
    '/Library/',
    '/usr',
    '/usr/',
    '/bin',
    '/bin/',
    '/sbin',
    '/sbin/',
    '/Applications',
    '/Applications/',
    '/Volumes',
    '/Volumes/',
    '~',
    '~/',
    '~/Library',
    '~/Library/',
    '~/Documents',
    '~/Documents/',
    '~/Desktop',
    '~/Desktop/',
    '~/Pictures',
    '~/Pictures/',
    '~/Music',
    '~/Music/',
    '~/Movies',
    '~/Movies/',
  ];

  /// Expands `~` to the user's actual home directory path.
  static String expandPath(String path) {
    if (path.startsWith('~')) {
      final home = Platform.environment['HOME'] ?? '';
      if (path == '~') return home;
      return path.replaceFirst('~', home);
    }
    return path;
  }

  /// Checks if a path is in the blacklist.
  static bool isBlacklisted(String path) {
    final expandedPath = Uri.parse(expandPath(path)).path;
    final normalized = expandedPath.endsWith('/')
        ? expandedPath
        : '$expandedPath/';

    for (final blacklisted in deletionBlacklist) {
      final expandedBlacklisted = Uri.parse(expandPath(blacklisted)).path;
      final blacklistedNormalized = expandedBlacklisted.endsWith('/')
          ? expandedBlacklisted
          : '$expandedBlacklisted/';
      if (normalized == blacklistedNormalized) {
        return true;
      }
    }
    return false;
  }
}
