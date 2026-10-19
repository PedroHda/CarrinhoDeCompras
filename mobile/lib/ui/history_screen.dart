import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/formatters.dart';
import '../domain/models.dart';
import 'app_view_model.dart';
import 'dialogs.dart';
import 'widgets.dart';

/// Pesquisa local por estabelecimento ou produto e filtro por mês de compra.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.model});
  final AppViewModel model;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _search = '';
  String _period = 'all';

  @override
  Widget build(BuildContext context) {
    String periodKey(Purchase purchase) =>
        DateFormat('yyyy-MM').format(purchase.receipt.issuedAt);
    final months = widget.model.purchases.map(periodKey).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (_period != 'all' && !months.contains(_period)) _period = 'all';
    final filtered = widget.model.purchases
        .where(
          (purchase) =>
              (_period == 'all' || periodKey(purchase) == _period) &&
              '${purchase.receipt.merchant} ${purchase.receipt.items.map((item) => item.description).join(' ')}'
                  .toLowerCase()
                  .contains(_search.toLowerCase()),
        )
        .toList();
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
        DropdownButtonFormField<String>(
          initialValue: _period,
          decoration: const InputDecoration(
            labelText: 'Período',
            prefixIcon: Icon(Icons.calendar_month_outlined),
          ),
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('Todos os períodos'),
            ),
            ...months.map(
              (month) => DropdownMenuItem(
                value: month,
                child: Text(
                  DateFormat(
                    'MMMM yyyy',
                    'pt_BR',
                  ).format(DateTime.parse('$month-01')),
                ),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _period = value!),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F1E5),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFCBE7D4),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFF147D50),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total no período'),
                    Text(
                      money(total),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${filtered.length} compras',
                      style: const TextStyle(fontSize: 12),
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
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Cada compra conta uma história',
            description: 'Conclua uma lista ou importe uma nota. Os produtos e valores pagos ficam registrados aqui.',
          ),
        for (final purchase in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F2EB),
                  child: Icon(
                    Icons.storefront_outlined,
                    color: Color(0xFF147D50),
                  ),
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
