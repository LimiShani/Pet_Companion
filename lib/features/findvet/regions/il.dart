import 'region.dart';

/// Israel: the first region of Find a vet.
///
/// The bounds match the server's (`supabase/functions/_shared/regions/il.ts`).
/// The localities are the centres of the larger cities and towns, enough to
/// search "near Rehovot" with no server call; anything else (a street, a
/// postcode, a smaller place) goes to the server's geocoder.
final israelRegion = VetRegion(
  code: 'IL',
  bounds: GeoBounds(south: 29.3, west: 34.2, north: 33.5, east: 35.95),
  languages: ['he', 'en'],
  center: GeoPoint(31.77, 35.0),
  emergencyLadderM: [10000, 25000, 50000, 120000],
  longTermLadderM: [5000, 10000, 20000],
  localities: _israelLocalities,
);

Locality _l(String en, String he, double lat, double lng, [List<String> aliases = const []]) =>
    Locality(names: {'en': en, 'he': he}, point: GeoPoint(lat, lng), aliases: aliases);

final _israelLocalities = <Locality>[
  _l('Jerusalem', 'ירושלים', 31.7683, 35.2137, ['Yerushalayim']),
  _l('Tel Aviv-Yafo', 'תל אביב-יפו', 32.0853, 34.7818, ['Tel Aviv', 'Jaffa', 'Yafo', 'תל אביב', 'יפו']),
  _l('Haifa', 'חיפה', 32.7940, 34.9896),
  _l('Rishon LeZion', 'ראשון לציון', 31.9730, 34.7925, ['Rishon', 'Rishon Lezion']),
  _l('Petah Tikva', 'פתח תקווה', 32.0840, 34.8878, ['Petach Tikva', 'Petah Tiqva', 'פתח תקוה']),
  _l('Ashdod', 'אשדוד', 31.8014, 34.6435),
  _l('Netanya', 'נתניה', 32.3215, 34.8532, ['Natanya']),
  _l('Beersheba', 'באר שבע', 31.2518, 34.7913, ['Beer Sheva', "Be'er Sheva", 'Beersheva']),
  _l('Bnei Brak', 'בני ברק', 32.0807, 34.8338),
  _l('Holon', 'חולון', 32.0158, 34.7874),
  _l('Ramat Gan', 'רמת גן', 32.0684, 34.8248),
  _l('Rehovot', 'רחובות', 31.8928, 34.8113, ['Rechovot']),
  _l('Ashkelon', 'אשקלון', 31.6688, 34.5743),
  _l('Bat Yam', 'בת ים', 32.0132, 34.7480),
  _l('Beit Shemesh', 'בית שמש', 31.7470, 34.9881),
  _l('Kfar Saba', 'כפר סבא', 32.1750, 34.9070, ['Kfar Sava']),
  _l('Herzliya', 'הרצליה', 32.1624, 34.8447, ['Herzliyya']),
  _l('Hadera', 'חדרה', 32.4340, 34.9196),
  _l("Modi'in-Maccabim-Re'ut", 'מודיעין-מכבים-רעות', 31.8980, 35.0104, ['Modiin', "Modi'in", 'מודיעין']),
  _l('Nazareth', 'נצרת', 32.6996, 35.3035),
  _l('Lod', 'לוד', 31.9510, 34.8881),
  _l('Ramla', 'רמלה', 31.9293, 34.8664),
  _l("Ra'anana", 'רעננה', 32.1848, 34.8713, ['Raanana']),
  _l('Rosh HaAyin', 'ראש העין', 32.0956, 34.9566, ['Rosh Haayin']),
  _l('Hod HaSharon', 'הוד השרון', 32.1500, 34.8880),
  _l('Ramat HaSharon', 'רמת השרון', 32.1460, 34.8390),
  _l('Kiryat Gat', 'קריית גת', 31.6100, 34.7642, ['Qiryat Gat', 'קרית גת']),
  _l('Nahariya', 'נהריה', 33.0059, 35.0941),
  _l('Afula', 'עפולה', 32.6078, 35.2897),
  _l('Karmiel', 'כרמיאל', 32.9190, 35.2950),
  _l('Eilat', 'אילת', 29.5577, 34.9519),
  _l('Tiberias', 'טבריה', 32.7922, 35.5312),
  _l('Kiryat Shmona', 'קריית שמונה', 33.2073, 35.5697, ['קרית שמונה']),
  _l('Dimona', 'דימונה', 31.0700, 35.0300),
  _l('Arad', 'ערד', 31.2589, 35.2128),
  _l('Yavne', 'יבנה', 31.8780, 34.7390),
  _l('Ness Ziona', 'נס ציונה', 31.9293, 34.7987, ['Nes Ziona']),
  _l('Givatayim', 'גבעתיים', 32.0722, 34.8125),
  _l('Kiryat Ono', 'קריית אונו', 32.0630, 34.8550, ['קרית אונו']),
  _l('Or Yehuda', 'אור יהודה', 32.0290, 34.8560),
  _l('Kiryat Ata', 'קריית אתא', 32.8090, 35.1060, ['קרית אתא']),
  _l('Akko', 'עכו', 32.9281, 35.0820, ['Acre', 'Acco']),
  _l('Safed', 'צפת', 32.9646, 35.4960, ['Tzfat', 'Zefat']),
  _l('Sderot', 'שדרות', 31.5250, 34.5960),
  _l('Netivot', 'נתיבות', 31.4230, 34.5890),
  _l('Ofakim', 'אופקים', 31.3140, 34.6200),
  _l('Rahat', 'רהט', 31.3930, 34.7570),
  _l('Gedera', 'גדרה', 31.8120, 34.7790),
  _l('Shoham', 'שוהם', 31.9990, 34.9460),
  _l('Mevaseret Zion', 'מבשרת ציון', 31.8030, 35.1500),
  _l("Zikhron Ya'akov", 'זכרון יעקב', 32.5700, 34.9520, ['Zichron Yaakov', 'Zikhron Yaakov']),
  _l('Pardes Hanna-Karkur', 'פרדס חנה-כרכור', 32.4730, 34.9700, ['Pardes Hana']),
  _l('Caesarea', 'קיסריה', 32.5000, 34.9000),
  _l("Yokne'am Illit", 'יקנעם עילית', 32.6590, 35.1100, ['Yokneam']),
  _l('Migdal HaEmek', 'מגדל העמק', 32.6780, 35.2400),
  _l("Beit She'an", 'בית שאן', 32.4970, 35.4970, ['Beit Shean']),
  _l('Umm al-Fahm', 'אום אל-פחם', 32.5190, 35.1530),
  _l("Ma'alot-Tarshiha", 'מעלות-תרשיחא', 33.0160, 35.2710, ['Maalot']),
  _l('Katzrin', 'קצרין', 32.9920, 35.6910, ['Qatzrin']),
  _l('Mitzpe Ramon', 'מצפה רמון', 30.6100, 34.8010),
];
