import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../domain/models.dart';
import 'app_view_model.dart';
import 'dialogs.dart';
import 'widgets.dart';

/// Conferência explícita antes de transformar leitura automática em histórico persistente.
class ReceiptReviewScreen extends StatefulWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.model,
    required this.draft,
    this.listId,
  });
  final AppViewModel model;
  final ReceiptDraft draft;
  final String? listId;
  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _merchant;
  late final TextEditingController _total;
  late final List<ReceiptLine> _items;
  late DateTime _date;
  String? _listId;
  bool _saving = false;
  bool _totalEdited = false;

  @override
  void initState() {
    super.initState();
    _merchant = TextEditingController(text: widget.draft.merchant);
    _items = [...widget.draft.items];
    _date = widget.draft.issuedAt;
    _listId = widget.listId;
    _total = TextEditingController(
      text: decimalInput(widget.draft.totalCents ?? widget.draft.itemsTotal),
    );
  }

  @override
  void dispose() {
    _merchant.dispose();
    _total.dispose();
    super.dispose();
  }

  /// Atualizações locais conservam o total fiscal informado; soma automática só sem total original.
  void _updateItems(VoidCallback action) => setState(() {
    action();
    if (widget.draft.totalCents == null && !_totalEdited) {
      _total.text = decimalInput(
        _items.fold<int>(0, (sum, item) => sum + item.totalCents),
      );
    }
  });

  Future<void> _editLine([int? index]) async {
    final original = index == null ? null : _items[index];
    final edit = await editProduct(
      context,
      receipt: true,
      fiscalTotal: original?.totalCents,
      original: original == null
          ? null
          : ShoppingItem(
              id: 'draft',
              name: original.description,
              quantityMilli: original.quantityMilli,
              unit: original.unit,
              unitPriceCents: original.unitPriceCents,
            ),
    );
    if (edit == null || !mounted) return;
    final line = ReceiptLine(
      description: edit.item.name,
      quantityMilli: edit.item.quantityMilli,
      unit: edit.item.unit,
      unitPriceCents: edit.item.unitPriceCents,
      totalCents: edit.totalCents,
    );
    _updateItems(() {
      if (index == null) {
        _items.add(line);
      } else {
        _items[index] = line;
      }
    });
  }

  /// Salva uma transação completa; erros deixam o formulário preenchido para correção.
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_items.isEmpty) {
      showMessage(context, 'Adicione pelo menos um produto.');
      return;
    }
    final paid = parseScaled(_total.text, 2);
    final sum = _items.fold<int>(0, (value, item) => value + item.totalCents);
    if (paid != sum &&
        !await confirmAction(
          context,
          'Conferir diferença',
          'A soma dos produtos é ${money(sum)} e o total pago é ${money(paid)}. Confirme se a diferença corresponde a descontos ou outros ajustes da nota.',
          action: 'Salvar assim',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final receipt = ReceiptDraft(
        merchant: _merchant.text.trim(),
        issuedAt: _date,
        items: List.unmodifiable(_items),
        totalCents: paid,
        accessKey: widget.draft.accessKey,
        source: widget.draft.source,
        sourceUrl: widget.draft.sourceUrl,
      );
      await widget.model.change(
        () => widget.model.repository.savePurchase(receipt, listId: _listId),
      );
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (mounted) showMessage(context, error.message);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Não foi possível salvar a compra. Seus dados preenchidos continuam aqui.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableLists = widget.model.lists
        .where((list) => !list.completed || list.id == _listId)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Conferir compra')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SectionHeader(
              'Tudo certo com a nota?',
              subtitle: 'Confira os produtos, a data e o valor pago.',
            ),
            if (widget.draft.source == 'ocr')
              const NoteBox(
                'Leitura por foto pode omitir produtos ou confundir números. Compare os itens abaixo com a nota e corrija antes de salvar.',
                warning: true,
              ),
            if (widget.draft.source == 'sefaz')
              const NoteBox(
                'Dados obtidos na consulta fiscal. Confira a compra antes de salvar.',
              ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _merchant,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Supermercado / estabelecimento',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe o estabelecimento.'
                  : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Data da compra'),
              subtitle: Text(shortDate(_date)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final chosen = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (chosen != null && mounted) setState(() => _date = chosen);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _listId ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Associar a uma lista',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Somente salvar no histórico'),
                ),
                ...availableLists.map(
                  (list) => DropdownMenuItem(
                    value: list.id,
                    child: Text(list.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) =>
                        setState(() => _listId = value == '' ? null : value),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_items.length} produtos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : () => _editLine(),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_items.isEmpty)
              const NoteBox(
                'Nenhum produto foi reconhecido. Você pode adicionar os itens manualmente ou voltar e usar uma foto mais nítida.',
                warning: true,
              ),
            for (var index = 0; index < _items.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    onTap: _saving ? null : () => _editLine(index),
                    title: Text(_items[index].description),
                    subtitle: Text(
                      '${quantity(_items[index].quantityMilli)} ${_items[index].unit} × ${money(_items[index].unitPriceCents)}\n${money(_items[index].totalCents)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Remover item',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _saving
                          ? null
                          : () => _updateItems(() => _items.removeAt(index)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'Soma dos produtos: ${money(_items.fold<int>(0, (sum, item) => sum + item.totalCents))}',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _total,
              decoration: const InputDecoration(
                labelText: 'Total efetivamente pago',
                prefixText: 'R\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _totalEdited = true,
              validator: (value) {
                try {
                  parseScaled(value ?? '', 2);
                  return null;
                } on FormatException catch (error) {
                  return error.message;
                }
              },
            ),
            const SizedBox(height: 24),
            if (_listId != null)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: NoteBox(
                  'Ao salvar, a lista associada será marcada como concluída.',
                  icon: Icons.task_alt,
                ),
              ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Salvando…' : 'Conferi, salvar compra'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
