import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/saved_deals_screen.dart';
import 'package:pet_companion/features/store/widgets/deal_card.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';

import 'store_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const mitzi = Pet(id: 'mitzi', name: 'Mitzi', species: PetSpecies.cat);
  const tweety = Pet(id: 'tweety', name: 'Tweety', species: PetSpecies.bird);

  Finder animalsTag(String dealId) => find.byKey(ValueKey('animals-$dealId'));

  String tagText(WidgetTester tester, String dealId) =>
      tester.widget<Text>(find.descendant(of: animalsTag(dealId), matching: find.byType(Text))).data!;

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byKey(const Key('store-screen'))));

  Pet selectedPet(WidgetTester tester) => containerOf(tester).read(selectedPetProvider);

  Finder menuItem(String label) => find.descendant(of: find.byType(PopupMenuItem<String>), matching: find.text(label));

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  Future<void> pickCategory(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(ChoiceChip, label);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  /// What Home's pet pills do: selects [petId] for the whole app while the
  /// Store tab is in the background, then comes back to the Store.
  Future<void> selectOnHome(WidgetTester tester, String petId) async {
    final container = containerOf(tester);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    container.read(selectedPetIdProvider.notifier).select(petId);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
  }

  testWidgets('the Store opens on the selected pet: its deals and the deals for every pet', (tester) async {
    await pumpStore(tester);

    // Kelly is a dog.
    expect(find.text('23 deals for dogs'), findsOneWidget);
    expect(animalsChipLabel(tester), 'For dogs');
    expect(find.text('All animals'), findsNothing);

    // A deal for every pet is there; a cat deal is not.
    await search(tester, 'first aid');
    expect(shownDealIds(tester), ['d-first-aid-kit']);
    await search(tester, 'clumping');
    expect(find.byType(DealCard), findsNothing);

    // No tags while the list is for one kind of animal.
    await search(tester, 'rope');
    expect(shownDealIds(tester), ['d-rope-tug-toy']);
    expect(animalsTag('d-rope-tug-toy'), findsNothing);
  });

  testWidgets('the animals menu lists each kind the owner keeps once, then "All animals"', (tester) async {
    // Two dogs, a cat and a bird.
    await pumpStore(tester, extraPets: [mitzi, tweety]);

    await tester.tap(animalsChip);
    await tester.pumpAndSettle();

    final items = tester.widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>));
    expect([for (final item in items) item.value], ['dog', 'cat', 'bird', 'all']);
    for (final label in ['Dogs', 'Cats', 'Birds', 'All animals']) {
      expect(menuItem(label), findsOneWidget, reason: label);
    }
  });

  testWidgets("choosing another kind narrows the Store to it and leaves the app's selected pet alone",
      (tester) async {
    await pumpStore(tester, extraPets: [mitzi]);
    expect(selectedPet(tester).id, 'kelly');

    await pickAnimals(tester, 'Cats');

    expect(selectedPet(tester).id, 'kelly');
    expect(animalsChipLabel(tester), 'For cats');
    expect(find.text('18 deals for cats'), findsOneWidget);
    // Biggest discount among what suits a cat.
    expect(shownDealIds(tester).first, 'd-nail-grinder');

    await search(tester, 'litter');
    expect(
      shownDealIds(tester),
      // The three litter deals, and the spray: its category is "Litter & cleaning".
      unorderedEquals([
        'd-clumping-litter-10kg',
        'd-hooded-litter-box',
        'd-silica-litter-5l',
        'd-odour-remover-spray',
      ]),
    );
    // Dog food is gone.
    await search(tester, 'kibble');
    expect(shownDealIds(tester), ['d-kitten-dry-2kg']);

    await pickAnimals(tester, 'Dogs');
    expect(selectedPet(tester).id, 'kelly');
    expect(shownDealIds(tester), unorderedEquals(['d-salmon-kibble-12kg', 'd-puppy-kibble-3kg']));
  });

  testWidgets('"All animals" shows every deal, tags who each is for, and leaves the selected pet alone',
      (tester) async {
    await pumpStore(tester);

    await pickAnimals(tester, 'All animals');

    expect(find.text('36 deals'), findsOneWidget);
    expect(animalsChipLabel(tester), 'All animals');
    expect(selectedPet(tester).id, 'kelly');

    expect(tagText(tester, 'd-rope-tug-toy'), 'Dogs');
    await search(tester, 'clumping');
    expect(tagText(tester, 'd-clumping-litter-10kg'), 'Cats');
    await search(tester, 'puzzle');
    expect(tagText(tester, 'd-puzzle-feeder'), 'Dogs, cats');
    await search(tester, 'cage bedding');
    expect(tagText(tester, 'd-paper-bedding-60l'), 'Rabbits, other pets');
    // A deal for every pet needs no tag.
    await search(tester, 'first aid');
    expect(shownDealIds(tester), ['d-first-aid-kit']);
    expect(animalsTag('d-first-aid-kit'), findsNothing);
  });

  testWidgets('a kind picked after "All animals" narrows the Store again, the selected pet\'s own kind too',
      (tester) async {
    await pumpStore(tester, extraPets: [mitzi]);

    await pickAnimals(tester, 'All animals');
    expect(find.text('36 deals'), findsOneWidget);

    // Kelly is a dog and still the app's pet: "Dogs" has to count as a
    // choice all the same.
    await pickAnimals(tester, 'Dogs');
    expect(find.text('23 deals for dogs'), findsOneWidget);
    expect(animalsChipLabel(tester), 'For dogs');

    await pickAnimals(tester, 'All animals');
    await pickAnimals(tester, 'Cats');
    expect(find.text('18 deals for cats'), findsOneWidget);
    expect(selectedPet(tester).id, 'kelly');
  });

  testWidgets('choosing a pet on another tab brings the Store back to that pet, from "All animals" or a picked kind',
      (tester) async {
    await pumpStore(tester, extraPets: [mitzi, tweety]);

    await pickAnimals(tester, 'All animals');
    expect(find.text('36 deals'), findsOneWidget);
    await selectOnHome(tester, 'mitzi');
    expect(find.text('18 deals for cats'), findsOneWidget);
    expect(animalsChipLabel(tester), 'For cats');

    await pickAnimals(tester, 'Dogs');
    expect(find.text('23 deals for dogs'), findsOneWidget);
    await selectOnHome(tester, 'tweety');
    expect(find.text('4 deals for birds'), findsOneWidget);
    expect(animalsChipLabel(tester), 'For birds');
  });

  testWidgets('nothing for this kind: the message offers "Show all animals"', (tester) async {
    await pumpStore(tester, extraPets: [tweety]);

    await pickAnimals(tester, 'Birds');
    expect(find.text('4 deals for birds'), findsOneWidget);

    await pickCategory(tester, 'Toys');
    expect(find.text('0 deals for birds'), findsOneWidget);
    expect(find.text('No deals for birds here'), findsOneWidget);
    expect(
      find.text('There is nothing for birds in Toys right now. Other animals have 5 deals here.'),
      findsOneWidget,
    );
    expect(find.text('Clear filters'), findsNothing);

    await tester.tap(find.text('Show all animals'));
    await tester.pumpAndSettle();

    // The category stays; every animal's toys are listed.
    expect(find.text('5 deals'), findsOneWidget);
    expect(animalsChipLabel(tester), 'All animals');
    expect(find.text('No deals for birds here'), findsNothing);
  });

  testWidgets('a search with nothing for the pet says how many deals other animals have', (tester) async {
    await pumpStore(tester);

    await search(tester, 'clumping');
    expect(find.text('No deals for dogs here'), findsOneWidget);
    expect(find.text('Nothing for dogs matches "clumping". Other animals have 1 deal here.'), findsOneWidget);

    await tester.tap(find.text('Show all animals'));
    await tester.pumpAndSettle();
    expect(shownDealIds(tester), ['d-clumping-litter-10kg']);
    expect(find.text('1 deal'), findsOneWidget);
  });

  testWidgets('the new category lists litter and cleaning deals', (tester) async {
    await pumpStore(tester, extraPets: [mitzi]);

    await pickCategory(tester, 'Litter & cleaning');
    expect(find.text('2 deals for dogs'), findsOneWidget);
    expect(shownDealIds(tester), ['d-waste-bags-300', 'd-odour-remover-spray']);

    await pickAnimals(tester, 'Cats');
    expect(find.text('4 deals for cats'), findsOneWidget);
    expect(
      shownDealIds(tester),
      ['d-clumping-litter-10kg', 'd-hooded-litter-box', 'd-silica-litter-5l', 'd-odour-remover-spray'],
    );
  });

  testWidgets('saved deals are not narrowed to the pet, and say who they are for', (tester) async {
    final store = fakeStore();
    await store.setSaved(userId: demoUserId, dealId: 'd-clumping-litter-10kg', saved: true);
    await store.setSaved(userId: demoUserId, dealId: 'd-rope-tug-toy', saved: true);
    await pumpStore(tester, repository: store);
    expect(find.text('23 deals for dogs'), findsOneWidget);

    await tester.tap(find.byTooltip('Saved deals'));
    await tester.pumpAndSettle();

    expect(find.byType(SavedDealsScreen), findsOneWidget);
    expect(find.text('2 saved deals'), findsOneWidget);
    expect(shownDealIds(tester), unorderedEquals(['d-clumping-litter-10kg', 'd-rope-tug-toy']));
    expect(tagText(tester, 'd-clumping-litter-10kg'), 'Cats');
    expect(tagText(tester, 'd-rope-tug-toy'), 'Dogs');
  });
}
