import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/pets_provider.dart';
import '../../theme/app_theme.dart';
import 'widgets/activity_card.dart';
import 'widgets/feeding_card.dart';
import 'widgets/health_card.dart';
import 'widgets/home_header.dart';
import 'widgets/pet_hero.dart';

/// The dashboard: header with dog selector, profile hero, and the three
/// feeding / activity / health cards.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(selectedPetProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeHeader(),
          PetHero(pet: pet),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FeedingCard(status: pet.feeding),
                const SizedBox(height: AppSpacing.cardGap),
                ActivityCard(status: pet.activity),
                const SizedBox(height: AppSpacing.cardGap),
                HealthCard(events: pet.healthEvents),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
