import 'dart:convert';
import 'dart:io';

import 'package:carrinho_de_compras/data/fiscal_service.dart';

/// Diagnóstico real usando exatamente o mesmo cliente fiscal incluído no APK.
Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/consult_receipt.dart "URL_DO_QR" [URL_DO_BACKEND]',
    );
    exitCode = 2;
    return;
  }
  final service = FiscalService();
  try {
    final receipt = await service.consult(
      arguments.first,
      backendUrl: arguments.length > 1 ? arguments[1] : '',
    );
    // O resumo não imprime a chave fiscal nem o conteúdo completo dos produtos.
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'merchant': receipt.merchant,
        'issuedAt': receipt.issuedAt.toIso8601String(),
        'itemCount': receipt.items.length,
        'totalCents': receipt.totalCents,
        'sumItemsCents': receipt.itemsTotal,
        'source': receipt.source,
      }),
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    service.dispose();
  }
}
