import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/fiscal_service.dart';
import '../data/ocr_service.dart';
import '../data/receipt_parser.dart';
import '../domain/models.dart';
import 'app_view_model.dart';
import 'dialogs.dart';
import 'receipt_review_screen.dart';
import 'widgets.dart';

/// Integra scanner nativo, seletor de fotos e navegação para conferência.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.model, this.listId});
  final AppViewModel model;
  final String? listId;
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _service = FiscalService();
  bool _busy = false;
  String? _error;
  String? _lastUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    _service.dispose();
    super.dispose();
  }

  /// Libera a câmera quando o app perde foco; retoma somente se a tela estiver livre.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // O diálogo inicial de permissão também muda o ciclo de vida antes de a câmera estar pronta.
    if (!_scanner.value.hasCameraPermission) return;
    if (state == AppLifecycleState.inactive) _scanner.stop();
    if (state == AppLifecycleState.resumed && !_busy && _error == null) {
      _scanner.start();
    }
  }

  Future<void> _review(ReceiptDraft draft) async {
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptReviewScreen(
          model: widget.model,
          draft: draft,
          listId: widget.listId,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  /// Um único processamento ativo impede várias consultas do mesmo QR por frame.
  Future<void> _consult(String value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _lastUrl = value;
    });
    await _scanner.stop();
    try {
      await _review(
        await _service.consult(value, backendUrl: widget.model.backendUrl),
      );
    } on FiscalFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível consultar esta nota. Experimente importar uma foto.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Fotos ficam no dispositivo; OCR lê texto mesmo se a consulta fiscal estiver fora do ar.
  Future<void> _photo(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      // Uma nova imagem não pode herdar a chave fiscal de uma nota anterior.
      _lastUrl = null;
    });
    await _scanner.stop();
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 95,
      );
      if (image == null) return;
      // Ao importar foto, tenta recuperar sua chave fiscal sem exigir consulta on-line.
      try {
        final decoded = await _scanner.analyzeImage(
          image.path,
          formats: const [BarcodeFormat.qrCode],
        );
        final value = decoded?.barcodes.firstOrNull?.rawValue;
        if (value != null) {
          ReceiptParser.validateUrl(value);
          _lastUrl = value;
        }
      } catch (_) {
        /* Foto sem QR legível continua no fluxo de reconhecimento de texto. */
      }
      final receipt = await OcrService().readPhoto(
        image.path,
        sourceUrl: _lastUrl,
      );
      await _review(receipt);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível ler a foto. Confira a permissão e fotografe a nota inteira, bem iluminada e sem inclinação.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        // Cancelar o seletor não deve deixar a câmera pausada nesta tela.
        if (_lastUrl == null && _error == null) {
          try {
            await _scanner.start();
          } catch (_) {
            /* O aviso de permissão permanece no preview. */
          }
        }
      }
    }
  }

  /// Entrada alternativa para QR copiado de outro aplicativo, sem reconstruir seu hash.
  Future<void> _pasteUrl() async {
    final value = await askName(
      context,
      title: 'Colar endereço do QR code',
      label: 'Endereço HTTPS da nota',
      maxLength: 4096,
    );
    if (value != null) await _consult(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Importar nota'),
      actions: [
        IconButton(
          tooltip: 'Lanterna',
          onPressed: _busy ? null : _scanner.toggleTorch,
          icon: const Icon(Icons.flashlight_on_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      children: [
        const SectionHeader(
          'Sua nota vira histórico',
          subtitle: 'Leia o QR code ou reconheça os produtos por foto.',
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 265,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: (capture) {
                    final value = capture.barcodes.firstOrNull?.rawValue;
                    if (value != null && !_busy && _error == null) {
                      _consult(value);
                    }
                  },
                  errorBuilder: (context, error) => const ColoredBox(
                    color: Color(0xFF263A2F),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Permita o uso da câmera para escanear. Você também pode importar uma foto da galeria.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF70E3A2),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                if (_busy)
                  const ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Centralize o QR code da nota no quadrado.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: NoteBox(_error!, warning: true),
          ),
        FilledButton.icon(
          onPressed: _busy ? null : () => _photo(ImageSource.camera),
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Fotografar e ler produtos'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _photo(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Importar foto da galeria'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _busy ? null : _pasteUrl,
          icon: const Icon(Icons.link),
          label: const Text('Colar endereço do QR code'),
        ),
        if (_lastUrl != null)
          TextButton(
            onPressed: () async {
              try {
                final uri = ReceiptParser.validateUrl(_lastUrl!);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                if (context.mounted) {
                  showMessage(context, 'Endereço fiscal não suportado.');
                }
              }
            },
            child: const Text('Abrir consulta oficial no navegador'),
          ),
        if (!_busy && (_error != null || _lastUrl != null))
          TextButton(
            onPressed: () {
              setState(() {
                _error = null;
                _lastUrl = null;
              });
              _scanner.start();
            },
            child: const Text('Ler outro QR code'),
          ),
        const SizedBox(height: 8),
        const NoteBox(
          'Os dados ficam no celular. A foto é processada localmente e os itens passam por conferência antes de salvar.',
          icon: Icons.phonelink_lock_outlined,
        ),
      ],
    ),
  );
}
