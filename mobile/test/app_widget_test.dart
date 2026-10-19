import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:carrinho_de_compras/data/local_database.dart';
import 'package:carrinho_de_compras/data/shopping_repository.dart';
import 'package:carrinho_de_compras/domain/models.dart';
import 'package:carrinho_de_compras/ui/app.dart';
import 'package:carrinho_de_compras/ui/app_view_model.dart';

void main() {
  sqfliteFfiInit();
  late Database database;
  late AppViewModel model;
  setUp(() async {
    await initializeDateFormatting('pt_BR');
    // Golden tests usam fontes reais, evitando os retângulos da fonte de teste Ahem.
    final font = FontLoader('AppRoboto')
      ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf'));
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
    final id = await repository.createList('Compra da semana');
    await repository.saveItem(
      id,
      const ShoppingItem(id: 'arroz', name: 'Arroz 5 kg', unitPriceCents: 2490),
    );
    await repository.saveItem(
      id,
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

  testWidgets('Renderiza a lista e navega entre histórico e ajustes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(CarrinhoApp(model: model));
    await tester.pumpAndSettle();
    expect(find.text('Compra da semana'), findsOneWidget);
    expect(find.text('1 de 2 itens • R\$\u00a039,27'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/listas.png'),
    );
    await tester.tap(find.text('Compra da semana'));
    await tester.pumpAndSettle();
    expect(find.text('Arroz 5 kg'), findsOneWidget);
    expect(find.text('Concluir compra'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/lista-aberta.png'),
    );
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Histórico').last);
    await tester.pumpAndSettle();
    expect(find.text('Cada compra conta uma história'), findsOneWidget);
    await tester.tap(find.text('Ajustes').last);
    await tester.pumpAndSettle();
    expect(find.text('Exportar backup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
