import 'hebrew_date.dart';
import 'jewish_holidays.dart';
import 'local_date.dart';
import 'parsha_schedule.dart';

/// Which tradition's haftarah to read.
enum HaftarahNusach { ashkenazi, sephardi, chabad }

/// Parsha numbers referenced by the rules below.
abstract final class _P {
  static const kedoshim = 30;
  static const pinchas = 41;
  static const masei = 43;
  static const matot = 42;
  static const reeh = 47;
  static const kiTeitzei = 49;
  static const vayeilech = 52;
  static const haazinu = 53;
}

/// Determines when a Shabbat's haftarah is replaced by a special one.
///
/// Returns a key into `specialHaftarot` in assets/data/parshiyot.json, or
/// null when the portion's own haftarah is read. The precedence follows the
/// common practice (Shulchan Aruch OC 425, 428, 684–685; Mishnah Berurah
/// ibid.). Sephardim and Chabad differ from Ashkenazim around Rosh Chodesh
/// Elul and in Kedoshim, as noted below.
String? specialHaftarahKey(LocalDate shabbat, PortionId portion, {required HaftarahNusach nusach}) {
  final ashkenazi = nusach == HaftarahNusach.ashkenazi;
  final h = HebrewDate.fromLocalDate(shabbat);
  final y = h.year;
  final rd = shabbat.rd;
  bool within(int fromRd, int toRd) => rd >= fromRd && rd <= toRd;
  final roshChodesh = JewishHolidays.isRoshChodesh(h);

  // Chanukah.
  final chanukah = JewishHolidays.chanukahDay(h);
  if (chanukah != null) {
    return roshChodesh
        ? 'Shabbat Rosh Chodesh Chanukah'
        : 'Chanukah Day $chanukah (on Shabbat)';
  }

  // The four parshiyot. In a leap year they fall around Adar II.
  final adar = HebrewDate.purimMonth(y);
  final roshChodeshAdar = HebrewDate(y, adar, 1).rd;
  final purim = HebrewDate(y, adar, 14).rd;
  final roshChodeshNisan = HebrewDate(y, HebrewMonth.nisan, 1).rd;
  final pesach = HebrewDate(y, HebrewMonth.nisan, 15).rd;
  if (within(roshChodeshAdar - 6, roshChodeshAdar)) {
    return roshChodesh ? 'Shabbat Shekalim (on Rosh Chodesh)' : 'Shabbat Shekalim';
  }
  if (within(purim - 7, purim - 1)) return 'Shabbat Zachor';
  if (within(roshChodeshNisan - 13, roshChodeshNisan - 7)) return 'Shabbat Parah';
  if (within(roshChodeshNisan - 6, roshChodeshNisan)) {
    return roshChodesh ? 'Shabbat HaChodesh (on Rosh Chodesh)' : 'Shabbat HaChodesh';
  }
  if (within(pesach - 7, pesach - 1)) return 'Shabbat HaGadol';

  // Shabbat Shuva, between Rosh Hashana and Yom Kippur.
  if (h.month == HebrewMonth.tishrei && h.day >= 3 && h.day <= 9) {
    if (portion.number == _P.haazinu) return "Shabbat Shuva (with Ha'azinu)";
    if (portion.number == _P.vayeilech) return 'Shabbat Shuva (with Vayeilech)';
  }

  if (roshChodesh) {
    // Rosh Chodesh Av: the haftarot of affliction take precedence, with
    // verses added for Rosh Chodesh.
    if (h.month == HebrewMonth.av) {
      if (portion.number == _P.masei && !portion.combined) return 'Masei on Shabbat Rosh Chodesh';
      if (portion.number == _P.matot && portion.combined) return 'Matot-Masei on Shabbat Rosh Chodesh';
    }
    // Re'eh on Rosh Chodesh Elul: Sephardim and Chabad read its own
    // haftarah, the third of consolation (Shulchan Aruch OC 425:1), adding
    // the first and last verses of the Rosh Chodesh haftarah. Ashkenazim read
    // the Rosh Chodesh haftarah (Rema ibid.), and Re'eh's with Ki Teitzei's.
    if (portion.number == _P.reeh && !ashkenazi) return "Re'eh on Shabbat Rosh Chodesh";
    return 'Shabbat Rosh Chodesh';
  }

  // Machar Chodesh: Rosh Chodesh is tomorrow. Not before Av, Elul or Tishrei,
  // when the haftarot of affliction and consolation are read.
  final tomorrow = HebrewDate.fromRd(rd + 1);
  if (JewishHolidays.isRoshChodesh(tomorrow) &&
      tomorrow.month != HebrewMonth.av &&
      tomorrow.month != HebrewMonth.elul &&
      !(tomorrow.month == HebrewMonth.tishrei && tomorrow.day == 1)) {
    return 'Shabbat Machar Chodesh';
  }

  // The three weeks begin on 17 Tammuz.
  if (portion.number == _P.pinchas &&
      h.month == HebrewMonth.tammuz &&
      h.day > 17) {
    return 'Pinchas occurring after 17 Tammuz';
  }

  // When Re'eh fell on Rosh Chodesh Elul, Ashkenazim join its haftarah (the
  // third of consolation) to Ki Teitzei's, which continues it in Isaiah 54.
  if (portion.number == _P.kiTeitzei && ashkenazi) {
    final reeh = HebrewDate.fromRd(rd - 14);
    if (JewishHolidays.isRoshChodesh(reeh)) {
      return 'Ki Teitzei with 3rd Haftarah of Consolation';
    }
  }

  // When Acharei Mot's haftarah was displaced by a special one, Ashkenazim
  // read it for Kedoshim. Sephardim and Chabad read Kedoshim's own.
  if (portion.number == _P.kedoshim && !portion.combined && ashkenazi) {
    // Acharei Mot was read last week, or two weeks ago if Pesach intervened.
    var previous = shabbat.addDays(-7);
    final ph = HebrewDate.fromLocalDate(previous);
    if (ph.month == HebrewMonth.nisan && ph.day >= 15 && ph.day <= 22) {
      previous = previous.addDays(-7);
    }
    if (specialHaftarahKey(previous, const PortionId(_P.kedoshim - 1), nusach: nusach) != null) {
      return 'Kedoshim following Special Shabbat';
    }
  }

  return null;
}
