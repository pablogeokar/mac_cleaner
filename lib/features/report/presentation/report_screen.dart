import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/file_size_formatter.dart';
import '../../dashboard/presentation/providers/disk_info_provider.dart';
import '../../dashboard/presentation/widgets/macos_window_shell.dart';
import '../../scanner/presentation/providers/scan_provider.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(scannerNotifierProvider);
    final diskInfoAsync = ref.watch(diskInfoNotifierProvider);

    final cleanedBytesFormatted = FileSizeFormatter.format(
      scanState.totalCleanedBytes,
    );
    final cleanedCount = scanState.totalCleanedFiles;

    return MacosWindowShell(
      currentRoute: '/report',
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success animation or check icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.secondary,
                size: 72,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Limpeza Concluída!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seu Mac agradece. O espaço em disco foi liberado com sucesso.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Summary Stats Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatSummaryCard(
                  title: 'Espaço Liberado',
                  value: cleanedBytesFormatted,
                  icon: Icons.speed,
                  iconColor: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 20),
                _StatSummaryCard(
                  title: 'Arquivos Removidos',
                  value: '$cleanedCount itens',
                  icon: Icons.delete_sweep_outlined,
                  iconColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Current free space indicator card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: diskInfoAsync.when(
                data: (info) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF242428).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.storage,
                            size: 16,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Espaço Livre Atual no Disco',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        FileSizeFormatter.format(info.freeBytes),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 48),

            // Nova Varredura / Return to Dashboard
            ElevatedButton(
              onPressed: () {
                ref.read(scannerNotifierProvider.notifier).resetToDashboard();
                context.go('/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Nova Varredura',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF242428).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
