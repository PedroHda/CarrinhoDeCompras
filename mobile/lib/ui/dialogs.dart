import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/formatters.dart';
import '../domain/models.dart';
import '../domain/list_input.dart';
import 'theme.dart';

/// Solicita um nome validado e libera o controlador depois de fechar o diálogo.
Future<String?> askName(
  BuildContext context, {
  String title = 'Nova lista',
  String initial = '',
  String label = 'Nome da lista',
  int maxLength = 120,
}) async {
  final controller = TextEditingController(text: initial);
  final form = GlobalKey<FormState>();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Ex.: Compra da semana',
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Digite um nome.' : null,
          onFieldSubmitted: (_) {
            if (form.currentState!.validate()) {
              Navigator.pop(dialogContext, controller.text.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(dialogContext, controller.text.trim());
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  // Espera a animação de fechamento antes de descartar o controlador do formulário.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  controller.dispose();
  return value;
}

/// Confirma ações destrutivas dentro do aplicativo, como excluir ou restaurar dados.
Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message, {
  String action = 'Excluir',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

/// Resultado comum permite reutilizar o formulário para lista e linha de nota fiscal.
class ProductEdit {
  const ProductEdit(this.item, this.totalCents);
  final ShoppingItem item;
  final int totalCents;
}

enum ListCreation { manual, bulk, previousMonth }

Future<ListCreation?> chooseListCreation(BuildContext context) =>
    showModalBottomSheet<ListCreation>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Text(
                  'Como vamos começar?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              for (final option in [
                (
                  ListCreation.manual,
                  Icons.add_shopping_cart_rounded,
                  'Item a item',
                  'Escolha produtos e quantidades no seu ritmo.',
                ),
                (
                  ListCreation.bulk,
                  Icons.playlist_add_rounded,
                  'Vários de uma vez',
                  'Digite ou cole um produto por linha.',
                ),
                (
                  ListCreation.previousMonth,
                  Icons.auto_awesome_rounded,
                  'Repetir mês anterior',
                  'Todos os produtos comprados, com as quantidades.',
                ),
              ])
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lavender,
                      foregroundColor: AppColors.primary,
                      child: Icon(option.$2),
                    ),
                    title: Text(
                      option.$3,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(option.$4),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, option.$1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

/// Um produto por linha; a prévia usa a mesma interpretação da gravação.
Future<List<ShoppingItem>?> askBulkProducts(BuildContext context) =>
    showModalBottomSheet<List<ShoppingItem>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _BulkProductsSheet(),
    );

class _BulkProductsSheet extends StatefulWidget {
  const _BulkProductsSheet();
  @override
  State<_BulkProductsSheet> createState() => _BulkProductsSheetState();
}

class _BulkProductsSheetState extends State<_BulkProductsSheet> {
  final _controller = TextEditingController();
  List<ShoppingItem> _items = [];
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _preview(String input) {
    setState(() {
      try {
        _items = parseShoppingItems(input);
        _error = null;
      } on FormatException catch (error) {
        _items = [];
        _error = error.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vários de uma vez',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Um produto por linha. Sem quantidade, adicionamos 1 unidade.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('bulk-input'),
            controller: _controller,
            autofocus: true,
            minLines: 5,
            maxLines: 8,
            maxLength: 30000,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            onChanged: _preview,
            decoration: InputDecoration(
              labelText: 'Seus produtos',
              alignLabelWithHint: true,
              hintText: 'Arroz\n2x Leite\n1,5 kg Banana',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          if (_items.isNotEmpty) ...[
            Text(
              '${_items.length} produtos para adicionar',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in _items.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${quantity(item.quantityMilli)} ${item.unit} · ${item.name}',
                ),
              ),
            if (_items.length > 4)
              Text('E mais ${_items.length - 4} produtos…'),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _items.isEmpty || _error != null
                ? null
                : () => Navigator.pop(context, _items),
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: Text('Adicionar ${_items.length} produtos'),
          ),
        ],
      ),
    ),
  );
}

/// Quantidade, unidade, preço e total fiscal são conferidos antes de aceitar a entrada.
Future<ProductEdit?> editProduct(
  BuildContext context, {
  ShoppingItem? original,
  int? fiscalTotal,
  bool receipt = false,
}) async {
  final name = TextEditingController(text: original?.name ?? '');
  final count = TextEditingController(
    text: quantity(original?.quantityMilli ?? 1000),
  );
  final price = TextEditingController(
    text: decimalInput(original?.unitPriceCents ?? 0),
  );
  final total = TextEditingController(
    text: decimalInput(fiscalTotal ?? original?.totalCents ?? 0),
  );
  final form = GlobalKey<FormState>();
  final units = {
    'un',
    'kg',
    'g',
    'l',
    'ml',
    'pct',
    'cx',
    'pc',
    'lt',
    'und',
    if (original != null) original.unit,
  }.toList();
  var unit = original?.unit ?? 'un';
  String? numberValidator(String? value, int digits, {bool positive = false}) {
    try {
      final parsed = parseScaled(value ?? '', digits);
      return positive && parsed == 0
          ? 'Informe uma quantidade maior que zero.'
          : null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  final result = await showModalBottomSheet<ProductEdit>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  original == null ? 'Adicionar produto' : 'Editar produto',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: name,
                  autofocus: original == null,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Produto'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Digite o nome do produto.'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: count,
                        decoration: const InputDecoration(
                          labelText: 'Quantidade',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) =>
                            numberValidator(value, 3, positive: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        initialValue: unit,
                        decoration: const InputDecoration(labelText: 'Unidade'),
                        items: units
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => unit = value!),
                      ),
                    ),
                  ],
                ),
                if (receipt) const SizedBox(height: 12),
                if (receipt)
                  TextFormField(
                    controller: price,
                    decoration: const InputDecoration(
                      labelText: 'Preço por unidade / kg',
                      prefixText: 'R\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => numberValidator(value, 2),
                  ),
                if (receipt)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: total,
                      decoration: const InputDecoration(
                        labelText: 'Total desta linha na nota',
                        prefixText: 'R\$ ',
                        helperText:
                            'Preserve descontos e arredondamentos da nota.',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) => numberValidator(value, 2),
                    ),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () {
                    if (!form.currentState!.validate()) return;
                    final item = ShoppingItem(
                      id: original?.id ?? const Uuid().v4(),
                      name: name.text.trim(),
                      quantityMilli: parseScaled(count.text, 3),
                      unit: unit,
                      unitPriceCents: receipt ? parseScaled(price.text, 2) : 0,
                      checked: original?.checked ?? false,
                    );
                    Navigator.pop(
                      sheetContext,
                      ProductEdit(
                        item,
                        receipt ? parseScaled(total.text, 2) : item.totalCents,
                      ),
                    );
                  },
                  child: const Text('Salvar produto'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 250));
  for (final controller in [name, count, price, total]) {
    controller.dispose();
  }
  return result;
}
