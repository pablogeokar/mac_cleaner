# PROMPT: Flutter macOS — App de Limpeza de Arquivos (Mac Cleaner)

## CONTEXTO GERAL

Você é um engenheiro Flutter sênior especializado em desenvolvimento para macOS desktop. Sua tarefa é implementar do zero um aplicativo completo chamado **MacSweep** — um app de limpeza de armazenamento para macOS, similar ao CleanMyMac, mas open source e construído em Flutter.

O app deve ser **funcional, seguro e eficiente**, utilizando as APIs nativas do macOS via `MethodChannel` ou `Process` do Dart para executar varreduras reais no sistema de arquivos.

---

## STACK TECNOLÓGICA OBRIGATÓRIA

- **Flutter** 3.22+ (canal stable)
- **Dart** 3.4+
- **Alvo**: macOS 12 Monterey ou superior
- **Arquitetura**: Clean Architecture com separação em `data`, `domain` e `presentation`
- **Gerência de estado**: Riverpod 2.x (com `@riverpod` code generation)
- **Roteamento**: GoRouter
- **UI**: Material 3 + componentes customizados com visual macOS-like (bordas arredondadas, blur, sidebar)
- **Permissões macOS**: `macos/Runner/Info.plist` e `macos/Runner/*.entitlements` devem ser configurados corretamente
- **Testes**: `flutter_test` para unit tests dos use cases

---

## ESTRUTURA DE DIRETÓRIOS ESPERADA

```
lib/
├── main.dart
├── app/
│   ├── app.dart                  # MaterialApp / configuração global
│   ├── router.dart               # GoRouter com todas as rotas
│   └── theme.dart                # ThemeData personalizado
├── core/
│   ├── constants/
│   │   └── scan_paths.dart       # Todos os paths de varredura (ver seção abaixo)
│   ├── utils/
│   │   ├── file_size_formatter.dart
│   │   └── shell_runner.dart     # Wrapper para Process.run / dart:io
│   └── errors/
│       └── scan_exception.dart
├── features/
│   ├── dashboard/
│   │   ├── data/
│   │   │   └── disk_info_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/disk_info.dart
│   │   │   └── use_cases/get_disk_info.dart
│   │   └── presentation/
│   │       ├── dashboard_screen.dart
│   │       └── widgets/
│   │           ├── storage_gauge_widget.dart
│   │           └── quick_stats_card.dart
│   ├── scanner/
│   │   ├── data/
│   │   │   ├── models/scan_item_model.dart
│   │   │   └── repositories/file_scanner_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/scan_item.dart
│   │   │   ├── entities/scan_category.dart
│   │   │   └── use_cases/
│   │   │       ├── scan_system_use_case.dart
│   │   │       └── delete_items_use_case.dart
│   │   └── presentation/
│   │       ├── scanner_screen.dart
│   │       └── widgets/
│   │           ├── scan_category_tile.dart
│   │           ├── scan_progress_bar.dart
│   │           └── file_list_view.dart
│   ├── results/
│   │   └── presentation/
│   │       ├── results_screen.dart
│   │       └── widgets/
│   │           ├── cleanup_summary_card.dart
│   │           └── file_item_row.dart
│   └── settings/
│       └── presentation/
│           └── settings_screen.dart
macos/
├── Runner/
│   ├── Info.plist
│   ├── DebugProfile.entitlements
│   └── Release.entitlements
└── ...
```

---

## CATEGORIAS DE LIMPEZA A IMPLEMENTAR

Implemente **obrigatoriamente** todas as categorias abaixo. Cada uma é uma `ScanCategory` com seu próprio conjunto de paths e lógica.

### 1. Cache do Sistema
```
~/Library/Caches/
/Library/Caches/
/private/var/folders/**/C/         # Cache temporário do sistema (NSTemporaryDirectory)
```
- Incluir subpastas recursivamente
- Excluir: `~/Library/Caches/com.apple.Safari` (tem tratamento especial)
- Limite seguro: deletar apenas arquivos com mais de 7 dias (verificar `lastAccessedDate`)

### 2. Logs do Sistema e Apps
```
~/Library/Logs/
/Library/Logs/
/private/var/log/
~/Library/Application Support/*/Logs/
/var/log/asl/
```
- Filtrar apenas extensões: `.log`, `.crash`, `.ips`, `.diag`
- Preservar logs com menos de 24h (podem estar em uso)
- Exibir tamanho agregado por app

### 3. Arquivos Temporários
```
/private/tmp/
/private/var/tmp/
~/Downloads/*.tmp
~/Downloads/*.part
~/Downloads/*.crdownload
~/Downloads/*.download
```
- Deletar com segurança apenas arquivos com `modifiedDate` > 48h

### 4. Lixeira
```
~/.Trash/
/Volumes/*/.Trashes/
```
- Listar todos os itens com nome, tamanho e data de exclusão
- Operação: esvaziar lixeira via `NSWorkspace` ou equivalente shell

### 5. Cache de Aplicativos Específicos
Implemente detecção automática para:

| App | Paths |
|-----|-------|
| Xcode | `~/Library/Developer/Xcode/DerivedData/`, `~/Library/Caches/com.apple.dt.Xcode`, `~/Library/Developer/CoreSimulator/Caches/` |
| Homebrew | `$(brew --cache)` (executar via shell), `/usr/local/Homebrew/` |
| npm | `~/.npm/_cacache/` |
| yarn | `~/Library/Caches/Yarn/` |
| pip | `~/Library/Caches/pip/` |
| Gradle | `~/.gradle/caches/` |
| Maven | `~/.m2/repository/` |
| Docker | `~/Library/Containers/com.docker.docker/Data/` (somente volumes não usados) |
| CocoaPods | `~/Library/Caches/CocoaPods/` |
| Carthage | `~/Carthage/` (builds, não Checkouts) |
| Simulator iOS | `~/Library/Developer/CoreSimulator/Devices/` (dispositivos não utilizados) |
| Android Studio | `~/.android/avd/`, `~/Library/Application Support/Google/AndroidStudio*` |

### 6. Downloads Duplicados e Grandes
```
~/Downloads/
~/Desktop/
~/Documents/
```
- Detectar duplicatas por hash MD5 (usar isolates para não travar a UI)
- Detectar arquivos > 500MB e listar com confirmação
- NÃO deletar automaticamente — apenas sugerir

### 7. Arquivos Residuais de Apps Desinstalados
```
~/Library/Application Support/
~/Library/Preferences/
~/Library/LaunchAgents/
/Library/LaunchAgents/
/Library/LaunchDaemons/
~/Library/Containers/
```
- Cruzar com apps instalados (ler `/Applications/` e `/usr/local/Caskroom/`)
- Marcar como "órfãos" os itens cujo bundle ID não corresponde a app instalado
- Exibir separadamente — requer confirmação do usuário antes de deletar

### 8. Fontes Duplicadas
```
~/Library/Fonts/
/Library/Fonts/
/System/Library/Fonts/       # READ-ONLY — apenas listar, nunca deletar
```
- Detectar fontes com mesmo PostScript Name instaladas em múltiplos locais
- Sugerir remoção da cópia de menor precedência

---

## ENTIDADES E MODELOS DE DOMÍNIO

```dart
// lib/features/scanner/domain/entities/scan_category.dart
enum ScanCategoryType {
  systemCache,
  systemLogs,
  temporaryFiles,
  trash,
  appCache,
  largeFiles,
  duplicates,
  appResiduals,
  duplicateFonts,
}

class ScanCategory {
  final ScanCategoryType type;
  final String displayName;
  final String description;
  final IconData icon;
  final List<String> targetPaths;
  final int fileCount;
  final int totalBytes;
  final bool isScanning;
  final bool isSelected;
  final List<ScanItem> items;
}

// lib/features/scanner/domain/entities/scan_item.dart
class ScanItem {
  final String path;
  final String fileName;
  final int sizeBytes;
  final DateTime lastModified;
  final DateTime lastAccessed;
  final ScanItemType type; // file, directory, symlink
  final bool isSafeToDelete;  // calculado com base em regras
  final String? reason;       // ex: "Não modificado há 30 dias"
  final bool isSelected;
}

// lib/features/dashboard/domain/entities/disk_info.dart
class DiskInfo {
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final String volumeName;
  final String mountPoint;
}
```

---

## LÓGICA DE VARREDURA (CRÍTICA)

### ShellRunner — Executor de Comandos

```dart
// lib/core/utils/shell_runner.dart
class ShellRunner {
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 30),
  });

  // Varredura de tamanho de diretório (du -sk)
  static Future<int> getDirectorySizeBytes(String path);

  // Listar arquivos recursivamente com metadata
  static Stream<ScanItem> listFilesRecursive(
    String path, {
    List<String>? extensions,
    DateTime? olderThan,
    int? maxDepth,
  });

  // Verificar se path existe e é acessível
  static Future<bool> isAccessible(String path);
}
```

### Algoritmo de Varredura por Categoria

A varredura deve funcionar como um `Stream<ScanProgress>` para permitir atualização em tempo real da UI:

```dart
class ScanProgress {
  final ScanCategoryType category;
  final double progress;         // 0.0 a 1.0
  final String currentPath;
  final int itemsFound;
  final int bytesFound;
  final bool isComplete;
}
```

Implemente a varredura com:
1. `compute()` ou `Isolate.run()` para operações pesadas de I/O
2. Microtasks agendados para não bloquear o event loop
3. Cancellation token via `CancelToken` para permitir que o usuário cancele

---

## OPERAÇÃO DE DELEÇÃO (SEGURANÇA CRÍTICA)

### Regras de Segurança Absolutas

```dart
class DeletionSafetyGuard {
  // NUNCA deletar estes paths, mesmo que solicitado
  static const List<String> _blacklist = [
    '/System/',
    '/Library/',      // raiz — somente subpaths específicos são permitidos
    '/usr/',
    '/bin/',
    '/sbin/',
    '/Applications/',
    '/Volumes/',      // diretamente — apenas .Trashes
    '~/',             // home diretamente
    '~/Library/',     // home Library diretamente
    '~/Documents/',
    '~/Desktop/',
    '~/Pictures/',
    '~/Music/',
    '~/Movies/',
  ];

  static bool isSafeToDelete(String path);
  static bool isPathInBlacklist(String path);
}
```

### Fluxo de Deleção

1. Usuário seleciona itens na tela de resultados
2. App exibe **modal de confirmação** com:
   - Total de itens
   - Total em bytes (formatado)
   - Aviso de que a operação é irreversível
   - Checkbox "Mover para Lixeira" (padrão: ativo) vs "Deletar permanentemente"
3. Por padrão, mover para lixeira via `NSWorkspace.shared.recycle()` (expor via `MethodChannel`)
4. Deletar permanentemente apenas quando explicitamente solicitado + dupla confirmação
5. Após deleção, exibir relatório: `X itens deletados, Y bytes liberados`

---

## INTERFACE DO USUÁRIO

### Layout Geral — Sidebar + Content

Implemente um layout macOS-like com:
- **Sidebar** (240px) à esquerda com a navegação por categoria
- **Content area** à direita com o conteúdo principal
- **Barra de título** customizada (sem decoração padrão do sistema)

```dart
// Configuração de janela em main.dart
WindowOptions windowOptions = const WindowOptions(
  size: Size(1100, 700),
  minimumSize: Size(900, 600),
  center: true,
  backgroundColor: Colors.transparent,
  skipTaskbar: false,
  titleBarStyle: TitleBarStyle.hidden,
);
// Usar package: window_manager
```

### Telas

#### 1. Dashboard (`/`)
- Gauge circular mostrando uso do disco (ex: 68% cheio)
- Cards para cada categoria com: ícone, nome, status (`Não verificado` / `X MB encontrados`)
- Botão principal: **"Iniciar Varredura Completa"**
- Botão secundário: **"Varredura Rápida"** (apenas cache e logs)
- Barra de armazenamento horizontal mostrando breakdown por tipo de arquivo

#### 2. Scanner em Progresso (`/scanning`)
- Lista das categorias com progress indicators individuais
- Log em tempo real das pastas sendo varridas (texto pequeno, cinza)
- Botão "Cancelar"
- Estimativa de tempo restante
- Animação de "varredura" no ícone do app (via `AppKitIconWidget` ou similar)

#### 3. Resultados (`/results`)
- Total encontrado em destaque (ex: **"4,2 GB encontrados"**)
- Lista de categorias com toggle para expandir itens
- Cada item: ícone de tipo, nome, path truncado, tamanho, checkbox de seleção
- Ações por categoria: "Selecionar tudo" / "Desselecionar"
- Rodapé fixo: total selecionado + botão **"Limpar Selecionados"**
- Filtro por: tamanho (crescente/decrescente), data, nome

#### 4. Relatório pós-limpeza (`/report`)
- Animação de sucesso (lottie ou Flutter animation)
- Cards: "X itens removidos", "Y GB liberados", "Espaço atual livre"
- Histórico das limpezas (persistir em `shared_preferences` ou SQLite)
- Botão "Nova Varredura"

#### 5. Configurações (`/settings`)
- Toggle: Iniciar com o sistema (LaunchAgent plist)
- Toggle: Varredura automática semanal
- Configurar paths excluídos pelo usuário (whitelist pessoal)
- Slider: tamanho mínimo de arquivo para "arquivos grandes" (padrão: 500MB)
- Slider: antiguidade mínima para arquivos temporários (padrão: 7 dias)
- Botão: "Exportar relatório como CSV"

---

## PERMISSÕES E ENTITLEMENTS macOS

### `macos/Runner/DebugProfile.entitlements` e `Release.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Necessário para ler/deletar arquivos fora do sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <false/>

    <!-- Se precisar rodar com sandbox (distribuição App Store), use: -->
    <!-- <key>com.apple.security.app-sandbox</key><true/> -->
    <!-- <key>com.apple.security.files.user-selected.read-write</key><true/> -->
    <!-- <key>com.apple.security.temporary-exception.files.absolute-path.read-write</key> -->

    <key>com.apple.security.files.all</key>
    <true/>

    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
```

> **AVISO**: Para distribuição fora da Mac App Store (direct distribution), `app-sandbox: false` é aceitável. Para Mac App Store, o app precisará de uma abordagem diferente com entitlements específicos e autorização via Security-scoped bookmarks.

### `Info.plist` — Descrição de uso
```xml
<key>NSDocumentsFolderUsageDescription</key>
<string>MacSweep precisa acessar sua pasta de Documentos para detectar arquivos duplicados.</string>
<key>NSDownloadsFolderUsageDescription</key>
<string>MacSweep precisa acessar Downloads para detectar arquivos temporários e incompletos.</string>
<key>NSDesktopFolderUsageDescription</key>
<string>MacSweep precisa acessar a Área de Trabalho para verificar arquivos grandes.</string>
```

---

## DEPENDÊNCIAS (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Estado
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  
  # Roteamento
  go_router: ^14.0.0
  
  # UI / macOS
  window_manager: ^0.3.9       # Controle da janela nativa
  macos_ui: ^2.0.0             # Componentes visuais macOS (opcional, use com critério)
  
  # Utilitários
  path: ^1.9.0
  path_provider: ^2.1.3
  shared_preferences: ^2.2.3
  intl: ^0.19.0
  
  # Gráficos
  fl_chart: ^0.68.0           # Para os gauges e barras de armazenamento
  
  # Animações
  lottie: ^3.1.0              # Para animação de sucesso
  
  # Sistema de arquivos
  watcher: ^1.1.0             # Monitorar mudanças em tempo real (opcional)
  crypto: ^3.0.3              # MD5 para detecção de duplicatas

dev_dependencies:
  build_runner: ^2.4.11
  riverpod_generator: ^2.4.0
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.3
```

---

## TESTES OBRIGATÓRIOS

Implemente testes unitários para:

```dart
// test/features/scanner/domain/use_cases/scan_system_use_case_test.dart
void main() {
  group('ScanSystemUseCase', () {
    test('deve retornar lista vazia quando diretório não existe', () async { ... });
    test('deve respeitar filtro de antiguidade de arquivo', () async { ... });
    test('deve ignorar paths na blacklist', () async { ... });
    test('deve calcular tamanho total corretamente', () async { ... });
  });
}

// test/core/utils/deletion_safety_guard_test.dart
void main() {
  group('DeletionSafetyGuard', () {
    test('deve bloquear deleção de /System/', () { ... });
    test('deve permitir deleção de ~/Library/Caches/', () { ... });
    test('deve bloquear deleção do home diretamente', () { ... });
  });
}
```

---

## OBSERVAÇÕES DE IMPLEMENTAÇÃO CRÍTICAS

1. **Nunca use `dart:io` diretamente na camada de apresentação**. Toda operação de I/O deve passar pelos repositórios.

2. **Isolates são obrigatórios** para varreduras recursivas. Use `Isolate.run()` para cálculos de hash MD5 e listagem de diretórios grandes. Não bloqueie a UI thread.

3. **Tratar erros de permissão**: Ao acessar paths do sistema, `FileSystemException` com `errno 13 (EACCES)` é esperado. Capture e registre sem crashar o app.

4. **Path expansion**: Implemente um helper `expandPath(String path)` que converte `~` para o home directory real via `Platform.environment['HOME']`.

5. **Progresso real**: A barra de progresso deve refletir progresso real (número de arquivos processados / estimativa total), não um timer fictício.

6. **Cancelamento**: Toda operação longa deve checar um `CancellationToken` e interromper limpa e graciosamente.

7. **Logging interno**: Use `debugPrint` com prefixos por módulo. Em produção, persistir em arquivo local para diagnóstico.

8. **Atualização de informações de disco**: Após cada limpeza, re-consultar `df -k /` para atualizar o gauge de disco.

9. **Detectar Xcode DerivedData com segurança**: Verificar se o Xcode está em uso antes de sugerir limpeza. Usar `lsof` para verificar se arquivos estão abertos.

10. **Homebrew**: Executar `brew --cache` via shell para obter o path real, não hardcodar.

---

## ENTREGÁVEIS ESPERADOS

Ao final da implementação, o repositório deve conter:

- [ ] Projeto Flutter completo e compilável para macOS
- [ ] Todas as 8 categorias de limpeza funcionando
- [ ] UI completa com todas as 5 telas
- [ ] Testes unitários com cobertura > 70% nos use cases
- [ ] `README.md` com instruções de build e requisitos de sistema
- [ ] Entitlements configurados corretamente para distribuição direta (não App Store)
- [ ] Nenhum crash ao varrer paths protegidos pelo sistema
- [ ] Operação de deleção com confirmação e fallback para lixeira

---

## EXEMPLO DE FLUXO COMPLETO (USER JOURNEY)

```
1. Usuário abre o app
   → Dashboard exibe uso atual do disco (ex: 234 GB / 500 GB — 47%)
   → Status de cada categoria: "Não verificado"

2. Usuário clica "Iniciar Varredura Completa"
   → Navega para /scanning
   → Cada categoria é varrida em paralelo (com concorrência limitada a 3)
   → Progress bar por categoria + log em tempo real

3. Varredura concluída (ex: 3min 42s)
   → Navega para /results
   → Total: 8,4 GB encontrados
   → Lista expandida por categoria:
      - Cache do Sistema: 2,1 GB (1.847 arquivos)
      - Xcode DerivedData: 4,2 GB (23.450 arquivos)
      - Logs do Sistema: 890 MB (234 arquivos)
      - ...

4. Usuário desmarca "Xcode DerivedData" (tem projeto em andamento)
   → Total selecionado atualiza: 4,2 GB

5. Usuário clica "Limpar Selecionados"
   → Modal de confirmação: "Mover 4,2 GB (1.891 arquivos) para a Lixeira?"
   → Usuário confirma

6. Deleção executada com progress bar
   → Navega para /report
   → "4,2 GB liberados! Seu Mac agradece 🎉"
   → Disco agora: 238 GB livre
```

---

*Prompt gerado para implementação por IA. Versão 1.0 — MacSweep Flutter macOS Cleaner.*
