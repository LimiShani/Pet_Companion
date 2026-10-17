// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'healthplan_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class HealthPlanL10nHe extends HealthPlanL10n {
  HealthPlanL10nHe([String locale = 'he']) : super(locale);

  @override
  String insightShorterWalks(String pet) {
    return 'הטיולים של \u2068$pet\u2069 היו קצרים יותר מבחודש שעבר. אם זה נמשך, כדאי לדבר על זה עם הווטרינר.';
  }

  @override
  String insightWeightUp(String pet, int percent) {
    return 'המשקל של \u2068$pet\u2069 עלה בכ־$percent% בשבועות האחרונים. אם זה נמשך, כדאי לדבר על זה עם הווטרינר.';
  }

  @override
  String insightWeightDown(String pet, int percent) {
    return 'המשקל של \u2068$pet\u2069 ירד בכ־$percent% בשבועות האחרונים. אם זה נמשך, כדאי לדבר על זה עם הווטרינר.';
  }

  @override
  String insightAppetiteLess(String pet, int count) {
    return 'בשבועיים האחרונים נרשם $count פעמים שהתיאבון של \u2068$pet\u2069 היה פחות מהרגיל. אם זה נמשך, כדאי לדבר על זה עם הווטרינר.';
  }

  @override
  String get insightSeeWalks => 'לטיולים';

  @override
  String get insightSeeWeight => 'למשקל';

  @override
  String get insightSeeJournal => 'ליומן התצפיות';
}
