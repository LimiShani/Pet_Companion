import '../../models/pet.dart';
import 'data/deal.dart';

/// Every user-facing text of the Store, in one place, so it can be moved
/// into the app's translation files in one go. Screens never spell out a
/// sentence themselves: they ask for it here.
///
/// Texts with a value in them are functions, so a translation can put the
/// value where its grammar wants it. Money and dates are already formatted
/// when they are passed in (see `StoreFormat`).
abstract final class StoreStrings {
  // ---- General --------------------------------------------------------
  static const somethingWentWrong = 'Something went wrong. Please try again.';
  static const cannotReachServer = 'Cannot reach the server. Check your connection and try again.';
  static const tryAgain = 'Try again';
  static const cancel = 'Cancel';

  // ---- Store tab ------------------------------------------------------
  static const storeTitle = 'Store';
  static const searchHint = 'Search deals';
  static const clearSearch = 'Clear search';
  static const savedDealsTooltip = 'Saved deals';
  static const shareADeal = 'Share a deal';
  static const allAnimals = 'All animals';
  static const allCategories = 'All';
  static const sortTooltip = 'Sort deals';
  static const couldNotLoadDeals = 'Could not load deals';
  static const couldNotRefresh = 'Could not refresh the deals. Please try again.';
  static const dealIsLive = 'Thanks! Your deal is live.';

  static String dealCount(int count) => count == 1 ? '1 deal' : '$count deals';

  /// "4 deals for cats".
  static String dealCountFor(int count, PetSpecies species) => '${dealCount(count)} for ${animalsLower(species)}';

  static const noDealsYetTitle = 'No deals yet';
  static const noDealsYetMessage =
      'New bargains will show up here. Found one yourself? Share it with other pet owners.';
  static const noDealsFoundTitle = 'No deals found';
  static const clearFilters = 'Clear filters';
  static const showAllAnimals = 'Show all animals';

  static String noDealsInCategory(String category) =>
      'There are no deals in $category right now. Try a different category.';
  static String nothingMatches(String query) => 'Nothing matches "$query". Try another word.';
  static String nothingMatchesInCategory(String query, String category) =>
      'Nothing matches "$query" in $category. Try another word or a different category.';

  /// "No deals for cats here".
  static String noDealsForAnimalsTitle(PetSpecies species) => 'No deals for ${animalsLower(species)} here';

  /// Why the selected pet's list is empty, then how many deals the other
  /// animals have with the same search and category.
  static String noDealsForAnimalsMessage({
    required PetSpecies species,
    required String query,
    required String? category,
    required int othersCount,
  }) {
    final animals = animalsLower(species);
    final String why;
    if (query.isEmpty && category == null) {
      why = 'There are no deals for $animals right now.';
    } else if (query.isEmpty) {
      why = 'There is nothing for $animals in $category right now.';
    } else if (category == null) {
      why = 'Nothing for $animals matches "$query".';
    } else {
      why = 'Nothing for $animals matches "$query" in $category.';
    }
    final others = othersCount == 1 ? 'Other animals have 1 deal here.' : 'Other animals have $othersCount deals here.';
    return '$why $others';
  }

  // ---- Categories, sort orders, animals, units -------------------------
  static String category(DealCategory category) => switch (category) {
        DealCategory.food => 'Food',
        DealCategory.treats => 'Treats',
        DealCategory.litterAndCleaning => 'Litter & cleaning',
        DealCategory.toys => 'Toys',
        DealCategory.health => 'Health',
        DealCategory.grooming => 'Grooming',
        DealCategory.accessories => 'Accessories',
        DealCategory.bedsAndCrates => 'Beds & crates',
      };

  static String sort(DealSort sort) => switch (sort) {
        DealSort.biggestDiscount => 'Biggest discount',
        DealSort.lowestPrice => 'Lowest price',
        DealSort.lowestUnitPrice => 'Lowest unit price',
        DealSort.newest => 'Newest',
        DealSort.endingSoon => 'Ending soon',
      };

  /// "Cats": a kind of animal, on a chip or a tag.
  static String animals(PetSpecies species) => switch (species) {
        PetSpecies.dog => 'Dogs',
        PetSpecies.cat => 'Cats',
        PetSpecies.bird => 'Birds',
        PetSpecies.rabbit => 'Rabbits',
        PetSpecies.reptile => 'Reptiles',
        PetSpecies.other => 'Other',
      };

  /// "cats": a kind of animal inside a sentence.
  static String animalsLower(PetSpecies species) => switch (species) {
        PetSpecies.dog => 'dogs',
        PetSpecies.cat => 'cats',
        PetSpecies.bird => 'birds',
        PetSpecies.rabbit => 'rabbits',
        PetSpecies.reptile => 'reptiles',
        PetSpecies.other => 'other pets',
      };

  static const allPets = 'All pets';
  static const forAllPets = 'For all pets';

  /// "For cats", "For dogs and cats", "For dogs, cats and birds".
  static String forAnimals(List<PetSpecies> species) {
    if (species.isEmpty) return forAllPets;
    final names = [for (final s in species) animalsLower(s)];
    if (names.length == 1) return 'For ${names.single}';
    return 'For ${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  /// "Cats", "Dogs, cats": the short tag on a deal's picture.
  static String animalsTag(List<PetSpecies> species) {
    if (species.isEmpty) return allPets;
    final first = animals(species.first);
    if (species.length == 1) return first;
    return [first, for (final s in species.skip(1)) animalsLower(s)].join(', ');
  }

  /// The unit as picked in the share form.
  static String unit(PackageUnit unit) => switch (unit) {
        PackageUnit.kg => 'kg',
        PackageUnit.g => 'g',
        PackageUnit.litre => 'litre',
        PackageUnit.ml => 'ml',
        PackageUnit.unit => 'units',
      };

  /// "10 kg", "500 ml", "300 units". [amount] is already formatted.
  static String packageSize(String amount, PackageUnit unit, {required bool one}) => switch (unit) {
        PackageUnit.kg => '$amount kg',
        PackageUnit.g => '$amount g',
        PackageUnit.litre => one ? '$amount litre' : '$amount litres',
        PackageUnit.ml => '$amount ml',
        PackageUnit.unit => one ? '$amount unit' : '$amount units',
      };

  /// "₪18.90 per kg", "₪5.98 per litre", "₪0.07 each". [money] is already
  /// formatted.
  static String unitPrice(String money, UnitKind kind) => switch (kind) {
        UnitKind.weight => '$money per kg',
        UnitKind.volume => '$money per litre',
        UnitKind.count => '$money each',
      };

  // ---- Deal card and deal page ------------------------------------------
  static const expired = 'Expired';
  static String discountBadge(int percent) => '-$percent%';
  static const freeDelivery = 'Free delivery';
  static String plusDelivery(String money) => '+ $money delivery';

  static const dealTitle = 'Deal';
  static const dealGoneTitle = 'This deal is gone';
  static const dealGoneMessage = 'It may have been removed by the person who shared it.';
  static const backToStore = 'Back to the Store';
  static String youSave(String money, int percent) => 'You save $money ($percent%)';
  static const unitPriceLabel = 'Unit price';
  static const packageLabel = 'Package';
  static const deliveryLabel = 'Delivery';
  static const deliveryFree = 'Free';
  static String deliveryPlus(String money) => '+ $money';
  static const deliveryNotGiven = 'Not given';
  static const deliveryAskSeller = 'Check with the seller';
  static const finalPriceLabel = 'Final price';
  static const sellerLabel = 'Seller';
  static const priceCheckedLabel = 'Price checked';
  static const postedLabel = 'Posted';
  static const endsLabel = 'Ends';
  static const priceMayHaveChanged = 'This price was checked a while ago. It may have changed.';
  static String dealEndedOn(String date) => 'This deal ended on $date';
  static const pickOfTheApp = 'Pet Companion pick';
  static const sharedByYou = 'Shared by you';
  static const sharedByMember = 'Shared by a member';
  static String sharedBy(String name) => 'Shared by $name';
  static const reportExpired = 'Report as expired';
  static const reportedExpired = 'You reported this as expired';
  static const reportThanks = 'Thanks, we will check it.';
  static const deleteMyDeal = 'Delete my deal';
  static const deleteDealTitle = 'Delete this deal?';
  static const deleteDealMessage = 'It will be removed from the Store for everyone.';
  static const delete = 'Delete';
  static const dealDeleted = 'Your deal was deleted.';
  static const openOffer = 'Open offer';
  static String opensInBrowser(String host) => 'Opens $host in your browser';
  static const couldNotOpenOffer = 'Could not open the offer. Please try again.';

  // ---- Times ------------------------------------------------------------
  static const justNow = 'Just now';
  static String minutesAgo(int minutes) => '$minutes min ago';
  static String hoursAgo(int hours) => hours == 1 ? '1 hour ago' : '$hours hours ago';
  static const yesterday = 'Yesterday';
  static String daysAgo(int days) => '$days days ago';
  static const noEndDate = 'No end date';
  static String ended(String date) => 'Ended $date';
  static String endsOn(String date, int daysLeft) => switch (daysLeft) {
        0 => '$date · ends today',
        1 => '$date · 1 day left',
        _ => '$date · $daysLeft days left',
      };

  /// "29.09.26 · yesterday": a date and how long ago that was.
  static String checkedOn(String date, int daysAgo) => switch (daysAgo) {
        0 => '$date · today',
        1 => '$date · yesterday',
        _ => '$date · $daysAgo days ago',
      };

  // ---- Saving -----------------------------------------------------------
  static const saveDeal = 'Save deal';
  static const removeFromSaved = 'Remove from saved';
  static const saved = 'Saved';
  static const removedFromSaved = 'Removed from saved deals';
  static const couldNotUpdateSaved = 'Could not update your saved deals. Please try again.';
  static const savedDealsTitle = 'Saved deals';
  static const couldNotLoadSaved = 'Could not load your saved deals';
  static const noSavedDealsTitle = 'No saved deals yet';
  static const noSavedDealsMessage = 'Tap the heart on a deal to keep it here.';
  static const browseDeals = 'Browse deals';
  static String savedCount(int count) => count == 1 ? '1 saved deal' : '$count saved deals';

  // ---- Share a deal -----------------------------------------------------
  static const shareIntro = 'Found a bargain? Tell other pet owners where to get it.';
  static const titleLabel = 'Title';
  static const titleHint = 'What is on offer?';
  static const categoryLabel = 'Category';
  static const categoryHint = 'Choose a category';
  static const animalsLabel = 'For which animals';
  static const animalsHelp = 'Starts on your selected pet. Pick more than one if it fits.';
  static String priceNowLabel(String symbol) => 'Price now ($symbol)';
  static String priceBeforeLabel(String symbol) => 'Price before ($symbol)';
  static String percentOff(int percent) => 'That is $percent% off';
  static const packageSizeLabel = 'Package size (optional)';
  static const packageAmountHint = 'Amount';
  static const packageUnitHint = 'Unit';
  static const packageHelp = 'For a multi-pack enter the total, for example 12 × 85 g is 1020 g.';
  static String thatIsUnitPrice(String unitPrice) => 'That is $unitPrice';
  static const deliveryOptionalLabel = 'Delivery (optional)';
  static const deliveryNotSure = 'Not sure';
  static const deliveryPaid = 'Paid';
  static String deliveryCostLabel(String symbol) => 'Delivery cost ($symbol)';
  static String finalPriceHint(String money) => 'Final price $money';
  static const sellerHint = 'The shop or website';
  static const linkLabel = 'Link to the offer';
  static const descriptionLabel = 'Description (optional)';
  static const descriptionHint = 'Size, flavour, what is included...';
  static const endDateLabel = 'End date (optional)';
  static const addEndDate = 'Add an end date';
  static String endsDate(String date) => 'Ends $date';
  static const removeEndDate = 'Remove the end date';
  static const lastDayOfDeal = 'Last day of the deal';
  static String checkedTodayNote(String date) => 'The price will show as checked today, $date.';
  static const shareDealButton = 'Share deal';

  // Problems in the form.
  static const titleRequired = 'Give the deal a title.';
  static const titleTooShort = 'Use at least 3 characters.';
  static const sellerRequired = 'Who is selling it?';
  static const categoryRequired = 'Pick a category.';
  static const originalPriceRequired = 'Enter the price before the discount.';
  static const priceRequired = 'Enter the price now.';
  static const notANumber = 'Enter a number, like 49.90.';
  static const priceAboveZero = 'The price must be above zero.';
  static const priceBelowOriginal = 'The deal price must be below the original price.';
  static const linkRequired = 'Paste the link to the offer.';
  static const linkNotHttps = 'Use a full link that starts with https://';
  static const packageAmountInvalid = 'Enter a size above zero, like 2.5.';
  static const packageUnitRequired = 'Choose a unit: kg, g, litre, ml or units.';
  static const deliveryCostRequired = 'Enter the delivery cost.';
  static const deliveryCostInvalid = 'Enter a number above zero, or pick Free.';

  // ---- Failures reported by the backend -----------------------------------
  static const signInToShare = 'Please sign in to share a deal.';
  static const signInToDelete = 'Please sign in to delete a deal.';
  static const signInToReport = 'Please sign in to report a deal.';
  static const dealNeedsTitleAndSeller = 'A deal needs a title and a seller.';
  static const linkMustBeHttps = 'Use a link that starts with https://';
  static const packageNotValid = 'The package size must be above zero.';
  static const deliveryNotValid = 'The delivery cost cannot be below zero.';
  static const onlyDeleteOwn = 'You can only delete deals you shared.';
  static const notAllowed = 'You are not allowed to do that. Please sign in again.';
  static const detailsNotValid = 'Some of the details are not valid. Please check them and try again.';
  static const dealNoLongerAvailable = 'This deal is no longer available.';
  static const sessionEnded = 'Your session has ended. Please sign in again.';
  static const storeNeedsUpdate = 'The Store is being updated. Please try again later.';
}
