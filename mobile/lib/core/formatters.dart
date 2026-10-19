import 'package:intl/intl.dart';

/// Converte texto decimal para inteiro escalado sem usar ponto flutuante.
int parseScaled(String input, int digits) {
  // O contrato suporta centavos (2) ou milésimos (3); outras escalas seriam ambíguas.
  if (digits != 2 && digits != 3) {
    throw ArgumentError.value(digits, 'digits', 'Use 2 ou 3 casas.');
  }
  // Aceita a vírgula brasileira e ponto decimal; remove o símbolo monetário.
  var value = input.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  }
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
    throw const FormatException('Informe um número positivo, como 4,79.');
  }
  // Completa casas ausentes e arredonda a primeira casa excedente comercialmente.
  final parts = value.split('.');
  final fraction = (parts.length == 2 ? parts[1] : '').padRight(
    digits + 1,
    '0',
  );
  final factor = digits == 2 ? 100 : 1000;
  final result =
      int.parse(parts[0]) * factor + int.parse(fraction.substring(0, digits));
  final rounded = result + (int.parse(fraction[digits]) >= 5 ? 1 : 0);
  if (rounded > 100000000000) {
    throw const FormatException('Número acima do limite permitido.');
  }
  return rounded;
}

/// Quantidade é expressa em milésimos; dinheiro é expresso em centavos.
int lineTotal(int priceCents, int quantityMilli) =>
    (priceCents * quantityMilli + 500) ~/ 1000;

/// Formata para apresentação sem usar o resultado em cálculos financeiros.
String money(int cents) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(cents / 100);

/// Remove zeros finais da quantidade, preservando até três casas decimais.
String quantity(int milli) =>
    NumberFormat('0.###', 'pt_BR').format(milli / 1000);

/// Entradas editáveis não recebem separador de milhares.
String decimalInput(int scaled, {int digits = 2}) =>
    (scaled / (digits == 2 ? 100 : 1000))
        .toStringAsFixed(digits)
        .replaceAll('.', ',');

/// Datas são exibidas no calendário local do usuário.
String shortDate(DateTime value) =>
    DateFormat('dd/MM/yyyy', 'pt_BR').format(value);
