import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_view_model.dart';
import 'dialogs.dart';
import 'widgets.dart';

/// Preferências e portabilidade dos dados; não exige conta nem serviço em nuvem.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.model});
  final AppViewModel model;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  /// Cria JSON temporário e abre o compartilhamento nativo para salvar onde o usuário escolher.
  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final content = await widget.model.repository.exportBackup();
      final directory = await getTemporaryDirectory();
      final file = File(
        paths.join(
          directory.path,
          'carrinho-backup-${DateTime.now().millisecondsSinceEpoch}.json',
        ),
      );
      await file.writeAsString(content, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Backup do Carrinho de Compras',
        ),
      );
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Não foi possível exportar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A substituição é confirmada pelo usuário e o repositório garante rollback em caso de falha.
  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;
      final size = await file.length();
      if (size == null || size > 5 * 1024 * 1024) {
        throw const FormatException('O backup precisa ter até 5 MB.');
      }
      final content = utf8.decode(await file.readAsBytes());
      if (!mounted ||
          !await confirmAction(
            context,
            'Restaurar backup?',
            'Todas as listas e compras atuais serão substituídas pelo arquivo escolhido. Exporte um backup antes se quiser preservá-las.',
            action: 'Restaurar',
          ) ||
          !mounted) {
        return;
      }
      await widget.model.change(
        () => widget.model.repository.restoreBackup(content),
      );
      if (mounted) showMessage(context, 'Backup restaurado.');
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Backup inválido ou incompatível. Os dados anteriores foram preservados.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// O modo direto é padrão. HTTP é permitido somente em loopback para teste via adb reverse.
  Future<void> _backend() async {
    final controller = TextEditingController(text: widget.model.backendUrl);
    final form = GlobalKey<FormState>();
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Serviço de consulta'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Deixe vazio para consultar diretamente pelo celular. Para usar a API .NET, informe sua URL.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL do backend (opcional)',
                  hintText: 'https://seu-servidor',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final uri = Uri.tryParse(value.trim());
                  const localHosts = {'127.0.0.1', 'localhost', '10.0.2.2'};
                  if (uri == null ||
                      !uri.hasAuthority ||
                      uri.userInfo.isNotEmpty ||
                      uri.hasQuery ||
                      uri.hasFragment ||
                      (uri.path.isNotEmpty && uri.path != '/') ||
                      !(uri.scheme == 'https' ||
                          (uri.scheme == 'http' &&
                              localHosts.contains(uri.host)))) {
                    return 'Use HTTPS ou HTTP local via adb reverse.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (saved != null) {
      await widget.model.change(
        () => widget.model.repository.setSetting('backend_url', saved),
      );
      if (mounted) {
        showMessage(
          context,
          saved.isEmpty ? 'Consulta direta ativada.' : 'Backend configurado.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
    children: [
      const SectionHeader(
        'Do seu jeito',
        subtitle: 'Seus dados, sob seu controle.',
      ),
      const NoteBox(
        'Listas, compras e preferências são armazenadas no SQLite privado deste celular. Faça backup antes de trocar de aparelho ou desinstalar.',
        icon: Icons.storage_outlined,
      ),
      const SizedBox(height: 24),
      Text('Seus dados', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.ios_share),
              title: const Text('Exportar backup'),
              subtitle: const Text(
                'Salvar ou compartilhar suas listas e compras',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _export,
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('Restaurar backup'),
              subtitle: const Text('Importar um arquivo JSON deste aplicativo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _restore,
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      Text('Consulta de notas', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.dns_outlined),
          title: const Text('Serviço de consulta'),
          subtitle: Text(
            widget.model.backendUrl.isEmpty
                ? 'Direto no celular • sem servidor configurado'
                : widget.model.backendUrl,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _backend,
        ),
      ),
      const SizedBox(height: 20),
      const NoteBox(
        'Consulta fiscal: NFC-e de São Paulo. Portais podem exigir verificação humana ou ficar indisponíveis. A leitura por foto funciona como alternativa local.',
        icon: Icons.receipt_long_outlined,
      ),
      const SizedBox(height: 28),
      const Center(
        child: Text(
          'Carrinho de Compras\nVersão 1.0.0 • Android',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
    ],
  );
}
