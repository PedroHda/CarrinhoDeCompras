import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../domain/models.dart';
import 'app_view_model.dart';
import 'dialogs.dart';
import 'history_screen.dart';
import 'list_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// Navegação principal conserva o estado das três abas durante a sessão.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.model});
  final AppViewModel model;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _completed = false;
  String _search = '';

  /// O nome validado é persistido antes de abrir a lista recém-criada.
  Future<void> _newList() async {
    final name = await askName(context);
    if (name == null || !mounted) return;
    try {
      final id = await widget.model.repository.createList(name);
      await widget.model.load();
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ListScreen(model: widget.model, listId: id),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Não foi possível criar a lista. Tente novamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model;
      return Scaffold(
        // SafeArea evita sobreposição com câmera frontal, gestos e barras do Android.
        body: SafeArea(
          child: model.loading
              ? const Center(child: CircularProgressIndicator())
              : model.loadError != null
              ? Center(child: Text(model.loadError!))
              : IndexedStack(
                  index: _tab,
                  children: [
                    _lists(model),
                    HistoryScreen(model: model),
                    SettingsScreen(model: model),
                  ],
                ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.checklist_rounded),
              label: 'Listas',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: 'Histórico',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              label: 'Ajustes',
            ),
          ],
        ),
      );
    },
  );

  /// Lista responsiva de cartões, com filtro separado para compras concluídas.
  Widget _lists(AppViewModel model) {
    final lists = model.lists
        .where(
          (list) =>
              list.completed == _completed &&
              list.name.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: model.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'CARRINHO DE COMPRAS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.phonelink_lock_outlined,
                size: 20,
                color: Color(0xFF63836D),
              ),
            ],
          ),
          const SectionHeader(
            'Minhas listas',
            subtitle: 'Sua próxima compra começa aqui.',
          ),
          FilledButton.icon(
            onPressed: _newList,
            icon: const Icon(Icons.add),
            label: const Text('Nova lista'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => ScanScreen(model: model)),
            ),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear ou fotografar nota'),
          ),
          const SizedBox(height: 22),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar uma lista',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Em andamento')),
              ButtonSegment(value: true, label: Text('Concluídas')),
            ],
            selected: {_completed},
            onSelectionChanged: (values) =>
                setState(() => _completed = values.first),
          ),
          const SizedBox(height: 20),
          if (lists.isEmpty)
            EmptyState(
              icon: _completed
                  ? Icons.task_alt
                  : Icons.shopping_basket_outlined,
              title: _search.isNotEmpty
                  ? 'Nenhuma lista encontrada'
                  : _completed
                  ? 'Compras bem organizadas'
                  : 'Vamos montar sua lista?',
              description: _search.isNotEmpty
                  ? 'Experimente outro nome.'
                  : _completed
                  ? 'As listas finalizadas ficam aqui para você consultar e duplicar.'
                  : 'Adicione os produtos e acompanhe o valor estimado antes de chegar ao caixa.',
            ),
          for (var index = 0; index < lists.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _listCard(lists[index], index),
            ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined, size: 15, color: Colors.grey),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Listas e histórico disponíveis sem internet',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cada cartão resume progresso e estimativa sem modificar a lista.
  Widget _listCard(ShoppingList list, int index) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ListScreen(model: widget.model, listId: list.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE7F2EA),
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                list.completed ? Icons.task_alt : Icons.shopping_bag_outlined,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${list.checkedCount} de ${list.items.length} itens • ${money(list.totalCents)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: list.items.isEmpty
                          ? 0
                          : list.checkedCount / list.items.length,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE9EEEA),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    ),
  );
}
