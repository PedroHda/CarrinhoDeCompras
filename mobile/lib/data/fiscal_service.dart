import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';
import 'receipt_parser.dart';

/// Pode consultar diretamente no celular ou usar o backend configurado pelo usuário.
class FiscalService {
  FiscalService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Sem backend configurado, o APK continua capaz de consultar a página pública.
  Future<ReceiptDraft> consult(String url, {String backendUrl = ''}) async {
    final uri = ReceiptParser.validateUrl(url);
    try {
      if (backendUrl.trim().isNotEmpty) {
        final base = Uri.parse(
          backendUrl.trim().replaceFirst(RegExp(r'/$'), ''),
        );
        final response = await _client
            .post(
              Uri.parse('$base/api/receipts/consult'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'url': uri.toString()}),
            )
            .timeout(const Duration(seconds: 30));
        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (response.statusCode != 200) {
          throw FiscalFailure(
            body['message'] as String? ??
                'O serviço de consulta não está disponível.',
          );
        }
        return ReceiptDraft.fromJson({...body, 'sourceUrl': url});
      }
      // Redirecionamentos automáticos ficam desligados: cada destino é validado.
      var destination = uri;
      for (var redirect = 0; redirect < 5; redirect++) {
        final request = http.Request('GET', destination)
          ..followRedirects = false;
        final response = await _client
            .send(request)
            .timeout(const Duration(seconds: 25));
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers['location'];
          await response.stream.drain<void>();
          if (location == null) {
            throw const FiscalFailure(
              'O portal redirecionou sem informar o destino.',
            );
          }
          destination = ReceiptParser.validateUrl(
            destination.resolve(location).toString(),
          );
          continue;
        }
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          throw const FiscalFailure(
            'A Sefaz está indisponível. Tente novamente ou importe uma foto.',
          );
        }
        // Limita o conteúdo mesmo quando o servidor não informa Content-Length.
        final bytes = <int>[];
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 25),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > 2 * 1024 * 1024) {
            throw const FiscalFailure(
              'Resposta fiscal maior que o limite permitido.',
            );
          }
        }
        String html;
        try {
          html = utf8.decode(bytes);
        } on FormatException {
          html = latin1.decode(bytes);
        }
        return ReceiptParser.fromHtml(html, url);
      }
      throw const FiscalFailure(
        'A consulta fiscal redirecionou mais vezes que o esperado.',
      );
    } on FiscalFailure {
      rethrow;
    } on TimeoutException {
      throw const FiscalFailure(
        'A consulta demorou demais. Tente novamente ou importe uma foto.',
      );
    } catch (_) {
      throw const FiscalFailure(
        'Sem acesso à consulta. Confira sua conexão e o endereço do backend, se configurado.',
      );
    }
  }

  /// Libera conexões abertas quando o proprietário do serviço é descartado.
  void dispose() => _client.close();
}
