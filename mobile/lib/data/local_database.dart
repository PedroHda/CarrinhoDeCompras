import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';

/// Serviço de persistência local; recebe uma conexão nos testes de integração.
class LocalDatabase {
  LocalDatabase(this.connection);
  final Database connection;

  /// O arquivo fica na área privada do aplicativo, sem permissão de armazenamento.
  static Future<LocalDatabase> open() async => LocalDatabase(
    await openDatabase(
      paths.join(await getDatabasesPath(), 'carrinho_v1.db'),
      version: 1,
      onConfigure: configure,
      onCreate: create,
    ),
  );

  /// SQLite exige habilitar integridade referencial para cada conexão.
  static Future<void> configure(Database database) async =>
      database.execute('PRAGMA foreign_keys = ON');

  /// Esquema inicial versionado; futuras mudanças devem ser feitas em onUpgrade.
  static Future<void> create(Database database, int version) async {
    // Listas persistem mesmo depois de concluídas e podem ser reutilizadas.
    await database.execute(
      'CREATE TABLE lists (id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0,1)))',
    );
    // CHECK protege valores também quando o dado vem de um backup externo.
    await database.execute(
      'CREATE TABLE list_items (id TEXT PRIMARY KEY, list_id TEXT NOT NULL REFERENCES lists(id) ON DELETE CASCADE, name TEXT NOT NULL, quantity_milli INTEGER NOT NULL CHECK(quantity_milli > 0), unit TEXT NOT NULL, unit_price_cents INTEGER NOT NULL CHECK(unit_price_cents >= 0), checked INTEGER NOT NULL CHECK(checked IN (0,1)), position INTEGER NOT NULL)',
    );
    // Chave fiscal única impede a mesma NFC-e de entrar duas vezes; NULL permite compras manuais.
    await database.execute(
      'CREATE TABLE purchases (id TEXT PRIMARY KEY, list_id TEXT REFERENCES lists(id) ON DELETE SET NULL, merchant TEXT NOT NULL, issued_at TEXT NOT NULL, access_key TEXT UNIQUE, total_cents INTEGER CHECK(total_cents >= 0), source TEXT NOT NULL, source_url TEXT)',
    );
    // O total original é preservado: desconto e arredondamento podem alterar quantidade × preço.
    await database.execute(
      'CREATE TABLE purchase_items (id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id TEXT NOT NULL REFERENCES purchases(id) ON DELETE CASCADE, description TEXT NOT NULL, quantity_milli INTEGER NOT NULL CHECK(quantity_milli > 0), unit TEXT NOT NULL, unit_price_cents INTEGER NOT NULL CHECK(unit_price_cents >= 0), total_cents INTEGER NOT NULL CHECK(total_cents >= 0), position INTEGER NOT NULL)',
    );
    await database.execute(
      'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    // Índices aceleram consultas por lista e por período do histórico.
    await database.execute(
      'CREATE INDEX ix_items_list ON list_items(list_id, position)',
    );
    await database.execute(
      'CREATE INDEX ix_purchase_date ON purchases(issued_at DESC)',
    );
  }
}
