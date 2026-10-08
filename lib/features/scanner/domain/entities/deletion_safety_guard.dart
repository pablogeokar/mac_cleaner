import 'dart:io';

import 'package:path/path.dart' as p;

class DeletionSafetyAssessment {
  final bool isAllowed;
  final String normalizedPath;
  final String reason;

  const DeletionSafetyAssessment({
    required this.isAllowed,
    required this.normalizedPath,
    required this.reason,
  });
}

/// Final, fail-closed validation used immediately before any filesystem write.
///
/// A path is deletable only when it is a strict descendant of a known cleanup
/// location. Merely being outside the macOS blocklist is intentionally not
/// enough.
class DeletionSafetyGuard {
  static const _systemRoots = <String>[
    '/System',
    '/Applications',
    '/Library',
    '/bin',
    '/sbin',
    '/usr',
    '/dev',
    '/etc',
    '/opt',
    '/Volumes',
    '/private/etc',
    '/private/var/db',
    '/private/var/root',
    '/private/var/run',
    '/private/var/vm',
    '/private/var/protected',
  ];

  static DeletionSafetyAssessment assess(
    String path, {
    List<String> excludedPaths = const [],
    String? homeDirectory,
  }) {
    final home = p.normalize(
      homeDirectory ?? Platform.environment['HOME'] ?? '',
    );
    final trimmed = path.trim();

    if (trimmed.isEmpty || trimmed.contains('\u0000')) {
      return const DeletionSafetyAssessment(
        isAllowed: false,
        normalizedPath: '',
        reason: 'Caminho vazio ou inválido.',
      );
    }

    final expanded = _expandHome(trimmed, home);
    if (!p.isAbsolute(expanded)) {
      return DeletionSafetyAssessment(
        isAllowed: false,
        normalizedPath: expanded,
        reason: 'Apenas caminhos absolutos podem ser removidos.',
      );
    }

    final normalized = p.normalize(expanded);
    if (normalized == p.separator || home.isEmpty || _same(normalized, home)) {
      return DeletionSafetyAssessment(
        isAllowed: false,
        normalizedPath: normalized,
        reason: 'Pasta raiz protegida.',
      );
    }

    for (final root in _systemRoots) {
      if (_sameOrWithin(root, normalized)) {
        return DeletionSafetyAssessment(
          isAllowed: false,
          normalizedPath: normalized,
          reason: 'Local protegido do macOS.',
        );
      }
    }

    for (final excluded in excludedPaths) {
      final normalizedExcluded = p.normalize(
        _expandHome(excluded.trim(), home),
      );
      if (p.isAbsolute(normalizedExcluded) &&
          _sameOrWithin(normalizedExcluded, normalized)) {
        return DeletionSafetyAssessment(
          isAllowed: false,
          normalizedPath: normalized,
          reason: 'Ignorado pelas configurações do usuário.',
        );
      }
    }

    final allowedRoots = <String>[
      p.join(home, 'Library', 'Caches'),
      p.join(home, 'Library', 'Logs'),
      p.join(home, 'Library', 'Application Support'),
      p.join(home, 'Library', 'Preferences'),
      p.join(home, 'Library', 'LaunchAgents'),
      p.join(home, 'Library', 'Containers'),
      p.join(home, 'Library', 'Fonts'),
      p.join(home, 'Library', 'Developer', 'Xcode', 'DerivedData'),
      p.join(home, 'Library', 'Developer', 'CoreSimulator', 'Caches'),
      p.join(home, '.Trash'),
      p.join(home, '.npm', '_cacache'),
      p.join(home, '.gradle', 'caches'),
      p.join(home, '.m2', 'repository'),
      p.join(home, 'Downloads'),
      p.join(home, 'Desktop'),
      p.join(home, 'Documents'),
      '/private/tmp',
      '/private/var/tmp',
    ].map(p.normalize).toList(growable: false);

    final isInApprovedLocation = allowedRoots.any(
      (root) => _isStrictlyWithin(root, normalized),
    );
    if (!isInApprovedLocation) {
      return DeletionSafetyAssessment(
        isAllowed: false,
        normalizedPath: normalized,
        reason: 'Fora das áreas aprovadas para limpeza.',
      );
    }

    return DeletionSafetyAssessment(
      isAllowed: true,
      normalizedPath: normalized,
      reason: 'Caminho validado em uma área de limpeza aprovada.',
    );
  }

  static bool isSafeToDelete(
    String path, {
    List<String> excludedPaths = const [],
    String? homeDirectory,
  }) {
    return assess(
      path,
      excludedPaths: excludedPaths,
      homeDirectory: homeDirectory,
    ).isAllowed;
  }

  static bool isPathInBlacklist(String path, {String? homeDirectory}) {
    final assessment = assess(path, homeDirectory: homeDirectory);
    return !assessment.isAllowed;
  }

  static String _expandHome(String value, String home) {
    if (value == '~') return home;
    if (value.startsWith('~/')) return p.join(home, value.substring(2));
    return value;
  }

  static bool _same(String first, String second) =>
      p.normalize(first).toLowerCase() == p.normalize(second).toLowerCase();

  static bool _sameOrWithin(String root, String candidate) =>
      _same(root, candidate) || _isStrictlyWithin(root, candidate);

  static bool _isStrictlyWithin(String root, String candidate) {
    final normalizedRoot = p.normalize(root).toLowerCase();
    final normalizedCandidate = p.normalize(candidate).toLowerCase();
    return p.isWithin(normalizedRoot, normalizedCandidate);
  }
}
