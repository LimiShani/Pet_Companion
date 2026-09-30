import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/pets_provider.dart';
import '../../theme/app_theme.dart';
import 'widgets/activity_card.dart';
import 'widgets/feeding_card.dart';
import 'widgets/health_card.dart';
import 'widgets/home_header.dart';
import 'widgets/pet_hero.dart';

/// The dashboard: a pinned top bar with the Emergency pill, then the pet
/// selector, the profile hero and the feeding / activity / health cards,
/// which scroll under the bar.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// The dashboard's vertical scroll view.
  static const scrollKey = Key('home-scroll');

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scroll.hasClients && _scroll.offset > 0;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(selectedPetProvider);
    // The bar is drawn over the top of the scrolling content, so the
    // content starts with a coral band of the bar's height.
    final barHeight = MediaQuery.paddingOf(context).top + HomeTopBar.height;

    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            key: HomeScreen.scrollKey,
            controller: _scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomePetRow(topInset: barHeight),
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
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: HomeTopBar(petId: pet.id, raised: _scrolled),
        ),
      ],
    );
  }
}
