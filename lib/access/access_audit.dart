/// Server-owned, append-only administration history.
class AccessAuditEntry {
  const AccessAuditEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    this.actorId,
    this.actorEmail,
    this.before,
    this.after,
  });

  final int id;
  final String action;
  final DateTime createdAt;
  final String? actorId;
  final String? actorEmail;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  factory AccessAuditEntry.fromJson(Map<String, dynamic> json) =>
      AccessAuditEntry(
        id: (json['id'] as num).toInt(),
        action: json['action'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        actorId: json['actor_id'] as String?,
        actorEmail: json['actor_email'] as String?,
        before: json['before_value'] is Map
            ? Map<String, dynamic>.from(json['before_value'] as Map)
            : null,
        after: json['after_value'] is Map
            ? Map<String, dynamic>.from(json['after_value'] as Map)
            : null,
      );
}

class AccessAuditQuery {
  const AccessAuditQuery({this.actor = '', this.action, this.from, this.until});
  final String actor;
  final String? action;
  final DateTime? from;

  /// Exclusive end, so a selected local end date includes the entire day.
  final DateTime? until;

  Map<String, dynamic> parameters({int? beforeId, int limit = 50}) => {
    'p_before_id': beforeId,
    'p_limit': limit,
    'p_actor': actor.trim().isEmpty ? null : actor.trim(),
    'p_action': action,
    'p_from': from?.toUtc().toIso8601String(),
    'p_until': until?.toUtc().toIso8601String(),
  };

  bool matches(AccessAuditEntry entry) =>
      (actor.trim().isEmpty ||
          '${entry.actorEmail ?? ''} ${entry.actorId ?? ''}'
              .toLowerCase()
              .contains(actor.trim().toLowerCase())) &&
      (action == null || entry.action.split(':').first == action) &&
      (from == null || !entry.createdAt.isBefore(from!)) &&
      (until == null || entry.createdAt.isBefore(until!));
}

class AccessAuditPage {
  const AccessAuditPage(this.entries, this.nextCursor);
  final List<AccessAuditEntry> entries;
  final int? nextCursor;

  factory AccessAuditPage.fromJson(Map<String, dynamic> json) =>
      AccessAuditPage(
        (json['entries'] as List)
            .map(
              (row) => AccessAuditEntry.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(),
        (json['next_cursor'] as num?)?.toInt(),
      );
}
