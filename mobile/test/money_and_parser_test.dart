import 'package:flutter_test/flutter_test.dart';
import 'package:carrinho_de_compras/core/formatters.dart';
import 'package:carrinho_de_compras/data/receipt_parser.dart';

/// Cenário sintético semelhante a cupons de supermercado, sem dados pessoais.
const sampleReceipt = '''
SUPERMERCADO DE TESTE LTDA
1 1005 ACEM RESFRIADO Kg 1,096 kg 42,90 47,02
2 2135 LIMAO TAHITI Kg 0,714 kg 9,99 7,13
3 1895 BARRIGA SUINA Kg 1,298 kg 24,90 32,32
4 996969 PAPEL MANTEIGA 28cmx7,5m 1 UN 6,99 6,99
5 12377 EMBUTIDO SUINO 0,198 kg 27,90 5,52
6 12377 EMBUTIDO SUINO 0,204 kg 27,90 5,69
7 12377 EMBUTIDO SUINO 0,194 kg 27,90 5,41
8 12480 QUEIJO MUSSARELA KG 1,358 kg 37,89 51,45
Valor total R\$ 161,53
18/10/2026 10:51:59
''';

void main() {
  group('Dinheiro e produtos por peso', () {
    test('Converte vírgula brasileira sem perder centavos', () {
      expect(parseScaled('R\$ 1.234,56', 2), 123456);
      expect(parseScaled('4.79', 2), 479);
      expect(parseScaled('0,714', 3), 714);
    });
    test('Arredonda a linha de carne como a nota fiscal', () {
      expect(lineTotal(4290, 1096), 4702);
      expect(lineTotal(999, 714), 713);
      expect(parseScaled('1,005', 2), 101);
    });
    test('Rejeita negativos, textos e números excessivos', () {
      for (final input in ['-1', 'abc', '1,2,3', '999999999999999']) {
        expect(() => parseScaled(input, 2), throwsFormatException);
      }
    });
  });
  group('Importação fiscal', () {
    test('Quantidade de itens não é confundida com o valor a pagar', () {
      final draft = ReceiptParser.fromHtml(
        '''<div id="u20">Mercado</div><table id="tabResult"><tr><td><span class="txtTit">Arroz</span><span class="Rqtd">1</span><span class="RUN">un</span><span class="RvlUnit">24,90</span><span class="valor">24,90</span></td></tr></table><div id="totalNota"><span class="totalNumb">8</span><span class="totalNumb txtMax">161,53</span></div>''',
        'https://www.nfce.fazenda.sp.gov.br/qrcode',
      );
      expect(draft.totalCents, 16153);
    });
    test('Reconhece oito linhas, pesos e total do cenário de referência', () {
      final draft = ReceiptParser.fromText(sampleReceipt);
      expect(draft.items.length, 8);
      expect(draft.totalCents, 16153);
      expect(draft.itemsTotal, 16153);
      expect(draft.items.first.quantityMilli, 1096);
      expect(draft.items[4].description, draft.items[5].description);
      expect(draft.issuedAt, DateTime(2026, 10, 18));
    });
    test('Foto ilegível não gera produtos ou totais fictícios', () {
      final draft = ReceiptParser.fromText('imagem sem produtos reconhecíveis');
      expect(draft.items, isEmpty);
      expect(draft.totalCents, isNull);
    });
    test(
      'Acentos e percentuais do OCR não são tratados como uma URL inválida',
      () {
        expect(
          ReceiptParser.accessKey('Promoção: 10% de desconto no pão'),
          isNull,
        );
      },
    );
    test('Destino deve pertencer exatamente ao portal oficial', () {
      for (final value in [
        'https://127.0.0.1/qrcode',
        'http://www.nfce.fazenda.sp.gov.br/qrcode',
        'https://www.nfce.fazenda.sp.gov.br.evil.example/qrcode',
        'https://www.nfce.fazenda.sp.gov.br/admin',
      ]) {
        expect(
          () => ReceiptParser.validateUrl(value),
          throwsA(isA<FiscalFailure>()),
        );
      }
    });
    test('Reconhece erro do portal sem salvar uma compra vazia', () {
      expect(
        () => ReceiptParser.fromHtml(
          '<script>Formato de QR-Code não suportado</script>',
          '',
        ),
        throwsA(isA<FiscalFailure>()),
      );
      expect(
        () => ReceiptParser.fromHtml('<div>captcha</div>', ''),
        throwsA(isA<FiscalFailure>()),
      );
    });
    test('Preserva valor de linha retornado pelo portal', () {
      final draft = ReceiptParser.fromHtml(
        '''<div id="u20">Mercado de teste</div><table id="tabResult"><tr><td><span class="txtTit">Leite</span><span class="Rqtd">Qtde.: 3</span><span class="RUN">UN: un</span><span class="RvlUnit">Vl. Unit.: 4,79</span><span class="valor">14,37</span></td></tr></table><span class="totalNumb">14,37</span>''',
        'https://www.nfce.fazenda.sp.gov.br/qrcode',
      );
      expect(draft.items.single.quantityMilli, 3000);
      expect(draft.items.single.totalCents, 1437);
    });
  });
}
