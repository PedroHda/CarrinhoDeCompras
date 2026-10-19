import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/formatters.dart';
import '../domain/history_period.dart';
import '../domain/models.dart';
import 'app_view_model.dart';
import 'dialogs.dart';
import 'widgets.dart';

/// Pesquisa por estabelecimento ou produto com períodos do calendário local.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.model});
  final AppViewModel model;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _search = '';
  HistoryPeriod _period = HistoryPeriod.all;
  DateTime _reference = DateTime.now();

  String _periodName(HistoryPeriod period) => switch (period) {
    HistoryPeriod.day => 'Dia',
    HistoryPeriod.week => 'Semana',
    HistoryPeriod.month => 'Mês',
    HistoryPeriod.year => 'Ano',
    HistoryPeriod.all => 'Tudo',
  };

  String _rangeLabel(HistoryDateRange? range) {
    if (range == null) return 'Todo o período';
    return switch (_period) {
      HistoryPeriod.day => DateFormat(
        'dd MMM yyyy',
        'pt_BR',
      ).format(range.start),
      HistoryPeriod.week =>
        '${DateFormat('dd/MM/yyyy').format(range.start)} a '
            '${DateFormat('dd/MM/yyyy').format(DateTime(range.end.year, range.end.month, range.end.day - 1))}',
      HistoryPeriod.month => DateFormat(
        'MMMM yyyy',
        'pt_BR',
      ).format(range.start),
      HistoryPeriod.year => DateFormat('yyyy').format(range.start),
      HistoryPeriod.all => 'Todo o período',
    };
  }

  Future<void> _chooseReference() async {
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2200, 12, 31);
    final initialDate = _reference.isBefore(firstDate)
        ? firstDate
        : _reference.isAfter(lastDate)
        ? lastDate
        : _reference;
    final chosen = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Escolha uma data do período',
    );
    if (chosen != null && mounted) setState(() => _reference = chosen);
  }

  void _movePeriod(int offset) => setState(
    () => _reference = shiftHistoryReference(_period, _reference, offset),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final range = historyDateRange(_period, _reference);
    final search = _search.trim().toLowerCase();
    final filtered =
        widget.model.purchases
            .where(
              (purchase) =>
                  (range == null ||
                      range.contains(purchase.receipt.issuedAt)) &&
                  '${purchase.receipt.merchant} ${purchase.receipt.items.map((item) => item.description).join(' ')}'
                      .toLowerCase()
                      .contains(search),
            )
            .toList()
          ..sort((a, b) => b.receipt.issuedAt.compareTo(a.receipt.issuedAt));
    final total = filtered.fold<int>(
      0,
      (sum, purchase) => sum + purchase.totalCents,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      children: [
        const SectionHeader(
          'Histórico',
          subtitle: 'O que você comprou, quando e por quanto.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final period in HistoryPeriod.values)
              ChoiceChip(
                label: Text(_periodName(period)),
                selected: _period == period,
                onSelected: (_) => setState(() => _period = period),
              ),
          ],
        ),
        if (range != null) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Período anterior',
                    onPressed: () => _movePeriod(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _chooseReference,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _rangeLabel(range),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Toque para escolher a data',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Próximo período',
                    onPressed: () => _movePeriod(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _reference = DateTime.now()),
              icon: const Icon(Icons.today_outlined, size: 17),
              label: const Text('Período atual'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.onPrimary.withValues(alpha: 0.18),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rangeLabel(range),
                      style: TextStyle(color: colors.onPrimary),
                    ),
                    Text(
                      money(total),
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'compra' : 'compras'}${search.isEmpty ? '' : ' na busca'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar mercado ou produto',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 18),
        if (filtered.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: search.isNotEmpty
                ? 'Nenhuma compra encontrada'
                : range != null
                ? 'Nenhuma compra neste período'
                : 'Cada compra conta uma história',
            description: search.isNotEmpty
                ? 'Tente outro mercado ou produto, ou mude o período.'
                : range != null
                ? 'Escolha outra data ou toque em Tudo para ver suas compras.'
                : 'Importe uma nota para guardar os produtos, quantidades e valores pagos aqui.',
          ),
        for (final purchase in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: colors.primary.withValues(alpha: 0.10),
                  child: Icon(Icons.storefront_outlined, color: colors.primary),
                ),
                title: Text(
                  purchase.receipt.merchant,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${shortDate(purchase.receipt.issuedAt)} • ${purchase.receipt.items.length} itens\n${money(purchase.totalCents)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PurchaseScreen(model: widget.model, purchase: purchase),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Exibe valores originais e a origem informada; não altera compras já confirmadas.
class PurchaseScreen extends StatelessWidget {
  const PurchaseScreen({
    super.key,
    required this.model,
    required this.purchase,
  });
  final AppViewModel model;
  final Purchase purchase;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalhes da compra'),
      actions: [
        IconButton(
          tooltip: 'Excluir compra',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            if (!await confirmAction(
                  context,
                  'Excluir compra?',
                  'A compra será removida do histórico. A lista original será preservada.',
                ) ||
                !context.mounted) {
              return;
            }
            try {
              await model.change(
                () => model.repository.deletePurchase(purchase.id),
              );
              if (context.mounted) Navigator.pop(context);
            } catch (_) {
              if (context.mounted) {
                showMessage(context, 'Não foi possível excluir a compra.');
              }
            }
          },
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        SectionHeader(
          purchase.receipt.merchant,
          subtitle: shortDate(purchase.receipt.issuedAt),
        ),
        NoteBox(
          purchase.receipt.source == 'ocr'
              ? 'Origem: foto da nota, conferida antes de salvar.'
              : purchase.receipt.source == 'sefaz'
              ? 'Origem: consulta da NFC-e, conferida antes de salvar.'
              : 'Origem: registro manual conferido.',
        ),
        const SizedBox(height: 20),
        for (final item in purchase.receipt.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                title: Text(item.description),
                subtitle: Text(
                  '${quantity(item.quantityMilli)} ${item.unit} × ${money(item.unitPriceCents)}',
                ),
                trailing: Text(
                  money(item.totalCents),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Total pago: ${money(purchase.totalCents)}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (purchase.totalCents != purchase.receipt.itemsTotal)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Soma dos itens: ${money(purchase.receipt.itemsTotal)}. A diferença foi preservada no registro da compra.',
            ),
          ),
        if (purchase.receipt.accessKey != null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: SelectableText(
              'Chave da NFC-e\n${purchase.receipt.accessKey}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    ),
  );
}
