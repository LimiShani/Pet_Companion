import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/pet_completeness.dart';

/// Keeps what is known about a pet's essentials up to date for as long as
/// [child] is mounted, including while its page is covered by another one.
///
/// A widget's own `ref.watch` is paused while its page is covered (another
/// tab, a page on top). If a vet or a health profile changes meanwhile, the
/// providers behind the essentials would catch up only when the page comes
/// back, in the middle of that frame's build, and flutter_riverpod 3.3
/// cannot do that safely: it fails with "setState() called during build".
/// The subscription held here is never paused, so the providers are
/// refreshed when the change happens and there is nothing left to catch up.
///
/// Every pets widget that reads a pet's essentials, or Health's providers
/// behind them, wraps what it builds in one of these.
class PetEssentialsKeeper extends StatefulWidget {
  const PetEssentialsKeeper({super.key, required this.petId, required this.child});

  final String petId;
  final Widget child;

  @override
  State<PetEssentialsKeeper> createState() => _PetEssentialsKeeperState();
}

class _PetEssentialsKeeperState extends State<PetEssentialsKeeper> {
  ProviderContainer? _container;
  ProviderSubscription<PetCompleteness>? _subscription;

  void _listen() {
    _subscription?.close();
    _subscription = _container!.listen(petCompletenessProvider(widget.petId), (_, _) {});
  }

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
  void didUpdateWidget(PetEssentialsKeeper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId != widget.petId) _listen();
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
