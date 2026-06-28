import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/presentation/widgets/macos_window_shell.dart';
import 'providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MacosWindowShell(
      currentRoute: '/settings',
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configurações',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Personalize o comportamento do MacSweep.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 32),

            Expanded(
              child: ListView(
                children: [
                  // Section: Automação
                  _SectionHeader('Automação'),
                  _SettingsCard(
                    children: [
                      _ToggleTile(
                        title: 'Iniciar com o Sistema',
                        subtitle:
                            'Abrir MacSweep automaticamente ao fazer login no macOS.',
                        value: settings.launchOnStartup,
                        onChanged: (val) => ref
                            .read(settingsProvider.notifier)
                            .toggleLaunchOnStartup(val),
                      ),
                      const Divider(height: 1),
                      _ToggleTile(
                        title: 'Varredura Automática Semanal',
                        subtitle:
                            'Executar uma varredura completa toda semana em segundo plano.',
                        value: settings.weeklyAutoScan,
                        onChanged: (val) => ref
                            .read(settingsProvider.notifier)
                            .toggleWeeklyAutoScan(val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section: Limites de Detecção
                  _SectionHeader('Limites de Detecção'),
                  _SettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tamanho mínimo para Arquivos Grandes',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Arquivos acima de ${(settings.largeFileMinSizeBytes / (1024 * 1024)).round()} MB serão listados.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Slider(
                              value:
                                  settings.largeFileMinSizeBytes /
                                  (1024 * 1024),
                              min: 100,
                              max: 2048,
                              divisions: 39,
                              activeColor: Theme.of(context).primaryColor,
                              inactiveColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              label:
                                  '${(settings.largeFileMinSizeBytes / (1024 * 1024)).round()} MB',
                              onChanged: (val) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateLargeFileMinSizeBytes(
                                      (val * 1024 * 1024).round(),
                                    );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Antiguidade mínima de Arquivos Temporários',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Arquivos não modificados há mais de ${settings.tempFileMinAgeHours} horas serão incluídos.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Slider(
                              value: settings.tempFileMinAgeHours.toDouble(),
                              min: 12,
                              max: 168,
                              divisions: 13,
                              activeColor: Theme.of(context).primaryColor,
                              inactiveColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              label: '${settings.tempFileMinAgeHours}h',
                              onChanged: (val) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateTempFileMinAgeHours(val.round());
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section: Caminhos Excluídos (Whitelist)
                  _SectionHeader('Caminhos Excluídos da Varredura'),
                  _SettingsCard(
                    children: [
                      if (settings.whitelistedPaths.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Nenhum caminho excluído configurado.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        )
                      else
                        ...settings.whitelistedPaths.map((path) {
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.folder_off_outlined,
                              size: 16,
                              color: Colors.white38,
                            ),
                            title: Text(
                              path,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white24,
                              ),
                              onPressed: () {
                                ref
                                    .read(settingsProvider.notifier)
                                    .removeWhitelistedPath(path);
                              },
                            ),
                          );
                        }),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text(
                            'Adicionar Caminho Excluído',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () =>
                              _showAddWhitelistDialog(context, ref),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddWhitelistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          title: const Text(
            'Adicionar Caminho Excluído',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: '/Users/Você/PastaImportante',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 12,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final path = controller.text.trim();
                if (path.isNotEmpty) {
                  ref.read(settingsProvider.notifier).addWhitelistedPath(path);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.3),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF242428).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            activeThumbColor: Theme.of(context).primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
