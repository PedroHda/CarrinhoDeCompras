import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_view_model.dart';
import 'home_screen.dart';
import 'theme.dart';

/// A composição recebe o modelo externamente, facilitando testes e futuras evoluções.
class CarrinhoApp extends StatelessWidget {
  const CarrinhoApp({super.key, required this.model});
  final AppViewModel model;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Carrinho de Compras',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: HomeScreen(model: model),
  );
}
