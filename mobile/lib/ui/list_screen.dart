import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../domain/models.dart';
import 'app_view_model.dart';
import 'dialogs.dart';
import 'receipt_review_screen.dart';
import 'scan_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.model, required this.listId});
  final AppViewModel model;
  final String listId;
  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  String _search = '';
  final _removing = <String>{};
  final _busyItems = <String>{};
  final _itemVersions = <String, int>{};

  Future<bool> _write(Future<void> Function() action) async {
    try {
      await widget.model.change(action);
      return true;
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Não foi possível salvar. Tente novamente.');
      }
      return false;
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

  Future<void> _bulk() async {
    final items = await askBulkProducts(context);
    if (items == null) return;
    final saved = await _write(
      () => widget.model.repository.addItems(widget.listId, items),
    );
    if (saved && mounted) {
      showMessage(context, '${items.length} produtos adicionados.');
    }
  }

  Future<void> _update(ShoppingItem item) async {
    if (_busyItems.contains(item.id)) return;
    setState(() => _busyItems.add(item.id));
    await _write(() => widget.model.repository.saveItem(widget.listId, item));
    if (mounted) setState(() => _busyItems.remove(item.id));
  }

  /// Desfazer recupera também a posição e a quantidade do produto.
  Future<void> _remove(ShoppingItem item, ShoppingList list) async {
    if (_removing.contains(item.id) || _busyItems.contains(item.id)) return;
    final index = list.items.indexWhere((entry) => entry.id == item.id);
    final nextId = index >= 0 && index + 1 < list.items.length
        ? list.items[index + 1].id
        : null;
    setState(() => _removing.add(item.id));
    final saved = await _write(
      () => widget.model.repository.deleteItem(item.id),
    );
    if (!mounted) return;
    setState(() {
      _removing.remove(item.id);
      // Recria a animação se a gravação falhar antes do próximo frame.
      if (!saved) _itemVersions[item.id] = (_itemVersions[item.id] ?? 0) + 1;
    });
    if (!saved) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.name} removido'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              _write(
                () => widget.model.repository.restoreItem(
                  widget.listId,
                  item,
                  beforeItemId: nextId,
                ),
              );
            },
          ),
        ),
      );
  }

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
      final saved = await _write(() async {
        await widget.model.repository.duplicateList(list);
      });
      if (saved && mounted) {
        showMessage(context, 'Cópia criada em Minhas listas.');
      }
    } else if (action == 'delete') {
      if (!await confirmAction(
            context,
            'Excluir lista?',
            'Os itens desta lista serão removidos. Compras registradas continuam no histórico.',
          ) ||
          !mounted) {
        return;
      }
      final saved = await _write(
        () => widget.model.repository.deleteList(list.id),
      );
      if (saved && mounted) Navigator.pop(context);
    }
  }

  /// Valores são informados na conferência, sem reutilizar estimativas antigas.
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
              unitPriceCents: 0,
              totalCents: 0,
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

  Widget _itemCard(ShoppingItem item, ShoppingList list) {
    final busy = _busyItems.contains(item.id);
    final step = {'kg', 'l', 'lt'}.contains(item.unit.toLowerCase())
        ? 100
        : 1000;
    final card = Card(
      color: item.checked ? AppColors.mint : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 6, 8),
        child: Row(
          children: [
            Checkbox(
              semanticLabel: 'Marcar ${item.name}',
              value: item.checked,
              activeColor: AppColors.green,
              onChanged: list.completed || busy
                  ? null
                  : (value) => _update(item.copyWith(checked: value)),
            ),
            Expanded(
              child: InkWell(
                onTap: list.completed || busy ? null : () => _edit(item),
                borderRadius: BorderRadius.circular(10),
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
                          color: item.checked ? AppColors.green : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${quantity(item.quantityMilli)} ${item.unit}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!list.completed) ...[
              IconButton(
                tooltip: 'Diminuir quantidade de ${item.name}',
                onPressed: busy || item.quantityMilli <= step
                    ? null
                    : () => _update(
                        item.copyWith(quantityMilli: item.quantityMilli - step),
                      ),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
              ),
              IconButton(
                tooltip: 'Aumentar quantidade de ${item.name}',
                onPressed: busy
                    ? null
                    : () => _update(
                        item.copyWith(quantityMilli: item.quantityMilli + step),
                      ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                color: AppColors.primary,
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções de ${item.name}',
                enabled: !busy,
                onSelected: (value) =>
                    value == 'edit' ? _edit(item) : _remove(item, list),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ] else
              const SizedBox(width: 16),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: list.completed
          ? card
          : Dismissible(
              key: ValueKey('${item.id}:${_itemVersions[item.id] ?? 0}'),
              direction: busy
                  ? DismissDirection.none
                  : DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDCD6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFB33732),
                ),
              ),
              onDismissed: (_) => _remove(item, list),
              child: card,
            ),
    );
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
            (item) =>
                !_removing.contains(item.id) &&
                item.name.toLowerCase().contains(_search.toLowerCase()),
          )
          .toList();
      final pending = items.where((item) => !item.checked).toList();
      final checked = items.where((item) => item.checked).toList();
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            SectionHeader(
              list.name,
              subtitle:
                  '${list.items.length} itens • ${list.checkedCount} no carrinho',
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.lavender,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_basket_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          list.completed
                              ? 'Compra concluída!'
                              : list.items.isNotEmpty &&
                                    list.checkedCount == list.items.length
                              ? 'Tudo no carrinho!'
                              : 'Faltam ${list.items.length - list.checkedCount} itens',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Text(
                        '${list.items.isEmpty ? 0 : (100 * list.checkedCount / list.items.length).round()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: list.items.isEmpty
                          ? 0
                          : list.checkedCount / list.items.length,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (list.completed)
              const NoteBox(
                'Use “Duplicar lista” para planejar sua próxima compra.',
                icon: Icons.task_alt,
              )
            else ...[
              FilledButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar produto'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _bulk,
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Adicionar vários de uma vez'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Toque para editar · Deslize para a esquerda para excluir',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar produto',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              EmptyState(
                icon: Icons.playlist_add,
                title: _search.isEmpty
                    ? 'Tudo começa com um produto'
                    : 'Nenhum produto encontrado',
                description: _search.isEmpty
                    ? 'Adicione um produto ou cole vários de uma vez. Depois, é só marcar o que já pegou.'
                    : 'Experimente outro nome.',
              ),
            if (pending.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'FALTA PEGAR',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                  ),
                ),
              ),
              for (final item in pending) _itemCard(item, list),
            ],
            if (checked.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 12),
                child: Text(
                  'NO CARRINHO',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
              ),
              for (final item in checked) _itemCard(item, list),
            ],
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
                  label: const Text('Ler nota e salvar no histórico'),
                ),
              ),
          ],
        ),
        bottomNavigationBar: list.completed
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${list.checkedCount} de ${list.items.length}\nno carrinho',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        flex: 2,
                        child: FilledButton(
                          onPressed: list.items.isEmpty
                              ? null
                              : () => _finish(list),
                          child: const Text('Concluir compra'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}
