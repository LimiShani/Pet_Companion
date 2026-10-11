import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../platform/session.dart';
import '../theme/app_theme.dart';
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

  AccessL10n get _l10n => context.accessL10n;
  String _category(String action) => switch (action.split(':').first) {
    'feature_catalog' => _l10n.categoryFeatureSettings,
    'access_groups' => _l10n.categoryGroups,
    'access_group_members' => _l10n.categoryGroupMembership,
    'user_capability_rules' => _l10n.categoryUserRules,
    'group_capability_rules' => _l10n.categoryGroupRules,
    'access_admins' => _l10n.categoryAdmins,
    'access_capabilities' => _l10n.categoryCapabilities,
    'vet_directory' => _l10n.categoryVetDirectory,
    _ => action,
  };

  String _actorLabel(AccessAuditEntry entry) =>
      entry.actorEmail ?? entry.actorId ?? _l10n.auditSystemActor;

  String _time(AccessAuditEntry entry) => DateFormat(
    'dd.MM.yyyy HH:mm:ss',
    Localizations.localeOf(context).languageCode,
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
    final l10n = _l10n;
    final close = context.l10n.commonClose;
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
                    '${_actorLabel(entry)}\n${_time(entry)}\n${entry.action}\n${l10n.auditEntryNumber(entry.id)}',
                  ),
                  if (entry.actorId != null) SelectableText(entry.actorId!),
                  const SizedBox(height: 16),
                  Text(l10n.auditBefore, style: AppText.sectionTitle),
                  SelectableText(
                    entry.before == null
                        ? l10n.auditNoPreviousValue
                        : json.convert(entry.before),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.auditAfter, style: AppText.sectionTitle),
                  SelectableText(
                    entry.after == null
                        ? l10n.auditRemoved
                        : json.convert(entry.after),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(close),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              ref.read(accessRepositoryProvider) is FakeAccessRepository
                  ? l10n.auditIntroDemo
                  : l10n.auditIntroSaved,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _actor,
              enabled: !_loading,
              onSubmitted: (_) => _apply(),
              decoration: InputDecoration(
                labelText: l10n.auditActorFilter,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _action ?? '',
              key: ValueKey(_action),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.auditActionType,
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(l10n.auditAllActions),
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
                        ? l10n.auditAnyDate
                        : '${DateFormat('dd.MM.yy').format(_dates!.start)} – ${DateFormat('dd.MM.yy').format(_dates!.end)}',
                  ),
                ),
                FilledButton(
                  onPressed: _loading ? null : _apply,
                  child: Text(l10n.auditSearch),
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
                  child: Text(l10n.auditClearFilters),
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
              Text(l10n.auditLoadFailed),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => _load(reset: _entries.isEmpty),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      Expanded(
        child: _entries.isEmpty && !_loading && !_failed
            ? Center(
                child: Text(l10n.auditEmpty),
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
                        child: Text(l10n.auditLoadOlder),
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
}
