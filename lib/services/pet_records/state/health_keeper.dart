import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'emergency_contacts.dart';
import 'emergency_kit.dart';
import 'health_providers.dart';

/// How much of a pet's health data a [HealthKeeper] keeps active.
enum HealthKeep {
  /// The vets, the health profile and the emergency contacts.
  contacts,

  /// The contacts, plus the emergency kit (which reads the care plan).
  emergency,

  /// Everything: also the records, documents, care plan and observations.
  everything,
}

/// Keeps a pet's health providers active while [child] is mounted.
///
/// Riverpod pauses a widget's subscriptions while the widget is covered by
/// another page. If the data changes meanwhile (a vet is edited on the
/// page above), the paused providers are rebuilt at the moment the page
/// below is uncovered, in the middle of a widget build, and a provider
/// that feeds other providers then trips Flutter's "setState during build"
/// assertion. Providers with an always-active listener are rebuilt at
/// once instead, so every Health screen and every piece other tabs place
/// (the emergency button, the vet tile...) wraps itself in a keeper.
class HealthKeeper extends StatefulWidget {
  const HealthKeeper({
    super.key,
    required this.petId,
    this.keep = HealthKeep.contacts,
    required this.child,
  });

  final String petId;
  final HealthKeep keep;
  final Widget child;

  @override
  State<HealthKeeper> createState() => _HealthKeeperState();
}

class _HealthKeeperState extends State<HealthKeeper> {
  ProviderContainer? _container;
  final _subscriptions = <ProviderSubscription<Object?>>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final container = ProviderScope.containerOf(context);
    if (!identical(container, _container)) {
      _container = container;
      _listen();
    }
  }

  @override
  void didUpdateWidget(HealthKeeper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId != widget.petId || oldWidget.keep != widget.keep) {
      _listen();
    }
  }

  void _listen() {
    final old = [..._subscriptions];
    _subscriptions.clear();
    final container = _container!;
    final id = widget.petId;
    void keep<T>(ProviderListenable<T> provider) => _subscriptions.add(
      container.listen<T>(provider, (_, _) {}, onError: (_, _) {}),
    );

    keep(vetsProvider);
    keep(healthProfileProvider(id));
    keep(petVetsProvider(id));
    keep(emergencyContactsProvider(id));
    if (widget.keep != HealthKeep.contacts) {
      keep(carePlanProvider(id));
      keep(kitChecksProvider(id));
      keep(emergencyKitProvider(id));
    }
    if (widget.keep == HealthKeep.everything) {
      keep(healthRecordsProvider(id));
      keep(healthDocumentsProvider(id));
      keep(observationsProvider(id));
      keep(petHealthDataProvider(id));
      keep(healthSummaryProvider(id));
    }
    // The new subscriptions are in place before the old ones go, so
    // nothing is disposed and loaded again in between.
    for (final sub in old) {
      sub.close();
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.close();
    }
    _subscriptions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
