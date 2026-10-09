/// A calendar day with no time of day or time zone.
///
/// Days are stored as an R.D. ("Rata Die") fixed day number, where day 1 is
/// January 1, year 1 of the proleptic Gregorian calendar. Using a plain day
/// number avoids the daylight-saving pitfalls of `DateTime` arithmetic and
/// makes conversion to the Hebrew calendar straightforward.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate.fromRd(this.rd);

  factory LocalDate(int year, int month, int day) {
    final epochDays =
        DateTime.utc(year, month, day).millisecondsSinceEpoch ~/ _msPerDay;
    return LocalDate.fromRd(epochDays + _unixEpochRd);
  }

  /// The civil date of [dateTime] in its own time zone.
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  factory LocalDate.today() => LocalDate.fromDateTime(DateTime.now());

  /// Parses `yyyy-mm-dd`.
  factory LocalDate.parse(String iso) {
    final parts = iso.split('-').map(int.parse).toList();
    return LocalDate(parts[0], parts[1], parts[2]);
  }

  static const _msPerDay = 86400000;
  static const _unixEpochRd = 719163;

  final int rd;

  DateTime get _utc =>
      DateTime.fromMillisecondsSinceEpoch((rd - _unixEpochRd) * _msPerDay,
          isUtc: true);

  int get year => _utc.year;
  int get month => _utc.month;
  int get day => _utc.day;

  /// Day of week with Sunday = 0 … Saturday = 6 (the Jewish convention).
  int get weekday => rd % 7;

  bool get isShabbat => weekday == 6;

  /// Midnight local time on this day.
  DateTime toDateTime() => DateTime(year, month, day);

  LocalDate addDays(int days) => LocalDate.fromRd(rd + days);

  int differenceInDays(LocalDate other) => rd - other.rd;

  /// The first day on or after this one that falls on [weekday] (0=Sunday).
  LocalDate onOrAfter(int weekday) => addDays((weekday - this.weekday) % 7);

  /// The last day on or before this one that falls on [weekday] (0=Sunday).
  LocalDate onOrBefore(int weekday) => addDays(-((this.weekday - weekday) % 7));

  bool isBefore(LocalDate other) => rd < other.rd;
  bool isAfter(LocalDate other) => rd > other.rd;

  String toIso() {
    final d = _utc;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  int compareTo(LocalDate other) => rd.compareTo(other.rd);

  bool operator <(LocalDate other) => rd < other.rd;
  bool operator <=(LocalDate other) => rd <= other.rd;
  bool operator >(LocalDate other) => rd > other.rd;
  bool operator >=(LocalDate other) => rd >= other.rd;

  @override
  bool operator ==(Object other) => other is LocalDate && other.rd == rd;

  @override
  int get hashCode => rd.hashCode;

  @override
  String toString() => toIso();
}
