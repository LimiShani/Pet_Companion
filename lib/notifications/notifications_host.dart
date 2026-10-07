import '../platform/feature_ui.dart';
import '../access/access_provider.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../services/pet_records/state/health_providers.dart';
import '../l10n/l10n.dart';
import '../models/pet.dart';
import '../navigation/app_router.dart';
import '../state/pets_provider.dart';
import 'notifications.dart';
import 'widgets/permission_sheet.dart';

/// Where a tapped reminder's target leads: `feeding:<petId>` the feeding
/// page, `activity:<petId>` the activity page, `health:<petId>` the
/// Schedule of the Health tab, `basket:<petId>` the Store tab. The pet
/// becomes the selected pet first. A push notification's target names a
/// feature action and an id (`post:<id>`, `room:<id>`): the module that
/// answers it opens the page. Anything else opens Home.
Future<void> openNotificationTarget(
  String target, {
  required GoRouter router,
  required List<Pet> pets,
  required void Function(String petId) selectPet,
  required void Function() showHealthSchedule,
  bool storeAvailable = true,
}) async {
  final colon = target.indexOf(':');
  final where = colon < 0 ? target : target.substring(0, colon);
  final petId = colon < 0 ? '' : target.substring(colon + 1);
  final pet = pets.where((p) => p.id == petId).firstOrNull;
  if (pet != null) selectPet(pet.id);

  // Close what is open over the pages (a sheet, a dialog, a pushed page).
  router.routerDelegate.navigatorKey.currentState?.popUntil(
    (route) => route.settings is Page,
  );

  switch (where) {
    case 'feeding' || 'activity':
      router.go(AppRoutes.home);
      if (pet == null) return;
      await WidgetsBinding.instance.endOfFrame;
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      await openFeature<Object>(context, where, pet.id);
    case 'health':
      showHealthSchedule();
      router.go(AppRoutes.health);
    case 'basket':
      router.go(storeAvailable ? AppRoutes.store : AppRoutes.home);
      if (!storeAvailable && pet != null) {
        await WidgetsBinding.instance.endOfFrame;
        final context = router.routerDelegate.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          await openFeature<Object>(context, 'basket', pet.id);
        }
      }
    default:
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (pet == null &&
          petId.isNotEmpty &&
          context != null &&
          context.mounted &&
          canOpenFeature(context, where)) {
        await openFeature<Object>(context, where, '', {'id': petId});
        return;
      }
      router.go(AppRoutes.home);
  }
}

/// Sits above every page of the app (in `MaterialApp.router`'s builder)
/// and does what needs the whole app: keeps every pet's reminders
/// scheduled ([ReminderCoordinator]), opens the page of a tapped reminder,
/// asks for permission the first time the account has something to remind
/// about, and checks again what the phone allows when the app comes back.
///
/// It also keeps this phone registered for push notifications
/// ([PushRegistrar]), opens the page of a tapped push notification, and
/// counts the ones that arrive while the app is open ([pushArrivalsProvider]).
///
/// Without a [NotificationPlatform] and without [PushMessaging] (tests, the
/// web) it is just [child].
class NotificationsHost extends ConsumerStatefulWidget {
  const NotificationsHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationsHost> createState() => _NotificationsHostState();
}

class _NotificationsHostState extends ConsumerState<NotificationsHost>
    with WidgetsBindingObserver {
  NotificationPlatform? _platform;
  PushMessaging? _push;
  ReminderCoordinator? _coordinator;
  GoRouter? _router;
  bool _asking = false;
  final _pushSubscriptions = <StreamSubscription<Object?>>[];

  bool get _active => _platform != null || _push != null;

  @override
  void initState() {
    super.initState();
    final platform = _platform = ref.read(notificationPlatformProvider);
    final push = _push = ref.read(pushMessagingProvider);
    if (!_active) return;
    WidgetsBinding.instance.addObserver(this);
    // After the first frame: the scope's container is in place, and the
    // router has started.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (platform != null) {
        _coordinator = ReminderCoordinator(
          ProviderScope.containerOf(context, listen: false),
        )..start();
        platform.onTap = _tapped;
      }
      if (push != null) _startPush(push);
      // A sheet or a page opened on top of the sign-in screen would go
      // with it: both wait until the tabs are on screen.
      final router = ref.read(routerProvider);
      _router = router;
      router.routerDelegate.addListener(_onRoute);
    });
  }

  void _tapped(String target) =>
      ref.read(notificationTapsProvider.notifier).tapped(target);

  void _startPush(PushMessaging push) {
    // Created here so it follows the account from the start.
    ref.read(pushRegistrarProvider);
    _pushSubscriptions
      ..add(push.taps.listen(_tapped, onError: (_) {}))
      ..add(
        push.arrivals.listen(
          (_) => ref.read(pushArrivalsProvider.notifier).arrived(),
          onError: (_) {},
        ),
      );
    push.initialTap().then((target) {
      if (target != null && mounted) _tapped(target);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    if (_active) {
      WidgetsBinding.instance.removeObserver(this);
      _platform?.onTap = null;
      _router?.routerDelegate.removeListener(_onRoute);
      _coordinator?.dispose();
      for (final sub in _pushSubscriptions) {
        sub.cancel();
      }
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.read(accessProvider.notifier).refresh();
    _coordinator?.resumed();
    ref.read(notificationAccessProvider.notifier).refresh();
  }

  /// Signed in, with the pets loaded and the tabs (or a page above them)
  /// on screen.
  bool get _ready {
    if (ref.read(authControllerProvider).value == null ||
        ref.read(petsGateProvider) != PetsGate.ready) {
      return false;
    }
    final path = _router?.routerDelegate.currentConfiguration.uri.path ?? '';
    return path.isNotEmpty &&
        path != AppRoutes.splash &&
        !AppRoutes.isPublic(path) &&
        path != '/welcome';
  }

  void _onRoute() {
    _openWaitingTap();
    _maybeAsk();
  }

  void _openWaitingTap() {
    if (ref.read(notificationTapsProvider) == null || !_ready) return;
    final target = ref.read(notificationTapsProvider.notifier).take();
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final kind = target.split(':').first;
      final capability = switch (kind) {
        'feeding' || 'activity' => 'care.view',
        'health' => 'health.schedule.view',
        'basket' => 'basket.view',
        'post' => 'community.feed.view',
        'room' => 'community.chat.view',
        _ => null,
      };
      if (capability != null && !ref.read(capabilityProvider(capability))) {
        ref.read(routerProvider).go(AppRoutes.home);
        return;
      }
      openNotificationTarget(
        target,
        router: ref.read(routerProvider),
        pets: ref.read(petsProvider),
        selectPet: ref.read(selectedPetIdProvider.notifier).select,
        showHealthSchedule: () => ref
            .read(healthSectionProvider.notifier)
            .show(HealthSection.schedule),
        storeAvailable: ref.read(capabilityProvider('store.deals.view')),
      );
    });
  }

  /// Asks once per phone, the first time the signed-in account has
  /// something that would ring. Never again afterwards: Settings shows what
  /// the phone allows, with a button.
  Future<void> _maybeAsk() async {
    final platform = _platform;
    if (platform == null ||
        _asking ||
        !_ready ||
        !ref.read(somethingToRemindProvider)) {
      return;
    }
    final store = ref.read(settingsStoreProvider);
    if (store.read(notificationsAskedSettingKey) == '1') return;
    _asking = true;
    try {
      final access = await platform.access();
      // The router has just moved on to the tabs; their page is in the
      // navigator only from the next frame, and a sheet shown before would
      // leave with the sign-in page.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_ready) return;
      final complete = access.allowed && access.exact != false;
      final context = ref
          .read(routerProvider)
          .routerDelegate
          .navigatorKey
          .currentContext;
      if (!complete && (context == null || !context.mounted)) return;
      await store.write(notificationsAskedSettingKey, '1');
      if (complete || context == null || !context.mounted) return;
      await showNotificationPermissionSheet(
        context,
        platform: platform,
        notificationsAllowed: access.allowed,
      );
      if (mounted) {
        await ref.read(notificationAccessProvider.notifier).refresh();
      }
    } catch (error) {
      debugPrint('PetLoop: could not ask for notifications: $error');
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_active) {
      ref.listen(notificationTapsProvider, (_, target) {
        if (target != null) _openWaitingTap();
      });
      ref.listen(petsGateProvider, (_, _) {
        _openWaitingTap();
        _maybeAsk();
      });
      ref.listen(somethingToRemindProvider, (_, something) {
        if (something) _maybeAsk();
      });
    }
    return widget.child;
  }
}
