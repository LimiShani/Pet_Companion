import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

/// Per-pet history and medical log. Placeholder until the log is built.
class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Health',
      icon: Icons.monitor_heart_rounded,
      message: 'Medical log, vaccinations, medicine schedule and vet visits for each pet will live here.',
    );
  }
}
