import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/services/pet_records/plans/plan_logic.dart';
import 'package:pet_companion/services/pet_records/plans/plan_templates.dart';

final today = DateTime(2026, 10, 17);

Pet dog({DateTime? born, double? years}) => Pet(
  id: 'kelly',
  name: 'Kelly',
  birthDate: born,
  ageYears: years,
);

Pet cat({DateTime? born}) =>
    Pet(id: 'soya', name: 'Soya', species: PetSpecies.cat, birthDate: born);

HealthRecord done(
  String title,
  DateTime at, {
  RecordKind kind = RecordKind.vaccination,
  String product = '',
  String? plan,
  String id = '',
}) => HealthRecord(
  id: id.isEmpty ? 'r-$title-${at.toIso8601String()}' : id,
  petId: 'kelly',
  kind: kind,
  title: title,
  scheduledAt: at,
  doneAt: at,
  productName: product,
  planItem: plan,
);

HealthRecord planned(
  String title,
  DateTime at, {
  RecordKind kind = RecordKind.vaccination,
  String? plan,
}) => HealthRecord(
  id: 'p-$title',
  petId: 'kelly',
  kind: kind,
  title: title,
  scheduledAt: at,
  planItem: plan,
);

PlanProposal itemOf(List<PlanProposal> plan, String key) =>
    plan.firstWhere((p) => p.item.key == key);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the templates', () {
    test('dogs and cats have their items; other animals none', () {
      expect(planTemplatesFor(PetSpecies.dog).map((i) => i.key), [
        'dog.rabies',
        'dog.combined',
        'dog.spirocerca',
        'dog.deworm',
        'dog.flea',
      ]);
      expect(planTemplatesFor(PetSpecies.cat).map((i) => i.key), [
        'cat.combined',
        'cat.rabies',
        'cat.deworm',
        'cat.flea',
      ]);
      expect(planTemplatesFor(PetSpecies.rabbit), isEmpty);
    });

    test('every item speaks both languages, says why and lists sources', () {
      final hebrew = RegExp('[֐-׿]');
      for (final item in [...dogPlan, ...catPlan]) {
        for (final text in [item.title, item.why, ?item.seriesTitle]) {
          expect(text.en.trim(), isNotEmpty, reason: item.key);
          expect(hebrew.hasMatch(text.he), isTrue, reason: item.key);
          expect(hebrew.hasMatch(text.en), isFalse, reason: item.key);
        }
        expect(item.sources, isNotEmpty, reason: item.key);
        expect(item.kind.hasNextDue, isTrue, reason: item.key);
        for (final word in item.matchWords) {
          expect(word, word.toLowerCase(), reason: item.key);
        }
        expect(planTemplateByKey(item.key), same(item));
      }
    });

    test('rabies is the law for dogs and a recommendation for cats', () {
      expect(planTemplateByKey('dog.rabies')!.standing, PlanStanding.requiredByLaw);
      expect(planTemplateByKey('cat.rabies')!.standing, PlanStanding.recommended);
      expect(planTemplateByKey('dog.rabies')!.startAgeWeeks, 12);
      expect(
        planTemplateByKey('dog.rabies')!.sources.first.title,
        contains('Veterinary Services'),
      );
    });

    test('a record matches its item by words in either language', () {
      final rabies = planTemplateByKey('dog.rabies')!;
      final deworm = planTemplateByKey('dog.deworm')!;
      final park = planTemplateByKey('dog.spirocerca')!;
      expect(rabies.matches(done('חיסון כלבת', today)), isTrue);
      expect(rabies.matches(done('Booster', today, product: 'Rabisin')), isTrue);
      expect(rabies.matches(done('Rabies', today, kind: RecordKind.checkup)), isFalse);
      final worming = done('Worming tablet', today, kind: RecordKind.preventive);
      expect(deworm.matches(worming), isTrue);
      expect(park.matches(worming), isFalse);
      final parkWorm = done('טיפול נגד תולעת הפארק', today, kind: RecordKind.preventive);
      expect(park.matches(parkWorm), isTrue);
      // A record of the plan matches its own item only.
      final fromPlan = done('Anything', today, plan: 'dog.combined#2');
      expect(planTemplateByKey('dog.combined')!.matches(fromPlan), isTrue);
      expect(rabies.matches(fromPlan), isFalse);
    });

    test('months are added on the calendar, never past the month', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2027, 11, 30), 3), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 3, 14), 12), DateTime(2027, 3, 14));
    });
  });

  group('PlanRef', () {
    test('reads and writes the plan_item column', () {
      for (final text in ['dog.rabies', 'dog.combined#2', 'dog.flea@3m', 'cat.combined#3']) {
        expect(PlanRef.parse(text).toString(), text);
      }
      expect(PlanRef.parse('dog.combined#2')!.dose, 2);
      expect(PlanRef.parse('dog.flea@3m')!.months, 3);
      for (final bad in [null, '', 'dog', 'Dog.rabies', 'dog.rabies#0', 'dog.flea@0m', 'dog.rabies;drop']) {
        expect(PlanRef.parse(bad), isNull, reason: '$bad');
      }
    });
  });

  group('proposePlan', () {
    test('an adult dog: from the last time, overdue as soon as possible, '
        'otherwise in two weeks', () {
      final records = [
        done('Rabies booster', DateTime(2026, 3, 14, 10)),
        done('Worming tablet', DateTime(2026, 4, 10), kind: RecordKind.preventive),
        done('Bravecto', DateTime(2026, 9, 30), kind: RecordKind.preventive),
      ];
      final plan = proposePlan(pet: dog(years: 9), records: records, today: today);
      final rabies = itemOf(plan, 'dog.rabies');
      expect(rabies.basis, PlanBasis.lastDone);
      expect(rabies.due, DateTime(2027, 3, 14));
      expect(rabies.lastDone, records[0]);
      final deworm = itemOf(plan, 'dog.deworm');
      expect(deworm.basis, PlanBasis.overdue);
      expect(deworm.due, today);
      final flea = itemOf(plan, 'dog.flea');
      expect(flea.basis, PlanBasis.lastDone);
      expect(flea.due, DateTime(2026, 10, 30), reason: 'monthly by default');
      expect(flea.withMonths(3, today: today).due, DateTime(2026, 12, 30));
      expect(flea.withMonths(3, today: today).ref.toString(), 'dog.flea@3m');
      final combined = itemOf(plan, 'dog.combined');
      expect(combined.basis, PlanBasis.noHistory);
      expect(combined.due, DateTime(2026, 10, 31));
      expect(combined.ref.dose, isNull, reason: 'an adult gets no puppy series');
    });

    test('a planned record of an item is kept, not planned twice', () {
      final records = [planned('Rabies booster', DateTime(2027, 3, 14, 9))];
      final rabies = itemOf(
        proposePlan(pet: dog(years: 4), records: records, today: today),
        'dog.rabies',
      );
      expect(rabies.basis, PlanBasis.alreadyPlanned);
      expect(rabies.planned, records.single);
      expect(rabies.due, DateTime(2027, 3, 14));
      expect(rabies.title(hebrew: true), 'Rabies booster');
    });

    test('a 9-week-old puppy: its series from its age, rabies at 3 months', () {
      final born = DateTime(2026, 8, 15);
      final plan = proposePlan(pet: dog(born: born), records: const [], today: today);
      final combined = itemOf(plan, 'dog.combined');
      expect(combined.basis, PlanBasis.series);
      expect(combined.ref.toString(), 'dog.combined#1');
      expect(combined.due, today, reason: 'the 8-week dose is late: today');
      expect(combined.title(hebrew: false), 'Combined vaccine, puppy dose 1 of 3');
      expect(combined.title(hebrew: true), 'חיסון משושה, מנת גור 1 מתוך 3');
      final rabies = itemOf(plan, 'dog.rabies');
      expect(rabies.basis, PlanBasis.tooYoung);
      expect(rabies.due, addDays(born, 12 * 7));
      expect(itemOf(plan, 'dog.spirocerca').basis, PlanBasis.tooYoung);
    });

    test('the next puppy dose comes at its age, and at least 3 weeks after '
        'the last one', () {
      final born = DateTime(2026, 7, 27);
      // Dose 1 late, at 10 weeks and 5 days; today the puppy is 11 weeks
      // and 5 days, and its 12-week dose would be in two days.
      final first = done('Combined vaccine', addDays(born, 75));
      final combined = itemOf(
        proposePlan(pet: dog(born: born), records: [first], today: today),
        'dog.combined',
      );
      expect(combined.ref.dose, 2);
      expect(combined.due, addDays(dateOnly(first.when), 21));
      expect(combined.due.isAfter(today), isTrue);
    });

    test('a kitten gets the cat series; a rabbit gets no plan', () {
      final plan = proposePlan(pet: cat(born: DateTime(2026, 9, 1)), records: const [], today: today);
      expect(itemOf(plan, 'cat.combined').ref.toString(), 'cat.combined#1');
      expect(itemOf(plan, 'cat.combined').due, addDays(DateTime(2026, 9, 1), 56));
      expect(
        proposePlan(
          pet: const Pet(id: 'b', name: 'Bun', species: PetSpecies.rabbit),
          records: const [],
          today: today,
        ),
        isEmpty,
      );
    });

    test('a planned record from a proposal: the item, at 9:00, in the app\'s '
        'language', () {
      final proposal = itemOf(
        proposePlan(pet: dog(years: 3), records: const [], today: today),
        'dog.spirocerca',
      );
      final record = plannedRecordOf(proposal, petId: 'kelly', hebrew: true);
      expect(record.isNew, isTrue);
      expect(record.isDone, isFalse);
      expect(record.kind, RecordKind.preventive);
      expect(record.title, 'מניעת תולעת הפארק');
      expect(record.scheduledAt, DateTime(2026, 10, 31, 9));
      expect(record.planItem, 'dog.spirocerca');
    });
  });

  group('after a plan item is done', () {
    HealthRecord doneFromPlan(String plan, DateTime at, {RecordKind kind = RecordKind.vaccination}) =>
        done('x', at, plan: plan, kind: kind);

    test('the series moves on dose by dose, then once a year', () {
      final born = DateTime(2026, 6, 1);
      final one = nextPlanStep(doneFromPlan('dog.combined#1', DateTime(2026, 7, 27)), birth: born)!;
      expect(one.ref.toString(), 'dog.combined#2');
      expect(one.due, addDays(born, 12 * 7));
      expect(one.title(hebrew: false), 'Combined vaccine, puppy dose 2 of 3');
      final three = nextPlanStep(doneFromPlan('dog.combined#3', DateTime(2026, 9, 21)), birth: born)!;
      expect(three.ref.toString(), 'dog.combined');
      expect(three.due, DateTime(2027, 9, 21));
      expect(three.title(hebrew: true), 'חיסון משושה');
      // Without a birthday, four weeks later.
      expect(
        nextPlanStep(doneFromPlan('cat.combined#1', DateTime(2026, 10, 1)))!.due,
        DateTime(2026, 10, 29),
      );
    });

    test('an item repeats after its interval, the young more often', () {
      expect(nextPlanStep(doneFromPlan('dog.rabies', DateTime(2026, 10, 17, 11)))!.due, DateTime(2027, 10, 17));
      expect(
        nextPlanStep(doneFromPlan('dog.flea@3m', DateTime(2026, 10, 17), kind: RecordKind.preventive))!
            .ref
            .toString(),
        'dog.flea@3m',
      );
      expect(
        nextPlanStep(doneFromPlan('dog.flea@3m', DateTime(2026, 10, 17), kind: RecordKind.preventive))!.due,
        DateTime(2027, 1, 17),
      );
      final puppy = DateTime(2026, 9, 1);
      expect(
        nextPlanStep(doneFromPlan('dog.deworm', DateTime(2026, 10, 17), kind: RecordKind.preventive), birth: puppy)!.due,
        DateTime(2026, 10, 31),
        reason: 'every 2 weeks under 12 weeks old',
      );
      expect(
        nextPlanStep(doneFromPlan('dog.deworm', DateTime(2026, 10, 17), kind: RecordKind.preventive))!.due,
        DateTime(2027, 1, 17),
        reason: 'every 3 months for an adult',
      );
    });

    test('the next due date is set only when a plan record becomes done', () {
      final plannedRabies = planned('Rabies vaccine', DateTime(2026, 10, 17, 9), plan: 'dog.rabies');
      final marked = withPlanNextDue(
        plannedRabies.withDone(DateTime(2026, 10, 18, 10)),
        before: plannedRabies,
      );
      expect(marked.nextDueOn, DateTime(2027, 10, 18));

      // Already done before: the owner's choice (even none) stands.
      final edited = marked.withNextDue(null);
      expect(withPlanNextDue(edited, before: marked).nextDueOn, isNull);
      // Its own next due date is kept.
      final own = plannedRabies.withDone(DateTime(2026, 10, 18)).withNextDue(DateTime(2027, 6, 1));
      expect(withPlanNextDue(own, before: plannedRabies).nextDueOn, DateTime(2027, 6, 1));
      // A record added by hand never gets one from the app.
      final byHand = planned('Rabies vaccine', DateTime(2026, 10, 17));
      expect(withPlanNextDue(byHand.withDone(DateTime(2026, 10, 18)), before: byHand).nextDueOn, isNull);
      // Nor does a plan record that is still planned.
      expect(withPlanNextDue(plannedRabies).nextDueOn, isNull);
    });

    test('its follow-up is named after the next step', () {
      final doneDose = done('Combined vaccine, puppy dose 1 of 3', DateTime(2026, 7, 27), plan: 'dog.combined#1');
      final follow = planFollowUpOf(doneDose, hebrew: false)!;
      expect(follow.planItem, 'dog.combined#2');
      expect(follow.title, 'Combined vaccine, puppy dose 2 of 3');
      expect(planFollowUpOf(done('Rabies', DateTime(2026, 1, 1)), hebrew: false), isNull);
    });
  });
}
