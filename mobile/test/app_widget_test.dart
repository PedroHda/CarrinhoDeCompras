import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:carrinho_de_compras/data/local_database.dart';
import 'package:carrinho_de_compras/data/shopping_repository.dart';
import 'package:carrinho_de_compras/domain/models.dart';
import 'package:carrinho_de_compras/ui/app.dart';
import 'package:carrinho_de_compras/ui/app_view_model.dart';
import 'package:carrinho_de_compras/ui/list_screen.dart';

void main() {
  sqfliteFfiInit();
  late Database database;
  late AppViewModel model;
  late String listId;
  setUp(() async {
    await initializeDateFormatting('pt_BR');
    // Golden tests usam fontes reais, evitando os retângulos da fonte de teste Ahem.
    final font = FontLoader('AppRoboto')
      ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/roboto-medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/roboto-black.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: LocalDatabase.configure,
        onCreate: LocalDatabase.create,
      ),
    );
    final repository = ShoppingRepository(LocalDatabase(database));
    listId = await repository.createList('Compra da semana');
    await repository.saveItem(
      listId,
      const ShoppingItem(id: 'arroz', name: 'Arroz 5 kg', unitPriceCents: 2490),
    );
    await repository.saveItem(
      listId,
      const ShoppingItem(
        id: 'leite',
        name: 'Leite integral',
        quantityMilli: 3000,
        unitPriceCents: 479,
        checked: true,
      ),
    );
    model = AppViewModel(repository);
    await model.load();
  });
  tearDown(() async {
    model.dispose();
    await database.close();
  });

  Future<void> launch(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(CarrinhoApp(model: model));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openList(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Compra da semana'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapVisible(tester, find.text('Compra da semana'));
  }

  /// A escrita real do SQLite precisa de I/O fora do relógio falso dos widgets.
  Future<void> waitForChange(
    WidgetTester tester,
    bool Function() completed,
  ) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!completed() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(completed(), isTrue, reason: 'A alteração deve ser persistida.');
    });
    await tester.pumpAndSettle();
  }

  ShoppingItem item(String id) =>
      model.listById(listId)!.items.singleWhere((item) => item.id == id);

  testWidgets('Renderiza listas sem preços e navega pelo histórico e ajustes', (
    tester,
  ) async {
    await launch(tester, const Size(430, 932));
    expect(find.text('Compra da semana'), findsOneWidget);
    expect(find.text('1 de 2 itens no carrinho'), findsOneWidget);
    expect(find.textContaining('R\$'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/listas.png'),
    );
    await openList(tester);
    expect(find.text('Arroz 5 kg'), findsOneWidget);
    expect(find.text('Concluir compra'), findsOneWidget);
    expect(find.text('2 itens • 1 no carrinho'), findsOneWidget);
    expect(find.textContaining('R\$'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/lista-aberta.png'),
    );
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Histórico').last);
    await tester.pumpAndSettle();
    expect(find.text('Cada compra conta uma história'), findsOneWidget);
    for (final label in ['Dia', 'Semana', 'Mês', 'Ano', 'Tudo']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mês'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma compra neste período'), findsOneWidget);
    expect(find.byTooltip('Período anterior'), findsOneWidget);
    expect(find.text('Período atual'), findsOneWidget);
    await tester.tap(find.text('Ajustes').last);
    await tester.pumpAndSettle();
    expect(find.text('Exportar backup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cria uma lista a partir das compras do mês anterior', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      await model.repository.savePurchase(
        ReceiptDraft(
          merchant: 'Mercado de teste',
          issuedAt: DateTime(now.year, now.month - 1, 15),
          items: const [
            ReceiptLine(
              description: 'Arroz',
              quantityMilli: 2000,
              unit: 'un',
              unitPriceCents: 800,
              totalCents: 1600,
            ),
            ReceiptLine(
              description: 'Arroz',
              quantityMilli: 3000,
              unit: 'un',
              unitPriceCents: 900,
              totalCents: 2700,
            ),
            ReceiptLine(
              description: 'Banana',
              quantityMilli: 1250,
              unit: 'kg',
              unitPriceCents: 600,
              totalCents: 750,
            ),
          ],
        ),
      );
      await model.load();
    });
    await launch(tester, const Size(360, 800));
    await tapVisible(tester, find.text('Nova lista'));
    for (final option in [
      'Item a item',
      'Vários de uma vez',
      'Repetir mês anterior',
    ]) {
      expect(find.text(option).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('Repetir mês anterior'));
    final expectedName =
        'Compras de ${DateFormat('MMMM', 'pt_BR').format(now)}';
    final nameField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(nameField.controller!.text, expectedName);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Salvar'));
    await waitForChange(tester, () => model.lists.length == 2);

    final created = model.lists.singleWhere((list) => list.id != listId);
    expect(created.name, expectedName);
    expect(created.items.map((item) => item.name), ['Arroz', 'Banana']);
    expect(created.items.map((item) => item.quantityMilli), [5000, 1250]);
    expect(created.items.map((item) => item.unit), ['un', 'kg']);
    expect(
      created.items.every((item) => item.unitPriceCents == 0 && !item.checked),
      isTrue,
    );
    expect(model.purchases.single.totalCents, 5050);
    expect(find.byType(ListScreen), findsOneWidget);
    expect(find.text(expectedName), findsOneWidget);
    expect(find.textContaining('R\$'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Adiciona um produto com quantidade sem solicitar preço', (
    tester,
  ) async {
    await launch(tester, const Size(360, 800));
    await openList(tester);
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Adicionar produto'),
    );
    expect(find.text('Preço por unidade / kg'), findsNothing);
    expect(find.text('Total desta linha na nota'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Produto'),
      'Café',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade'),
      '2',
    );
    await tapVisible(tester, find.text('Salvar produto'));
    await waitForChange(
      tester,
      () => model.listById(listId)!.items.length == 3,
    );
    final coffee = model
        .listById(listId)!
        .items
        .singleWhere((item) => item.name == 'Café');
    expect(coffee.quantityMilli, 2000);
    expect(coffee.unitPriceCents, 0);
    expect(coffee.checked, isFalse);
    await tester.ensureVisible(find.text('Café'));
    await tester.pumpAndSettle();
    expect(find.text('Café'), findsOneWidget);
    expect(find.textContaining('R\$'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cola vários produtos com quantidades e salva o lote', (
    tester,
  ) async {
    await launch(tester, const Size(360, 800));
    await openList(tester);
    await tapVisible(tester, find.text('Adicionar vários de uma vez'));
    await tester.enterText(
      find.byKey(const Key('bulk-input')),
      '2x Iogurte natural\n1,5 kg Banana\nOvos',
    );
    await tester.pumpAndSettle();
    expect(find.text('3 produtos para adicionar'), findsOneWidget);
    expect(find.text('1,5 kg · Banana'), findsOneWidget);
    await tapVisible(tester, find.text('Adicionar 3 produtos'));
    await waitForChange(
      tester,
      () => model.listById(listId)!.items.length == 5,
    );
    final added = model.listById(listId)!.items.skip(2).toList();
    expect(added.map((item) => item.name), [
      'Iogurte natural',
      'Banana',
      'Ovos',
    ]);
    expect(added.map((item) => item.quantityMilli), [2000, 1500, 1000]);
    expect(added.map((item) => item.unit), ['un', 'kg', 'un']);
    expect(
      added.every((item) => item.unitPriceCents == 0 && !item.checked),
      isTrue,
    );
    expect(find.textContaining('R\$'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ajusta quantidade, muda seção e desfaz exclusão por gesto', (
    tester,
  ) async {
    await launch(tester, const Size(360, 800));
    await openList(tester);
    await tapVisible(
      tester,
      find.byTooltip('Aumentar quantidade de Arroz 5 kg'),
    );
    await waitForChange(tester, () => item('arroz').quantityMilli == 2000);
    await tapVisible(
      tester,
      find.byTooltip('Diminuir quantidade de Arroz 5 kg'),
    );
    await waitForChange(tester, () => item('arroz').quantityMilli == 1000);
    await tapVisible(
      tester,
      find.byTooltip('Aumentar quantidade de Arroz 5 kg'),
    );
    await waitForChange(tester, () => item('arroz').quantityMilli == 2000);

    Finder riceCheckbox() => find.descendant(
      of: find.ancestor(
        of: find.text('Arroz 5 kg'),
        matching: find.byType(Card),
      ),
      matching: find.byType(Checkbox),
    );

    await tapVisible(tester, riceCheckbox());
    await waitForChange(tester, () => item('arroz').checked);
    expect(find.text('Tudo no carrinho!'), findsOneWidget);
    await tapVisible(tester, riceCheckbox());
    await waitForChange(tester, () => !item('arroz').checked);
    expect(item('arroz').quantityMilli, 2000);

    final dismissible = find.ancestor(
      of: find.text('Arroz 5 kg'),
      matching: find.byType(Dismissible),
    );
    await tester.ensureVisible(dismissible);
    await tester.pumpAndSettle();
    await tester.drag(dismissible, const Offset(-400, 0));
    await tester.pumpAndSettle();
    await waitForChange(
      tester,
      () => !model.listById(listId)!.items.any((item) => item.id == 'arroz'),
    );
    expect(find.text('Arroz 5 kg'), findsNothing);
    expect(find.text('Arroz 5 kg removido'), findsOneWidget);
    await tester.tap(find.text('Desfazer'));
    await waitForChange(
      tester,
      () => model.listById(listId)!.items.length == 2,
    );
    expect(model.listById(listId)!.items.first.id, 'arroz');
    expect(item('arroz').quantityMilli, 2000);
    expect(item('arroz').checked, isFalse);
    expect(find.textContaining('R\$'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
