import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/services/safety/data/food_safety.dart';
import 'package:pet_companion/services/safety/data/safety_text.dart';
import 'package:pet_companion/services/safety/data/urgent_signs.dart';

// The built-in safety content: "Is it urgent?" and "Can they eat this?".
// Both ship in English and Hebrew with their sources, and say no amounts.

final _hebrew = RegExp('[א-ת]');

/// An amount or a dose: a number with a unit.
final _amount = RegExp(
  r'\d+\s*(g|kg|mg|ml|grams?|kilos?|cups?|tablespoons?|teaspoons?|גרם|ק״ג|מ״ג|מ״ל|כפות|כוסות)\b',
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('urgent signs', () {
    test('every sign has English and Hebrew, and a stable id', () {
      final ids = <String>{};
      for (final sign in urgentSigns) {
        expect(ids.add(sign.id), isTrue, reason: 'duplicate ${sign.id}');
        for (final text in [sign.title, sign.detail]) {
          expect(text.en.trim(), isNotEmpty, reason: sign.id);
          expect(_hebrew.hasMatch(text.he), isTrue, reason: '${sign.id}: ${text.he}');
          expect(_amount.hasMatch(text.en) || _amount.hasMatch(text.he), isFalse, reason: sign.id);
        }
      }
      expect(urgentSigns.length, greaterThanOrEqualTo(14));
    });

    test('dogs and cats get their own signs; other animals the general list', () {
      final dog = urgentSignsFor(SafetyAnimal.dog).map((s) => s.id);
      final cat = urgentSignsFor(SafetyAnimal.cat).map((s) => s.id);
      final rabbit = urgentSignsFor(SafetyAnimal.of(PetSpecies.rabbit)).map((s) => s.id);
      expect(dog, containsAll(['breathing', 'collapse', 'seizure', 'poison', 'bloat', 'bleeding', 'heat', 'eye', 'accident']));
      expect(dog, isNot(contains('urine')));
      expect(cat, containsAll(['breathing', 'poison', 'urine']));
      expect(cat, isNot(contains('bloat')));
      expect(rabbit, isNot(contains('bloat')));
      expect(rabbit, isNot(contains('urine')));
      expect(rabbit, contains('breathing'));
      expect(rabbit.length, urgentSigns.where((s) => s.only == null).length);
      // The most common emergencies lead.
      expect(dog.first, 'breathing');
    });

    test('the sources are listed', () {
      expect(urgentSignSources, isNotEmpty);
      for (final source in urgentSignSources) {
        expect(source.url, startsWith('https://'));
        expect(source.name, isNotEmpty);
      }
      expect(urgentSignSources.map((s) => s.name).join(' '), contains('MSD Veterinary Manual'));
    });
  });

  group('foods and plants', () {
    test('60 to 90 entries, each in both languages, one line, no amounts', () {
      expect(foodEntries.length, inInclusiveRange(60, 90));
      final ids = <String>{};
      for (final entry in foodEntries) {
        expect(ids.add(entry.id), isTrue, reason: 'duplicate ${entry.id}');
        expect(entry.en, isNotEmpty, reason: entry.id);
        expect(entry.he, isNotEmpty, reason: entry.id);
        expect(entry.he.every(_hebrew.hasMatch), isTrue, reason: entry.id);
        expect(entry.line.en, isNot(contains('\n')), reason: entry.id);
        expect(_hebrew.hasMatch(entry.line.he), isTrue, reason: entry.id);
        expect(_amount.hasMatch(entry.line.en) || _amount.hasMatch(entry.line.he), isFalse, reason: entry.id);
      }
      // Every kind is there.
      for (final kind in FoodKind.values) {
        expect(foodEntries.where((e) => e.kind == kind), isNotEmpty, reason: kind.name);
      }
      // All three answers are used.
      for (final level in FoodLevel.values) {
        expect(foodEntries.where((e) => e.dog == level), isNotEmpty, reason: level.name);
      }
    });

    FoodEntry entry(String id) => foodEntries.singleWhere((e) => e.id == id);

    test('the answer differs by animal where the sources say so', () {
      expect(entry('lily').levelFor(SafetyAnimal.cat), FoodLevel.dangerous);
      expect(entry('lily').levelFor(SafetyAnimal.dog), FoodLevel.aLittle);
      expect(entry('avocado').levelFor(SafetyAnimal.bird), FoodLevel.dangerous);
      expect(entry('avocado').levelFor(SafetyAnimal.dog), FoodLevel.aLittle);
      expect(entry('essentialoils').levelFor(SafetyAnimal.cat), FoodLevel.dangerous);
      for (final id in ['chocolate', 'grapes', 'xylitol', 'onion', 'garlic', 'leek', 'macadamia', 'alcohol', 'caffeine']) {
        expect(entry(id).dog, FoodLevel.dangerous, reason: id);
        expect(entry(id).cat, FoodLevel.dangerous, reason: id);
      }
      expect(entry('carrot').levelFor(SafetyAnimal.dog), FoodLevel.safe);
      // Nothing is said for rabbits and the rest: the vet is asked.
      expect(entry('carrot').levelFor(SafetyAnimal.of(PetSpecies.rabbit)), isNull);
      // Before an animal is chosen, the most careful answer.
      expect(entry('lily').worst, FoodLevel.dangerous);
      expect(entry('avocado').worst, FoodLevel.dangerous);
      expect(entry('carrot').worst, FoodLevel.safe);
    });

    test('search finds English and Hebrew names and other names, best first', () {
      expect(searchFoods('choc').first.id, 'chocolate');
      expect(searchFoods('Chocolate').first.id, 'chocolate');
      expect(searchFoods('raisin').first.id, 'grapes');
      expect(searchFoods('sugar-free gum').first.id, 'xylitol');
      expect(searchFoods('lily').map((e) => e.id).take(2), ['lily', 'lilyofthevalley']);
      expect(searchFoods('tea').map((e) => e.id), containsAll(['caffeine', 'essentialoils']));
      expect(searchFoods('שוקולד').first.id, 'chocolate');
      expect(searchFoods('שוקו').first.id, 'chocolate');
      expect(searchFoods('צימוקים').first.id, 'grapes');
      expect(searchFoods('שום').first.id, 'garlic');
      // While typing, before the final letter: "שו" finds garlic too.
      expect(searchFoods('שו').map((e) => e.id), contains('garlic'));
      expect(searchFoods('הרדוף').first.id, 'oleander');
      expect(searchFoods('אקמול').first.id, 'medicines');
      expect(searchFoods('zzzz'), isEmpty);
    });

    test('an empty search lists everything in the language\'s order', () {
      final en = searchFoods('');
      expect(en.length, foodEntries.length);
      final names = en.map((e) => e.name('en')).toList();
      expect(names, [...names]..sort());
      final he = searchFoods('  ', languageCode: 'he');
      expect(he.length, foodEntries.length);
      expect(he.first.name('he'), isNot(en.first.name('he')));
    });

    test('the sources are listed', () {
      expect(foodSafetySources.map((s) => s.name).join(' '), contains('ASPCA'));
      expect(foodSafetySources.map((s) => s.name).join(' '), contains('Pet Poison Helpline'));
      for (final source in foodSafetySources) {
        expect(source.url, startsWith('https://'));
      }
    });
  });

  test('search text ignores case, vowel marks, punctuation and final letters', () {
    expect(normalizeSafetySearch('  Sugar-Free  GUM '), 'sugar free gum');
    expect(normalizeSafetySearch('שׁוּם'), 'שומ');
    expect(normalizeSafetySearch('ענבים, צימוקים'), 'ענבימ צימוקימ');
    expect(SafetyText('Dog', 'כלב').of('he'), 'כלב');
    expect(SafetyText('Dog', 'כלב').of('en'), 'Dog');
    expect(SafetyAnimal.of(PetSpecies.cat), SafetyAnimal.cat);
    expect(SafetyAnimal.of(PetSpecies.reptile), SafetyAnimal.other);
  });
}
