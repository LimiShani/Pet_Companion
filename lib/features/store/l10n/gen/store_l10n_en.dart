// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'store_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class StoreL10nEn extends StoreL10n {
  StoreL10nEn([String locale = 'en']) : super(locale);

  @override
  String get tabTitle => 'Store';

  @override
  String get searchHint => 'Search deals';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get savedDeals => 'Saved deals';

  @override
  String get shareADeal => 'Share a deal';

  @override
  String get allAnimals => 'All animals';

  @override
  String get allCategories => 'All';

  @override
  String get sortTooltip => 'Sort deals';

  @override
  String get couldNotLoadDeals => 'Could not load deals';

  @override
  String get couldNotRefresh => 'Could not refresh the deals. Please try again.';

  @override
  String get dealIsLive => 'Thanks! Your deal is live.';

  @override
  String dealCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deals',
      one: '1 deal',
    );
    return '$_temp0';
  }

  @override
  String dealCountFor(int count, String animals) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deals',
      one: '1 deal',
    );
    return '$_temp0 for $animals';
  }

  @override
  String get noDealsYetTitle => 'No deals yet';

  @override
  String get noDealsYetMessage => 'New bargains will show up here. Found one yourself? Share it with other pet owners.';

  @override
  String get noDealsFoundTitle => 'No deals found';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get showAllAnimals => 'Show all animals';

  @override
  String noDealsInCategory(String category) {
    return 'There are no deals in $category right now. Try a different category.';
  }

  @override
  String nothingMatches(String query) {
    return 'Nothing matches \"$query\". Try another word.';
  }

  @override
  String nothingMatchesInCategory(String query, String category) {
    return 'Nothing matches \"$query\" in $category. Try another word or a different category.';
  }

  @override
  String noDealsForAnimalsTitle(String animals) {
    return 'No deals for $animals here';
  }

  @override
  String noneForAnimals(String animals) {
    return 'There are no deals for $animals right now.';
  }

  @override
  String noneForAnimalsInCategory(String animals, String category) {
    return 'There is nothing for $animals in $category right now.';
  }

  @override
  String noneForAnimalsMatching(String animals, String query) {
    return 'Nothing for $animals matches \"$query\".';
  }

  @override
  String noneForAnimalsMatchingInCategory(String animals, String query, String category) {
    return 'Nothing for $animals matches \"$query\" in $category.';
  }

  @override
  String othersHaveDeals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deals',
      one: '1 deal',
    );
    return 'Other animals have $_temp0 here.';
  }

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryTreats => 'Treats';

  @override
  String get categoryLitterAndCleaning => 'Litter & cleaning';

  @override
  String get categoryToys => 'Toys';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryGrooming => 'Grooming';

  @override
  String get categoryAccessories => 'Accessories';

  @override
  String get categoryBedsAndCrates => 'Beds & crates';

  @override
  String get sortBiggestDiscount => 'Biggest discount';

  @override
  String get sortLowestPrice => 'Lowest price';

  @override
  String get sortLowestUnitPrice => 'Lowest unit price';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortEndingSoon => 'Ending soon';

  @override
  String get animalsDog => 'Dogs';

  @override
  String get animalsCat => 'Cats';

  @override
  String get animalsBird => 'Birds';

  @override
  String get animalsRabbit => 'Rabbits';

  @override
  String get animalsReptile => 'Reptiles';

  @override
  String get animalsOther => 'Other';

  @override
  String get animalsInSentenceDog => 'dogs';

  @override
  String get animalsInSentenceCat => 'cats';

  @override
  String get animalsInSentenceBird => 'birds';

  @override
  String get animalsInSentenceRabbit => 'rabbits';

  @override
  String get animalsInSentenceReptile => 'reptiles';

  @override
  String get animalsInSentenceOther => 'other pets';

  @override
  String get allPets => 'All pets';

  @override
  String get forAllPets => 'For all pets';

  @override
  String forAnimals(String animals) {
    return 'For $animals';
  }

  @override
  String listAnd(String first, String last) {
    return '$first and $last';
  }

  @override
  String listComma(String first, String next) {
    return '$first, $next';
  }

  @override
  String get unitKg => 'kg';

  @override
  String get unitG => 'g';

  @override
  String get unitLitre => 'litre';

  @override
  String get unitMl => 'ml';

  @override
  String get unitUnits => 'units';

  @override
  String packageKg(String amount) {
    return '$amount kg';
  }

  @override
  String packageG(String amount) {
    return '$amount g';
  }

  @override
  String packageLitreOne(String amount) {
    return '$amount litre';
  }

  @override
  String packageLitres(String amount) {
    return '$amount litres';
  }

  @override
  String packageMl(String amount) {
    return '$amount ml';
  }

  @override
  String packageUnitOne(String amount) {
    return '$amount unit';
  }

  @override
  String packageUnits(String amount) {
    return '$amount units';
  }

  @override
  String unitPricePerKg(String price) {
    return '$price per kg';
  }

  @override
  String unitPricePerLitre(String price) {
    return '$price per litre';
  }

  @override
  String unitPriceEach(String price) {
    return '$price each';
  }

  @override
  String get expired => 'Expired';

  @override
  String get freeDelivery => 'Free delivery';

  @override
  String plusDelivery(String price) {
    return '+ $price delivery';
  }

  @override
  String get dealTitle => 'Deal';

  @override
  String get dealGoneTitle => 'This deal is gone';

  @override
  String get dealGoneMessage => 'It may have been removed by the person who shared it.';

  @override
  String get backToStore => 'Back to the Store';

  @override
  String youSave(String amount, int percent) {
    return 'You save $amount ($percent%)';
  }

  @override
  String get unitPriceLabel => 'Unit price';

  @override
  String get packageLabel => 'Package';

  @override
  String get deliveryLabel => 'Delivery';

  @override
  String get deliveryFree => 'Free';

  @override
  String deliveryPlus(String price) {
    return '+ $price';
  }

  @override
  String get deliveryNotGiven => 'Not given';

  @override
  String get deliveryAskSeller => 'Check with the seller';

  @override
  String get finalPriceLabel => 'Final price';

  @override
  String get sellerLabel => 'Seller';

  @override
  String get priceCheckedLabel => 'Price checked';

  @override
  String get postedLabel => 'Posted';

  @override
  String get endsLabel => 'Ends';

  @override
  String get priceMayHaveChanged => 'This price was checked a while ago. It may have changed.';

  @override
  String dealEndedOn(String date) {
    return 'This deal ended on $date';
  }

  @override
  String get pickOfTheApp => 'Pet Companion pick';

  @override
  String get sharedByYou => 'Shared by you';

  @override
  String get sharedByMember => 'Shared by a member';

  @override
  String sharedBy(String name) {
    return 'Shared by $name';
  }

  @override
  String get reportExpired => 'Report as expired';

  @override
  String get reportedExpired => 'You reported this as expired';

  @override
  String get reportThanks => 'Thanks, we will check it.';

  @override
  String get deleteMyDeal => 'Delete my deal';

  @override
  String get deleteDealTitle => 'Delete this deal?';

  @override
  String get deleteDealMessage => 'It will be removed from the Store for everyone.';

  @override
  String get dealDeleted => 'Your deal was deleted.';

  @override
  String get openOffer => 'Open offer';

  @override
  String opensInBrowser(String host) {
    return 'Opens $host in your browser';
  }

  @override
  String get couldNotOpenOffer => 'Could not open the offer. Please try again.';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String timeDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get noEndDate => 'No end date';

  @override
  String endedOn(String date) {
    return 'Ended $date';
  }

  @override
  String endsOn(String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'ends today',
    );
    return '$date · $_temp0';
  }

  @override
  String checkedOn(String date, String when) {
    return '$date · $when';
  }

  @override
  String get checkedToday => 'today';

  @override
  String get checkedYesterday => 'yesterday';

  @override
  String checkedDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get saveDeal => 'Save deal';

  @override
  String get removeFromSaved => 'Remove from saved';

  @override
  String get savedConfirmation => 'Saved';

  @override
  String get removedFromSaved => 'Removed from saved deals';

  @override
  String get couldNotUpdateSaved => 'Could not update your saved deals. Please try again.';

  @override
  String get couldNotLoadSaved => 'Could not load your saved deals';

  @override
  String get noSavedDealsTitle => 'No saved deals yet';

  @override
  String get noSavedDealsMessage => 'Tap the heart on a deal to keep it here.';

  @override
  String get browseDeals => 'Browse deals';

  @override
  String savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved deals',
      one: '1 saved deal',
    );
    return '$_temp0';
  }

  @override
  String get shareIntro => 'Found a bargain? Tell other pet owners where to get it.';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldTitleHint => 'What is on offer?';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldCategoryHint => 'Choose a category';

  @override
  String get fieldAnimals => 'For which animals';

  @override
  String get fieldAnimalsHelp => 'Starts on your selected pet. Pick more than one if it fits.';

  @override
  String fieldPriceNow(String symbol) {
    return 'Price now ($symbol)';
  }

  @override
  String fieldPriceBefore(String symbol) {
    return 'Price before ($symbol)';
  }

  @override
  String hintPercentOff(int percent) {
    return 'That is $percent% off';
  }

  @override
  String get fieldPackageSize => 'Package size (optional)';

  @override
  String get fieldPackageAmountHint => 'Amount';

  @override
  String get fieldPackageUnitHint => 'Unit';

  @override
  String get fieldPackageHelp => 'For a multi-pack enter the total, for example 12 × 85 g is 1020 g.';

  @override
  String hintUnitPrice(String unitPrice) {
    return 'That is $unitPrice';
  }

  @override
  String get fieldDelivery => 'Delivery (optional)';

  @override
  String get deliveryNotSure => 'Not sure';

  @override
  String get deliveryPaid => 'Paid';

  @override
  String fieldDeliveryCost(String symbol) {
    return 'Delivery cost ($symbol)';
  }

  @override
  String hintFinalPrice(String price) {
    return 'Final price $price';
  }

  @override
  String get fieldSellerHint => 'The shop or website';

  @override
  String get fieldLink => 'Link to the offer';

  @override
  String get fieldDescription => 'Description (optional)';

  @override
  String get fieldDescriptionHint => 'Size, flavour, what is included...';

  @override
  String get fieldEndDate => 'End date (optional)';

  @override
  String get addEndDate => 'Add an end date';

  @override
  String endsDate(String date) {
    return 'Ends $date';
  }

  @override
  String get removeEndDate => 'Remove the end date';

  @override
  String get lastDayOfDeal => 'Last day of the deal';

  @override
  String checkedTodayNote(String date) {
    return 'The price will show as checked today, $date.';
  }

  @override
  String get shareDealButton => 'Share deal';

  @override
  String get validTitleRequired => 'Give the deal a title.';

  @override
  String validTitleTooShort(int count) {
    return 'Use at least $count characters.';
  }

  @override
  String get validSellerRequired => 'Who is selling it?';

  @override
  String get validCategoryRequired => 'Pick a category.';

  @override
  String get validOriginalPriceRequired => 'Enter the price before the discount.';

  @override
  String get validPriceRequired => 'Enter the price now.';

  @override
  String get validNotANumber => 'Enter a number, like 49.90.';

  @override
  String get validPriceAboveZero => 'The price must be above zero.';

  @override
  String get validPriceBelowOriginal => 'The deal price must be below the original price.';

  @override
  String get validLinkRequired => 'Paste the link to the offer.';

  @override
  String validLinkNotHttps(String prefix) {
    return 'Use a full link that starts with $prefix';
  }

  @override
  String get validPackageAmount => 'Enter a size above zero, like 2.5.';

  @override
  String get validPackageUnit => 'Choose a unit: kg, g, litre, ml or units.';

  @override
  String get validDeliveryCostRequired => 'Enter the delivery cost.';

  @override
  String get validDeliveryCostInvalid => 'Enter a number above zero, or pick Free.';

  @override
  String get errNetwork => 'Cannot reach the server. Check your connection and try again.';

  @override
  String get errSignInToShare => 'Please sign in to share a deal.';

  @override
  String get errSignInToDelete => 'Please sign in to delete a deal.';

  @override
  String get errSignInToReport => 'Please sign in to report a deal.';

  @override
  String get errNeedsTitleAndSeller => 'A deal needs a title and a seller.';

  @override
  String errLinkMustBeHttps(String prefix) {
    return 'Use a link that starts with $prefix';
  }

  @override
  String get errPackageNotValid => 'The package size must be above zero.';

  @override
  String get errDeliveryNotValid => 'The delivery cost cannot be below zero.';

  @override
  String get errOnlyDeleteOwn => 'You can only delete deals you shared.';

  @override
  String get errNotAllowed => 'You are not allowed to do that. Please sign in again.';

  @override
  String get errDetailsNotValid => 'Some of the details are not valid. Please check them and try again.';

  @override
  String get errDealNoLongerAvailable => 'This deal is no longer available.';

  @override
  String get errSessionEnded => 'Your session has ended. Please sign in again.';

  @override
  String get errStoreNeedsUpdate => 'The Store is being updated. Please try again later.';
}
