import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:carrinho_de_compras/data/local_database.dart';
import 'package:carrinho_de_compras/data/shopping_repository.dart';
import 'package:carrinho_de_compras/domain/models.dart';

void main() {
  sqfliteFfiInit();
  late Database database;
  late ShoppingRepository repository;
  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: LocalDatabase.configure,
        onCreate: LocalDatabase.create,
      ),
    );
    repository = ShoppingRepository(LocalDatabase(database));
  });
  tearDown(() async => database.close());

  /// Fixture com valores conhecidos para testes transacionais do SQLite real.
  ReceiptDraft receipt({String? key}) => ReceiptDraft(
    merchant: 'Mercado de teste',
    issuedAt: DateTime(2026, 10, 18),
    accessKey: key,
    totalCents: 1437,
    items: const [
      ReceiptLine(
        description: 'Leite integral',
        quantityMilli: 3000,
        unit: 'un',
        unitPriceCents: 479,
        totalCents: 1437,
      ),
    ],
  );

  test(
    'Lista e item persistem com apóstrofos e caracteres brasileiros',
    () async {
      final id = await repository.createList("Compra da mãe d'água");
      await repository.saveItem(
        id,
        const ShoppingItem(
          id: 'item-1',
          name: 'Pão',
          quantityMilli: 2000,
          unitPriceCents: 849,
        ),
      );
      final lists = await repository.lists();
      expect(lists.single.name, "Compra da mãe d'água");
      expect(lists.single.totalCents, 1698);
    },
  );
  test('Duplicação desmarca itens e mantém a lista original', () async {
    final id = await repository.createList('Semana');
    await repository.saveItem(
      id,
      const ShoppingItem(
        id: 'item-1',
        name: 'Leite',
        quantityMilli: 3000,
        unitPriceCents: 479,
        checked: true,
      ),
    );
    final original = (await repository.lists()).single;
    await repository.duplicateList(original);
    final lists = await repository.lists();
    expect(lists.length, 2);
    expect(
      lists.singleWhere((list) => list.id != id).items.single.checked,
      isFalse,
    );
    expect(
      lists.singleWhere((list) => list.id == id).items.single.checked,
      isTrue,
    );
    final copiedItem = lists.singleWhere((list) => list.id != id).items.single;
    expect(copiedItem.id, isNot('item-1'));
    expect(copiedItem.quantityMilli, 3000);
    expect(copiedItem.unitPriceCents, 0);
    expect(original.items.single.unitPriceCents, 479);
  });
  test('Entrada em lote preserva a ordem e edições não movem o item', () async {
    final id = await repository.createList('Semana');
    const first = ShoppingItem(id: 'a', name: 'Arroz');
    await repository.saveItem(id, first);
    await repository.addItems(id, const [
      ShoppingItem(id: 'b', name: 'Feijão'),
      ShoppingItem(id: 'c', name: 'Leite'),
    ]);
    await repository.saveItem(id, first.copyWith(checked: true));
    await repository.saveItem(id, const ShoppingItem(id: 'd', name: 'Pão'));
    expect((await repository.lists()).single.items.map((item) => item.id), [
      'a',
      'b',
      'c',
      'd',
    ]);
  });
  test('Falha no meio do lote desfaz todas as inserções', () async {
    final id = await repository.createList('Semana');
    await repository.saveItem(id, const ShoppingItem(id: 'a', name: 'Arroz'));
    await expectLater(
      repository.addItems(id, const [
        ShoppingItem(id: 'b', name: 'Feijão'),
        ShoppingItem(id: 'c', name: 'Leite', quantityMilli: 0),
      ]),
      throwsA(isA<DatabaseException>()),
    );
    expect((await repository.lists()).single.items.single.id, 'a');
    await expectLater(
      repository.addItems(id, const [
        ShoppingItem(id: 'b', name: 'Feijão'),
        ShoppingItem(id: 'a', name: 'Produto repetido'),
      ]),
      throwsA(isA<DatabaseException>()),
    );
    expect((await repository.lists()).single.items.single.name, 'Arroz');
  });
  test('Falha no lote inicial não deixa uma lista vazia persistida', () async {
    await repository.createList('Lista anterior');
    await expectLater(
      repository.createList(
        'Nova lista com falha',
        items: const [
          ShoppingItem(id: 'a', name: 'Arroz'),
          ShoppingItem(id: 'b', name: 'Feijão', quantityMilli: 0),
        ],
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect((await repository.lists()).single.name, 'Lista anterior');
    final id = await repository.createList(
      'Lote válido',
      items: const [
        ShoppingItem(id: 'a', name: 'Arroz'),
        ShoppingItem(id: 'b', name: 'Feijão'),
      ],
    );
    expect(
      (await repository.lists())
          .singleWhere((list) => list.id == id)
          .items
          .map((item) => item.id),
      ['a', 'b'],
    );
  });
  test(
    'Desfazer exclusão recupera dados e posição, inclusive nas pontas',
    () async {
      final id = await repository.createList('Semana');
      const first = ShoppingItem(id: 'a', name: 'Arroz');
      const middle = ShoppingItem(
        id: 'b',
        name: 'Queijo',
        quantityMilli: 750,
        unit: 'kg',
        checked: true,
      );
      const last = ShoppingItem(id: 'c', name: 'Leite');
      await repository.addItems(id, const [first, middle, last]);
      await repository.deleteItem(middle.id);
      await repository.restoreItem(id, middle, beforeItemId: last.id);
      var items = (await repository.lists()).single.items;
      expect(items.map((item) => item.id), ['a', 'b', 'c']);
      expect(items[1].quantityMilli, 750);
      expect(items[1].unit, 'kg');
      expect(items[1].checked, isTrue);
      await repository.deleteItem(first.id);
      await repository.restoreItem(id, first, beforeItemId: middle.id);
      await repository.deleteItem(last.id);
      await repository.restoreItem(id, last);
      items = (await repository.lists()).single.items;
      expect(items.map((item) => item.id), ['a', 'b', 'c']);
      await repository.deleteItem(first.id);
      await repository.restoreItem(id, first, beforeItemId: 'vizinho-excluido');
      expect((await repository.lists()).single.items.map((item) => item.id), [
        'b',
        'c',
        'a',
      ]);
    },
  );
  test(
    'Concluir planejamento não cria uma compra sem nota no histórico',
    () async {
      final id = await repository.createList('Semana');
      await repository.completeList(id);
      expect((await repository.lists()).single.completed, isTrue);
      expect(await repository.purchases(), isEmpty);
    },
  );
  test('Mês anterior agrega quantidades e preserva unidades e histórico', () async {
    Future<void> save(DateTime date, String name, int count, String unit) =>
        repository.savePurchase(
          ReceiptDraft(
            merchant: 'Mercado',
            issuedAt: date,
            items: [
              ReceiptLine(
                description: name,
                quantityMilli: count,
                unit: unit,
                unitPriceCents: 990,
                totalCents: 1990,
              ),
            ],
          ),
        );
    await save(DateTime(2026, 8, 31, 23, 59), 'Fora de agosto', 1000, 'un');
    await save(DateTime(2026, 9), '  Leite   integral  ', 3000, 'UN');
    await save(
      DateTime(2026, 9, 30, 23, 59).toUtc(),
      'LEITE integral',
      2000,
      'un',
    );
    await save(DateTime(2026, 9, 20), 'Leite integral', 750, 'kg');
    await save(DateTime(2026, 10), 'Fora de outubro', 1000, 'un');
    final id = await repository.createListFromPreviousMonth(
      '  Repor outubro  ',
      referenceDate: DateTime(2026, 10, 19),
    );
    expect(id, isNotNull);
    final list = (await repository.lists()).single;
    expect(list.id, id);
    expect(list.name, 'Repor outubro');
    expect(list.completed, isFalse);
    expect(list.items.length, 2);
    expect(list.items.first.name, 'Leite integral');
    expect(
      list.items.singleWhere((item) => item.unit == 'un').quantityMilli,
      5000,
    );
    expect(
      list.items.singleWhere((item) => item.unit == 'kg').quantityMilli,
      750,
    );
    expect(list.items.every((item) => !item.checked), isTrue);
    expect(list.items.every((item) => item.unitPriceCents == 0), isTrue);
    final originalPurchases = await repository.purchases();
    expect(originalPurchases.length, 5);
    expect(
      originalPurchases.every(
        (purchase) => purchase.receipt.items.single.unitPriceCents == 990,
      ),
      isTrue,
    );
    final secondId = await repository.createListFromPreviousMonth(
      'Outra reposição',
      referenceDate: DateTime(2026, 10),
    );
    final copies = await repository.lists();
    expect(secondId, isNot(id));
    expect(
      copies.expand((list) => list.items).map((item) => item.id).toSet().length,
      4,
    );
    // O backup antigo continua preservando notas e listas sem mudar de formato.
    final backup = await repository.exportBackup();
    await repository.deleteList(id!);
    await repository.restoreBackup(backup);
    final restored = (await repository.lists()).singleWhere(
      (list) => list.id == id,
    );
    expect(restored.items.map((item) => item.quantityMilli), [5000, 750]);
    expect(restored.items.every((item) => item.unitPriceCents == 0), isTrue);
    expect(
      (await repository.purchases()).first.receipt.items.single.totalCents,
      1990,
    );
  });
  test('Mês anterior na virada do ano usa dezembro completo', () async {
    for (final date in [
      DateTime(2026, 11, 30, 23, 59),
      DateTime(2026, 12),
      DateTime(2026, 12, 31, 23, 59),
      DateTime(2027, 1),
    ]) {
      await repository.savePurchase(
        ReceiptDraft(
          merchant: 'Mercado',
          issuedAt: date,
          items: receipt().items,
        ),
      );
    }
    await repository.createListFromPreviousMonth(
      'Janeiro',
      referenceDate: DateTime(2027, 1, 15),
    );
    expect((await repository.lists()).single.items.single.quantityMilli, 6000);
  });
  test('Sem compras no mês anterior não cria uma lista vazia', () async {
    await repository.savePurchase(receipt());
    final id = await repository.createListFromPreviousMonth(
      'Sem dados',
      referenceDate: DateTime(2026, 10, 19),
    );
    expect(id, isNull);
    expect(await repository.lists(), isEmpty);
  });
  test('Nota duplicada é rejeitada sem gravação parcial', () async {
    final key = List.filled(44, '3').join();
    await repository.savePurchase(receipt(key: key));
    await expectLater(
      repository.savePurchase(receipt(key: key)),
      throwsFormatException,
    );
    expect((await repository.purchases()).length, 1);
  });
  test('Excluir lista preserva compra e remove o vínculo', () async {
    final id = await repository.createList('Semana');
    await repository.savePurchase(receipt(), listId: id);
    expect((await repository.lists()).single.completed, isTrue);
    await repository.deleteList(id);
    expect((await repository.purchases()).single.listId, isNull);
  });
  test('Backup restaura itens, preços e vínculo com a lista', () async {
    final id = await repository.createList('Semana');
    await repository.saveItem(
      id,
      const ShoppingItem(id: 'item-1', name: 'Arroz', unitPriceCents: 2490),
    );
    await repository.savePurchase(receipt(), listId: id);
    final backup = await repository.exportBackup();
    await repository.deleteList(id);
    await repository.restoreBackup(backup);
    expect((await repository.lists()).single.items.single.unitPriceCents, 2490);
    expect((await repository.purchases()).single.listId, id);
  });
  test('Falha durante restauração reverte exclusão e inserções', () async {
    await repository.createList('Dados que precisam sobreviver');
    final broken =
        jsonDecode(await repository.exportBackup()) as Map<String, dynamic>;
    broken['lists'] = [broken['lists'][0], broken['lists'][0]];
    await expectLater(
      repository.restoreBackup(jsonEncode(broken)),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      (await repository.lists()).single.name,
      'Dados que precisam sobreviver',
    );
  });
  test(
    'Dados continuam disponíveis depois de fechar e reabrir o arquivo',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'carrinho-sqlite-test-',
      );
      final path = '${directory.path}/persistent.db';
      final first = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: LocalDatabase.configure,
          onCreate: LocalDatabase.create,
        ),
      );
      await ShoppingRepository(LocalDatabase(first))
          .createList('Lista persistente');
      await first.close();
      final second = await databaseFactoryFfi.openDatabase(path);
      expect(
        (await ShoppingRepository(LocalDatabase(second)).lists()).single.name,
        'Lista persistente',
      );
      await second.close();
      // Remove somente o arquivo e a pasta temporária criados por este teste.
      await File(path).delete();
      await directory.delete();
    },
  );
}
