/// Pure policy types shared by the application and its feature modules.
library;

enum AccessRule { inherit, allow, deny }

const capabilityCatalog = <String>[
  'pets.view',
  'pets.edit',
  'care.view',
  'care.edit',
  'health.records.view',
  'health.records.edit',
  'health.records.export',
  'health.schedule.view',
  'health.schedule.edit',
  'health.emergency.view',
  'health.emergency.edit',
  'health.emergency.export',
  'community.feed.view',
  'community.feed.post',
  'community.feed.edit',
  'community.chat.view',
  'community.chat.send',
  'community.guides.view',
  'community.moderate',
  'store.deals.view',
  'store.deals.share',
  'store.deals.edit',
  'budget.view',
  'budget.edit',
  'basket.view',
  'basket.edit',
  'firstdays.view',
  'firstdays.edit',
  'findvet.search',
  'findvet.admin',
  'access.admin',
];

String featureOf(String capability) => capability.split('.').first;

String? requiredView(String capability) {
  if (capability == 'access.admin' || capability == 'findvet.search') {
    return null;
  }
  if (capability == 'findvet.admin') return 'findvet.search';
  if (capability == 'community.moderate') return 'community.feed.view';
  if (capability.endsWith('.view')) return null;
  return '${capability.substring(0, capability.lastIndexOf('.'))}.view';
}

class AccessDecision {
  const AccessDecision(this.allowed, this.reason);
  final bool allowed;
  final String reason;
}

class AccessPolicy {
  AccessPolicy({
    required Map<String, bool> enabled,
    Map<String, AccessRule> individual = const {},
    List<Map<String, AccessRule>> groups = const [],
    Set<String> publicCapabilities = const {},
  }) : enabled = Map.unmodifiable(enabled),
       individual = Map.unmodifiable(individual),
       groups = List.unmodifiable(
         groups.map(Map<String, AccessRule>.unmodifiable),
       ),
       publicCapabilities = Set.unmodifiable(publicCapabilities);

  final Map<String, bool> enabled;
  final Map<String, AccessRule> individual;
  final List<Map<String, AccessRule>> groups;
  final Set<String> publicCapabilities;

  AccessDecision evaluate(String capability, {bool anonymous = false}) {
    if (!capabilityCatalog.contains(capability)) {
      return const AccessDecision(false, 'Unknown capability');
    }
    if (enabled[featureOf(capability)] != true) {
      return const AccessDecision(false, 'Feature disabled');
    }
    final prerequisite = requiredView(capability);
    if (prerequisite != null &&
        !evaluate(prerequisite, anonymous: anonymous).allowed) {
      return const AccessDecision(false, 'View access required');
    }
    if (anonymous) {
      return AccessDecision(
        publicCapabilities.contains(capability),
        'Public policy',
      );
    }
    final override = individual[capability] ?? AccessRule.inherit;
    if (override != AccessRule.inherit) {
      return AccessDecision(
        override == AccessRule.allow,
        'Individual override',
      );
    }
    final rules = groups.map((g) => g[capability] ?? AccessRule.inherit);
    if (rules.contains(AccessRule.deny)) {
      return const AccessDecision(false, 'Group deny');
    }
    if (rules.contains(AccessRule.allow)) {
      return const AccessDecision(true, 'Group allow');
    }
    return const AccessDecision(false, 'No grant');
  }
}

class AccessSnapshot {
  AccessSnapshot({
    required this.userId,
    required Iterable<String> allowed,
    this.revision = 0,
    Map<String, String> reasons = const {},
    Map<String, bool> enabled = const {},
  }) : allowed = Set.unmodifiable(allowed),
       reasons = Map.unmodifiable(reasons),
       enabled = Map.unmodifiable(enabled);

  final String? userId;
  final Set<String> allowed;
  final Map<String, String> reasons;
  final Map<String, bool> enabled;
  final int revision;

  bool can(String capability) => allowed.contains(capability);

  factory AccessSnapshot.fromJson(Map<String, dynamic> json) => AccessSnapshot(
    userId: json['user_id'] as String?,
    allowed: (json['allowed'] as List? ?? const []).cast<String>(),
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    reasons: Map<String, String>.from(json['reasons'] as Map? ?? const {}),
    enabled: Map<String, bool>.from(json['enabled'] as Map? ?? const {}),
  );
}
