import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';

/// Which animal a chat room or a guide is for. The words for it are in the
/// strings files (`CommunityWords.audienceTag`, `forWhom`).
enum Audience {
  everyone('all'),
  dogs('dog'),
  cats('cat'),

  /// A kind of animal this version has no view of its own for yet (rabbits,
  /// birds): shown only under Everything.
  other('other');

  const Audience(this.key);

  /// The value stored in `chat_channels.audience`: `all`, or a kind of
  /// animal as in `pets.species`.
  final String key;

  /// The audience for a stored value. Rooms created before the column
  /// existed (`null`) are for everyone.
  static Audience fromKey(String? key) => switch (key) {
        null || 'all' => everyone,
        'dog' => dogs,
        'cat' => cats,
        _ => other,
      };
}

/// What the Chat and Guides sections show: one animal's content plus what
/// is shared by everyone, or everything. The chips' labels are in the strings
/// files (`CommunityWords.scope`).
enum CommunityScope {
  dogs,
  cats,
  everything;

  bool shows(Audience audience) => switch (this) {
        dogs => audience == Audience.everyone || audience == Audience.dogs,
        cats => audience == Audience.everyone || audience == Audience.cats,
        everything => true,
      };

  /// The view a pet's owner starts on: their animal's, or everything for
  /// an animal with no view of its own.
  static CommunityScope forSpecies(PetSpecies species) => switch (species) {
        PetSpecies.dog => dogs,
        PetSpecies.cat => cats,
        _ => everything,
      };
}

/// The view chosen in the Chat and Guides sections (one choice for both).
///
/// Starts on the selected pet's kind and goes back to it whenever another
/// pet is selected. Not remembered between launches.
class CommunityScopeNotifier extends Notifier<CommunityScope> {
  @override
  CommunityScope build() {
    // The id as well, so switching between two pets resets a manual choice.
    final (_, species) = ref.watch(selectedPetProvider.select((pet) => (pet.id, pet.species)));
    return CommunityScope.forSpecies(species);
  }

  void select(CommunityScope scope) => state = scope;
}

final communityScopeProvider = NotifierProvider<CommunityScopeNotifier, CommunityScope>(CommunityScopeNotifier.new);
