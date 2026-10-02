# Hebrew wording: rules and glossary

The reference for every Hebrew string in the app, approved by the owner.
Every term lives in a strings file, so changing one is a one-line edit
followed by `dart run tool/gen_l10n.dart`.

## Adding a string (any feature)

1. Add the key to your feature's English file, for example
   `lib/features/health/l10n/health_en.arb`. Give it a `@key` entry with a
   `description` when the meaning is not obvious, and with `placeholders`
   when it has any (`"type": "String"` or `"int"`).
2. Add the same key to the Hebrew file beside it (`health_he.arb`),
   following the rules below. A key you leave out shows in English and is
   listed in `l10n/gen/untranslated.json`.
3. Run `dart run tool/gen_l10n.dart health` (no argument: every module).
4. Use it: `context.healthL10n.yourKey` in a widget, or
   `ref.watch(healthL10nProvider).yourKey` in code without a
   `BuildContext`. Shared words (Save, Cancel, Today...) are in
   `context.l10n`. One import gives everything:
   `package:pet_companion/l10n/l10n.dart`.

Never edit the files in `l10n/gen/`. There is no `l10n.yaml` in the project
root, and there must not be one.

In Hebrew, put the marks U+2068 and U+2069 around every placeholder that
carries text (a name, an address, a title), so a Latin word cannot reorder
the sentence. Write them as JSON escapes (backslash, `u2068`); the generator
also rewrites invisible ones as escapes. A test checks this.

Plurals use the ICU form, and Hebrew often needs a form for two:
`{count, plural, =1{מבצע אחד} =2{שני מבצעים} other{{count} מבצעים}}`.

Dates, numbers, money: `AppFormat.of(context)`. Phone numbers, addresses of
any kind, "-40%": wrap with `ltr(...)`. Text somebody typed:
`textDirection: directionOfText(text, fallback: Directionality.of(context))`.

## Rules, so nobody is addressed as a man or as a woman

1. **Buttons are action nouns:** שמירה, הוספה, מחיקה (not שמור / שמרי).
2. **Instructions are impersonal or from "us":** "אפשר לנסות שוב", "צריך
   להזין אימייל", "לא הצלחנו לטעון".
3. **"You" only in forms spelled the same for everyone:** שלך, אותך, and
   the past tense (שכחת, שמרת). Never a singular command or "הוסף/י".
4. **The user's own words are in the first person:** "שכחתי סיסמה".
5. **A pet may be male or female:** "הפרופיל של קלי מוכן", not "קלי מוכנה".
   No prefix glued to a name: "עבור קלי", not "לקלי".
6. Casual and warm, plain words; "חיה" and "וטרינר". No exclamation marks
   outside greetings.

"PetLoop" stays in Latin letters. A language is named in its own
letters (עברית, English) on every screen.

Punctuation: Hebrew quotation marks ״...״, gershayim in abbreviations
(ק״ג, ד״ר), geresh for foreign sounds (צ׳אט) and day letters (א׳).

## Glossary

| English | Hebrew |
|---|---|
| Home · Health · Community · Store | בית · בריאות · קהילה · חנות |
| Overview · Schedule · History · Insights | סקירה · לוח זמנים · היסטוריה · תובנות |
| Feed · Chat · Guides | פיד · צ׳אט · מדריכים |
| pet, pets, "2 pets" | חיה, חיות, "2 חיות" |
| Add a pet | הוספת חיה |
| Breed · Age · Weight · Mix | גזע · גיל · משקל · מעורב |
| kg · g · years | ק״ג · גרם · שנים |
| Feeding · Activity · Steps · Activity time | האכלה · פעילות · צעדים · זמן פעילות |
| Next feeding · Next walk | ההאכלה הבאה · הטיול הבא |
| Goal 900 cal/day · 375 cal today | יעד: 900 קלוריות ביום · 375 קלוריות היום |
| Upcoming / Coming up | בקרוב |
| Today · Tomorrow · Yesterday | היום · מחר · אתמול |
| Emergency | חירום |
| Emergency card | כרטיס חירום |
| Call · Message · Map | חיוג · הודעה · מפה |
| Regular vet | וטרינר קבוע |
| Emergency vet (24 h) | וטרינר חירום (24 שעות) |
| Emergency contact | איש קשר לחירום |
| Add Kelly's vet | הוספת וטרינר עבור קלי |
| You make the call or send the message yourself. | האפליקציה רק פותחת את החייגן או את ההודעות. החיוג והשליחה בידיים שלך. |
| PetLoop never contacts anyone on its own, and it does not replace veterinary advice. | PetLoop אף פעם לא יוצרת קשר עם אף אחד בעצמה, ואינה תחליף לייעוץ וטרינרי. |
| This guide is general guidance and not a substitute for advice from your veterinarian. | המדריך נותן מידע כללי ואינו תחליף לייעוץ של וטרינר. |
| Looks urgent? Contact the vet | נראה דחוף? כדאי לפנות לווטרינר |
| Quick log | רישום מהיר |
| Add record | הוספת רשומה |
| Medical records (one: record) | תיק רפואי (אחת: רשומה) |
| Vaccinations · Vet visits · Documents | חיסונים · ביקורי וטרינר · מסמכים |
| Medicines · Routine · Reminder | תרופות · שגרה · תזכורת |
| Record dose: Given · Not given · Not sure | רישום מנה: ניתנה · לא ניתנה · לא ידוע |
| Needs review · Done today | ממתינות לעדכון · בוצע היום |
| Every day · Weekdays · Weekends | כל יום · ימי חול · סוף שבוע |
| Journal (what the owner noticed) | יומן תצפיות |
| Allergies · Medical conditions · Microchip | אלרגיות · מחלות רקע · שבב |
| None known | לא ידוע על כאלה |
| Essentials | פרטים חיוניים |
| 2 of 5 essentials still to add | חסרים 2 מתוך 5 פרטים חיוניים |
| Not now · Skip for now | לא עכשיו · לדלג בינתיים |
| New post · Post (the button) | פוסט חדש · פרסום |
| Like · Comments · Report | לייק · תגובות · דיווח |
| Message General · Send | הודעה בחדר ״כללי״ · שליחה |
| Rooms: General, Puppies, Training tips, Senior dogs, Health questions | כללי, גורים, טיפים לאילוף, כלבים מבוגרים, שאלות בריאות |
| deal, deals | מבצע, מבצעים |
| Share a deal · Saved deals | שיתוף מבצע · מבצעים ששמרתי |
| Open offer | מעבר למבצע באתר המוכר |
| Expired · 12 days left · Ends today | הסתיים · נותרו 12 ימים · מסתיים היום |
| Food, Treats, Toys, Health, Grooming, Accessories, Beds & crates | מזון, חטיפים, צעצועים, בריאות, טיפוח, אביזרים, מיטות וכלובים |
| Biggest discount · Lowest price · Newest · Ending soon | ההנחה הגדולה ביותר · המחיר הנמוך ביותר · החדשים ביותר · מסתיימים בקרוב |
| Sign in · Create an account · Sign out | כניסה · יצירת חשבון · יציאה מהחשבון |
| Email · Password · Forgot password? | אימייל · סיסמה · שכחתי סיסמה |
| Welcome back · New here? | טוב לראות אותך שוב · פעם ראשונה כאן? |
| Sign in to see how your pets are doing today. | כניסה קצרה, ואפשר לראות מה שלום החיות שלך היום. |
| Language · Follow the phone | שפה · לפי שפת המכשיר |
| Menu · My pets · Settings | תפריט · החיות שלי · הגדרות |
| Week · First day of the week | שבוע · היום הראשון בשבוע |
| Saturday · Sunday · Monday (as a choice) | שבת · ראשון · שני |
| Sunday to Thursday · Monday to Friday | ראשון עד חמישי · שני עד שישי |
| Save · Cancel · Delete · Edit · Add | שמירה · ביטול · מחיקה · עריכה · הוספה |
| Back · Close · Continue · Share · Try again | חזרה · סגירה · המשך · שיתוף · לנסות שוב |
| No records yet · No deals yet · No messages yet | עדיין אין רשומות · עדיין אין מבצעים · עדיין אין הודעות |
| Could not load deals | לא הצלחנו לטעון את המבצעים |
| Something went wrong. Please try again. | משהו השתבש. אפשר לנסות שוב. |
| This cannot be undone. | אי אפשר לבטל את הפעולה הזאת. |
