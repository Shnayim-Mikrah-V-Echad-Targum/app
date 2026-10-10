/// A place whose Shabbat times the reader follows, as listed in
/// assets/data/cities.json (GeoNames, CC BY 4.0) and kept in the settings.
///
/// The settings keep the whole place rather than its id, so its times can be
/// worked out without loading the list, and a later list never changes them.
class City {
  const City({
    required this.id,
    required this.nameEn,
    this.nameHe,
    required this.countryCode,
    this.region,
    required this.latitude,
    required this.longitude,
    required this.timeZone,
    this.candleMinutes = defaultCandleMinutes,
  });

  /// Candles are lit 18 minutes before sunset outside Israel. The list gives
  /// every place its own minutes: 20 in Israel, 40 in Jerusalem, 30 in Haifa
  /// and Zikhron Ya'akov, as Hebcal has them.
  static const defaultCandleMinutes = 18;

  /// The GeoNames id.
  final int id;
  final String nameEn;

  /// Null where the list has no Hebrew name; the English one stands in.
  final String? nameHe;

  /// ISO 3166-1 alpha-2, e.g. "IL".
  final String countryCode;

  /// The state of an American place ("US.NY"), which tells apart the many
  /// places of one name; null elsewhere.
  final String? region;

  /// Degrees north and east.
  final double latitude;
  final double longitude;

  /// The IANA time zone, e.g. "Asia/Jerusalem".
  final String timeZone;

  /// How many minutes before sunset candles are lit.
  final int candleMinutes;

  /// The name in the UI's language.
  String name({required bool hebrew}) => hebrew ? (nameHe ?? nameEn) : nameEn;

  /// Reads a place in the shape cities.json and the settings store it.
  /// Throws a [FormatException] if it can't be read or isn't a real place.
  factory City.fromJson(Map<String, dynamic> j) {
    final id = j['id'], en = j['name_en'], he = j['name_he'], cc = j['cc'], region = j['region'];
    final lat = j['lat'], lon = j['lon'], tz = j['tz'], minutes = j['candleMinutes'] ?? defaultCandleMinutes;
    if (id is! int ||
        en is! String ||
        en.isEmpty ||
        (he != null && (he is! String || he.isEmpty)) ||
        cc is! String ||
        (region != null && region is! String) ||
        lat is! num ||
        lon is! num ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        tz is! String ||
        tz.isEmpty ||
        minutes is! int ||
        minutes < 0 ||
        minutes > 90) {
      throw FormatException('Unreadable city $j');
    }
    return City(
      id: id,
      nameEn: en,
      nameHe: he as String?,
      countryCode: cc,
      region: region as String?,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      timeZone: tz,
      candleMinutes: minutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_en': nameEn,
        'name_he': nameHe,
        'cc': countryCode,
        if (region != null) 'region': region,
        'lat': latitude,
        'lon': longitude,
        'tz': timeZone,
        'candleMinutes': candleMinutes,
      };

  @override
  bool operator ==(Object other) =>
      other is City &&
      other.id == id &&
      other.nameEn == nameEn &&
      other.nameHe == nameHe &&
      other.countryCode == countryCode &&
      other.region == region &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timeZone == timeZone &&
      other.candleMinutes == candleMinutes;

  @override
  int get hashCode =>
      Object.hash(id, nameEn, nameHe, countryCode, region, latitude, longitude, timeZone, candleMinutes);

  @override
  String toString() => 'City($id, $nameEn)';
}
