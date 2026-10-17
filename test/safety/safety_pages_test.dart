import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/safety/food_check_screen.dart';
import 'package:pet_companion/features/safety/lost_mode_screens.dart';
import 'package:pet_companion/features/safety/safety_widgets.dart';
import 'package:pet_companion/features/safety/urgent_signs_screen.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/services/community/data/community_models.dart';
import 'package:pet_companion/services/community/data/community_providers.dart';
import 'package:pet_companion/services/community/data/fake_feed_repository.dart';
import 'package:pet_companion/services/safety/data/fake_lost_alerts_repository.dart';
import 'package:pet_companion/services/safety/data/food_safety.dart';
import 'package:pet_companion/services/safety/data/safety_text.dart';
import 'package:pet_companion/services/safety/state/safety_providers.dart';

import '../health/health_test_helpers.dart';

// The safety pages, reached from the Emergency sheet as the owner reaches
// them: Is it urgent?, Can they eat this? (search, filters, a food's
// sheet) and Lost mode (start, preview, the open alert, found, cancel).

const _alex = AppUser(id: 'demo', email: 'demo@petloop.app', displayName: 'Alex');
const _maya = AppUser(id: 'maya', email: 'maya@example.test', displayName: 'Maya');

/// A harness whose Lost mode writes its posts into a fake feed, as the
/// server writes them into the community.
({HealthHarness h, FakeFeedRepository feed, FakeLostAlertsRepository lost}) _lostHarness() {
  final feed = FakeFeedRepository(latency: Duration.zero, now: () => fixedNow, seeded: false);
  final lost = FakeLostAlertsRepository(
    latency: Duration.zero,
    now: () => fixedNow,
    seeded: false,
    petFacts: (id) => (name: id == 'kelly' ? 'Kelly' : 'Soya', species: id == 'kelly' ? 'dog' : 'cat'),
    postWriter: (alert) async => (await feed.createPost(
      author: _alex,
      text: lostPostBody(language: 'en', name: alert.petName, species: alert.petSpecies, seenAt: alert.lastSeenAt),
      petName: alert.petName,
      kind: PostKind.lostFound,
    )).id,
  );
  final h = HealthHarness(lostAlerts: lost);
  h.extraOverrides.add(feedRepositoryProvider.overrideWithValue(feed));
  return (h: h, feed: feed, lost: lost);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget button(String petId) => Row(children: [EmergencyButton(petId: petId, onCoral: false)]);

  Future<HealthHarness> openSheet(WidgetTester tester, String petId, {HealthHarness? harness}) async {
    final h = await pumpHealthHost(tester, button(petId), harness: harness);
    await tester.tap(find.byType(EmergencyButton));
    await tester.pumpAndSettle();
    return h;
  }

  group('Is it urgent?', () {
    testWidgets("a dog's signs under one Call now that dials the 24 h clinic", (tester) async {
      final h = await openSheet(tester, 'kelly');
      await tapVisible(tester, find.byKey(const Key('emergency-urgent')));

      expect(find.byType(UrgentSignsScreen), findsOneWidget);
      expect(find.text('Is it urgent?'), findsOneWidget);
      expect(find.text('Signs in dogs'), findsOneWidget);
      expect(find.byKey(UrgentSignsScreen.signKey('bloat')), findsOneWidget);
      expect(find.byKey(UrgentSignsScreen.signKey('urine')), findsNothing);
      expect(find.text('Trouble breathing'), findsOneWidget);
      // One action: Call now, above the list, no button on any sign.
      expect(find.text('Call now'), findsOneWidget);
      expect(find.text('City Animal Hospital'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(UrgentSignsScreen.listKey), matching: find.byType(ButtonStyleButton)),
        findsNothing,
      );
      await tester.tap(find.byKey(SafetyCallCard.callKey));
      await tester.pumpAndSettle();
      expect(h.launcher.calls.single.target, '+972 3 555 0199');

      // The sources, folded.
      expect(find.textContaining('Pet Poison Helpline'), findsNothing);
      await tapVisible(tester, find.text('Where this comes from'));
      expect(find.textContaining('Pet Poison Helpline'), findsOneWidget);
      expect(find.text('Lists and signs are general guidance, not a diagnosis. When in doubt, call.'), findsOneWidget);
    });

    testWidgets("a cat's signs, and a clinic to find when no vet is saved", (tester) async {
      final cat = HealthHarness(pets: [Pet(id: 'soya', name: 'Soya', species: PetSpecies.cat, createdAt: DateTime(2025))]);
      await openSheet(tester, 'soya', harness: cat);
      await tapVisible(tester, find.byKey(const Key('emergency-urgent')));
      expect(find.text('Signs in cats'), findsOneWidget);
      expect(find.byKey(UrgentSignsScreen.signKey('urine')), findsOneWidget);
      expect(find.byKey(UrgentSignsScreen.signKey('bloat')), findsNothing);
      expect(find.text('Call now'), findsNothing);
      expect(find.byKey(SafetyCallCard.findClinicKey), findsOneWidget);
      expect(find.text('No vet saved? Find a clinic nearby'), findsOneWidget);
    });
  });

  group('Can they eat this?', () {
    Finder tagOf(String id, String level) =>
        find.descendant(of: find.byKey(FoodCheckScreen.rowKey(id)), matching: find.text(level));

    testWidgets('search, the answer, the sheet and a call to the vet', (tester) async {
      final h = await openSheet(tester, 'kelly');
      await tapVisible(tester, find.byKey(const Key('emergency-food')));
      expect(find.text('Can Kelly eat this?'), findsOneWidget);
      expect(find.text('Dog'), findsOneWidget);
      // Everything to begin with, the dangerous first.
      expect(tagOf('chocolate', 'Dangerous'), findsOneWidget);

      await tester.enterText(find.byKey(FoodCheckScreen.searchKey), 'raisin');
      await tester.pumpAndSettle();
      expect(tagOf('grapes', 'Dangerous'), findsOneWidget);
      expect(find.byKey(FoodCheckScreen.rowKey('carrot')), findsNothing);

      await tester.tap(find.byKey(FoodCheckScreen.rowKey('grapes')));
      await tester.pumpAndSettle();
      expect(find.text('Can harm the kidneys, even a few. There is no safe amount.'), findsOneWidget);
      expect(find.text('For cats: Dangerous · For birds: not on our list'), findsOneWidget);
      expect(find.text('Also: grape, raisin, sultanas, currants'), findsOneWidget);
      expect(find.text('Eaten already? Call even if all seems fine.'), findsOneWidget);
      expect(tester.widget(find.byKey(FoodSheet.callKey)), isA<FilledButton>());
      await tester.tap(find.byKey(FoodSheet.callKey));
      await tester.pumpAndSettle();
      expect(h.launcher.calls.single.target, '+972 3 555 0199');
      Navigator.of(tester.element(find.byType(FoodSheet))).pop();
      await tester.pumpAndSettle();

      // A synonym is shown under the name it found.
      await tester.enterText(find.byKey(FoodCheckScreen.searchKey), 'grapefruit');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byKey(FoodCheckScreen.rowKey('citrus')), matching: find.text('grapefruit')),
        findsOneWidget,
      );

      // Nothing found: one sentence, one action.
      await tester.enterText(find.byKey(FoodCheckScreen.searchKey), 'lychee');
      await tester.pumpAndSettle();
      expect(find.byKey(FoodCheckScreen.nothingKey), findsOneWidget);
      expect(find.text('Nothing found for “lychee”.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('food-nothing-call')));
      await tester.pumpAndSettle();
      expect(h.launcher.calls, hasLength(2));
    });

    testWidgets('the kind chips and one animal at a time', (tester) async {
      await openSheet(tester, 'kelly');
      await tapVisible(tester, find.byKey(const Key('emergency-food')));
      await tester.tap(find.byKey(FoodCheckScreen.kindKey(FoodKind.plant)));
      await tester.pumpAndSettle();
      expect(find.byKey(FoodCheckScreen.rowKey('chocolate')), findsNothing);
      expect(tagOf('lily', 'A little'), findsOneWidget);

      await tester.tap(find.byKey(FoodCheckScreen.animalKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FoodCheckScreen.animalItemKey(SafetyAnimal.cat)).last);
      await tester.pumpAndSettle();
      expect(find.text('Cat'), findsOneWidget);
      expect(tagOf('lily', 'Dangerous'), findsOneWidget);

      // A safe answer: a quieter call.
      await tester.enterText(find.byKey(FoodCheckScreen.searchKey), 'catnip');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FoodCheckScreen.rowKey('catnip')));
      await tester.pumpAndSettle();
      expect(tester.widget(find.byKey(FoodSheet.callKey)), isA<OutlinedButton>());
      expect(find.text('Not sure? Call the vet'), findsOneWidget);
      expect(find.text('Eaten already? Call even if all seems fine.'), findsNothing);
      expect(find.text('For dogs: Safe · For birds: not on our list'), findsOneWidget);
    });
  });

  group('Lost mode', () {
    testWidgets('start, preview, the open alert, sightings and found', (tester) async {
      final (:h, :feed, :lost) = _lostHarness();
      await openSheet(tester, 'kelly', harness: h);
      await tapVisible(tester, find.byKey(const Key('emergency-lost')));

      // Step 1.
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('Kelly'), findsWidgets);
      expect(find.byKey(LostStartScreen.changePetKey), findsOneWidget);
      await tapVisible(tester, find.byKey(LostStartScreen.nextKey));
      expect(find.text('Choose the town first'), findsOneWidget);
      await tapVisible(tester, find.byKey(LostStartScreen.townKey));
      await tester.enterText(find.byKey(const Key('lost-town-field')), 'raan');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lost-town-raanana')));
      await tester.pumpAndSettle();
      expect(find.text("Ra'anana"), findsOneWidget);
      await tester.enterText(find.byKey(LostStartScreen.placeKey), 'Ahuza park gate');
      await tester.enterText(find.byKey(LostStartScreen.noteKey), 'Shy, do not chase');
      await tapVisible(tester, find.byKey(LostStartScreen.nextKey));

      // Step 2: the post as people will see it, in the card's language
      // (Hebrew by default).
      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(find.text('What people will see'), findsOneWidget);
      final preview = find.byKey(LostStartScreen.previewKey);
      expect(find.descendant(of: preview, matching: find.textContaining('מחפשים את')), findsOneWidget);
      expect(find.descendant(of: preview, matching: find.textContaining('Ahuza park gate')), findsOneWidget);
      expect(find.descendant(of: preview, matching: find.textContaining('Shy, do not chase')), findsOneWidget);
      expect(find.descendant(of: preview, matching: find.text('Lost and found')), findsOneWidget);
      expect(
        find.text("People in Ra'anana who use PetLoop get one notification. Sightings come as comments."),
        findsOneWidget,
      );
      // Back keeps what was typed.
      await tapVisible(tester, find.byKey(LostStartScreen.backKey));
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('Ahuza park gate'), findsOneWidget);
      await tapVisible(tester, find.byKey(LostStartScreen.nextKey));

      await tapVisible(tester, find.text('Start lost mode'));
      final alert = lost.alerts.single;
      expect(alert.isActive, isTrue);
      expect(alert.localityCode, 'raanana');
      expect(alert.lastSeenPlace, 'Ahuza park gate');
      expect(alert.note, 'Shy, do not chase');
      expect(alert.language, 'he');
      // The card to share comes next, over the open alert.
      expect(find.text('Kelly is lost'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LostAlertScreen), findsOneWidget);
      expect(find.text('Kelly is missing'), findsOneWidget);
      expect(find.text("Ra'anana · Ahuza park gate"), findsOneWidget);
      expect(find.text('No sightings yet. Sharing the card reaches more people.'), findsOneWidget);

      // A neighbour comments; the page opened again lists it.
      await real(tester, () => feed.addComment(author: _maya, postId: alert.postId!, text: 'Saw her by the school'));
      lost.addSighting(alert.id);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LostStartScreen), findsNothing);
      await tapVisible(tester, find.byKey(const Key('emergency-lost')));
      expect(find.text('Saw her by the school'), findsOneWidget);
      expect(find.byKey(LostAlertScreen.openPostKey), findsOneWidget);

      // Found: the alert closes and the page with it.
      await tapVisible(tester, find.text('Kelly is home'));
      expect(lost.alerts.single.status, LostAlertStatus.found);
      expect(find.byType(LostAlertScreen), findsNothing);
      expect(find.text('Good news. The alert is closed.'), findsOneWidget);
      expect(find.text('Lost mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing without found asks first', (tester) async {
      final (:h, feed: _, :lost) = _lostHarness();
      await real(
        tester,
        () => lost.start(LostStart(petId: 'kelly', localityCode: 'raanana', seenAt: fixedNow, place: 'Park')),
      );
      await openSheet(tester, 'kelly', harness: h);
      expect(find.text('Kelly is missing · no sightings yet'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('emergency-lost')));

      await tapVisible(tester, find.byKey(LostAlertScreen.closeKey));
      expect(find.text('Close the alert without “found”?'), findsOneWidget);
      await tester.tap(find.text('Keep looking'));
      await tester.pumpAndSettle();
      expect(lost.alerts.single.isActive, isTrue);

      await tapVisible(tester, find.byKey(LostAlertScreen.closeKey));
      await tester.tap(find.byKey(const Key('lost-alert-close-confirm')));
      await tester.pumpAndSettle();
      expect(lost.alerts.single.status, LostAlertStatus.cancelled);
      expect(find.text('The alert is closed.'), findsOneWidget);
      expect(find.text('Lost mode'), findsOneWidget);
    });

    testWidgets('a refusal is said on step 2 and nothing is lost', (tester) async {
      final (:h, feed: _, :lost) = _lostHarness();
      await openSheet(tester, 'soya', harness: h);
      await tapVisible(tester, find.byKey(const Key('emergency-lost')));
      await tapVisible(tester, find.byKey(LostStartScreen.townKey));
      await tester.enterText(find.byKey(const Key('lost-town-field')), 'haifa');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lost-town-haifa')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(LostStartScreen.nextKey));
      lost.failing = true;
      await tapVisible(tester, find.text('Start lost mode'));
      expect(find.text('Could not do that. Please try again.'), findsOneWidget);
      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(lost.alerts, isEmpty);
    });
  });
}
