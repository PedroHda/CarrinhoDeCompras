import 'package:flutter/foundation.dart';

import '../data/shopping_repository.dart';
import '../domain/models.dart';

/// Estado compartilhado simples com ChangeNotifier e dependência injetada no construtor.
class AppViewModel extends ChangeNotifier {
  AppViewModel(this.repository);
  final ShoppingRepository repository;
  List<ShoppingList> lists = [];
  List<Purchase> purchases = [];
  bool loading = true;
  String? loadError;
  String backendUrl = '';

  /// Recarrega depois de cada alteração persistida; a tela observa uma única fonte.
  Future<void> load() async {
    try {
      lists = await repository.lists();
      purchases = await repository.purchases();
      backendUrl = await repository.setting('backend_url');
      loadError = null;
    } catch (_) {
      loadError = 'Não foi possível abrir os dados locais. Feche e abra o aplicativo novamente.';
    }
    loading = false;
    notifyListeners();
  }

  /// Operação de escrita concluída antes da atualização visual evita sucesso falso.
  Future<void> change(Future<void> Function() action) async {
    await action();
    await load();
  }

  /// A identidade permite encontrar a versão atualizada da lista após uma mutação.
  ShoppingList? listById(String id) =>
      lists.where((list) => list.id == id).firstOrNull;
}
