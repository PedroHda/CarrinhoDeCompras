import 'package:carrinho_de_compras/domain/history_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Períodos do histórico', () {
    test('Dia inclui todos os horários e exclui o próximo dia', () {
      final range = historyDateRange(
        HistoryPeriod.day,
        DateTime(2026, 10, 19, 12),
      )!;
      expect(range.start, DateTime(2026, 10, 19));
      expect(range.contains(DateTime(2026, 10, 19)), isTrue);
      expect(range.contains(DateTime(2026, 10, 19, 23, 59, 59, 999)), isTrue);
      expect(range.contains(DateTime(2026, 10, 18, 23, 59, 59)), isFalse);
      expect(range.contains(DateTime(2026, 10, 20)), isFalse);
    });

    test('Semana começa na segunda e atravessa a virada do ano', () {
      final range = historyDateRange(HistoryPeriod.week, DateTime(2027, 1, 3))!;
      expect(range.start, DateTime(2026, 12, 28));
      expect(range.end, DateTime(2027, 1, 4));
      expect(range.contains(DateTime(2027, 1, 3, 23, 59)), isTrue);
      expect(range.contains(DateTime(2027, 1, 4)), isFalse);
    });

    test('Mês respeita fevereiro em ano bissexto', () {
      final range = historyDateRange(
        HistoryPeriod.month,
        DateTime(2028, 2, 15),
      )!;
      expect(range.start, DateTime(2028, 2));
      expect(range.contains(DateTime(2028, 2, 29, 23, 59)), isTrue);
      expect(range.end, DateTime(2028, 3));
    });

    test('Ano inclui dezembro e exclui janeiro do ano seguinte', () {
      final range = historyDateRange(
        HistoryPeriod.year,
        DateTime(2026, 10, 19),
      )!;
      expect(range.start, DateTime(2026));
      expect(range.contains(DateTime(2026, 12, 31, 23, 59)), isTrue);
      expect(range.contains(DateTime(2027)), isFalse);
    });

    test('Todo o período não limita datas', () {
      expect(historyDateRange(HistoryPeriod.all, DateTime(2026)), isNull);
    });

    test('Datas UTC são comparadas com o calendário local', () {
      final localDate = DateTime(2026, 10, 19, 23, 30);
      final range = historyDateRange(HistoryPeriod.day, localDate)!;
      expect(range.contains(localDate.toUtc()), isTrue);
    });

    test('Navegação mensal não pula fevereiro ao partir do dia 31', () {
      final next = shiftHistoryReference(
        HistoryPeriod.month,
        DateTime(2026, 1, 31),
        1,
      );
      expect(next, DateTime(2026, 2));
      expect(
        shiftHistoryReference(HistoryPeriod.month, next, -1),
        DateTime(2026, 1),
      );
    });

    test('Navegação por dia, semana e ano atravessa fronteiras', () {
      expect(
        shiftHistoryReference(HistoryPeriod.day, DateTime(2026, 3), -1),
        DateTime(2026, 2, 28),
      );
      expect(
        shiftHistoryReference(HistoryPeriod.week, DateTime(2026, 12, 28), 1),
        DateTime(2027, 1, 4),
      );
      expect(
        shiftHistoryReference(HistoryPeriod.year, DateTime(2028, 2, 29), 1),
        DateTime(2029),
      );
    });
  });
}
