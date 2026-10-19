import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/formatters.dart';
import '../domain/models.dart';

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
  const units = ['un', 'kg', 'g', 'l', 'ml', 'pct', 'cx', 'pc', 'lt', 'und'];
  var unit = units.contains(original?.unit) ? original!.unit : 'un';
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
                const SizedBox(height: 12),
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
                      unitPriceCents: parseScaled(price.text, 2),
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
