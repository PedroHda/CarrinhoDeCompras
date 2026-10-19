import '../core/formatters.dart';

/// Item planejado; o identificador permanece estável ao marcar ou editar.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantityMilli = 1000,
    this.unit = 'un',
    this.unitPriceCents = 0,
    this.checked = false,
  });
  final String id;
  final String name;
  final int quantityMilli;
  final String unit;
  final int unitPriceCents;
  final bool checked;
  int get totalCents => lineTotal(unitPriceCents, quantityMilli);

  /// Reconstrói um item imutável depois de uma alteração da interface.
  ShoppingItem copyWith({
    String? name,
    int? quantityMilli,
    String? unit,
    int? unitPriceCents,
    bool? checked,
  }) => ShoppingItem(
    id: id,
    name: name ?? this.name,
    quantityMilli: quantityMilli ?? this.quantityMilli,
    unit: unit ?? this.unit,
    unitPriceCents: unitPriceCents ?? this.unitPriceCents,
    checked: checked ?? this.checked,
  );

  /// O mesmo contrato serve ao backup; o banco usa suas próprias colunas.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantityMilli': quantityMilli,
    'unit': unit,
    'unitPriceCents': unitPriceCents,
    'checked': checked,
  };
  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: json['id'] as String,
    name: json['name'] as String,
    quantityMilli: json['quantityMilli'] as int,
    unit: json['unit'] as String,
    unitPriceCents: json['unitPriceCents'] as int,
    checked: json['checked'] as bool,
  );
}

/// Lista planejada, separada das compras efetivamente registradas no histórico.
class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    required this.createdAt,
    this.completed = false,
    this.items = const [],
  });
  final String id;
  final String name;
  final DateTime createdAt;
  final bool completed;
  final List<ShoppingItem> items;
  int get totalCents => items.fold(0, (sum, item) => sum + item.totalCents);
  int get checkedCount => items.where((item) => item.checked).length;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'completed': completed,
    'items': items.map((item) => item.toJson()).toList(),
  };
  factory ShoppingList.fromJson(Map<String, dynamic> json) => ShoppingList(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    completed: json['completed'] as bool,
    items: (json['items'] as List)
        .map(
          (item) =>
              ShoppingItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
}

/// Linha fiscal preserva a descrição e o total original, inclusive arredondamentos.
class ReceiptLine {
  const ReceiptLine({
    required this.description,
    required this.quantityMilli,
    required this.unit,
    required this.unitPriceCents,
    required this.totalCents,
  });
  final String description;
  final int quantityMilli;
  final String unit;
  final int unitPriceCents;
  final int totalCents;
  Map<String, dynamic> toJson() => {
    'description': description,
    'quantityMilli': quantityMilli,
    'unit': unit,
    'unitPriceCents': unitPriceCents,
    'totalCents': totalCents,
  };
  factory ReceiptLine.fromJson(Map<String, dynamic> json) => ReceiptLine(
    description: json['description'] as String,
    quantityMilli: json['quantityMilli'] as int,
    unit: json['unit'] as String,
    unitPriceCents: json['unitPriceCents'] as int,
    totalCents: json['totalCents'] as int,
  );
}

/// Rascunho de compra: pode vir da consulta, OCR ou entrada manual.
class ReceiptDraft {
  const ReceiptDraft({
    required this.merchant,
    required this.issuedAt,
    required this.items,
    this.accessKey,
    this.totalCents,
    this.source = 'manual',
    this.sourceUrl,
  });
  final String merchant;
  final DateTime issuedAt;
  final List<ReceiptLine> items;
  final String? accessKey;
  final int? totalCents;
  final String source;
  final String? sourceUrl;
  int get itemsTotal => items.fold(0, (sum, item) => sum + item.totalCents);
  Map<String, dynamic> toJson() => {
    'merchant': merchant,
    'issuedAt': issuedAt.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
    'accessKey': accessKey,
    'totalCents': totalCents,
    'source': source,
    'sourceUrl': sourceUrl,
  };
  factory ReceiptDraft.fromJson(Map<String, dynamic> json) => ReceiptDraft(
    merchant: json['merchant'] as String,
    issuedAt:
        DateTime.tryParse(json['issuedAt'] as String? ?? '') ?? DateTime.now(),
    items: (json['items'] as List)
        .map(
          (item) =>
              ReceiptLine.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    accessKey: json['accessKey'] as String?,
    totalCents: json['totalCents'] as int?,
    source: json['source'] as String? ?? 'manual',
    sourceUrl: json['sourceUrl'] as String?,
  );
}

/// Registro salvo é um rascunho confirmado com identidade própria e vínculo opcional.
class Purchase {
  const Purchase({required this.id, required this.receipt, this.listId});
  final String id;
  final ReceiptDraft receipt;
  final String? listId;
  int get totalCents => receipt.totalCents ?? receipt.itemsTotal;
  Map<String, dynamic> toJson() => {
    'id': id,
    'listId': listId,
    'receipt': receipt.toJson(),
  };
  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
    id: json['id'] as String,
    listId: json['listId'] as String?,
    receipt: ReceiptDraft.fromJson(
      Map<String, dynamic>.from(json['receipt'] as Map),
    ),
  );
}
