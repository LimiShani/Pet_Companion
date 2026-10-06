import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../platform/session.dart';
import 'access_provider.dart';
import 'feature_gate.dart';

class AccessAuditView extends ConsumerStatefulWidget {
  const AccessAuditView({super.key, required this.reloadToken});
  final int reloadToken;

  @override
  ConsumerState<AccessAuditView> createState() => _AccessAuditViewState();
}

class _AccessAuditViewState extends ConsumerState<AccessAuditView> {
  final _actor = TextEditingController();
  final _entries = <AccessAuditEntry>[];
  AccessAuditQuery _query = const AccessAuditQuery();
  String? _action;
  DateTimeRange? _dates;
  int? _next;
  bool _loading = false;
  bool _failed = false;
  int _request = 0;

  bool get _hebrew => Localizations.localeOf(context).languageCode == 'he';
  String _text(String en, String he) => _hebrew ? he : en;
  String _category(String action) => switch (action.split(':').first) {
    'feature_catalog' => _text('Feature settings', 'הגדרות תכונות'),
    'access_groups' => _text('Groups', 'קבוצות'),
    'access_group_members' => _text('Group membership', 'חברות בקבוצות'),
    'user_capability_rules' => _text('Individual permissions', 'הרשאות אישיות'),
    'group_capability_rules' => _text('Group permissions', 'הרשאות קבוצתיות'),
    'access_admins' => _text('Administrators', 'מנהלי הרשאות'),
    'access_capabilities' => _text('Capability catalog', 'קטלוג הרשאות'),
    'vet_directory' => _text('Vet directory review', 'סקירת מדריך וטרינרים'),
    _ => action,
  };

  String _actorLabel(AccessAuditEntry entry) =>
      entry.actorEmail ??
      entry.actorId ??
      _text('System / database owner', 'מערכת / בעל מסד הנתונים');

  String _time(AccessAuditEntry entry) => DateFormat(
    'dd.MM.yyyy HH:mm:ss',
    _hebrew ? 'he' : 'en',
  ).format(entry.createdAt.toLocal());

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) _load(reset: true);
    });
  }

  @override
  void didUpdateWidget(covariant AccessAuditView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      Future.microtask(() {
        if (mounted) _load(reset: true);
      });
    }
  }

  @override
  void dispose() {
    _actor.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final request = ++_request;
    final ticket = SessionTicket.widget(ref);
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _entries.clear();
        _next = null;
      }
    });
    try {
      if (!ref.read(capabilityProvider('access.admin'))) {
        throw const FeatureDenied('access.admin');
      }
      final page = await ref
          .read(accessRepositoryProvider)
          .history(_query, beforeId: reset ? null : _next);
      if (!mounted || !ticket.current || request != _request) return;
      setState(() {
        _entries.addAll(page.entries);
        _next = page.nextCursor;
      });
    } catch (_) {
      if (mounted && ticket.current && request == _request) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && ticket.current && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  void _apply() {
    final end = _dates?.end;
    _query = AccessAuditQuery(
      actor: _actor.text,
      action: _action,
      from: _dates?.start,
      until: end == null ? null : DateTime(end.year, end.month, end.day + 1),
    );
    _load(reset: true);
  }

  Future<void> _chooseDates() async {
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dates,
    );
    if (!mounted || dates == null) return;
    setState(() => _dates = dates);
  }

  void _details(AccessAuditEntry entry) {
    const json = JsonEncoder.withIndent('  ');
    showDialog<void>(
      context: context,
      builder: (context) => FeatureGate(
        capability: 'access.admin',
        builder: (context) => AlertDialog(
          title: Text(_category(entry.action)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    '${_actorLabel(entry)}\n${_time(entry)}\n${entry.action}\n${_text('Entry', 'רשומה')} #${entry.id}',
                  ),
                  if (entry.actorId != null) SelectableText(entry.actorId!),
                  const SizedBox(height: 16),
                  Text(
                    _text('Before', 'לפני'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SelectableText(
                    entry.before == null
                        ? _text('No previous value', 'אין ערך קודם')
                        : json.convert(entry.before),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _text('After', 'אחרי'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SelectableText(
                    entry.after == null
                        ? _text('Removed', 'הוסר')
                        : json.convert(entry.after),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_text('Close', 'סגירה')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              _text(
                ref.read(accessRepositoryProvider) is FakeAccessRepository
                    ? 'Demo history resets when the app closes. Tap an entry for details.'
                    : 'Saved administration history. Tap an entry for details.',
                ref.read(accessRepositoryProvider) is FakeAccessRepository
                    ? 'היסטוריית ההדגמה מתאפסת בסגירת האפליקציה. לחצו על רשומה לפרטים.'
                    : 'היסטוריית ניהול שמורה. לחצו על רשומה לפרטים.',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _actor,
              enabled: !_loading,
              onSubmitted: (_) => _apply(),
              decoration: InputDecoration(
                labelText: _text(
                  'Administrator email or ID',
                  'דוא״ל או מזהה מנהל',
                ),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _action ?? '',
              key: ValueKey(_action),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _text('Action type', 'סוג פעולה'),
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(_text('All actions', 'כל הפעולות')),
                ),
                for (final action in [
                  'feature_catalog',
                  'access_groups',
                  'access_group_members',
                  'user_capability_rules',
                  'group_capability_rules',
                  'access_admins',
                  'access_capabilities',
                  'vet_directory',
                ])
                  DropdownMenuItem(
                    value: action,
                    child: Text(_category(action)),
                  ),
              ],
              onChanged: _loading
                  ? null
                  : (value) =>
                        setState(() => _action = value == '' ? null : value),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _loading ? null : _chooseDates,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _dates == null
                        ? _text('Any date', 'כל תאריך')
                        : '${DateFormat('dd.MM.yy').format(_dates!.start)} – ${DateFormat('dd.MM.yy').format(_dates!.end)}',
                  ),
                ),
                FilledButton(
                  onPressed: _loading ? null : _apply,
                  child: Text(_text('Search history', 'חיפוש בהיסטוריה')),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _actor.clear();
                          setState(() {
                            _action = null;
                            _dates = null;
                          });
                          _apply();
                        },
                  child: Text(_text('Clear filters', 'ניקוי מסננים')),
                ),
              ],
            ),
          ],
        ),
      ),
      if (_loading) const LinearProgressIndicator(),
      if (_failed)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text(
                _text(
                  'Could not load saved history. Check the connection and migration 0017.',
                  'טעינת ההיסטוריה נכשלה. בדקו את החיבור ואת עדכון מסד הנתונים 0017.',
                ),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => _load(reset: _entries.isEmpty),
                child: Text(_text('Retry', 'נסו שוב')),
              ),
            ],
          ),
        ),
      Expanded(
        child: _entries.isEmpty && !_loading && !_failed
            ? Center(
                child: Text(
                  _text(
                    'No administration actions found.',
                    'לא נמצאו פעולות ניהול.',
                  ),
                ),
              )
            : ListView.builder(
                key: const Key('access-audit-list'),
                itemCount: _entries.length + (_next == null ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index == _entries.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton(
                        onPressed: _loading ? null : () => _load(reset: false),
                        child: Text(
                          _text('Load older actions', 'טעינת פעולות קודמות'),
                        ),
                      ),
                    );
                  }
                  final entry = _entries[index];
                  final value =
                      entry.after ?? entry.before ?? const <String, dynamic>{};
                  final target = [
                    value['name'],
                    value['capability'],
                    value['target_id'] ??
                        value['user_id'] ??
                        value['group_id'] ??
                        value['id'],
                  ].where((v) => v != null).join(' · ');
                  return ListTile(
                    title: Text(_category(entry.action)),
                    subtitle: Text(
                      '${_actorLabel(entry)} · ${_time(entry)}${target.isEmpty ? '' : '\n$target'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _details(entry),
                  );
                },
              ),
      ),
    ],
  );
}
