import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import 'app_view_model.dart';
import 'dialogs.dart';
import 'history_screen.dart';
import 'list_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
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
  bool _creating = false;

  /// O nome validado é persistido antes de abrir a lista recém-criada.
  Future<void> _newList() async {
    final mode = await chooseListCreation(context);
    if (mode == null || !mounted) return;
    final previous = DateTime(DateTime.now().year, DateTime.now().month - 1);
    final name = await askName(
      context,
      initial: mode == ListCreation.previousMonth
          ? 'Compras de ${DateFormat('MMMM', 'pt_BR').format(DateTime.now())}'
          : '',
      title: mode == ListCreation.previousMonth
          ? 'Repetir mês anterior'
          : 'Nova lista',
    );
    if (name == null || !mounted) return;
    List<ShoppingItem>? bulk;
    if (mode == ListCreation.bulk) {
      bulk = await askBulkProducts(context);
      if (bulk == null || !mounted) return;
    }
    setState(() => _creating = true);
    try {
      final String? id;
      if (mode == ListCreation.previousMonth) {
        id = await widget.model.repository.createListFromPreviousMonth(name);
      } else {
        id = await widget.model.repository.createList(
          name,
          items: bulk ?? const [],
        );
      }
      if (id == null) {
        if (mounted) {
          showMessage(
            context,
            'Nenhuma compra em ${DateFormat('MMMM yyyy', 'pt_BR').format(previous)}. Salve uma nota no histórico para usar esta opção.',
          );
        }
        return;
      }
      await widget.model.load();
      if (mounted) {
        setState(() => _completed = false);
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ListScreen(model: widget.model, listId: id!),
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
    } finally {
      if (mounted) setState(() => _creating = false);
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
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, Color(0xFF8B62D9)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFFCBB9),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'BORA ORGANIZAR?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Menos correria.\nMais organização.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sua lista do seu jeito. Um item, vários de uma vez ou a compra do mês passado.',
                  style: TextStyle(color: Color(0xFFF0E9FF), height: 1.4),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD3BD),
                    foregroundColor: AppColors.ink,
                  ),
                  onPressed: _creating ? null : _newList,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_creating ? 'Criando…' : 'Nova lista'),
                ),
              ],
            ),
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
          const SectionHeader(
            'Minhas listas',
            subtitle: 'Tudo que falta para a próxima compra.',
          ),
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
                  : 'Crie uma lista, adicione produtos e vá marcando o que já está no carrinho.',
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

  /// Cada cartão resume o progresso; valores pertencem ao histórico de compras.
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
              backgroundColor: index.isEven
                  ? AppColors.lavender
                  : const Color(0xFFFFE7DD),
              foregroundColor: index.isEven
                  ? AppColors.primary
                  : const Color(0xFFAC4933),
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
                    '${list.checkedCount} de ${list.items.length} itens no carrinho',
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
                      backgroundColor: AppColors.lavender,
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
