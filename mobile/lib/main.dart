import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/local_database.dart';
import 'data/shopping_repository.dart';
import 'ui/app.dart';
import 'ui/app_view_model.dart';

/// Inicializa infraestrutura antes da primeira tela; nenhuma conta é necessária.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  try {
    final database = await LocalDatabase.open();
    final model = AppViewModel(ShoppingRepository(database));
    await model.load();
    runApp(CarrinhoApp(model: model));
  } catch (_) {
    // Uma falha de abertura não deve apagar o banco nem causar um ciclo de crash.
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Não foi possível abrir o armazenamento local. Reinicie o aplicativo. Seus dados não foram apagados.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
