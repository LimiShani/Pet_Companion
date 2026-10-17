import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../presentation/health_widgets.dart';
import '../../services/safety/data/food_safety.dart';
import '../../services/safety/data/safety_text.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/coral_header.dart';
import 'safety_widgets.dart';

/// "Can Kelly eat this?": a searchable list of foods, plants and things
/// around the house with one answer each for the chosen animal (the pet's
/// kind to begin with). A row opens a short sheet with the line, the other
/// animals' answers and a call to the vet. No amounts, no calculator.
class FoodCheckScreen extends StatefulWidget {
  const FoodCheckScreen({super.key, required this.pet});

  static const searchKey = Key('food-search');
  static const animalKey = Key('food-animal');
  static const listKey = Key('food-list');
  static const nothingKey = Key('food-nothing');

  static Key rowKey(String id) => ValueKey('food-$id');
  static Key kindKey(FoodKind kind) => ValueKey('food-kind-${kind.name}');
  static Key animalItemKey(SafetyAnimal animal) =>
      ValueKey('food-animal-${animal.name}');

  final Pet pet;

  @override
  State<FoodCheckScreen> createState() => _FoodCheckScreenState();
}

class _FoodCheckScreenState extends State<FoodCheckScreen> {
  final _query = TextEditingController();
  late SafetyAnimal _animal = SafetyAnimal.of(widget.pet.species);
  final _kinds = <FoodKind>{};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<FoodEntry> _results(String language) {
    final query = _query.text;
    var found = searchFoods(query, languageCode: language);
    if (_kinds.isNotEmpty) {
      found = [
        for (final e in found)
          if (_kinds.contains(e.kind)) e,
      ];
    }
    if (normalizeSafetySearch(query).isEmpty) {
      // Everything: the dangerous ones first, then alphabetical.
      int weight(FoodEntry e) => switch (e.levelFor(_animal) ?? e.worst) {
        FoodLevel.dangerous => 0,
        FoodLevel.aLittle => 1,
        FoodLevel.safe => 2,
      };
      found.sort((a, b) {
        final w = weight(a).compareTo(weight(b));
        return w != 0 ? w : a.name(language).compareTo(b.name(language));
      });
    }
    return found;
  }

  /// The other name the search found [entry] by, when it is not the name
  /// on the row ("raisins" for Grapes and raisins).
  String? _matched(FoodEntry entry, String language) {
    final q = normalizeSafetySearch(_query.text);
    if (q.isEmpty) return null;
    final shown = entry.name(language);
    if (normalizeSafetySearch(shown).contains(q)) return null;
    for (final name in [...entry.en, ...entry.he]) {
      if (normalizeSafetySearch(name).contains(q)) return name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final safety = context.safetyL10n;
    final language = safetyLanguageOf(context);
    final results = _results(language);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: safety.foodRow(widget.pet.name),
            showBack: true,
            bottom: _SearchField(
              controller: _query,
              hint: safety.foodSearchHint,
              clearTooltip: safety.foodSearchClear,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _filters(context),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                8,
                AppSpacing.screen,
                24 +
                    MediaQuery.viewInsetsOf(context).bottom +
                    MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (results.isEmpty)
                    _Nothing(petId: widget.pet.id, query: _query.text.trim())
                  else
                    HealthCard(
                      key: FoodCheckScreen.listKey,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < results.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 1, indent: 16, endIndent: 16),
                            _FoodRow(
                              key: FoodCheckScreen.rowKey(results[i].id),
                              name: results[i].name(language),
                              matched: _matched(results[i], language),
                              level: results[i].levelFor(_animal),
                              onTap: () => showFoodSheet(
                                context,
                                entry: results[i],
                                animal: _animal,
                                petId: widget.pet.id,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  const SafetySourcesCard(sources: foodSafetySources),
                  const SizedBox(height: 12),
                  FinePrint(context.healthL10n.emergencySheetFinePrint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The one filter row: the animal menu chip, a divider, the kinds.
  Widget _filters(BuildContext context) {
    final safety = context.safetyL10n;
    final kinds = {
      FoodKind.food: safety.kindFoods,
      FoodKind.plant: safety.kindPlants,
      FoodKind.household: safety.kindHousehold,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        12,
        AppSpacing.screen,
        4,
      ),
      child: Row(
        children: [
          PopupMenuButton<SafetyAnimal>(
            key: FoodCheckScreen.animalKey,
            tooltip: safety.animalMenuTooltip,
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            ),
            onSelected: (animal) => setState(() => _animal = animal),
            itemBuilder: (context) => [
              for (final animal in SafetyAnimal.values)
                PopupMenuItem(
                  key: FoodCheckScreen.animalItemKey(animal),
                  value: animal,
                  child: Text(
                    safetyAnimalText(context, animal),
                    style: AppText.body.copyWith(
                      color: AppColors.ink,
                      fontWeight: animal == _animal
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
            ],
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
              decoration: const ShapeDecoration(
                color: AppColors.yellow,
                shape: StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    safetyAnimalText(context, _animal),
                    style: AppText.secondary.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const AppIcon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.ink,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1.5,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFFE2D2B4),
          ),
          for (final MapEntry(key: kind, value: label) in kinds.entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(
                key: FoodCheckScreen.kindKey(kind),
                label: Text(label),
                selected: _kinds.contains(kind),
                showCheckmark: false,
                onSelected: (on) => setState(
                  () => on ? _kinds.add(kind) : _kinds.remove(kind),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The search field in the header's bottom: white, focused on arrival,
/// with a clear button while there is text.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.clearTooltip,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final String clearTooltip;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
        key: FoodCheckScreen.searchKey,
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppText.bodyLarge.copyWith(color: AppColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          prefixIcon: const AppIcon(Icons.search_rounded, color: AppColors.brown),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: clearTooltip,
                  icon: const AppIcon(Icons.close_rounded, color: AppColors.brown),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    super.key,
    required this.name,
    required this.level,
    required this.onTap,
    this.matched,
  });

  final String name;
  final String? matched;
  final FoodLevel? level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppText.cardTitle.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (matched != null)
                      TypedText(
                        matched!,
                        style: AppText.label.copyWith(color: AppColors.brown),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: FoodLevelTag(level: level),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nothing matches: one sentence and one action.
class _Nothing extends ConsumerWidget {
  const _Nothing({required this.petId, required this.query});

  final String petId;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safety = context.safetyL10n;
    return HealthCard(
      key: FoodCheckScreen.nothingKey,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TypedText(
            safety.foodNothing(query),
            textAlign: TextAlign.center,
            style: AppText.cardTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            safety.foodNotSure,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.brown),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('food-nothing-call'),
            onPressed: () => callFirstContact(context, ref, petId),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.call_rounded, size: 18),
            label: Text(safety.foodCallVet),
          ),
        ],
      ),
    );
  }
}

/// A food's sheet: its answer for [animal], the one line, the other
/// animals' answers, its other names and a call to the vet (the one filled
/// button when it is dangerous).
Future<void> showFoodSheet(
  BuildContext context, {
  required FoodEntry entry,
  required SafetyAnimal animal,
  required String petId,
}) => showHealthSheet<void>(
  context,
  FoodSheet(entry: entry, animal: animal, petId: petId),
);

class FoodSheet extends ConsumerWidget {
  const FoodSheet({
    super.key,
    required this.entry,
    required this.animal,
    required this.petId,
  });

  static const callKey = Key('food-call-vet');

  final FoodEntry entry;
  final SafetyAnimal animal;
  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safety = context.safetyL10n;
    final language = safetyLanguageOf(context);
    final level = entry.levelFor(animal);
    final others = [
      for (final (other, label) in [
        (SafetyAnimal.dog, safety.forDogs),
        (SafetyAnimal.cat, safety.forCats),
        (SafetyAnimal.bird, safety.forBirds),
      ])
        if (other != animal)
          safety.forAnimal(
            label,
            entry.levelFor(other) == null
                ? safety.levelNotListed
                : foodLevelText(context, entry.levelFor(other)),
          ),
    ].join(' · ');
    final names = language == 'he' ? entry.he : entry.en;
    final dangerous = level == FoodLevel.dangerous;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(entry.name(language), style: AppText.heading),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: FoodLevelTag(level: level),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(entry.line.of(language), style: AppText.bodyLarge),
        const SizedBox(height: 6),
        Text(others, style: AppText.secondary.copyWith(color: AppColors.brown)),
        if (names.length > 1) ...[
          const SizedBox(height: 4),
          Text(
            safety.foodAlso(names.skip(1).join(', ')),
            style: AppText.secondary.copyWith(color: AppColors.brown),
          ),
        ],
        const SizedBox(height: 16),
        if (dangerous) ...[
          FilledButton.icon(
            key: callKey,
            onPressed: () => callFirstContact(context, ref, petId),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.coralDark,
              foregroundColor: AppColors.white,
              textStyle: AppText.button(16),
            ),
            icon: const AppIcon(Icons.call_rounded, size: 20),
            label: Text(safety.foodCallVet),
          ),
          const SizedBox(height: 8),
          Text(
            safety.foodEatenAlready,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.ink),
          ),
        ] else
          OutlinedButton.icon(
            key: callKey,
            onPressed: () => callFirstContact(context, ref, petId),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.call_rounded, size: 18),
            label: Text(safety.foodNotSure),
          ),
      ],
    );
  }
}
