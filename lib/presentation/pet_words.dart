import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import '../models/pet.dart';
import '../services/pets/data/pets_repository.dart';

// The words for a pet in the language of the screen. The model
// (`models/pet.dart`) holds no words of its own beyond English names for
// logs; every screen gets what it shows from here, with the strings of its
// language: `context.petsL10n` in a widget, `ref.watch(petsL10nProvider)`
// elsewhere.

/// "Dog" / "כלב".
String petSpeciesText(PetsL10n l10n, PetSpecies species) => switch (species) {
  PetSpecies.dog => l10n.speciesDog,
  PetSpecies.cat => l10n.speciesCat,
  PetSpecies.bird => l10n.speciesBird,
  PetSpecies.rabbit => l10n.speciesRabbit,
  PetSpecies.reptile => l10n.speciesReptile,
  PetSpecies.other => l10n.speciesOther,
};

/// "Male", "Female", "Not sure".
String petSexText(PetsL10n l10n, PetSex sex) => switch (sex) {
  PetSex.male => l10n.sexMale,
  PetSex.female => l10n.sexFemale,
  PetSex.unknown => l10n.notSure,
};

/// "Yes", "No", "Not sure".
String petNeuteredText(PetsL10n l10n, Neutered neutered) => switch (neutered) {
  Neutered.yes => l10n.answerYes,
  Neutered.no => l10n.answerNo,
  Neutered.unknown => l10n.notSure,
};

String _lowerFirst(String text) =>
    text.isEmpty ? text : '${text[0].toLowerCase()}${text.substring(1)}';

/// An age in words: "3 years", "4 months", "Under a week", "About 3 years";
/// in Hebrew with its own forms for one and two ("שנה", "שנתיים").
String petAgeWords(PetsL10n l10n, PetAge age) {
  final count = age.count;
  final String text;
  if (count == null) {
    text = l10n.ageYearsExact(age.exactYears!.toStringAsFixed(1));
  } else if (age.isUnderAWeek) {
    text = l10n.ageUnderAWeek;
  } else {
    text = switch (age.unit) {
      PetAgeUnit.years => l10n.ageYears(count),
      PetAgeUnit.months => l10n.ageMonths(count),
      PetAgeUnit.weeks => l10n.ageWeeks(count),
    };
  }
  return age.approx ? l10n.ageAbout(_lowerFirst(text)) : text;
}

/// The age of [pet] in words at [now] (today when not given), or `null`
/// when it is not known.
String? petAgeText(PetsL10n l10n, Pet pet, {DateTime? now}) {
  final age = pet.ageAt(now ?? DateTime.now());
  return age == null ? null : petAgeWords(l10n, age);
}

/// Birds and reptiles are weighed in grams; the value is still stored in kg
/// (as in Health).
bool petWeighsInGrams(PetSpecies species) =>
    species == PetSpecies.bird || species == PetSpecies.reptile;

/// [value] with at most [decimals] decimals and no trailing zeros.
String trimmedNumber(double value, int decimals) {
  final text = value.toStringAsFixed(decimals);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

/// "18 kg", "4.25 kg", or "35 g" for an animal weighed in grams. To the
/// gram either way, so that a small animal is never shown as 0 kg.
String petWeightText(PetsL10n l10n, double kg, PetSpecies species) =>
    petWeighsInGrams(species)
    ? l10n.weightG(trimmedNumber(kg * 1000, 0))
    : l10n.weightKg(trimmedNumber(kg, 3));

/// What "Mixed or not sure" stores as the breed.
const kMixedBreed = 'Mixed';

/// The breed as the owner typed it, or the word for "Mixed" in the screen's
/// language when that was the answer; `null` when there is none.
String? petBreedText(PetsL10n l10n, Pet pet) {
  final breed = pet.breed?.trim() ?? '';
  if (breed.isEmpty) return null;
  return breed.toLowerCase() == kMixedBreed.toLowerCase()
      ? l10n.breedMixed
      : breed;
}

bool _rightToLeft(PetsL10n l10n) => l10n.localeName != 'en';

/// Something the owner typed (a breed, a vet's name), ready to sit in a
/// line of the screen's language: kept as one unit when it runs the other
/// way, so it cannot reorder the line around it.
String typedInLine(PetsL10n l10n, String typed) {
  final lineIsRtl = _rightToLeft(l10n);
  final direction = directionOfText(
    typed,
    fallback: lineIsRtl ? TextDirection.rtl : TextDirection.ltr,
  );
  return (direction == TextDirection.rtl) == lineIsRtl ? typed : isolate(typed);
}

/// A phone number ready to sit in a line of the screen's language: on a
/// right-to-left screen it is kept left-to-right as one unit.
String phoneInLine(PetsL10n l10n, String phone) =>
    _rightToLeft(l10n) ? ltr(phone) : phone;

/// "Dog · Mixed · about 3 years": the kind, then what is known. The age is
/// counted at [now] (today when not given).
String petSummaryLine(PetsL10n l10n, Pet pet, {DateTime? now}) {
  final breed = petBreedText(l10n, pet);
  final age = petAgeText(l10n, pet, now: now);
  return [
    petSpeciesText(l10n, pet.species),
    if (breed != null) typedInLine(l10n, breed),
    if (age != null) _lowerFirst(age),
  ].join(' · ');
}

/// What to tell the owner about a pets failure, in the language of the
/// given strings. The repositories only report the reason (see
/// [PetsFailure]); the words are put here.
String petsErrorText(PetsL10n l10n, AppL10n app, Object? error) {
  if (error is! PetsException) return app.errorGeneric;
  return switch (error.failure) {
    PetsFailure.notYours => l10n.errNotYours,
    PetsFailure.invalid => l10n.errInvalid,
    PetsFailure.databaseOutdated => l10n.errDatabaseOutdated,
    PetsFailure.signInAgain => l10n.errSignInAgain,
    PetsFailure.save => l10n.errSave,
    PetsFailure.load => l10n.errLoad,
    PetsFailure.delete => l10n.errDelete,
    PetsFailure.photoSave => l10n.errPhotoSave,
    PetsFailure.photoRemove => l10n.errPhotoRemove,
    PetsFailure.photoLoad => l10n.errPhotoLoad,
    PetsFailure.photoTooLarge => l10n.errPhotoTooLarge,
    PetsFailure.photoUnsupported => l10n.errPhotoUnsupported,
    PetsFailure.photoUnsupportedChooseAnother =>
      l10n.errPhotoUnsupportedChooseAnother,
    PetsFailure.photoGone => l10n.errPhotoGone,
    PetsFailure.offline => l10n.errOffline,
    PetsFailure.cameraNotAllowed => l10n.errCameraNotAllowed,
    PetsFailure.photosNotAllowed => l10n.errPhotosNotAllowed,
    PetsFailure.camera => l10n.errCamera,
    PetsFailure.photos => l10n.errPhotos,
    PetsFailure.nameMissing => l10n.nameMissing,
    // Words from elsewhere (another feature, a test) are in English: shown
    // as they are on an English screen, replaced by a plain line otherwise.
    PetsFailure.unknown =>
      l10n.localeName == 'en' ? error.message : app.errorGeneric,
  };
}

/// [petsErrorText] in the language of the screen [context] is on.
String petsErrorOf(BuildContext context, Object? error) =>
    petsErrorText(context.petsL10n, context.l10n, error);
