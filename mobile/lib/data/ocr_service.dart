import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/models.dart';
import 'receipt_parser.dart';

/// Reconhecimento de texto latino executado no próprio aparelho, sem enviar a foto.
class OcrService {
  /// Reconstrói linhas pela posição para melhorar cupons com colunas separadas.
  Future<ReceiptDraft> readPhoto(String path, {String? sourceUrl}) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      final lines = result.blocks.expand((block) => block.lines).toList()
        ..sort(
          (a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy),
        );
      final groups = <List<TextLine>>[];
      for (final line in lines) {
        // Agrupa caixas na mesma altura; cupons muito inclinados devem ser recapturados.
        if (groups.isEmpty ||
            (groups.last.first.boundingBox.center.dy -
                        line.boundingBox.center.dy)
                    .abs() >
                line.boundingBox.height * .55) {
          groups.add([line]);
        } else {
          groups.last.add(line);
        }
      }
      final reconstructed = groups
          .map((group) {
            group.sort(
              (a, b) => a.boundingBox.left.compareTo(b.boundingBox.left),
            );
            return group.map((line) => line.text).join(' ');
          })
          .join('\n');
      // Seleciona a reconstrução que reconheceu mais linhas de produto.
      final structured = ReceiptParser.fromText(
        reconstructed,
        sourceUrl: sourceUrl,
      );
      final plain = ReceiptParser.fromText(result.text, sourceUrl: sourceUrl);
      return structured.items.length >= plain.items.length ? structured : plain;
    } finally {
      // O modelo nativo precisa ser fechado mesmo quando a imagem é inválida.
      await recognizer.close();
    }
  }
}
