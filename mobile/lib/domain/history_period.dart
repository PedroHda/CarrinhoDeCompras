/// Períodos do histórico, sempre baseados no calendário local do aparelho.
enum HistoryPeriod { day, week, month, year, all }

/// Intervalo com fim exclusivo para incluir qualquer horário do último dia.
class HistoryDateRange {
  const HistoryDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    final localDate = date.toLocal();
    return !localDate.isBefore(start) && localDate.isBefore(end);
  }
}

/// A semana vai de segunda a domingo, inclusive ao atravessar meses e anos.
HistoryDateRange? historyDateRange(HistoryPeriod period, DateTime reference) {
  final date = reference.toLocal();
  switch (period) {
    case HistoryPeriod.day:
      return HistoryDateRange(
        start: DateTime(date.year, date.month, date.day),
        end: DateTime(date.year, date.month, date.day + 1),
      );
    case HistoryPeriod.week:
      final monday = date.day - (date.weekday - DateTime.monday);
      return HistoryDateRange(
        start: DateTime(date.year, date.month, monday),
        end: DateTime(date.year, date.month, monday + 7),
      );
    case HistoryPeriod.month:
      return HistoryDateRange(
        start: DateTime(date.year, date.month),
        end: DateTime(date.year, date.month + 1),
      );
    case HistoryPeriod.year:
      return HistoryDateRange(
        start: DateTime(date.year),
        end: DateTime(date.year + 1),
      );
    case HistoryPeriod.all:
      return null;
  }
}

/// Navega por unidades do calendário sem pular meses em datas como dia 31.
DateTime shiftHistoryReference(
  HistoryPeriod period,
  DateTime reference,
  int offset,
) {
  final date = reference.toLocal();
  switch (period) {
    case HistoryPeriod.day:
      return DateTime(date.year, date.month, date.day + offset);
    case HistoryPeriod.week:
      return DateTime(date.year, date.month, date.day + offset * 7);
    case HistoryPeriod.month:
      return DateTime(date.year, date.month + offset);
    case HistoryPeriod.year:
      return DateTime(date.year + offset);
    case HistoryPeriod.all:
      return date;
  }
}
