import 'dart:async';

import 'package:carrinho_de_compras/core/formatters.dart';
import 'package:carrinho_de_compras/data/local_database.dart';
import 'package:carrinho_de_compras/data/shopping_repository.dart';
import 'package:carrinho_de_compras/domain/models.dart';
import 'package:carrinho_de_compras/ui/app_view_model.dart';
import 'package:carrinho_de_compras/ui/history_screen.dart';
import 'package:carrinho_de_compras/ui/list_screen.dart';
import 'package:carrinho_de_compras/ui/receipt_review_screen.dart';
import 'package:carrinho_de_compras/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Simula uma falha imediata, antes de o próximo frame remover o Dismissible.
class _FailingDeleteRepository extends ShoppingRepository {
  _FailingDeleteRepository(super.storage);

  @override
  Future<void> deleteItem(String id) async =>
      throw StateError('Falha simulada ao gravar no banco');
}

Widget _app(Widget home) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('pt', 'BR'),
  supportedLocales: const [Locale('pt', 'BR')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

void main() {
  sqfliteFfiInit();
  late Database database;
  late ShoppingRepository repository;
  late AppViewModel model;
  late String listId;

  setUp(() async {
    await initializeDateFormatting('pt_BR');
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: LocalDatabase.configure,
        onCreate: LocalDatabase.create,
      ),
    );
    repository = ShoppingRepository(LocalDatabase(database));
    listId = await repository.createList('Compra do mês');
    await repository.addItems(listId, const [
      ShoppingItem(id: 'leite', name: 'Leite integral'),
      ShoppingItem(id: 'banana', name: 'Banana prata'),
    ]);
    model = AppViewModel(repository);
    await model.load();
  });

  tearDown(() async {
    model.dispose();
    await database.close();
  });

  testWidgets(
    'Salvar a nota guarda preços e quantidades no histórico e conclui a lista',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final draft = ReceiptDraft(
        merchant: 'Mercado da leitura',
        issuedAt: DateTime(2026, 10, 19),
        source: 'sefaz',
        totalCents: 2436,
        items: const [
          ReceiptLine(
            description: 'Leite integral',
            quantityMilli: 3000,
            unit: 'un',
            unitPriceCents: 479,
            totalCents: 1437,
          ),
          ReceiptLine(
            description: 'Banana prata',
            quantityMilli: 1250,
            unit: 'kg',
            unitPriceCents: 799,
            totalCents: 999,
          ),
        ],
      );
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ListenableBuilder(
              listenable: model,
              builder: (_, _) => HistoryScreen(model: model),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cada compra conta uma história'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      unawaited(
        navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                ReceiptReviewScreen(model: model, draft: draft, listId: listId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conferir compra'), findsOneWidget);
      expect(find.text('Leite integral'), findsOneWidget);
      expect(find.text('Banana prata'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Conferi, salvar compra'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ReceiptReviewScreen),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              ),
            )
            .first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Conferi, salvar compra'));
      await tester.pump(const Duration(milliseconds: 350));
      // O SQLite FFI faz I/O real fora do relógio simulado dos widgets.
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (model.purchases.isEmpty && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(model.purchases, hasLength(1));
      });
      await tester.pumpAndSettle();
      expect(find.text('Conferir compra'), findsNothing);
      expect(find.text('Mercado da leitura'), findsOneWidget);
      final purchase = model.purchases.single;
      expect(purchase.listId, listId);
      expect(purchase.totalCents, 2436);
      expect(purchase.receipt.source, 'sefaz');
      expect(purchase.receipt.items.map((item) => item.quantityMilli), [
        3000,
        1250,
      ]);
      expect(purchase.receipt.items.map((item) => item.unitPriceCents), [
        479,
        799,
      ]);
      expect(model.listById(listId)!.completed, isTrue);

      await tester.ensureVisible(find.text('Mercado da leitura'));
      await tester.tap(find.text('Mercado da leitura'));
      await tester.pumpAndSettle();
      expect(find.text('Detalhes da compra'), findsOneWidget);
      expect(find.text('3 un × ${money(479)}'), findsOneWidget);
      expect(find.text('1,25 kg × ${money(799)}'), findsOneWidget);
      expect(find.text('Total pago: ${money(2436)}'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Falha imediata no swipe mantém o item e permite tentar novamente',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      model.dispose();
      model = AppViewModel(_FailingDeleteRepository(LocalDatabase(database)));
      await tester.runAsync(model.load);
      await tester.pumpWidget(_app(ListScreen(model: model, listId: listId)));
      await tester.pumpAndSettle();
      final product = find.text('Leite integral');
      await tester.ensureVisible(product);
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.drag(
          find.ancestor(of: product, matching: find.byType(Dismissible)),
          const Offset(-400, 0),
        );
        await tester.pumpAndSettle();
        expect(product, findsOneWidget);
        expect(
          find.text('Não foi possível salvar. Tente novamente.'),
          findsOneWidget,
        );
        expect(model.listById(listId)!.items.length, 2);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
