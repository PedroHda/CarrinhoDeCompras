import 'package:carrinho_de_compras/domain/list_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Uma linha vira um item sem preço e com identidade própria', () {
    final items = parseShoppingItems('  Arroz\r\n\nFeijão\rLeite  \nArroz');
    expect(items.map((item) => item.name), [
      'Arroz',
      'Feijão',
      'Leite',
      'Arroz',
    ]);
    expect(items.map((item) => item.id).toSet().length, 4);
    expect(items.every((item) => item.quantityMilli == 1000), isTrue);
    expect(items.every((item) => item.unit == 'un'), isTrue);
    expect(items.every((item) => item.unitPriceCents == 0), isTrue);
    expect(items.every((item) => !item.checked), isTrue);
  });

  test('Aceita separadores de linha digitados literalmente', () {
    final items = parseShoppingItems(r'Arroz\nFeijão\r\nLeite');
    expect(items.map((item) => item.name), ['Arroz', 'Feijão', 'Leite']);
  });

  test('Reconhece multiplicador e peso com vírgula ou ponto', () {
    final items = parseShoppingItems(
      '2x Arroz\n3 X Leite\n1,5 kg Banana\n0.250 KG Queijo\n2 l Água',
    );
    expect(items.map((item) => item.name), [
      'Arroz',
      'Leite',
      'Banana',
      'Queijo',
      'Água',
    ]);
    expect(items.map((item) => item.quantityMilli), [
      2000,
      3000,
      1500,
      250,
      2000,
    ]);
    expect(items.map((item) => item.unit), ['un', 'un', 'kg', 'kg', 'l']);
  });

  test('Não confunde números e expressões comerciais com quantidade', () {
    final names = [
      '51 Cachaça',
      '7 grãos',
      '100% suco de uva',
      '3x1 detergente',
      '2 litros de leite',
    ];
    final items = parseShoppingItems(names.join('\n'));
    expect(items.map((item) => item.name), names);
    expect(items.every((item) => item.quantityMilli == 1000), isTrue);
  });

  test('Entrada vazia não cria produtos', () {
    expect(parseShoppingItems(' \n\r\n '), isEmpty);
  });

  test('Rejeita quantidade explícita nula e lotes acima do limite', () {
    expect(() => parseShoppingItems('0x Arroz'), throwsFormatException);
    expect(() => parseShoppingItems('0,0001 kg Queijo'), throwsFormatException);
    expect(
      () => parseShoppingItems('999999999999999x Arroz'),
      throwsFormatException,
    );
    expect(
      () => parseShoppingItems(List.filled(2001, 'Arroz').join('\n')),
      throwsFormatException,
    );
    expect(
      () => parseShoppingItems(List.filled(161, 'A').join()),
      throwsFormatException,
    );
  });
}
