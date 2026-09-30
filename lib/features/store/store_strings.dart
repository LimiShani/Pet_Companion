import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import 'data/deal.dart';
import 'data/store_repository.dart';

/// The bridge between the Store's values and its words.
///
/// The words themselves live in `l10n/store_en.arb` and `l10n/store_he.arb`
/// (see `lib/l10n/GLOSSARY.md`); in a widget they are `context.storeL10n`.
/// What is stored in the database (a category, a unit, a kind of animal, a
/// sort order, a reason for failure) stays a key, and is put into words here
/// in the language on screen. Lists and the few sentences made of more than
/// one message are put together here too, so no screen glues words by hand.
extension StoreWords on StoreL10n {
  String category(DealCategory category) => switch (category) {
        DealCategory.food => categoryFood,
        DealCategory.treats => categoryTreats,
        DealCategory.litterAndCleaning => categoryLitterAndCleaning,
        DealCategory.toys => categoryToys,
        DealCategory.health => categoryHealth,
        DealCategory.grooming => categoryGrooming,
        DealCategory.accessories => categoryAccessories,
        DealCategory.bedsAndCrates => categoryBedsAndCrates,
      };

  String sort(DealSort sort) => switch (sort) {
        DealSort.biggestDiscount => sortBiggestDiscount,
        DealSort.lowestPrice => sortLowestPrice,
        DealSort.lowestUnitPrice => sortLowestUnitPrice,
        DealSort.newest => sortNewest,
        DealSort.endingSoon => sortEndingSoon,
      };

  /// "Cats": a kind of animal, on a chip or a tag.
  String animals(PetSpecies species) => switch (species) {
        PetSpecies.dog => animalsDog,
        PetSpecies.cat => animalsCat,
        PetSpecies.bird => animalsBird,
        PetSpecies.rabbit => animalsRabbit,
        PetSpecies.reptile => animalsReptile,
        PetSpecies.other => animalsOther,
      };

  /// "cats": a kind of animal inside a sentence.
  String animalsInSentence(PetSpecies species) => switch (species) {
        PetSpecies.dog => animalsInSentenceDog,
        PetSpecies.cat => animalsInSentenceCat,
        PetSpecies.bird => animalsInSentenceBird,
        PetSpecies.rabbit => animalsInSentenceRabbit,
        PetSpecies.reptile => animalsInSentenceReptile,
        PetSpecies.other => animalsInSentenceOther,
      };

  /// The unit as picked in the share form.
  String unit(PackageUnit unit) => switch (unit) {
        PackageUnit.kg => unitKg,
        PackageUnit.g => unitG,
        PackageUnit.litre => unitLitre,
        PackageUnit.ml => unitMl,
        PackageUnit.unit => unitUnits,
      };

  /// "10 kg", "500 ml", "300 units". [amount] is already formatted; [one]
  /// says it is exactly one.
  String packageSize(String amount, PackageUnit unit, {required bool one}) => switch (unit) {
        PackageUnit.kg => packageKg(amount),
        PackageUnit.g => packageG(amount),
        PackageUnit.litre => one ? packageLitreOne(amount) : packageLitres(amount),
        PackageUnit.ml => packageMl(amount),
        PackageUnit.unit => one ? packageUnitOne(amount) : packageUnits(amount),
      };

  /// "₪18.90 per kg", "₪5.98 per litre", "₪0.07 each". [money] is already
  /// formatted.
  String unitPriceOf(String money, UnitKind kind) => switch (kind) {
        UnitKind.weight => unitPricePerKg(money),
        UnitKind.volume => unitPricePerLitre(money),
        UnitKind.count => unitPriceEach(money),
      };

  /// "dogs", "dogs and cats", "dogs, cats and rabbits": a list the way the
  /// language writes one (in Hebrew the "and" is joined to the last word).
  String list(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.single;
    final allButLast = items.sublist(0, items.length - 1).reduce(listComma);
    return listAnd(allButLast, items.last);
  }

  /// "For cats", "For dogs and cats", or "For all pets" when no animal is
  /// named.
  String forWhom(List<PetSpecies> species) =>
      species.isEmpty ? forAllPets : forAnimals(list([for (final kind in species) animalsInSentence(kind)]));

  /// "Cats", "Dogs, cats": the short tag on a deal's picture.
  String animalsTag(List<PetSpecies> species) {
    if (species.isEmpty) return allPets;
    return [
      animals(species.first),
      for (final kind in species.skip(1)) animalsInSentence(kind),
    ].reduce(listComma);
  }

  /// "23 deals for dogs".
  String dealsFor(int count, PetSpecies species) => dealCountFor(count, animalsInSentence(species));

  /// "No deals for cats here".
  String noDealsForTitle(PetSpecies species) => noDealsForAnimalsTitle(animalsInSentence(species));

  /// Why the selected pet's list is empty, then how many deals the other
  /// animals have with the same search and category: two sentences.
  String noDealsForMessage({
    required PetSpecies species,
    required String query,
    required String? category,
    required int othersCount,
  }) {
    final animals = animalsInSentence(species);
    final String why;
    if (query.isEmpty && category == null) {
      why = noneForAnimals(animals);
    } else if (query.isEmpty) {
      why = noneForAnimalsInCategory(animals, category!);
    } else if (category == null) {
      why = noneForAnimalsMatching(animals, query);
    } else {
      why = noneForAnimalsMatchingInCategory(animals, query, category);
    }
    return '$why ${othersHaveDeals(othersCount)}';
  }

  /// What a failed Store action reports, in words. `null` for a failure the
  /// Store has no words of its own for.
  String? failure(StoreFailure failure) => switch (failure) {
        StoreFailure.network => errNetwork,
        StoreFailure.signInToShare => errSignInToShare,
        StoreFailure.signInToDelete => errSignInToDelete,
        StoreFailure.signInToReport => errSignInToReport,
        StoreFailure.needsTitleAndSeller => errNeedsTitleAndSeller,
        StoreFailure.priceNotBelowOriginal => validPriceBelowOriginal,
        StoreFailure.linkNotHttps => errLinkMustBeHttps(httpsPrefix),
        StoreFailure.packageNotValid => errPackageNotValid,
        StoreFailure.deliveryNotValid => errDeliveryNotValid,
        StoreFailure.onlyDeleteOwn => errOnlyDeleteOwn,
        StoreFailure.notAllowed => errNotAllowed,
        StoreFailure.detailsNotValid => errDetailsNotValid,
        StoreFailure.dealNoLongerAvailable => errDealNoLongerAvailable,
        StoreFailure.sessionEnded => errSessionEnded,
        StoreFailure.storeNeedsUpdate => errStoreNeedsUpdate,
        StoreFailure.unknown => null,
      };
}

/// How a web address must start. Never translated; the Hebrew messages keep
/// it left to right.
const httpsPrefix = 'https://';

/// User-facing text for a Store failure, in the language on screen.
String storeErrorText(BuildContext context, Object error) {
  final words = error is StoreException ? context.storeL10n.failure(error.failure) : null;
  return words ?? context.l10n.errorGeneric;
}

/// The direction a piece of content reads in: a deal's title, description
/// or seller. Content is what somebody wrote (the sample catalogue, a
/// curated deal, a member) and is never translated, so an English title
/// stays left to right on a Hebrew screen and the other way round.
TextDirection contentDirection(BuildContext context, String text) =>
    directionOfText(text, fallback: Directionality.of(context));
