import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../domain/models.dart';
import 'app_view_model.dart';
import 'dialogs.dart';
import 'receipt_review_screen.dart';
import 'scan_screen.dart';
import 'widgets.dart';

/// Detalhes editáveis da lista; operações de banco passam pelo modelo/repositório.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.model, required this.listId});
  final AppViewModel model;
  final String listId;
  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  String _search = '';

  /// Captura erros de gravação sem marcar uma operação malsucedida como concluída.
  Future<void> _write(Future<void> Function() action) async {
    try {
      await widget.model.change(action);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Não foi possível salvar. Tente novamente.');
      }
    }
  }

  Future<void> _edit([ShoppingItem? original]) async {
    final result = await editProduct(context, original: original);
    if (result != null) {
      await _write(
        () => widget.model.repository.saveItem(widget.listId, result.item),
      );
    }
  }

  /// Opções mantêm identidade e histórico de preços dos registros anteriores.
  Future<void> _menu(String action, ShoppingList list) async {
    if (action == 'rename') {
      final name = await askName(
        context,
        title: 'Renomear lista',
        initial: list.name,
      );
      if (name != null) {
        await _write(() => widget.model.repository.renameList(list.id, name));
      }
    } else if (action == 'duplicate') {
      await _write(() async {
        await widget.model.repository.duplicateList(list);
      });
      if (mounted) showMessage(context, 'Cópia criada em Minhas listas.');
    } else if (action == 'delete') {
      if (!await confirmAction(
            context,
            'Excluir lista?',
            'Os itens desta lista serão removidos. Compras já registradas continuam no histórico.',
          ) ||
          !mounted) {
        return;
      }
      await _write(() => widget.model.repository.deleteList(list.id));
      if (mounted) Navigator.pop(context);
    }
  }

  /// Finalização manual usa apenas itens marcados e exige a conferência dos valores.
  Future<void> _finish(ShoppingList list) async {
    final selected = list.items.where((item) => item.checked).toList();
    if (selected.isEmpty) {
      showMessage(
        context,
        'Marque os produtos que você comprou antes de concluir.',
      );
      return;
    }
    final draft = ReceiptDraft(
      merchant: '',
      issuedAt: DateTime.now(),
      source: 'manual',
      items: selected
          .map(
            (item) => ReceiptLine(
              description: item.name,
              quantityMilli: item.quantityMilli,
              unit: item.unit,
              unitPriceCents: item.unitPriceCents,
              totalCents: item.totalCents,
            ),
          )
          .toList(),
    );
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptReviewScreen(
          model: widget.model,
          draft: draft,
          listId: list.id,
        ),
      ),
    );
    if (saved == true && mounted) {
      showMessage(context, 'Compra salva no histórico.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final list = widget.model.listById(widget.listId);
      if (list == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final items = list.items
          .where(
            (item) => item.name.toLowerCase().contains(_search.toLowerCase()),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sua lista'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) => _menu(value, list),
              itemBuilder: (_) => [
                if (!list.completed)
                  const PopupMenuItem(value: 'rename', child: Text('Renomear')),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Text('Duplicar lista'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Excluir lista'),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          children: [
            SectionHeader(
              list.name,
              subtitle:
                  '${list.items.length} itens • ${list.checkedCount} comprados',
            ),
            if (list.completed)
              const NoteBox(
                'Lista concluída. Use “Duplicar lista” para planejar uma nova compra.',
                icon: Icons.task_alt,
              ),
            if (!list.completed)
              FilledButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar produto'),
              ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar produto',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.playlist_add,
                title: 'Tudo começa com um produto',
                description: 'Informe quantidade e preço para acompanhar a estimativa. O preço pode ser preenchido depois.',
              ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Checkbox(
                          value: item.checked,
                          onChanged: list.completed
                              ? null
                              : (value) => _write(
                                  () => widget.model.repository.saveItem(
                                    list.id,
                                    item.copyWith(checked: value),
                                  ),
                                ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: list.completed ? null : () => _edit(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      decoration: item.checked
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: item.checked ? Colors.grey : null,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${quantity(item.quantityMilli)} ${item.unit} × ${money(item.unitPriceCents)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            money(item.totalCents),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!list.completed)
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _edit(item);
                              } else {
                                if (!mounted ||
                                    !await confirmAction(
                                      context,
                                      'Excluir produto?',
                                      item.name,
                                    ) ||
                                    !mounted) {
                                  return;
                                }
                                await _write(
                                  () => widget.model.repository.deleteItem(
                                    item.id,
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Excluir'),
                              ),
                            ],
                          )
                        else
                          const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ),
              ),
            if (!list.completed)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ScanScreen(model: widget.model, listId: list.id),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Importar nota desta compra'),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE4EBE5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total estimado',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        money(list.totalCents),
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!list.completed)
                  FilledButton(
                    onPressed: list.items.isEmpty ? null : () => _finish(list),
                    child: const Text('Concluir compra'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
