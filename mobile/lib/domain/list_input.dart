import 'package:uuid/uuid.dart';

import '../core/formatters.dart';
import 'models.dart';

/// Uma linha por produto. Quantidades só são interpretadas com “x” ou unidade
/// explícita, preservando nomes como “51 Cachaça” e “7 grãos”.
List<ShoppingItem> parseShoppingItems(String input) {
  final lines = input
      .replaceAll(r'\r\n', '\n')
      .replaceAll(r'\n', '\n')
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length > 2000) {
    throw const FormatException('Adicione no máximo 2.000 produtos por vez.');
  }
  final multiplied = RegExp(r'^(\d+(?:[.,]\d+)?)\s*[xX×]\s+(.+)$');
  final measured = RegExp(
    r'^(\d+(?:[.,]\d+)?)\s+(un|und|unid|kg|g|mg|l|ml|pct|cx|pc|lt|dz)\s+(.+)$',
    caseSensitive: false,
  );
  return lines.map((line) {
    var name = line;
    var unit = 'un';
    var quantityMilli = 1000;
    final countMatch = multiplied.firstMatch(line);
    final unitMatch = measured.firstMatch(line);
    if (countMatch != null) {
      quantityMilli = parseScaled(countMatch.group(1)!, 3);
      name = countMatch.group(2)!.trim();
    } else if (unitMatch != null) {
      quantityMilli = parseScaled(unitMatch.group(1)!, 3);
      unit = unitMatch.group(2)!.toLowerCase();
      name = unitMatch.group(3)!.trim();
    }
    if (quantityMilli <= 0) {
      throw FormatException('A quantidade de “$name” deve ser maior que zero.');
    }
    if (name.length > 160) {
      throw const FormatException(
        'Use até 160 caracteres no nome de cada produto.',
      );
    }
    return ShoppingItem(
      id: const Uuid().v4(),
      name: name,
      quantityMilli: quantityMilli,
      unit: unit,
    );
  }).toList();
}
