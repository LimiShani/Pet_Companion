import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'store_l10n_en.dart';
import 'store_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of StoreL10n
/// returned by `StoreL10n.of(context)`.
///
/// Applications need to include `StoreL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/store_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: StoreL10n.localizationsDelegates,
///   supportedLocales: StoreL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the StoreL10n.supportedLocales
/// property.
abstract class StoreL10n {
  StoreL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static StoreL10n of(BuildContext context) {
    return Localizations.of<StoreL10n>(context, StoreL10n)!;
  }

  static const LocalizationsDelegate<StoreL10n> delegate = _StoreL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// Title of the Store tab's header.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get tabTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search deals'**
  String get searchHint;

  /// Tooltip of the x in the search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// Title of the saved deals page and tooltip of the heart that opens it.
  ///
  /// In en, this message translates to:
  /// **'Saved deals'**
  String get savedDeals;

  /// The floating button on the Store tab and the title of the form it opens.
  ///
  /// In en, this message translates to:
  /// **'Share a deal'**
  String get shareADeal;

  /// The pill after the pet pills: shows the deals for every kind of animal.
  ///
  /// In en, this message translates to:
  /// **'All animals'**
  String get allAnimals;

  /// The first category chip: every category.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategories;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort deals'**
  String get sortTooltip;

  /// No description provided for @couldNotLoadDeals.
  ///
  /// In en, this message translates to:
  /// **'Could not load deals'**
  String get couldNotLoadDeals;

  /// No description provided for @couldNotRefresh.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh the deals. Please try again.'**
  String get couldNotRefresh;

  /// Shown after a deal was shared.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your deal is live.'**
  String get dealIsLive;

  /// How many deals the grid shows when every animal is included.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 deal} other{{count} deals}}'**
  String dealCount(int count);

  /// How many deals suit the selected pet's kind: '23 deals for dogs'. animals is one of the animalsIn... words.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 deal} other{{count} deals}} for {animals}'**
  String dealCountFor(int count, String animals);

  /// No description provided for @noDealsYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No deals yet'**
  String get noDealsYetTitle;

  /// No description provided for @noDealsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'New bargains will show up here. Found one yourself? Share it with other pet owners.'**
  String get noDealsYetMessage;

  /// No description provided for @noDealsFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No deals found'**
  String get noDealsFoundTitle;

  /// Button: removes the search text and the category.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// Button on the empty list of one pet.
  ///
  /// In en, this message translates to:
  /// **'Show all animals'**
  String get showAllAnimals;

  /// No description provided for @noDealsInCategory.
  ///
  /// In en, this message translates to:
  /// **'There are no deals in {category} right now. Try a different category.'**
  String noDealsInCategory(String category);

  /// No description provided for @nothingMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\". Try another word.'**
  String nothingMatches(String query);

  /// No description provided for @nothingMatchesInCategory.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\" in {category}. Try another word or a different category.'**
  String nothingMatchesInCategory(String query, String category);

  /// Title of the empty list of one pet, when other animals do have deals. animals is one of the animalsIn... words.
  ///
  /// In en, this message translates to:
  /// **'No deals for {animals} here'**
  String noDealsForAnimalsTitle(String animals);

  /// First sentence of the empty list of one pet. It is followed by othersHaveDeals.
  ///
  /// In en, this message translates to:
  /// **'There are no deals for {animals} right now.'**
  String noneForAnimals(String animals);

  /// No description provided for @noneForAnimalsInCategory.
  ///
  /// In en, this message translates to:
  /// **'There is nothing for {animals} in {category} right now.'**
  String noneForAnimalsInCategory(String animals, String category);

  /// No description provided for @noneForAnimalsMatching.
  ///
  /// In en, this message translates to:
  /// **'Nothing for {animals} matches \"{query}\".'**
  String noneForAnimalsMatching(String animals, String query);

  /// No description provided for @noneForAnimalsMatchingInCategory.
  ///
  /// In en, this message translates to:
  /// **'Nothing for {animals} matches \"{query}\" in {category}.'**
  String noneForAnimalsMatchingInCategory(
    String animals,
    String query,
    String category,
  );

  /// Second sentence of the empty list of one pet: what the other animals have with the same search and category.
  ///
  /// In en, this message translates to:
  /// **'Other animals have {count, plural, =1{1 deal} other{{count} deals}} here.'**
  String othersHaveDeals(int count);

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryTreats.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get categoryTreats;

  /// No description provided for @categoryLitterAndCleaning.
  ///
  /// In en, this message translates to:
  /// **'Litter & cleaning'**
  String get categoryLitterAndCleaning;

  /// No description provided for @categoryToys.
  ///
  /// In en, this message translates to:
  /// **'Toys'**
  String get categoryToys;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categoryGrooming.
  ///
  /// In en, this message translates to:
  /// **'Grooming'**
  String get categoryGrooming;

  /// No description provided for @categoryAccessories.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get categoryAccessories;

  /// No description provided for @categoryBedsAndCrates.
  ///
  /// In en, this message translates to:
  /// **'Beds & crates'**
  String get categoryBedsAndCrates;

  /// No description provided for @sortBiggestDiscount.
  ///
  /// In en, this message translates to:
  /// **'Biggest discount'**
  String get sortBiggestDiscount;

  /// No description provided for @sortLowestPrice.
  ///
  /// In en, this message translates to:
  /// **'Lowest price'**
  String get sortLowestPrice;

  /// Sort order: cheapest per kg, per litre or per item first.
  ///
  /// In en, this message translates to:
  /// **'Lowest unit price'**
  String get sortLowestUnitPrice;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortEndingSoon.
  ///
  /// In en, this message translates to:
  /// **'Ending soon'**
  String get sortEndingSoon;

  /// A kind of animal on a chip or a tag. The animalsIn... words are the same kinds inside a sentence.
  ///
  /// In en, this message translates to:
  /// **'Dogs'**
  String get animalsDog;

  /// No description provided for @animalsCat.
  ///
  /// In en, this message translates to:
  /// **'Cats'**
  String get animalsCat;

  /// No description provided for @animalsBird.
  ///
  /// In en, this message translates to:
  /// **'Birds'**
  String get animalsBird;

  /// No description provided for @animalsRabbit.
  ///
  /// In en, this message translates to:
  /// **'Rabbits'**
  String get animalsRabbit;

  /// No description provided for @animalsReptile.
  ///
  /// In en, this message translates to:
  /// **'Reptiles'**
  String get animalsReptile;

  /// The last kind of animal on a chip: none of the kinds above.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get animalsOther;

  /// A kind of animal inside a sentence: 'for dogs', '23 deals for dogs'.
  ///
  /// In en, this message translates to:
  /// **'dogs'**
  String get animalsInSentenceDog;

  /// No description provided for @animalsInSentenceCat.
  ///
  /// In en, this message translates to:
  /// **'cats'**
  String get animalsInSentenceCat;

  /// No description provided for @animalsInSentenceBird.
  ///
  /// In en, this message translates to:
  /// **'birds'**
  String get animalsInSentenceBird;

  /// No description provided for @animalsInSentenceRabbit.
  ///
  /// In en, this message translates to:
  /// **'rabbits'**
  String get animalsInSentenceRabbit;

  /// No description provided for @animalsInSentenceReptile.
  ///
  /// In en, this message translates to:
  /// **'reptiles'**
  String get animalsInSentenceReptile;

  /// No description provided for @animalsInSentenceOther.
  ///
  /// In en, this message translates to:
  /// **'other pets'**
  String get animalsInSentenceOther;

  /// Chip in the share form: the deal suits every pet.
  ///
  /// In en, this message translates to:
  /// **'All pets'**
  String get allPets;

  /// Pill on the deal page of a deal that names no animals.
  ///
  /// In en, this message translates to:
  /// **'For all pets'**
  String get forAllPets;

  /// Pill on the deal page: 'For cats', 'For dogs, cats and rabbits'. animals is a list built with listComma and listAnd.
  ///
  /// In en, this message translates to:
  /// **'For {animals}'**
  String forAnimals(String animals);

  /// Joins the last item of a list to what comes before it: 'dogs and cats', 'dogs, cats and rabbits'.
  ///
  /// In en, this message translates to:
  /// **'{first} and {last}'**
  String listAnd(String first, String last);

  /// Joins two items in the middle of a list.
  ///
  /// In en, this message translates to:
  /// **'{first}, {next}'**
  String listComma(String first, String next);

  /// A unit of package size, as picked in the share form.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitG.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitG;

  /// No description provided for @unitLitre.
  ///
  /// In en, this message translates to:
  /// **'litre'**
  String get unitLitre;

  /// No description provided for @unitMl.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get unitMl;

  /// The unit for things that are counted: 28 chews, 300 bags.
  ///
  /// In en, this message translates to:
  /// **'units'**
  String get unitUnits;

  /// A package size: '12 kg'. amount is a formatted number.
  ///
  /// In en, this message translates to:
  /// **'{amount} kg'**
  String packageKg(String amount);

  /// No description provided for @packageG.
  ///
  /// In en, this message translates to:
  /// **'{amount} g'**
  String packageG(String amount);

  /// A package of exactly one litre.
  ///
  /// In en, this message translates to:
  /// **'{amount} litre'**
  String packageLitreOne(String amount);

  /// No description provided for @packageLitres.
  ///
  /// In en, this message translates to:
  /// **'{amount} litres'**
  String packageLitres(String amount);

  /// No description provided for @packageMl.
  ///
  /// In en, this message translates to:
  /// **'{amount} ml'**
  String packageMl(String amount);

  /// A package of exactly one item.
  ///
  /// In en, this message translates to:
  /// **'{amount} unit'**
  String packageUnitOne(String amount);

  /// No description provided for @packageUnits.
  ///
  /// In en, this message translates to:
  /// **'{amount} units'**
  String packageUnits(String amount);

  /// A unit price. price is formatted money: '₪18.90 per kg'.
  ///
  /// In en, this message translates to:
  /// **'{price} per kg'**
  String unitPricePerKg(String price);

  /// No description provided for @unitPricePerLitre.
  ///
  /// In en, this message translates to:
  /// **'{price} per litre'**
  String unitPricePerLitre(String price);

  /// The price of one item of a pack.
  ///
  /// In en, this message translates to:
  /// **'{price} each'**
  String unitPriceEach(String price);

  /// Badge on a deal whose end date has passed.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @freeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Free delivery'**
  String get freeDelivery;

  /// On a deal card: what delivery adds. price is formatted money.
  ///
  /// In en, this message translates to:
  /// **'+ {price} delivery'**
  String plusDelivery(String price);

  /// Title of a deal's page.
  ///
  /// In en, this message translates to:
  /// **'Deal'**
  String get dealTitle;

  /// No description provided for @dealGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This deal is gone'**
  String get dealGoneTitle;

  /// No description provided for @dealGoneMessage.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed by the person who shared it.'**
  String get dealGoneMessage;

  /// No description provided for @backToStore.
  ///
  /// In en, this message translates to:
  /// **'Back to the Store'**
  String get backToStore;

  /// amount is formatted money, percent the whole-number discount.
  ///
  /// In en, this message translates to:
  /// **'You save {amount} ({percent}%)'**
  String youSave(String amount, int percent);

  /// Label in the price card: the price per kg, per litre or per item.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get unitPriceLabel;

  /// Label in the price card: how much is in the package.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get packageLabel;

  /// No description provided for @deliveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryLabel;

  /// Delivery costs nothing. Also the choice in the share form.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get deliveryFree;

  /// What delivery adds to the price. price is formatted money.
  ///
  /// In en, this message translates to:
  /// **'+ {price}'**
  String deliveryPlus(String price);

  /// The deal does not say what delivery costs.
  ///
  /// In en, this message translates to:
  /// **'Not given'**
  String get deliveryNotGiven;

  /// No description provided for @deliveryAskSeller.
  ///
  /// In en, this message translates to:
  /// **'Check with the seller'**
  String get deliveryAskSeller;

  /// The price plus delivery.
  ///
  /// In en, this message translates to:
  /// **'Final price'**
  String get finalPriceLabel;

  /// No description provided for @sellerLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get sellerLabel;

  /// Label of the day the price was last checked.
  ///
  /// In en, this message translates to:
  /// **'Price checked'**
  String get priceCheckedLabel;

  /// No description provided for @postedLabel.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get postedLabel;

  /// No description provided for @endsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get endsLabel;

  /// No description provided for @priceMayHaveChanged.
  ///
  /// In en, this message translates to:
  /// **'This price was checked a while ago. It may have changed.'**
  String get priceMayHaveChanged;

  /// No description provided for @dealEndedOn.
  ///
  /// In en, this message translates to:
  /// **'This deal ended on {date}'**
  String dealEndedOn(String date);

  /// A deal curated by the app rather than shared by a member.
  ///
  /// In en, this message translates to:
  /// **'PetLoop pick'**
  String get pickOfTheApp;

  /// No description provided for @sharedByYou.
  ///
  /// In en, this message translates to:
  /// **'Shared by you'**
  String get sharedByYou;

  /// The sharer has no display name.
  ///
  /// In en, this message translates to:
  /// **'Shared by a member'**
  String get sharedByMember;

  /// No description provided for @sharedBy.
  ///
  /// In en, this message translates to:
  /// **'Shared by {name}'**
  String sharedBy(String name);

  /// No description provided for @reportExpired.
  ///
  /// In en, this message translates to:
  /// **'Report as expired'**
  String get reportExpired;

  /// No description provided for @reportedExpired.
  ///
  /// In en, this message translates to:
  /// **'You reported this as expired'**
  String get reportedExpired;

  /// No description provided for @reportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks, we will check it.'**
  String get reportThanks;

  /// No description provided for @deleteMyDeal.
  ///
  /// In en, this message translates to:
  /// **'Delete my deal'**
  String get deleteMyDeal;

  /// No description provided for @deleteDealTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this deal?'**
  String get deleteDealTitle;

  /// No description provided for @deleteDealMessage.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from the Store for everyone.'**
  String get deleteDealMessage;

  /// No description provided for @dealDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your deal was deleted.'**
  String get dealDeleted;

  /// The button that opens the seller's page in the browser.
  ///
  /// In en, this message translates to:
  /// **'Open offer'**
  String get openOffer;

  /// Under the Open offer button. host is the seller's web address, e.g. example.com.
  ///
  /// In en, this message translates to:
  /// **'Opens {host} in your browser'**
  String opensInBrowser(String host);

  /// No description provided for @couldNotOpenOffer.
  ///
  /// In en, this message translates to:
  /// **'Could not open the offer. Please try again.'**
  String get couldNotOpenOffer;

  /// How long ago a deal was posted.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 min ago} other{{minutes} min ago}}'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour ago} other{{hours} hours ago}}'**
  String timeHoursAgo(int hours);

  /// A deal posted a day ago.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterday;

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day ago} other{{days} days ago}}'**
  String timeDaysAgo(int days);

  /// No description provided for @noEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get noEndDate;

  /// No description provided for @endedOn.
  ///
  /// In en, this message translates to:
  /// **'Ended {date}'**
  String endedOn(String date);

  /// When a running deal ends and how many days are left: '12.10.26 · 12 days left'.
  ///
  /// In en, this message translates to:
  /// **'{date} · {days, plural, =0{ends today} =1{1 day left} other{{days} days left}}'**
  String endsOn(String date, int days);

  /// The day a price was checked and how long ago that was: '29.09.26 · yesterday'. when is checkedToday, checkedYesterday or checkedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{date} · {when}'**
  String checkedOn(String date, String when);

  /// Second half of checkedOn.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get checkedToday;

  /// No description provided for @checkedYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get checkedYesterday;

  /// No description provided for @checkedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day ago} other{{days} days ago}}'**
  String checkedDaysAgo(int days);

  /// Tooltip of the heart on a deal that is not saved.
  ///
  /// In en, this message translates to:
  /// **'Save deal'**
  String get saveDeal;

  /// Tooltip of the heart on a saved deal.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get removeFromSaved;

  /// Short message after saving a deal.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedConfirmation;

  /// No description provided for @removedFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved deals'**
  String get removedFromSaved;

  /// No description provided for @couldNotUpdateSaved.
  ///
  /// In en, this message translates to:
  /// **'Could not update your saved deals. Please try again.'**
  String get couldNotUpdateSaved;

  /// No description provided for @couldNotLoadSaved.
  ///
  /// In en, this message translates to:
  /// **'Could not load your saved deals'**
  String get couldNotLoadSaved;

  /// No description provided for @noSavedDealsTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved deals yet'**
  String get noSavedDealsTitle;

  /// No description provided for @noSavedDealsMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a deal to keep it here.'**
  String get noSavedDealsMessage;

  /// Button on the empty saved list: back to the Store.
  ///
  /// In en, this message translates to:
  /// **'Browse deals'**
  String get browseDeals;

  /// No description provided for @savedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved deal} other{{count} saved deals}}'**
  String savedCount(int count);

  /// No description provided for @shareIntro.
  ///
  /// In en, this message translates to:
  /// **'Found a bargain? Tell other pet owners where to get it.'**
  String get shareIntro;

  /// Label of the field for the name of the product on offer.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldTitleHint.
  ///
  /// In en, this message translates to:
  /// **'What is on offer?'**
  String get fieldTitleHint;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get fieldCategoryHint;

  /// No description provided for @fieldAnimals.
  ///
  /// In en, this message translates to:
  /// **'For which animals'**
  String get fieldAnimals;

  /// No description provided for @fieldAnimalsHelp.
  ///
  /// In en, this message translates to:
  /// **'Starts on your selected pet. Pick more than one if it fits.'**
  String get fieldAnimalsHelp;

  /// symbol is the currency sign.
  ///
  /// In en, this message translates to:
  /// **'Price now ({symbol})'**
  String fieldPriceNow(String symbol);

  /// No description provided for @fieldPriceBefore.
  ///
  /// In en, this message translates to:
  /// **'Price before ({symbol})'**
  String fieldPriceBefore(String symbol);

  /// Worked out live under the two price fields.
  ///
  /// In en, this message translates to:
  /// **'That is {percent}% off'**
  String hintPercentOff(int percent);

  /// No description provided for @fieldPackageSize.
  ///
  /// In en, this message translates to:
  /// **'Package size (optional)'**
  String get fieldPackageSize;

  /// No description provided for @fieldPackageAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldPackageAmountHint;

  /// No description provided for @fieldPackageUnitHint.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get fieldPackageUnitHint;

  /// No description provided for @fieldPackageHelp.
  ///
  /// In en, this message translates to:
  /// **'For a multi-pack enter the total, for example 12 × 85 g is 1020 g.'**
  String get fieldPackageHelp;

  /// Worked out live under the package size. unitPrice is a whole unit price, e.g. '₪3.69 per kg'.
  ///
  /// In en, this message translates to:
  /// **'That is {unitPrice}'**
  String hintUnitPrice(String unitPrice);

  /// No description provided for @fieldDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery (optional)'**
  String get fieldDelivery;

  /// Choice in the share form: the sharer does not know the delivery cost.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get deliveryNotSure;

  /// Choice in the share form: delivery costs money.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get deliveryPaid;

  /// No description provided for @fieldDeliveryCost.
  ///
  /// In en, this message translates to:
  /// **'Delivery cost ({symbol})'**
  String fieldDeliveryCost(String symbol);

  /// Worked out live under the delivery choice.
  ///
  /// In en, this message translates to:
  /// **'Final price {price}'**
  String hintFinalPrice(String price);

  /// No description provided for @fieldSellerHint.
  ///
  /// In en, this message translates to:
  /// **'The shop or website'**
  String get fieldSellerHint;

  /// No description provided for @fieldLink.
  ///
  /// In en, this message translates to:
  /// **'Link to the offer'**
  String get fieldLink;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get fieldDescription;

  /// No description provided for @fieldDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Size, flavour, what is included...'**
  String get fieldDescriptionHint;

  /// No description provided for @fieldEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date (optional)'**
  String get fieldEndDate;

  /// No description provided for @addEndDate.
  ///
  /// In en, this message translates to:
  /// **'Add an end date'**
  String get addEndDate;

  /// The chosen end date in the share form.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String endsDate(String date);

  /// No description provided for @removeEndDate.
  ///
  /// In en, this message translates to:
  /// **'Remove the end date'**
  String get removeEndDate;

  /// Title of the calendar that picks the end date.
  ///
  /// In en, this message translates to:
  /// **'Last day of the deal'**
  String get lastDayOfDeal;

  /// No description provided for @checkedTodayNote.
  ///
  /// In en, this message translates to:
  /// **'The price will show as checked today, {date}.'**
  String checkedTodayNote(String date);

  /// The button that sends the share form.
  ///
  /// In en, this message translates to:
  /// **'Share deal'**
  String get shareDealButton;

  /// No description provided for @validTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the deal a title.'**
  String get validTitleRequired;

  /// No description provided for @validTitleTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {count} characters.'**
  String validTitleTooShort(int count);

  /// No description provided for @validSellerRequired.
  ///
  /// In en, this message translates to:
  /// **'Who is selling it?'**
  String get validSellerRequired;

  /// No description provided for @validCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a category.'**
  String get validCategoryRequired;

  /// No description provided for @validOriginalPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the price before the discount.'**
  String get validOriginalPriceRequired;

  /// No description provided for @validPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the price now.'**
  String get validPriceRequired;

  /// No description provided for @validNotANumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, like 49.90.'**
  String get validNotANumber;

  /// No description provided for @validPriceAboveZero.
  ///
  /// In en, this message translates to:
  /// **'The price must be above zero.'**
  String get validPriceAboveZero;

  /// No description provided for @validPriceBelowOriginal.
  ///
  /// In en, this message translates to:
  /// **'The deal price must be below the original price.'**
  String get validPriceBelowOriginal;

  /// No description provided for @validLinkRequired.
  ///
  /// In en, this message translates to:
  /// **'Paste the link to the offer.'**
  String get validLinkRequired;

  /// prefix is https://, kept left to right.
  ///
  /// In en, this message translates to:
  /// **'Use a full link that starts with {prefix}'**
  String validLinkNotHttps(String prefix);

  /// No description provided for @validPackageAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a size above zero, like 2.5.'**
  String get validPackageAmount;

  /// No description provided for @validPackageUnit.
  ///
  /// In en, this message translates to:
  /// **'Choose a unit: kg, g, litre, ml or units.'**
  String get validPackageUnit;

  /// No description provided for @validDeliveryCostRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the delivery cost.'**
  String get validDeliveryCostRequired;

  /// No description provided for @validDeliveryCostInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number above zero, or pick Free.'**
  String get validDeliveryCostInvalid;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your connection and try again.'**
  String get errNetwork;

  /// No description provided for @errSignInToShare.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to share a deal.'**
  String get errSignInToShare;

  /// No description provided for @errSignInToDelete.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to delete a deal.'**
  String get errSignInToDelete;

  /// No description provided for @errSignInToReport.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to report a deal.'**
  String get errSignInToReport;

  /// No description provided for @errNeedsTitleAndSeller.
  ///
  /// In en, this message translates to:
  /// **'A deal needs a title and a seller.'**
  String get errNeedsTitleAndSeller;

  /// prefix is https://, kept left to right.
  ///
  /// In en, this message translates to:
  /// **'Use a link that starts with {prefix}'**
  String errLinkMustBeHttps(String prefix);

  /// No description provided for @errPackageNotValid.
  ///
  /// In en, this message translates to:
  /// **'The package size must be above zero.'**
  String get errPackageNotValid;

  /// No description provided for @errDeliveryNotValid.
  ///
  /// In en, this message translates to:
  /// **'The delivery cost cannot be below zero.'**
  String get errDeliveryNotValid;

  /// No description provided for @errOnlyDeleteOwn.
  ///
  /// In en, this message translates to:
  /// **'You can only delete deals you shared.'**
  String get errOnlyDeleteOwn;

  /// No description provided for @errNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to do that. Please sign in again.'**
  String get errNotAllowed;

  /// No description provided for @errDetailsNotValid.
  ///
  /// In en, this message translates to:
  /// **'Some of the details are not valid. Please check them and try again.'**
  String get errDetailsNotValid;

  /// No description provided for @errDealNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This deal is no longer available.'**
  String get errDealNoLongerAvailable;

  /// No description provided for @errSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please sign in again.'**
  String get errSessionEnded;

  /// No description provided for @errStoreNeedsUpdate.
  ///
  /// In en, this message translates to:
  /// **'The Store is being updated. Please try again later.'**
  String get errStoreNeedsUpdate;
}

class _StoreL10nDelegate extends LocalizationsDelegate<StoreL10n> {
  const _StoreL10nDelegate();

  @override
  Future<StoreL10n> load(Locale locale) {
    return SynchronousFuture<StoreL10n>(lookupStoreL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_StoreL10nDelegate old) => false;
}

StoreL10n lookupStoreL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return StoreL10nEn();
    case 'he':
      return StoreL10nHe();
  }

  throw FlutterError(
    'StoreL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
