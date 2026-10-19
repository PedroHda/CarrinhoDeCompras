import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'local_database.dart';

/// Fonte de verdade das listas e compras; telas nunca executam SQL diretamente.
class ShoppingRepository {
  ShoppingRepository(this.storage);
  final LocalDatabase storage;
  final _uuid = const Uuid();
  Database get _db => storage.connection;

  /// Carrega listas com os respectivos itens, mantendo ordenação estável.
  Future<List<ShoppingList>> lists() async {
    final rows = await _db.query(
      'lists',
      orderBy: 'completed, created_at DESC',
    );
    final result = <ShoppingList>[];
    for (final row in rows) {
      final items = await _db.query(
        'list_items',
        where: 'list_id = ?',
        whereArgs: [row['id']],
        orderBy: 'position',
      );
      result.add(
        ShoppingList(
          id: row['id'] as String,
          name: row['name'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          completed: row['completed'] == 1,
          items: items
              .map(
                (item) => ShoppingItem(
                  id: item['id'] as String,
                  name: item['name'] as String,
                  quantityMilli: item['quantity_milli'] as int,
                  unit: item['unit'] as String,
                  unitPriceCents: item['unit_price_cents'] as int,
                  checked: item['checked'] == 1,
                ),
              )
              .toList(),
        ),
      );
    }
    return result;
  }

  /// Cria uma lista vazia e retorna a identidade usada na navegação.
  Future<String> createList(String name) async {
    final id = _uuid.v4();
    await _db.insert('lists', {
      'id': id,
      'name': name.trim(),
      'created_at': DateTime.now().toIso8601String(),
      'completed': 0,
    });
    return id;
  }

  /// Consultas parametrizadas separam conteúdo digitado e instruções SQL.
  Future<void> renameList(String id, String name) async => _db.update(
    'lists',
    {'name': name.trim()},
    where: 'id = ?',
    whereArgs: [id],
  );
  Future<void> deleteList(String id) async =>
      _db.delete('lists', where: 'id = ?', whereArgs: [id]);
  Future<void> deleteItem(String id) async =>
      _db.delete('list_items', where: 'id = ?', whereArgs: [id]);
  Future<void> deletePurchase(String id) async =>
      _db.delete('purchases', where: 'id = ?', whereArgs: [id]);

  /// Upsert conserva a posição de um item existente e adiciona novos ao final.
  Future<void> saveItem(String listId, ShoppingItem item) async {
    final old = await _db.query(
      'list_items',
      columns: ['position'],
      where: 'id = ?',
      whereArgs: [item.id],
    );
    final position = old.isEmpty
        ? DateTime.now().microsecondsSinceEpoch
        : old.first['position'];
    await _db.insert('list_items', {
      'id': item.id,
      'list_id': listId,
      'name': item.name,
      'quantity_milli': item.quantityMilli,
      'unit': item.unit,
      'unit_price_cents': item.unitPriceCents,
      'checked': item.checked ? 1 : 0,
      'position': position,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Duplicar cria novas identidades e desmarca itens; o histórico original fica preservado.
  Future<String> duplicateList(ShoppingList original) async {
    final id = _uuid.v4();
    await _db.transaction((txn) async {
      await _insertList(
        txn,
        ShoppingList(
          id: id,
          name: '${original.name} (cópia)',
          createdAt: DateTime.now(),
          items: original.items
              .map(
                (item) => ShoppingItem(
                  id: _uuid.v4(),
                  name: item.name,
                  quantityMilli: item.quantityMilli,
                  unit: item.unit,
                  unitPriceCents: item.unitPriceCents,
                ),
              )
              .toList(),
        ),
      );
    });
    return id;
  }

  /// Histórico mantém os preços pagos em cada data, sem sobrescrever compras anteriores.
  Future<List<Purchase>> purchases() async {
    final rows = await _db.query('purchases', orderBy: 'issued_at DESC');
    final result = <Purchase>[];
    for (final row in rows) {
      final items = await _db.query(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [row['id']],
        orderBy: 'position',
      );
      result.add(
        Purchase(
          id: row['id'] as String,
          listId: row['list_id'] as String?,
          receipt: ReceiptDraft(
            merchant: row['merchant'] as String,
            issuedAt: DateTime.parse(row['issued_at'] as String),
            accessKey: row['access_key'] as String?,
            totalCents: row['total_cents'] as int?,
            source: row['source'] as String,
            sourceUrl: row['source_url'] as String?,
            items: items
                .map(
                  (item) => ReceiptLine(
                    description: item['description'] as String,
                    quantityMilli: item['quantity_milli'] as int,
                    unit: item['unit'] as String,
                    unitPriceCents: item['unit_price_cents'] as int,
                    totalCents: item['total_cents'] as int,
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
    return result;
  }

  /// Salva cabeçalho, linhas e conclusão da lista em uma única transação.
  Future<void> savePurchase(ReceiptDraft receipt, {String? listId}) async {
    await _db.transaction((txn) async {
      if (receipt.accessKey != null) {
        final existing = await txn.query(
          'purchases',
          columns: ['id'],
          where: 'access_key = ?',
          whereArgs: [receipt.accessKey],
        );
        if (existing.isNotEmpty) {
          throw const FormatException('Esta nota já está no histórico.');
        }
      }
      await _insertPurchase(
        txn,
        Purchase(id: _uuid.v4(), receipt: receipt, listId: listId),
      );
      if (listId != null) {
        await txn.update(
          'lists',
          {'completed': 1},
          where: 'id = ?',
          whereArgs: [listId],
        );
      }
    });
  }

  /// Preferências também ficam no SQLite privado do aplicativo.
  Future<String> setting(String key) async {
    final values = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return values.isEmpty ? '' : values.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async => _db.insert(
    'settings',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  /// Backup lógico portátil: não copia um arquivo SQLite enquanto ele está aberto.
  Future<String> exportBackup() async => jsonEncode({
    'format': 'carrinho-backup',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'lists': (await lists()).map((list) => list.toJson()).toList(),
    'purchases': (await purchases())
        .map((purchase) => purchase.toJson())
        .toList(),
  });

  /// Valida todo o documento antes de substituir dados; uma falha faz rollback integral.
  Future<void> restoreBackup(String content) async {
    if (content.length > 5 * 1024 * 1024) {
      throw const FormatException('Backup maior que 5 MB.');
    }
    final json = jsonDecode(content) as Map<String, dynamic>;
    if (json['format'] != 'carrinho-backup' || json['version'] != 1) {
      throw const FormatException('Formato de backup não reconhecido.');
    }
    final savedLists = (json['lists'] as List)
        .map(
          (value) =>
              ShoppingList.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
    final savedPurchases = (json['purchases'] as List)
        .map(
          (value) => Purchase.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
    if (savedLists.length > 1000 || savedPurchases.length > 10000) {
      throw const FormatException('Backup excede o limite de registros.');
    }
    for (final list in savedLists) {
      if (list.name.trim().isEmpty ||
          list.name.length > 120 ||
          list.items.length > 2000) {
        throw const FormatException('Lista inválida no backup.');
      }
      for (final item in list.items) {
        if (item.name.trim().isEmpty ||
            item.quantityMilli <= 0 ||
            item.unitPriceCents < 0) {
          throw const FormatException('Item inválido no backup.');
        }
      }
    }
    for (final purchase in savedPurchases) {
      if (purchase.receipt.merchant.trim().isEmpty ||
          purchase.receipt.items.isEmpty ||
          purchase.totalCents < 0) {
        throw const FormatException('Compra inválida no backup.');
      }
    }
    await _db.transaction((txn) async {
      await txn.delete('purchases');
      await txn.delete('lists');
      for (final list in savedLists) {
        await _insertList(txn, list);
      }
      for (final purchase in savedPurchases) {
        await _insertPurchase(txn, purchase);
      }
    });
  }

  /// Auxiliar aceita Transaction, impedindo gravações parciais durante restauração.
  Future<void> _insertList(DatabaseExecutor txn, ShoppingList list) async {
    await txn.insert('lists', {
      'id': list.id,
      'name': list.name,
      'created_at': list.createdAt.toIso8601String(),
      'completed': list.completed ? 1 : 0,
    });
    for (var index = 0; index < list.items.length; index++) {
      final item = list.items[index];
      await txn.insert('list_items', {
        'id': item.id,
        'list_id': list.id,
        'name': item.name,
        'quantity_milli': item.quantityMilli,
        'unit': item.unit,
        'unit_price_cents': item.unitPriceCents,
        'checked': item.checked ? 1 : 0,
        'position': index,
      });
    }
  }

  /// Guarda a posição de cada linha para reproduzir a ordem da nota original.
  Future<void> _insertPurchase(DatabaseExecutor txn, Purchase purchase) async {
    final receipt = purchase.receipt;
    await txn.insert('purchases', {
      'id': purchase.id,
      'list_id': purchase.listId,
      'merchant': receipt.merchant,
      'issued_at': receipt.issuedAt.toIso8601String(),
      'access_key': receipt.accessKey,
      'total_cents': receipt.totalCents,
      'source': receipt.source,
      'source_url': receipt.sourceUrl,
    });
    for (var index = 0; index < receipt.items.length; index++) {
      final item = receipt.items[index];
      await txn.insert('purchase_items', {
        'purchase_id': purchase.id,
        'description': item.description,
        'quantity_milli': item.quantityMilli,
        'unit': item.unit,
        'unit_price_cents': item.unitPriceCents,
        'total_cents': item.totalCents,
        'position': index,
      });
    }
  }
}
