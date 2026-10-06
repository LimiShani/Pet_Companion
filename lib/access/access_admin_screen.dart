import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../platform/session.dart';
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

class _AdministrationState extends ConsumerState<_Administration> {
  Map<String, dynamic>? _data;
  Object? _error;
  bool _busy = false;
  String? _user;
  String? _group;
  AccessSnapshot? _preview;
  int _request = 0;

  bool get _hebrew => Localizations.localeOf(context).languageCode == 'he';
  String _text(String en, String he) => _hebrew ? he : en;
  String _featureLabel(String id) => switch (id) {
    'pets' => _text('Pet profiles', 'פרופילי חיות'),
    'care' => _text('Daily care', 'טיפול יומי'),
    'health' => _text('Health', 'בריאות'),
    'health.records' => _text('Health records', 'רישומי בריאות'),
    'health.schedule' => _text('Health schedule', 'תזמון בריאות'),
    'health.emergency' => _text('Emergency tools', 'כלי חירום'),
    'community' => _text('Community', 'קהילה'),
    'community.feed' => _text('Community feed', 'פוסטים בקהילה'),
    'community.chat' => _text('Community chat', 'צ׳אט בקהילה'),
    'community.guides' => _text('Guides', 'מדריכים'),
    'store' || 'store.deals' => _text('Deals', 'מבצעים'),
    'budget' => _text('Budget', 'תקציב'),
    'basket' => _text('Basket', 'סל קניות'),
    'firstdays' => _text('First days', 'הימים הראשונים'),
    'findvet' => _text('Find a vet', 'חיפוש וטרינר'),
    _ => id,
  };
  String _capabilityLabel(String id) {
    final parts = id.split('.');
    final action = parts.removeLast();
    final label = switch (action) {
      'view' => _text('View', 'צפייה'),
      'edit' => _text('Edit', 'עריכה'),
      'export' => _text('Export', 'ייצוא'),
      'post' => _text('Post', 'פרסום'),
      'send' => _text('Send', 'שליחה'),
      'share' => _text('Share', 'שיתוף'),
      'search' => _text('Search', 'חיפוש'),
      'admin' => _text('Review directory', 'ניהול המדריך'),
      _ => action,
    };
    return '${_featureLabel(parts.join('.'))} · $label';
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
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addGroup() async {
    final controller = TextEditingController();
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text('New group', 'קבוצה חדשה')),
        content: TextField(
          controller: controller,
          maxLength: 80,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _text('Group name', 'שם הקבוצה'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_text('Cancel', 'ביטול')),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(_text('Create', 'יצירה')),
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
                    '${_preview?.can(capability) == true ? _text('Allowed', 'מותר') : _text('Blocked', 'חסום')} · ${_preview?.reasons[capability] ?? ''}',
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
                  child: Text(_text('Inherit', 'ירושה')),
                ),
                DropdownMenuItem(
                  value: 'allow',
                  child: Text(_text('Allow', 'אישור')),
                ),
                DropdownMenuItem(
                  value: 'deny',
                  child: Text(_text('Deny', 'חסימה')),
                ),
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
        decoration: InputDecoration(labelText: _text('User', 'משתמש')),
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
        Text(
          _text('Group membership', 'חברות בקבוצות'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
        Text(
          _text('Individual overrides', 'הרשאות אישיות'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
        label: Text(_text('New group', 'קבוצה חדשה')),
      ),
      DropdownButtonFormField<String>(
        initialValue: _group,
        isExpanded: true,
        decoration: InputDecoration(labelText: _text('Group', 'קבוצה')),
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
          _text(
            'A disabled feature is blocked for everyone. Individual rules override group rules; group denial wins over group allowance.',
            'תכונה כבויה חסומה לכולם. הרשאות אישיות גוברות על קבוצות; חסימה בקבוצה גוברת על אישור בקבוצה.',
          ),
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
            title: Text(_text('Public vet search', 'חיפוש וטרינר לציבור')),
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
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: Text(_text('Feature access', 'הרשאות לתכונות')),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: _text('Users', 'משתמשים')),
            Tab(text: _text('Groups', 'קבוצות')),
            Tab(text: _text('Features', 'תכונות')),
            Tab(text: _text('Audit', 'היסטוריה')),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _text(
                  'Could not update access. Check the connection and that migration 0014 has been applied.',
                  'עדכון ההרשאות נכשל. יש לבדוק את החיבור ואת התקנת עדכון מסד הנתונים 0014.',
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
                            child: Text(_text('Retry', 'נסו שוב')),
                          ),
                  )
                : TabBarView(
                    children: [
                      _users(),
                      _groups(),
                      _features(),
                      AccessAuditView(reloadToken: _request),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
