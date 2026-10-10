// Builds assets/data/cities.json, the places a reader can choose for Shabbat
// times (Settings → Reading & customs):
//
//   cd tool/data && node build_cities.mjs
//
// Source: the GeoNames gazetteer (https://www.geonames.org/, CC BY 4.0), as
// packaged by geonamescache 3.0.2 (MIT, https://github.com/yaph/geonamescache),
// a pinned wheel from PyPI that is downloaded once into tool/data/.cache (or
// $DATA_CACHE) and checked against its SHA-256. Nothing from it ships but the
// selected places.
//
// The list holds every place of 100,000 people or more, and every Israeli
// city: Israeli places of 10,000 or more, and a few smaller ones readers look
// for. Each has its English and Hebrew names, coordinates, IANA time zone and
// how many minutes before sunset candles are lit. It is sorted by population,
// largest first, so the app can rank search results by the order alone.
//
// Changes from GeoNames, all listed below: Israeli names are written as
// Israelis write them, sections of a city that GeoNames lists apart are
// left out, Hebrew names are picked from the alternate names (preferring
// Hebrew spellings to Yiddish ones), and Israeli localities beyond the Green
// Line keep Israel time, as their residents do.

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import {fileURLToPath} from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..', '..');
const cacheDir = process.env.DATA_CACHE || path.join(here, '.cache');

const SOURCE = {
  url: 'https://files.pythonhosted.org/packages/48/c2/52f1b29de8839b4b55cd2641dfd722a6a94953d74fa82514e26084a92318/geonamescache-3.0.2-py3-none-any.whl',
  sha256: 'b830e8942f2d58c7e68782dcf4dff2ffe8c4104a35ee881ed1ad4023cefcdba4',
  file: 'geonamescache-3.0.2-py3-none-any.whl',
};

const MIN_POPULATION = 100000;
const MIN_POPULATION_IL = 10000;

/**
 * Minutes before sunset that candles are lit: 18 outside Israel and 20 in
 * it, apart from these places' own customs. Hebcal's defaults.
 */
const CANDLE_MINUTES = {
  281184: 40, // Jerusalem
  294801: 30, // Haifa
  293067: 30, // Zikhron Ya'akov
};
const CANDLE_MINUTES_DEFAULT = 18;
const CANDLE_MINUTES_ISRAEL = 20;

// ---------------------------------------------------------------------------
// Israel

/**
 * Every Israeli place listed, by GeoNames id, with its English and Hebrew
 * names as Israelis write them. GeoNames' own English names are academic
 * transliterations ("Petaẖ Tiqva"), which few would search for.
 */
const IL_NAMES = {
  281184: ['Jerusalem', 'ירושלים'],
  293397: ['Tel Aviv', 'תל אביב'],
  294801: ['Haifa', 'חיפה'],
  293703: ['Rishon LeZion', 'ראשון לציון'],
  293918: ['Petah Tikva', 'פתח תקווה'],
  294071: ['Netanya', 'נתניה'],
  295629: ['Ashdod', 'אשדוד'],
  295514: ['Bnei Brak', 'בני ברק'],
  294751: ['Holon', 'חולון'],
  295530: ['Beersheba', 'באר שבע'],
  293788: ['Ramat Gan', 'רמת גן'],
  293725: ['Rehovot', 'רחובות'],
  295620: ['Ashkelon', 'אשקלון'],
  295548: ['Bat Yam', 'בת ים'],
  295432: ['Beit Shemesh', 'בית שמש'],
  294514: ['Kfar Saba', 'כפר סבא'],
  294778: ['Herzliya', 'הרצליה'],
  294946: ['Hadera', 'חדרה'],
  282926: ["Modi'in", 'מודיעין'],
  294098: ['Nazareth', 'נצרת'],
  294421: ['Lod', 'לוד'],
  8199378: ["Modi'in Illit", 'מודיעין עילית'],
  293768: ['Ramla', 'רמלה'],
  293807: ["Ra'anana", 'רעננה'],
  293690: ['Rosh HaAyin', 'ראש העין'],
  294760: ['Hod HaSharon', 'הוד השרון'],
  293842: ['Kiryat Gat', 'קריית גת'],
  294999: ['Givatayim', 'גבעתיים'],
  293845: ['Kiryat Ata', 'קריית אתא'],
  294117: ['Nahariya', 'נהריה'],
  293286: ['Umm al-Fahm', 'אום אל-פחם'],
  295277: ['Eilat', 'אילת'],
  295721: ['Acre', 'עכו'],
  294074: ['Ness Ziona', 'נס ציונה'],
  8428480: ['Elad', 'אלעד'],
  293222: ['Yavne', 'יבנה'],
  293783: ['Ramat HaSharon', 'רמת השרון'],
  294577: ['Karmiel', 'כרמיאל'],
  295740: ['Afula', 'עפולה'],
  293943: ['Pardes Hanna-Karkur', 'פרדס חנה-כרכור'],
  293322: ['Tiberias', 'טבריה'],
  295130: ['Tayibe', 'טייבה'],
  293844: ['Kiryat Bialik', 'קריית ביאליק'],
  294068: ['Netivot', 'נתיבות'],
  294097: ['Nof HaGalil', 'נוף הגליל'],
  293831: ['Kiryat Motzkin', 'קריית מוצקין'],
  293539: ["Shefa-'Amr", 'שפרעם'],
  12031840: ['Kiryat Ono', 'קריית אונו'],
  293822: ['Kiryat Yam', 'קריית ים'],
  293962: ['Or Yehuda', 'אור יהודה'],
  295328: ['Dimona', 'דימונה'],
  293100: ['Safed', 'צפת'],
  293992: ['Ofakim', 'אופקים'],
  293655: ['Sakhnin', 'סח׳נין'],
  295064: ['Gedera', 'גדרה'],
  295571: ['Baqa al-Gharbiyye', 'באקה אל-גרבייה'],
  10227184: ['Yehud-Monosson', 'יהוד-מונוסון'],
  294981: ['Givat Shmuel', 'גבעת שמואל'],
  295657: ['Arad', 'ערד'],
  293308: ['Tirat Carmel', 'טירת כרמל'],
  295525: ["Be'er Ya'akov", 'באר יעקב'],
  293619: ['Sderot', 'שדרות'],
  295127: ['Tira', 'טירה'],
  293426: ['Tamra', 'טמרה'],
  294210: ['Migdal HaEmek', 'מגדל העמק'],
  293835: ['Kiryat Malakhi', 'קריית מלאכי'],
  295089: ['Ganei Tikva', 'גני תקווה'],
  295365: ['Daliyat al-Karmel', 'דאלית אל-כרמל'],
  295655: ["Ar'ara", 'ערערה'],
  294492: ['Kfar Yona', 'כפר יונה'],
  294078: ['Nesher', 'נשר'],
  294245: ['Mevaseret Zion', 'מבשרת ציון'],
  295080: ['Gan Yavne', 'גן יבנה'],
  294604: ['Kafr Qasim', 'כפר קאסם'],
  293153: ['Yokneam Illit', 'יקנעם עילית'],
  293067: ["Zikhron Ya'akov", 'זכרון יעקב'],
  294387: ['Maghar', 'מגאר'],
  294610: ['Kafr Kanna', 'כפר כנא'],
  293825: ['Kiryat Shmona', 'קריית שמונה'],
  11524864: ['Kadima-Zoran', 'קדימה-צורן'],
  293420: ["Ma'alot-Tarshiha", 'מעלות-תרשיחא'],
  8374209: ['Hura', 'חורה'],
  294622: ['Jadeidi-Makr', 'ג׳דיידה-מכר'],
  8374220: ['Kuseife', 'כסייפה'],
  8428283: ['Shoham', 'שוהם'],
  8199394: ['Ariel', 'אריאל'],
  8310136: ['Tel Sheva', 'תל שבע'],
  294608: ['Kafr Manda', 'כפר מנדא'],
  8184212: ['Rahat', 'רהט'],
  294605: ['Kafr Qara', 'כפר קרע'],
  293969: ['Or Akiva', 'אור עקיבא'],
  293254: ['Yafa an-Naseriyye', 'יפיע'],
  293823: ['Kiryat Tivon', 'קריית טבעון'],
  8374203: ["Ar'ara BaNegev", 'ערערה בנגב'],
  293181: ['Yarka', 'ירכא'],
  293896: ['Qalansawe', 'קלנסווה'],
  295435: ["Beit She'an", 'בית שאן'],
  295410: ['Binyamina-Givat Ada', 'בנימינה-גבעת עדה'],
  295174: ['Reineh', 'ריינה'],
  294373: ['Majd al-Krum', 'מג׳ד אל-כרום'],
  294626: ['Jisr az-Zarqa', 'ג׳סר א-זרקא'],
  294303: ['Mazkeret Batya', 'מזכרת בתיה'],
  11979755: ["Ma'ale Iron", 'מעלה עירון'],
  294658: ['Iksal', 'אכסאל'],
  295765: ['Abu Snan', 'אבו סנאן'],
  294615: ['Kabul', 'כאבול'],
  8184241: ['Lakiya', 'לקיה'],
  295122: ['Even Yehuda', 'אבן יהודה'],
  295285: ['Ein Mahil', 'עין מאהל'],
  294663: ["I'billin", 'אעבלין'],
  295269: ['Fureidis', 'פוריידיס'],
  293354: ['Tel Mond', 'תל מונד'],
  294114: ['Nahf', 'נחף'],
  295584: ['Azor', 'אזור'],
  293721: ['Rekhasim', 'רכסים'],
  295341: ['Deir al-Asad', 'דיר אל-אסד'],
  294642: ['Isfiya', 'עספיא'],
  294630: ['Jatt', 'ג׳ת'],
  295523: ['Beit Jann', 'בית ג׳ן'],
  294552: ['Kiryat Ekron', 'קריית עקרון'],
  8184332: ['Segev Shalom', 'שגב שלום'],
  295339: ['Deir Hanna', 'דיר חנא'],
  293203: ['Yeruham', 'ירוחם'],
  294634: ['Jaljulia', 'ג׳לג׳וליה'],
  294600: ['Kafr Yasif', 'כפר יאסיף'],
  // Smaller places readers look for.
  282993: ["Ma'ale Adumim", 'מעלה אדומים'],
  284375: ['Beitar Illit', 'ביתר עילית'],
  8199386: ["Givat Ze'ev", 'גבעת זאב'],
  283991: ['Efrat', 'אפרת'],
  443093: ['Katzrin', 'קצרין'],
  293821: ["Kiryat Ye'arim (Telz-Stone)", 'קריית יערים (טלז סטון)'],
  294545: ['Kfar Chabad', 'כפר חב״ד'],
  8141842: ['Harish', 'חריש'],
  294166: ['Mitzpe Ramon', 'מצפה רמון'],
};

/** Israeli places under [MIN_POPULATION_IL] that are listed all the same. */
const IL_EXTRA = [282993, 284375, 8199386, 283991, 443093, 293821, 294545, 8141842, 294166];

/** Sections of a city, and duplicates, that GeoNames lists as places. */
const SKIP = new Set([
  7498240, // West Jerusalem
  7303419, // East Jerusalem
  293253, // Jaffa, part of Tel Aviv-Yafo
  293837, // Kiryat HaYovel, Jerusalem
  281187, // Givat Hananya (Abu Tor), Jerusalem
  8478264, // Herzliya Pituah, Herzliya
  12156557, // Binyamina-Givat Ada, listed twice
  293207, // Yehud, part of Yehud-Monosson
]);

/**
 * Israeli localities beyond the Green Line, which GeoNames files under PS,
 * some with Asia/Hebron, whose daylight-saving dates differ from Israel's.
 * Their residents keep Israel time.
 */
const ISRAEL_TIME = new Set([282993, 284375, 8199386, 283991]);

/**
 * GeoNames gives Beitar Illit's Hebrew name to Battir, the village 3 km
 * north of it; the city's own coordinates are these.
 */
const COORDINATES = {284375: [31.6967, 35.1153]};

// ---------------------------------------------------------------------------
// Names elsewhere

/**
 * Communities readers look for by their own name, under [MIN_POPULATION]:
 * no listed city is near enough to stand in for the first three.
 */
const WORLD_EXTRA = {
  5100280: ['Lakewood', 'לייקווד'], // New Jersey
  5127315: ['Monsey', 'מונסי'],
  5123533: ['Kiryas Joel', 'קרית יואל'],
  2648773: ['Gateshead', 'גייטסהד'],
};

/** English names where GeoNames has the local one. */
const EN_NAMES = {
  2886242: 'Cologne', // Köln
  6077243: 'Montreal', // Montréal
};

/**
 * Hebrew names where the alternate names have none, or the spelling picked
 * from them isn't the usual Hebrew one.
 */
const HE_NAMES = {
  745044: 'איסטנבול', // not ביזנטיון
  4699066: 'יוסטון',
  2660646: 'ז׳נבה',
  1512569: 'טשקנט',
  292223: 'דובאי',
  1275339: 'מומבאי',
  2063523: 'פרת',
  5099836: 'ג׳רזי סיטי',
  5134086: 'רוצ׳סטר',
  5043473: 'רוצ׳סטר',
  4781708: 'ריצ׳מונד',
  6122085: 'ריצ׳מונד',
  2638671: 'סלפורד',
  4140963: 'וושינגטון',
  2165087: 'גולד קוסט',
  709930: 'דניפרו',
  1796236: 'שנגחאי',
  2174003: 'בריסביין',
  2192362: 'קרייסטצ׳רץ׳',
  4273837: 'קנזס סיטי',
  2190324: 'המילטון',
  5133273: 'קווינס',
  5110266: 'הברונקס',
  5139568: 'סטטן איילנד',
};

const COUNTRIES = {
  AE: ['United Arab Emirates', 'איחוד האמירויות'],
  AF: ['Afghanistan', 'אפגניסטן'],
  AL: ['Albania', 'אלבניה'],
  AM: ['Armenia', 'ארמניה'],
  AO: ['Angola', 'אנגולה'],
  AR: ['Argentina', 'ארגנטינה'],
  AT: ['Austria', 'אוסטריה'],
  AU: ['Australia', 'אוסטרליה'],
  AZ: ['Azerbaijan', 'אזרבייג׳ן'],
  BA: ['Bosnia and Herzegovina', 'בוסניה והרצגובינה'],
  BD: ['Bangladesh', 'בנגלדש'],
  BE: ['Belgium', 'בלגיה'],
  BF: ['Burkina Faso', 'בורקינה פאסו'],
  BG: ['Bulgaria', 'בולגריה'],
  BH: ['Bahrain', 'בחריין'],
  BI: ['Burundi', 'בורונדי'],
  BJ: ['Benin', 'בנין'],
  BO: ['Bolivia', 'בוליביה'],
  BR: ['Brazil', 'ברזיל'],
  BS: ['Bahamas', 'איי בהאמה'],
  BW: ['Botswana', 'בוטסואנה'],
  BY: ['Belarus', 'בלארוס'],
  CA: ['Canada', 'קנדה'],
  CD: ['DR Congo', 'הרפובליקה הדמוקרטית של קונגו'],
  CF: ['Central African Republic', 'הרפובליקה המרכז-אפריקאית'],
  CG: ['Republic of the Congo', 'הרפובליקה של קונגו'],
  CH: ['Switzerland', 'שווייץ'],
  CI: ['Ivory Coast', 'חוף השנהב'],
  CL: ['Chile', 'צ׳ילה'],
  CM: ['Cameroon', 'קמרון'],
  CN: ['China', 'סין'],
  CO: ['Colombia', 'קולומביה'],
  CR: ['Costa Rica', 'קוסטה ריקה'],
  CU: ['Cuba', 'קובה'],
  CV: ['Cape Verde', 'כף ורדה'],
  CW: ['Curaçao', 'קוראסאו'],
  CY: ['Cyprus', 'קפריסין'],
  CZ: ['Czechia', 'צ׳כיה'],
  DE: ['Germany', 'גרמניה'],
  DJ: ['Djibouti', 'ג׳יבוטי'],
  DK: ['Denmark', 'דנמרק'],
  DO: ['Dominican Republic', 'הרפובליקה הדומיניקנית'],
  DZ: ['Algeria', 'אלג׳יריה'],
  EC: ['Ecuador', 'אקוודור'],
  EE: ['Estonia', 'אסטוניה'],
  EG: ['Egypt', 'מצרים'],
  EH: ['Western Sahara', 'סהרה המערבית'],
  ER: ['Eritrea', 'אריתריאה'],
  ES: ['Spain', 'ספרד'],
  ET: ['Ethiopia', 'אתיופיה'],
  FI: ['Finland', 'פינלנד'],
  FR: ['France', 'צרפת'],
  GA: ['Gabon', 'גבון'],
  GB: ['United Kingdom', 'בריטניה'],
  GE: ['Georgia', 'גאורגיה'],
  GH: ['Ghana', 'גאנה'],
  GM: ['Gambia', 'גמביה'],
  GN: ['Guinea', 'גינאה'],
  GQ: ['Equatorial Guinea', 'גינאה המשוונית'],
  GR: ['Greece', 'יוון'],
  GT: ['Guatemala', 'גואטמלה'],
  GW: ['Guinea-Bissau', 'גינאה-ביסאו'],
  GY: ['Guyana', 'גיאנה'],
  HK: ['Hong Kong', 'הונג קונג'],
  HN: ['Honduras', 'הונדורס'],
  HR: ['Croatia', 'קרואטיה'],
  HT: ['Haiti', 'האיטי'],
  HU: ['Hungary', 'הונגריה'],
  ID: ['Indonesia', 'אינדונזיה'],
  IE: ['Ireland', 'אירלנד'],
  IL: ['Israel', 'ישראל'],
  IN: ['India', 'הודו'],
  IQ: ['Iraq', 'עיראק'],
  IR: ['Iran', 'איראן'],
  IS: ['Iceland', 'איסלנד'],
  IT: ['Italy', 'איטליה'],
  JM: ['Jamaica', 'ג׳מייקה'],
  JO: ['Jordan', 'ירדן'],
  JP: ['Japan', 'יפן'],
  KE: ['Kenya', 'קניה'],
  KG: ['Kyrgyzstan', 'קירגיזסטן'],
  KH: ['Cambodia', 'קמבודיה'],
  KP: ['North Korea', 'צפון קוריאה'],
  KR: ['South Korea', 'דרום קוריאה'],
  KW: ['Kuwait', 'כווית'],
  KZ: ['Kazakhstan', 'קזחסטן'],
  LA: ['Laos', 'לאוס'],
  LB: ['Lebanon', 'לבנון'],
  LK: ['Sri Lanka', 'סרי לנקה'],
  LR: ['Liberia', 'ליבריה'],
  LS: ['Lesotho', 'לסוטו'],
  LT: ['Lithuania', 'ליטא'],
  LV: ['Latvia', 'לטביה'],
  LY: ['Libya', 'לוב'],
  MA: ['Morocco', 'מרוקו'],
  MD: ['Moldova', 'מולדובה'],
  ME: ['Montenegro', 'מונטנגרו'],
  MG: ['Madagascar', 'מדגסקר'],
  MK: ['North Macedonia', 'מקדוניה הצפונית'],
  ML: ['Mali', 'מאלי'],
  MM: ['Myanmar', 'מיאנמר'],
  MN: ['Mongolia', 'מונגוליה'],
  MO: ['Macao', 'מקאו'],
  MR: ['Mauritania', 'מאוריטניה'],
  MU: ['Mauritius', 'מאוריציוס'],
  MV: ['Maldives', 'האיים המלדיביים'],
  MW: ['Malawi', 'מלאווי'],
  MX: ['Mexico', 'מקסיקו'],
  MY: ['Malaysia', 'מלזיה'],
  MZ: ['Mozambique', 'מוזמביק'],
  NA: ['Namibia', 'נמיביה'],
  NE: ['Niger', 'ניז׳ר'],
  NG: ['Nigeria', 'ניגריה'],
  NI: ['Nicaragua', 'ניקרגואה'],
  NL: ['Netherlands', 'הולנד'],
  NO: ['Norway', 'נורווגיה'],
  NP: ['Nepal', 'נפאל'],
  NZ: ['New Zealand', 'ניו זילנד'],
  OM: ['Oman', 'עומאן'],
  PA: ['Panama', 'פנמה'],
  PE: ['Peru', 'פרו'],
  PG: ['Papua New Guinea', 'פפואה גינאה החדשה'],
  PH: ['Philippines', 'הפיליפינים'],
  PK: ['Pakistan', 'פקיסטן'],
  PL: ['Poland', 'פולין'],
  PR: ['Puerto Rico', 'פוארטו ריקו'],
  PS: ['Palestinian Territories', 'השטחים הפלסטיניים'],
  PT: ['Portugal', 'פורטוגל'],
  PY: ['Paraguay', 'פרגוואי'],
  QA: ['Qatar', 'קטאר'],
  RE: ['Réunion', 'ראוניון'],
  RO: ['Romania', 'רומניה'],
  RS: ['Serbia', 'סרביה'],
  RU: ['Russia', 'רוסיה'],
  RW: ['Rwanda', 'רואנדה'],
  SA: ['Saudi Arabia', 'ערב הסעודית'],
  SD: ['Sudan', 'סודאן'],
  SE: ['Sweden', 'שוודיה'],
  SG: ['Singapore', 'סינגפור'],
  SI: ['Slovenia', 'סלובניה'],
  SK: ['Slovakia', 'סלובקיה'],
  SL: ['Sierra Leone', 'סיירה לאונה'],
  SN: ['Senegal', 'סנגל'],
  SO: ['Somalia', 'סומליה'],
  SR: ['Suriname', 'סורינאם'],
  SS: ['South Sudan', 'דרום סודאן'],
  SV: ['El Salvador', 'אל סלוודור'],
  SY: ['Syria', 'סוריה'],
  SZ: ['Eswatini', 'אסוואטיני'],
  TD: ['Chad', 'צ׳אד'],
  TG: ['Togo', 'טוגו'],
  TH: ['Thailand', 'תאילנד'],
  TJ: ['Tajikistan', 'טג׳יקיסטן'],
  TL: ['Timor-Leste', 'מזרח טימור'],
  TM: ['Turkmenistan', 'טורקמניסטן'],
  TN: ['Tunisia', 'תוניסיה'],
  TR: ['Turkey', 'טורקיה'],
  TW: ['Taiwan', 'טאיוואן'],
  TZ: ['Tanzania', 'טנזניה'],
  UA: ['Ukraine', 'אוקראינה'],
  UG: ['Uganda', 'אוגנדה'],
  US: ['United States', 'ארצות הברית'],
  UY: ['Uruguay', 'אורוגוואי'],
  UZ: ['Uzbekistan', 'אוזבקיסטן'],
  VE: ['Venezuela', 'ונצואלה'],
  VN: ['Vietnam', 'וייטנאם'],
  XK: ['Kosovo', 'קוסובו'],
  YE: ['Yemen', 'תימן'],
  ZA: ['South Africa', 'דרום אפריקה'],
  ZM: ['Zambia', 'זמביה'],
  ZW: ['Zimbabwe', 'זימבבואה'],
};

/** US states, which tell apart the many American places of the same name. */
const US_STATES_HE = {
  AL: 'אלבמה', AK: 'אלסקה', AZ: 'אריזונה', AR: 'ארקנסו', CA: 'קליפורניה', CO: 'קולורדו',
  CT: 'קונטיקט', DE: 'דלאוור', DC: 'וושינגטון די. סי.', FL: 'פלורידה', GA: 'ג׳ורג׳יה',
  HI: 'הוואי', ID: 'איידהו', IL: 'אילינוי', IN: 'אינדיאנה', IA: 'איווה', KS: 'קנזס',
  KY: 'קנטקי', LA: 'לואיזיאנה', ME: 'מיין', MD: 'מרילנד', MA: 'מסצ׳וסטס', MI: 'מישיגן',
  MN: 'מינסוטה', MS: 'מיסיסיפי', MO: 'מיזורי', MT: 'מונטנה', NE: 'נברסקה', NV: 'נבדה',
  NH: 'ניו המפשייר', NJ: 'ניו ג׳רזי', NM: 'ניו מקסיקו', NY: 'ניו יורק', NC: 'צפון קרוליינה',
  ND: 'צפון דקוטה', OH: 'אוהיו', OK: 'אוקלהומה', OR: 'אורגון', PA: 'פנסילבניה',
  RI: 'רוד איילנד', SC: 'דרום קרוליינה', SD: 'דרום דקוטה', TN: 'טנסי', TX: 'טקסס', UT: 'יוטה',
  VT: 'ורמונט', VA: 'וירג׳יניה', WA: 'וושינגטון', WV: 'מערב וירג׳יניה', WI: 'ויסקונסין',
  WY: 'ויומינג',
};

// ---------------------------------------------------------------------------
// Reading the source

async function sourceWheel() {
  const file = path.join(cacheDir, SOURCE.file);
  let data;
  if (fs.existsSync(file)) {
    data = fs.readFileSync(file);
  } else {
    process.stdout.write(`  downloading ${SOURCE.url}\n`);
    const res = await fetch(SOURCE.url);
    if (!res.ok) throw new Error(`${res.status} for ${SOURCE.url}`);
    data = Buffer.from(await res.arrayBuffer());
  }
  const sha = crypto.createHash('sha256').update(data).digest('hex');
  if (sha !== SOURCE.sha256) throw new Error(`${SOURCE.file}: SHA-256 ${sha}, expected ${SOURCE.sha256}`);
  if (!fs.existsSync(file)) {
    fs.mkdirSync(cacheDir, {recursive: true});
    fs.writeFileSync(file, data);
  }
  return data;
}

/** The files [names] from the zip archive [zip], by name. */
function unzip(zip, names) {
  // The end-of-central-directory record is in the last 64 KiB + 22 bytes.
  let eocd = -1;
  for (let i = zip.length - 22; i >= Math.max(0, zip.length - 65557); i--) {
    if (zip.readUInt32LE(i) === 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw new Error('not a zip archive');
  const count = zip.readUInt16LE(eocd + 10);
  let p = zip.readUInt32LE(eocd + 16);
  const out = {};
  for (let n = 0; n < count; n++) {
    if (zip.readUInt32LE(p) !== 0x02014b50) throw new Error('bad zip central directory');
    const method = zip.readUInt16LE(p + 10);
    const compressed = zip.readUInt32LE(p + 20);
    const nameLength = zip.readUInt16LE(p + 28);
    const extraLength = zip.readUInt16LE(p + 30);
    const commentLength = zip.readUInt16LE(p + 32);
    const local = zip.readUInt32LE(p + 42);
    const name = zip.toString('utf8', p + 46, p + 46 + nameLength);
    if (names.includes(name)) {
      const start = local + 30 + zip.readUInt16LE(local + 26) + zip.readUInt16LE(local + 28);
      const raw = zip.subarray(start, start + compressed);
      out[name] = method === 0 ? raw : zlib.inflateRawSync(raw);
    }
    p += 46 + nameLength + extraLength + commentLength;
  }
  for (const name of names) if (!out[name]) throw new Error(`${name} is not in the archive`);
  return out;
}

// ---------------------------------------------------------------------------
// Hebrew names

const HEBREW_LETTER = /[א-ת]/;
const POINTS = /[֑-ׇ]/;
const PLAIN_HEBREW = /^[א-ת][א-ת \-־'’׳"״.]*$/;

/** [name] with an apostrophe written as a geresh, and quotes as gershayim. */
const hebrewPunctuation = (name) => name.trim().replace(/['’]/g, '׳').replace(/"/g, '״').replace(/ {2,}/g, ' ');

/**
 * How Yiddish a spelling looks. Many places have both a Hebrew and a Yiddish
 * spelling among their alternate names ("לונדון", "לאנדאן"), and Yiddish
 * writes vowels with ע and א where Hebrew uses ו and י or leaves them out.
 */
function yiddishness(name) {
  let score = 0;
  for (const digraph of ['זש', 'טש', 'דזש']) score += 3 * name.split(digraph).length - 3;
  for (const word of name.split(/[ \-־]+/)) {
    for (let i = 1; i < word.length; i++) {
      const last = i === word.length - 1;
      if (word[i] === 'ע') score += last ? 3 : 1;
      if (word[i] === 'א') score += last ? 2 : 0.5;
    }
  }
  return score;
}

/** The Hebrew name among [alternates], or null if they have none. */
function hebrewName(alternates) {
  const candidates = [
    ...new Set(
      alternates.filter((a) => HEBREW_LETTER.test(a) && !POINTS.test(a) && PLAIN_HEBREW.test(a.trim())).map(hebrewPunctuation),
    ),
  ];
  if (candidates.length === 0) return null;
  // The least Yiddish, then one with a geresh ("ריצ׳מונד" over "ריצמונד"),
  // then the fullest spelling ("סיאול" over "סאול").
  const geresh = (name) => (name.includes('׳') ? 0 : 1);
  candidates.sort(
    (a, b) => yiddishness(a) - yiddishness(b) || geresh(a) - geresh(b) || b.length - a.length || a.localeCompare(b),
  );
  return candidates[0];
}

/**
 * Other names that search should find an Israeli place by, beyond the
 * spellings of its name that [aliases] picks out.
 */
const IL_ALIASES = {
  293397: ['Tel Aviv-Yafo', 'Jaffa', 'Yafo', 'תל אביב-יפו', 'יפו'],
  293918: ['Petach Tikva', 'Petach Tikvah'],
  293703: ['Rishon Lezion', 'Rishon LeTsiyon'],
  295530: ["Be'er Sheva", 'Beer Sheva'],
  295432: ['Bet Shemesh'],
  295514: ['Bene Beraq'],
  282926: ["Modi'in-Maccabim-Re'ut", 'מודיעין-מכבים-רעות'],
  8199378: ['Kiryat Sefer', 'קריית ספר'],
  295721: ['Akko'],
  293100: ['Tzfat', 'Tsfat', 'Zefat'],
  294097: ['Nazareth Illit', 'Upper Nazareth', 'נצרת עילית'],
  293539: ['Shfaram'],
  295130: ['Taibe', 'Taibeh'],
  293821: ['Telz-Stone', 'Telzstone', 'טלזסטון'],
  294545: ['Kfar Habad'],
  293153: ['Yoqneam'],
  10227184: ['Yehud'],
};

/** [s] for comparing spellings: Latin letters only, sounds spelled alike. */
const soundKey = (s) =>
  s
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z]+/g, '')
    .replace(/ch|kh/g, 'h')
    .replace(/q|c/g, 'k')
    .replace(/[jy]/g, 'i')
    .replace(/w/g, 'v')
    .replace(/tz|ts/g, 'z')
    .replace(/(.)\1+/g, '$1');

/**
 * Other Latin spellings of an Israeli place's name that search should find
 * it by ("Petach Tikva", "Qiryat Gat"), from its alternate names: those that
 * begin as its English name does. The rest are names in other languages, or
 * other places altogether (Jerusalem's include "Ariel" and "Salem").
 */
function aliases(place, en) {
  const own = soundKey(en);
  const seen = new Set([own]);
  const out = [];
  for (const a of [place.name, ...place.alternatenames]) {
    if (!/^[A-Za-z\u00C0-\u024F\u1E00-\u1EFF][A-Za-z\u00C0-\u024F\u1E00-\u1EFF '’‘`ʼ\-.]*$/.test(a)) continue;
    const key = soundKey(a);
    if (seen.has(key) || key.slice(0, 3) !== own.slice(0, 3)) continue;
    seen.add(key);
    out.push(a);
  }
  return [...out, ...(IL_ALIASES[place.geonameid] ?? [])];
}

// ---------------------------------------------------------------------------
// Building

const round4 = (x) => Math.round(x * 10000) / 10000;

async function main() {
  const files = unzip(await sourceWheel(), [
    'geonamescache/data/cities1000.json',
    'geonamescache/data/us_states.json',
  ]);
  const places = Object.values(JSON.parse(files['geonamescache/data/cities1000.json']));
  const states = JSON.parse(files['geonamescache/data/us_states.json']);
  const byId = new Map(places.map((p) => [p.geonameid, p]));

  const israeli = (p) => (p.countrycode === 'IL' && p.population >= MIN_POPULATION_IL) || IL_EXTRA.includes(p.geonameid);
  const chosen = places
    .filter((p) => !SKIP.has(p.geonameid))
    .filter((p) => israeli(p) || (p.countrycode !== 'IL' && p.population >= MIN_POPULATION) || WORLD_EXTRA[p.geonameid])
    .sort((a, b) => b.population - a.population || a.geonameid - b.geonameid);
  for (const id of [...IL_EXTRA, ...Object.keys(WORLD_EXTRA).map(Number)]) {
    if (!byId.has(id)) throw new Error(`no GeoNames place ${id}`);
  }

  // Outside the US, whose states tell them apart, keep only the largest of
  // the places in one country with the same name (mostly a city's district
  // that shares a name with a city elsewhere).
  const named = new Set();
  const cities = [];
  for (const p of chosen) {
    const il = israeli(p);
    const en = il ? IL_NAMES[p.geonameid]?.[0] : (WORLD_EXTRA[p.geonameid]?.[0] ?? EN_NAMES[p.geonameid] ?? p.name);
    if (!en) throw new Error(`Israeli place ${p.geonameid} (${p.name}) needs names in IL_NAMES`);
    const cc = il ? 'IL' : p.countrycode;
    const region = cc === 'US' ? `US.${p.admin1code}` : null;
    const key = `${en}|${cc}|${region ?? ''}`;
    if (named.has(key)) continue;
    named.add(key);
    const he = il
      ? IL_NAMES[p.geonameid][1]
      : (WORLD_EXTRA[p.geonameid]?.[1] ?? HE_NAMES[p.geonameid] ?? hebrewName(p.alternatenames));
    const [lat, lon] = COORDINATES[p.geonameid] ?? [p.latitude, p.longitude];
    const city = {
      id: p.geonameid,
      name_en: en,
      name_he: he,
      cc,
      ...(region ? {region} : {}),
      lat: round4(lat),
      lon: round4(lon),
      tz: ISRAEL_TIME.has(p.geonameid) ? 'Asia/Jerusalem' : p.timezone,
      candleMinutes: CANDLE_MINUTES[p.geonameid] ?? (il ? CANDLE_MINUTES_ISRAEL : CANDLE_MINUTES_DEFAULT),
    };
    if (il) {
      const alt = aliases(p, en);
      if (alt.length) city.alt = alt;
    }
    cities.push(city);
  }
  for (const id of Object.keys(IL_NAMES)) {
    if (!cities.some((c) => c.id === Number(id))) throw new Error(`IL_NAMES lists ${id}, which isn't chosen`);
  }

  const countries = {};
  for (const cc of [...new Set(cities.map((c) => c.cc))].sort()) {
    const names = COUNTRIES[cc];
    if (!names) throw new Error(`no names for country ${cc}`);
    countries[cc] = {en: names[0], he: names[1]};
  }
  const regions = {};
  for (const region of [...new Set(cities.map((c) => c.region).filter(Boolean))].sort()) {
    const code = region.slice(3);
    if (!states[code] || !US_STATES_HE[code]) throw new Error(`no names for ${region}`);
    regions[region] = {en: states[code].name, he: US_STATES_HE[code]};
  }

  const out = {
    source: 'GeoNames (geonames.org), CC BY 4.0; selected and adapted by tool/data/build_cities.mjs',
    countries,
    regions,
    cities,
  };
  const file = path.join(root, 'assets', 'data', 'cities.json');
  fs.writeFileSync(file, `${JSON.stringify(out)}\n`);
  const hebrew = cities.filter((c) => c.name_he).length;
  process.stdout.write(
    `wrote assets/data/cities.json: ${cities.length} places (${cities.filter((c) => c.cc === 'IL').length} in Israel, ` +
      `${hebrew} with Hebrew names), ${(fs.statSync(file).size / 1024).toFixed(0)} KB\n`,
  );
}

await main();
