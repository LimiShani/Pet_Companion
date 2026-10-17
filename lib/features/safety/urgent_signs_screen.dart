import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../presentation/health_widgets.dart';
import '../../services/safety/data/safety_text.dart';
import '../../services/safety/data/urgent_signs.dart';
import '../../theme/app_area.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/area_disc.dart';
import '../../widgets/coral_header.dart';
import 'safety_widgets.dart';

/// "Is it urgent?": signs that mean going to a vet now, for the pet's kind
/// of animal (the general list for rabbits, birds and the rest), with one
/// Call now at the top. General guidance, never a diagnosis: no sign has a
/// button of its own, every one means the same thing.
class UrgentSignsScreen extends StatelessWidget {
  const UrgentSignsScreen({super.key, required this.pet});

  static const listKey = Key('urgent-signs');

  /// The row of the sign [id].
  static Key signKey(String id) => ValueKey('urgent-$id');

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final safety = context.safetyL10n;
    final language = safetyLanguageOf(context);
    final animal = SafetyAnimal.of(pet.species);
    final signs = urgentSignsFor(animal);
    final section = switch (animal) {
      SafetyAnimal.dog => safety.urgentSectionDog,
      SafetyAnimal.cat => safety.urgentSectionCat,
      _ => safety.urgentSectionAny,
    };
    // Call now stays in view above the list (pinned), the one action.
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: safety.urgentRow, showBack: true),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screen,
              12,
              AppSpacing.screen,
              0,
            ),
            child: SafetyCallCard(petId: pet.id),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                12,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: _body(context, safety, language, animal, signs, section),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    SafetyL10n safety,
    String language,
    SafetyAnimal animal,
    List<UrgentSign> signs,
    String section,
  ) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            safety.urgentLead,
            style: AppText.body.copyWith(color: AppColors.brown),
          ),
          const SizedBox(height: 16),
          Text(section, style: AppText.sectionTitle),
          if (animal == SafetyAnimal.bird || animal == SafetyAnimal.other) ...[
            const SizedBox(height: 2),
            Text(
              safety.urgentOtherNote,
              style: AppText.secondary.copyWith(color: AppColors.brown),
            ),
          ],
          const SizedBox(height: 10),
          HealthCard(
            key: listKey,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < signs.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                  _SignRow(key: signKey(signs[i].id), sign: signs[i], language: language),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SafetySourcesCard(sources: urgentSignSources),
          const SizedBox(height: 12),
          FinePrint(context.healthL10n.emergencySheetFinePrint),
        ],
      );
  }
}

class _SignRow extends StatelessWidget {
  const _SignRow({super.key, required this.sign, required this.language});

  final UrgentSign sign;
  final String language;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AreaDisc(Icons.warning_amber_rounded, area: AppArea.health),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sign.title.of(language),
                  style: AppText.cardTitle.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  sign.detail.of(language),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
