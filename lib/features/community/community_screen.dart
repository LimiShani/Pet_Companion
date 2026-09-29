import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

/// Social hub: feed, chat and pet photos. Placeholder until built.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Community',
      icon: Icons.people_rounded,
      message: 'Share photos of your pets, chat with other owners and browse guides on raising and training.',
    );
  }
}
