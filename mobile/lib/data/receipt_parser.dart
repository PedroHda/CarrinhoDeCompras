import 'package:html/parser.dart' as html_parser;

import '../core/formatters.dart';
import '../domain/models.dart';

/// Falha esperada de consulta; a interface apresenta alternativas sem perder a lista.
class FiscalFailure implements Exception {
  const FiscalFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Parsers puros e testáveis: nenhuma câmera, rede ou banco é acessado aqui.
class ReceiptParser {
  /// Preserva a chave de 44 dígitos quando ela aparece no QR ou no texto da nota.
  static String? accessKey(String value) {
    // Texto de OCR pode conter acentos e "%" solto; isso não invalida os outros campos.
    var decoded = value;
    if (value.contains('%')) {
      try {
        decoded = Uri.decodeFull(value);
      } catch (_) {
        /* Procura a chave no texto original. */
      }
    }
    return RegExp(r'(?<!\d)\d{44}(?!\d)').firstMatch(decoded)?.group(0);
  }

  /// A primeira versão aceita somente os endereços HTTPS oficiais de NFC-e paulista.
  static Uri validateUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    const hosts = {'www.nfce.fazenda.sp.gov.br', 'nfce.fazenda.sp.gov.br'};
    const paths = {
      '/qrcode',
      '/nfceconsultapublica/paginas/consultaqrcode.aspx',
      '/nfceconsultapublica/paginas/consultapublica.aspx',
    };
    if (uri == null ||
        value.length > 4096 ||
        uri.scheme != 'https' ||
        !hosts.contains(uri.host.toLowerCase()) ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !paths.contains(
          uri.path.toLowerCase().replaceFirst(RegExp(r'/$'), ''),
        )) {
      throw const FiscalFailure(
        'Use o QR code de uma NFC-e de São Paulo. Para outros documentos, importe uma foto.',
      );
    }
    return uri;
  }

  /// Extrai os itens de uma página pública; mudanças de leiaute geram erro explícito.
  static ReceiptDraft fromHtml(String html, String url) {
    if (html.contains('Formato de QR-Code') ||
        html.contains('QR Code inválido')) {
      throw const FiscalFailure(
        'A Sefaz recusou o QR code. Você pode importar uma foto da nota e conferir os itens.',
      );
    }
    final document = html_parser.parse(html);
    final items = <ReceiptLine>[];
    for (final row in document.querySelectorAll(
      '#tabResult tr, table tr[id^="Item"], table tr[id^="item"]',
    )) {
      String text(String selector) =>
          row.querySelector(selector)?.text.trim() ?? '';
      final name = text('.txtTit, .descricao, [data-field="description"]');
      if (name.isEmpty) continue;
      final count = _number(
        text('.Rqtd, .quantidade, [data-field="quantity"]'),
      );
      final price = _number(
        text('.RvlUnit, .valorUnitario, [data-field="unit-price"]'),
      );
      final total = _number(text('.valor, .valorTotal, [data-field="total"]'));
      if (count == null || price == null || total == null) {
        throw const FiscalFailure(
          'O portal mudou o formato dos produtos. Importe uma foto da nota.',
        );
      }
      final unit = text('.RUN, .unidade, [data-field="unit"]')
          .replaceFirst(
            RegExp(r'^\s*(UN|Unidade)\s*:\s*', caseSensitive: false),
            '',
          )
          .toLowerCase();
      items.add(
        ReceiptLine(
          description: name,
          quantityMilli: parseScaled(count, 3),
          unit: unit.isEmpty ? 'un' : unit,
          unitPriceCents: parseScaled(price, 2),
          totalCents: parseScaled(total, 2),
        ),
      );
    }
    if (items.isEmpty) {
      if (html.toLowerCase().contains('captcha') ||
          html.contains('caracteres da imagem')) {
        throw const FiscalFailure(
          'O portal pediu uma verificação humana. Abra a consulta no navegador ou importe uma foto.',
        );
      }
      throw const FiscalFailure(
        'Não encontramos produtos na consulta. Tente uma foto da nota ou tente novamente mais tarde.',
      );
    }
    final merchant = document
        .querySelector('#u20, .txtTopo, [data-field="merchant"]')
        ?.text
        .trim();
    // A mesma classe também representa a quantidade de itens: seleciona o valor a pagar.
    final totals = document.querySelectorAll('.totalNumb');
    final totalNode =
        document.querySelector(
          '#totalNota .totalNumb.txtMax, [data-field="receipt-total"]',
        ) ??
        document.querySelector('.totalNumb.txtMax') ??
        (totals.length == 1 ? totals.single : null);
    final total = _number(totalNode?.text ?? '');
    return ReceiptDraft(
      merchant: merchant == null || merchant.isEmpty
          ? 'Estabelecimento da nota'
          : merchant,
      issuedAt: _date(document.body?.text ?? ''),
      items: items,
      totalCents: total == null ? null : parseScaled(total, 2),
      accessKey: accessKey(url),
      source: 'sefaz',
      sourceUrl: url,
    );
  }

  /// Interpreta linhas de OCR sem prometer reconhecer qualquer leiaute de cupom.
  static ReceiptDraft fromText(String raw, {String? sourceUrl}) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final items = <ReceiptLine>[];
    // Captura número do item, código, descrição, quantidade, unidade, preço e total.
    final pattern = RegExp(
      r'^\s*\d{1,3}\s+\d{3,14}\s+(.+?)\s+(\d+(?:[.,]\d+)?)\s*(kg|un|und|pc|pct|lt|l|cx|g|ml)\s+(?:R\$\s*)?(\d+(?:[.,]\d+)+)\s+(?:R\$\s*)?(\d+(?:[.,]\d+)+)\s*$',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      try {
        final count = parseScaled(match[2]!, 3);
        if (count <= 0) continue;
        items.add(
          ReceiptLine(
            description: match[1]!.trim(),
            quantityMilli: count,
            unit: match[3]!.toLowerCase(),
            unitPriceCents: parseScaled(match[4]!, 2),
            totalCents: parseScaled(match[5]!, 2),
          ),
        );
      } on FormatException {
        // Linhas ilegíveis ficam fora do rascunho e podem ser adicionadas na conferência.
        continue;
      }
    }
    // A imagem pode ser parcialmente legível; o usuário sempre confere e corrige.
    final merchantLine = lines
        .where(
          (line) => RegExp(
            r'LTDA|ATACADO|SUPERMERCADO|HORTIFRUTI',
            caseSensitive: false,
          ).hasMatch(line),
        )
        .firstOrNull;
    var merchant =
        merchantLine
            ?.replaceFirst(
              RegExp(r'^.*?\d{2}[.\s]?\d{3}[.\s]?\d{3}/\d{4}-\d{2}\s*'),
              '',
            )
            .trim() ??
        '';
    if (merchant.isEmpty) merchant = 'Compra importada';
    final totalMatch = RegExp(
      r'(?:Valor\s+total|TOTAL\s+A\s+PAGAR)\s*(?:R\$)?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    return ReceiptDraft(
      merchant: merchant,
      issuedAt: _date(raw),
      items: items,
      totalCents: totalMatch == null ? null : parseScaled(totalMatch[1]!, 2),
      accessKey:
          accessKey(raw.replaceAll(RegExp(r'(?<=\d)[ \t](?=\d)'), '')) ??
          (sourceUrl == null ? null : accessKey(sourceUrl)),
      source: 'ocr',
      sourceUrl: sourceUrl,
    );
  }

  /// Datas não encontradas usam hoje e ficam editáveis na tela de conferência.
  static DateTime _date(String value) {
    final match = RegExp(r'(?<!\d)(\d{2})/(\d{2})/(\d{4})(?!\d)')
        .firstMatch(value);
    if (match == null) return DateTime.now();
    return DateTime(
      int.parse(match[3]!),
      int.parse(match[2]!),
      int.parse(match[1]!),
    );
  }

  // O último número do rótulo representa o valor exibido pelo portal.
  static String? _number(String value) =>
      RegExp(r'\d+(?:[.,]\d+)*').allMatches(value).lastOrNull?.group(0);
}
