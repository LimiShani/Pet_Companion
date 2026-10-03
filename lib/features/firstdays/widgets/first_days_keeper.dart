import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../state/first_days_providers.dart';

/// Keeps a pet's first 30 days (and, once a path exists, the health and
/// care data that tick its tasks) active while [child] is mounted, for the
/// reason given on `HealthKeeper`: Home and the pet's profile stay below
/// the pages that change this data (the feeding page, a new vet visit, the
/// first 30 days page itself), and what they show must follow without
/// being rebuilt in the middle of a frame.
class FirstDaysKeeper extends StatefulWidget {
  const FirstDaysKeeper({super.key, required this.petId, required this.child});

  final String petId;
  final Widget child;

  @override
  State<FirstDaysKeeper> createState() => _FirstDaysKeeperState();
}

class _FirstDaysKeeperState extends State<FirstDaysKeeper> {
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
  void didUpdateWidget(FirstDaysKeeper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId != widget.petId) _listen();
  }

  void _listen() {
    final old = [..._subscriptions];
    _subscriptions.clear();
    final container = _container!;
    final id = widget.petId;
    void keep<T>(ProviderListenable<T> provider) =>
        _subscriptions.add(container.listen<T>(provider, (_, _) {}, onError: (_, _) {}));
    keep(firstDaysProvider(id));
    // Watches the health and care data itself, once a path exists.
    keep(firstDaysViewProvider(id));
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
