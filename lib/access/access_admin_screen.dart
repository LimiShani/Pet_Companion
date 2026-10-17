import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import '../platform/session.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/coral_header.dart';
import '../widgets/coral_segmented_control.dart';
import 'access_provider.dart';
import 'access_audit_view.dart';
import 'feature_gate.dart';

void openAccessAdministration(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => const AccessAdministrationScreen(),
      ),
    );

class AccessAdministrationScreen extends StatelessWidget {
  const AccessAdministrationScreen({super.key});
  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'access.admin',
    builder: (_) => const _Administration(),
  );
}

class _Administration extends ConsumerStatefulWidget {
  const _Administration();
  @override
  ConsumerState<_Administration> createState() => _AdministrationState();
}

enum _Section { users, groups, features, audit }

class _AdministrationState extends ConsumerState<_Administration> {
  Map<String, dynamic>? _data;
  Object? _error;
  bool _busy = false;
  String? _user;
  String? _group;
  AccessSnapshot? _preview;
  int _request = 0;
  _Section _section = _Section.users;

  AccessL10n get _l10n => context.accessL10n;
  String _featureLabel(String id) => switch (id) {
    'pets' => _l10n.featurePets,
    'care' => _l10n.featureCare,
    'health' => _l10n.featureHealth,
    'health.records' => _l10n.featureHealthRecords,
    'health.schedule' => _l10n.featureHealthSchedule,
    'health.emergency' => _l10n.featureHealthEmergency,
    'community' => _l10n.featureCommunity,
    'community.feed' => _l10n.featureCommunityFeed,
    'community.chat' => _l10n.featureCommunityChat,
    'community.guides' => _l10n.featureCommunityGuides,
    'community.parks' => _l10n.featureCommunityParks,
    'community.meetups' => _l10n.featureCommunityMeetups,
    'community.hazards' => _l10n.featureCommunityHazards,
    'store' || 'store.deals' => _l10n.featureDeals,
    'budget' => _l10n.featureBudget,
    'basket' => _l10n.featureBasket,
    'firstdays' => _l10n.featureFirstDays,
    'findvet' => _l10n.featureFindVet,
    'household' => _l10n.featureHousehold,
    'safety' => _l10n.featureSafety,
    _ => id,
  };
  String _capabilityLabel(String id) {
    final parts = id.split('.');
    final action = parts.removeLast();
    final label = switch (action) {
      'view' => _l10n.actionView,
      'edit' => _l10n.actionEdit,
      'export' => _l10n.actionExport,
      'post' => _l10n.actionPost,
      'send' => _l10n.actionSend,
      'share' => _l10n.actionShare,
      'search' => _l10n.actionSearch,
      'admin' => _l10n.actionAdmin,
      'moderate' => _l10n.actionModerate,
      'suggest' => _l10n.actionSuggest,
      'review' => _l10n.actionReview,
      'private' => _l10n.actionPrivate,
      'lists' => _l10n.actionLists,
      'lost' => _l10n.actionLost,
      _ => action,
    };
    return _l10n.capabilityLabel(_featureLabel(parts.join('.')), label);
  }

  List<Map<String, dynamic>> _rows(String key) => ((_data?[key] as List?) ?? [])
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final request = ++_request;
    final ticket = SessionTicket.widget(ref);
    try {
      if (!ref.read(capabilityProvider('access.admin'))) {
        throw const FeatureDenied('access.admin');
      }
      final repository = ref.read(accessRepositoryProvider);
      final data = await repository.administration();
      final preview = _user == null ? null : await repository.preview(_user!);
      if (!mounted || !ticket.current || request != _request) return;
      setState(() {
        _data = data;
        _preview = preview;
        _error = null;
      });
    } catch (error) {
      _report(error);
      if (mounted && ticket.current && request == _request) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _change(String action, Map<String, dynamic> values) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ticket = SessionTicket.widget(ref);
      if (!ref.read(capabilityProvider('access.admin'))) {
        throw const FeatureDenied('access.admin');
      }
      await ref.read(accessRepositoryProvider).change(action, values);
      ticket.check();
      await ref.read(accessProvider.notifier).refresh();
      if (mounted) await _load();
    } catch (error) {
      _report(error);
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The screen only says the settings could not be loaded; the cause
  /// (usually the connection, or migration 0014 not applied) goes to the
  /// log.
  void _report(Object error) => debugPrint(
    'Feature access administration failed (is migration 0014 applied?): '
    '$error',
  );

  Future<void> _addGroup() async {
    final l10n = _l10n;
    final cancel = context.l10n.commonCancel;
    final controller = TextEditingController();
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newGroup),
        content: TextField(
          controller: controller,
          maxLength: 80,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.groupName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
    final name = await Navigator.of(context, rootNavigator: true).push(route);
    route.completed.then((_) => controller.dispose());
    if (name != null) {
      await _change('group', {'id': const Uuid().v4(), 'name': name});
    }
  }

  Widget _rules({required String kind, required String id}) {
    final l10n = _l10n;
    final rows = _rows(kind == 'user' ? 'user_rules' : 'group_rules');
    final key = '${kind}_id';
    return Column(
      children: [
        for (final capability in capabilityCatalog.where(
          (c) => c != 'access.admin',
        ))
          ListTile(
            title: Text(_capabilityLabel(capability)),
            subtitle: kind == 'user'
                ? Text(
                    l10n.ruleSummary(
                      _preview?.can(capability) == true
                          ? l10n.allowed
                          : l10n.blocked,
                      _preview?.reasons[capability] ?? '',
                    ),
                  )
                : null,
            trailing: DropdownButton<String>(
              value:
                  rows
                          .where(
                            (r) =>
                                r[key] == id && r['capability'] == capability,
                          )
                          .firstOrNull?['allowed'] ==
                      true
                  ? 'allow'
                  : rows
                            .where(
                              (r) =>
                                  r[key] == id && r['capability'] == capability,
                            )
                            .firstOrNull?['allowed'] ==
                        false
                  ? 'deny'
                  : 'inherit',
              items: [
                DropdownMenuItem(
                  value: 'inherit',
                  child: Text(l10n.ruleInherit),
                ),
                DropdownMenuItem(value: 'allow', child: Text(l10n.ruleAllow)),
                DropdownMenuItem(value: 'deny', child: Text(l10n.ruleDeny)),
              ],
              onChanged: _busy
                  ? null
                  : (value) => _change('${kind}_rule', {
                      key: id,
                      'capability': capability,
                      'allowed': value == 'inherit' ? null : value == 'allow',
                    }),
            ),
          ),
      ],
    );
  }

  Widget _users() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      DropdownButtonFormField<String>(
        initialValue: _user,
        isExpanded: true,
        decoration: InputDecoration(labelText: _l10n.user),
        items: [
          for (final user in _rows('users'))
            DropdownMenuItem(
              value: user['id'] as String,
              child: Text(
                user['email'] as String? ?? user['id'] as String,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: _busy
            ? null
            : (id) {
                setState(() {
                  _user = id;
                  _preview = null;
                });
                _load();
              },
      ),
      if (_user != null) ...[
        const SizedBox(height: 16),
        Text(_l10n.groupMembership, style: AppText.sectionTitle),
        for (final group in _rows('groups'))
          CheckboxListTile(
            title: Text(group['name'] as String),
            value: _rows(
              'members',
            ).any((r) => r['group_id'] == group['id'] && r['user_id'] == _user),
            onChanged: _busy
                ? null
                : (member) => _change('member', {
                    'group_id': group['id'],
                    'user_id': _user,
                    'member': member,
                  }),
          ),
        Text(_l10n.individualOverrides, style: AppText.sectionTitle),
        _rules(kind: 'user', id: _user!),
      ],
    ],
  );

  Widget _groups() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      OutlinedButton.icon(
        onPressed: _busy ? null : _addGroup,
        icon: const Icon(Icons.group_add_outlined),
        label: Text(_l10n.newGroup),
      ),
      DropdownButtonFormField<String>(
        initialValue: _group,
        isExpanded: true,
        decoration: InputDecoration(labelText: _l10n.group),
        items: [
          for (final group in _rows('groups'))
            DropdownMenuItem(
              value: group['id'] as String,
              child: Text(group['name'] as String),
            ),
        ],
        onChanged: _busy ? null : (id) => setState(() => _group = id),
      ),
      if (_group != null) _rules(kind: 'group', id: _group!),
    ],
  );

  Widget _features() => ListView(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _l10n.featuresNote,
          style: AppText.body.copyWith(color: AppColors.brown),
        ),
      ),
      for (final feature in _rows(
        'features',
      ).where((f) => f['id'] != 'access')) ...[
        SwitchListTile(
          title: Text(_featureLabel(feature['id'] as String)),
          value: feature['enabled'] == true,
          onChanged: _busy
              ? null
              : (value) =>
                    _change('feature', {'id': feature['id'], 'enabled': value}),
        ),
        if (feature['id'] == 'findvet')
          SwitchListTile(
            title: Text(_l10n.publicVetSearch),
            value: feature['public_enabled'] == true,
            onChanged: _busy
                ? null
                : (value) => _change('feature', {
                    'id': 'findvet',
                    'enabled': feature['enabled'],
                    'public_enabled': value,
                  }),
          ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          CoralHeader(
            title: l10n.title,
            showBack: true,
            actions: [
              CoralHeaderAction(
                icon: Icons.refresh_rounded,
                tooltip: l10n.refresh,
                onPressed: _busy ? null : _load,
              ),
            ],
            bottom: CoralSegmentedControl(
              labels: [
                l10n.tabUsers,
                l10n.tabGroups,
                l10n.tabFeatures,
                l10n.tabAudit,
              ],
              selectedIndex: _section.index,
              onChanged: (index) =>
                  setState(() => _section = _Section.values[index]),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.loadFailed,
                style: AppText.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _data == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : TextButton(
                            onPressed: _load,
                            child: Text(l10n.retry),
                          ),
                  )
                : switch (_section) {
                    _Section.users => _users(),
                    _Section.groups => _groups(),
                    _Section.features => _features(),
                    _Section.audit => AccessAuditView(reloadToken: _request),
                  },
          ),
        ],
      ),
    );
  }
}
