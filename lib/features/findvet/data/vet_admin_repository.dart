import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// An item of the directory review queue, opened by the weekly check (or
/// by a heuristic match) for a person to decide.
class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.kind,
    required this.severity,
    required this.createdAt,
    this.facilityId,
    this.facilityName,
    this.details = const {},
  });

  final String id;
  final String? facilityId;
  final String? facilityName;

  /// 'emergency_evidence_missing', 'phone_conflict', 'closure',
  /// 'source_unreachable', 'new_emergency_evidence', 'verify_coordinates',
  /// 'link_candidate'... (new kinds show with their raw name).
  final String kind;

  /// 'high', 'medium' or 'low'.
  final String severity;
  final Map<String, Object?> details;
  final DateTime createdAt;

  factory ReviewItem.fromJson(Map json) => ReviewItem(
    id: '${json['id']}',
    facilityId: json['facility_id'] as String?,
    facilityName: json['facility_name'] as String?,
    kind: '${json['kind']}',
    severity: '${json['severity']}',
    details: json['details'] is Map ? Map<String, Object?>.from(json['details'] as Map) : const {},
    createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// One sourced claim of a facility, as admins see it.
class AdminClaim {
  const AdminClaim({
    required this.key,
    required this.value,
    required this.status,
    this.sourceUrl,
    this.sourceKind,
    this.checkedAt,
    this.confirmedAt,
  });

  final String key;
  final Object? value;

  /// 'current', 'unverified', 'conflict' or 'withdrawn'.
  final String status;
  final String? sourceUrl;
  final String? sourceKind;
  final DateTime? checkedAt;
  final DateTime? confirmedAt;

  factory AdminClaim.fromJson(Map json) => AdminClaim(
    key: '${json['key']}',
    value: json['value'],
    status: '${json['status']}',
    sourceUrl: json['sourceUrl'] as String?,
    sourceKind: json['sourceKind'] as String?,
    checkedAt: DateTime.tryParse('${json['checkedAt']}'),
    confirmedAt: DateTime.tryParse('${json['confirmedAt']}'),
  );

  /// [value] as one line of text.
  String get valueText {
    final v = value;
    if (v is List) return v.join(', ');
    if (v is Map) return v.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return v == null ? '' : '$v';
  }
}

/// A facility of our directory, whatever its review status.
class AdminFacility {
  const AdminFacility({
    required this.id,
    required this.name,
    required this.reviewStatus,
    this.nameHe,
    this.address,
    this.city,
    this.phone,
    this.website,
    this.facilityType,
    this.lastCheckedAt,
    this.lastConfirmedAt,
    this.claims = const [],
  });

  final String id;
  final String name;
  final String? nameHe;
  final String? address;
  final String? city;
  final String? phone;
  final String? website;
  final String? facilityType;

  /// 'pending', 'approved', 'needs_review' or 'withdrawn'.
  final String reviewStatus;
  final DateTime? lastCheckedAt;
  final DateTime? lastConfirmedAt;
  final List<AdminClaim> claims;

  AdminClaim? claim(String key) {
    for (final c in claims) {
      if (c.key == key) return c;
    }
    return null;
  }

  factory AdminFacility.fromJson(Map json) => AdminFacility(
    id: '${json['id']}',
    name: '${json['name']}',
    nameHe: json['name_he'] as String?,
    address: json['address'] as String?,
    city: json['city'] as String?,
    phone: json['phone'] as String?,
    website: json['website'] as String?,
    facilityType: json['facility_type'] as String?,
    reviewStatus: '${json['review_status']}',
    lastCheckedAt: DateTime.tryParse('${json['last_checked_at']}'),
    lastConfirmedAt: DateTime.tryParse('${json['last_confirmed_at']}'),
    claims: [
      for (final c in (json['claims'] as List? ?? const []))
        if (c is Map) AdminClaim.fromJson(c),
    ],
  );
}

/// The directory review actions. Each one is checked on the server: an
/// account that is not a directory admin is refused, whatever the app
/// shows.
abstract class VetAdminRepository {
  Future<bool> isAdmin();
  Future<List<ReviewItem>> reviewItems();
  Future<List<AdminFacility>> facilities();

  /// [action]: 'resolve' or 'dismiss'.
  Future<void> resolve(String itemId, String action, String note);

  /// [status]: 'approved', 'needs_review' or 'withdrawn'.
  Future<void> setStatus(String facilityId, String status, String note);

  /// Records a corrected or confirmed claim with where it was read.
  Future<void> setClaim(
    String facilityId, {
    required String key,
    required Object value,
    required String sourceUrl,
    required String sourceKind,
    required String note,
  });

  Future<void> withdrawClaim(String facilityId, String key, String note);
}

class SupabaseVetAdminRepository implements VetAdminRepository {
  SupabaseVetAdminRepository(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<bool> isAdmin() async {
    if (_client.auth.currentUser == null) return false;
    return await _client.rpc<bool>('vet_is_admin') == true;
  }

  @override
  Future<List<ReviewItem>> reviewItems() async {
    final rows = await _client.rpc<List<dynamic>>('vet_admin_review_items');
    return [for (final row in rows) ReviewItem.fromJson(row as Map)];
  }

  @override
  Future<List<AdminFacility>> facilities() async {
    final rows = await _client.rpc<List<dynamic>>('vet_admin_facilities');
    return [for (final row in rows) AdminFacility.fromJson(row as Map)];
  }

  @override
  Future<void> resolve(String itemId, String action, String note) =>
      _client.rpc<void>('vet_admin_resolve', params: {'p_item': itemId, 'p_action': action, 'p_note': note});

  @override
  Future<void> setStatus(String facilityId, String status, String note) => _client.rpc<void>(
    'vet_admin_set_status',
    params: {'p_facility': facilityId, 'p_status': status, 'p_note': note},
  );

  @override
  Future<void> setClaim(
    String facilityId, {
    required String key,
    required Object value,
    required String sourceUrl,
    required String sourceKind,
    required String note,
  }) => _client.rpc<void>(
    'vet_admin_set_claim',
    params: {
      'p_facility': facilityId,
      'p_key': key,
      'p_value': value,
      'p_source_url': sourceUrl,
      'p_source_kind': sourceKind,
      'p_note': note,
    },
  );

  @override
  Future<void> withdrawClaim(String facilityId, String key, String note) => _client.rpc<void>(
    'vet_admin_withdraw_claim',
    params: {'p_facility': facilityId, 'p_key': key, 'p_note': note},
  );
}

/// In memory, for the demo and the tests. The demo account is an admin so
/// the review page can be tried without a backend; its data is made up.
class FakeVetAdminRepository implements VetAdminRepository {
  FakeVetAdminRepository({this.admin = true, List<ReviewItem>? items, List<AdminFacility>? facilities})
    : items = items ?? _demoItems(),
      facilityList = facilities ?? _demoFacilities();

  bool admin;
  final List<ReviewItem> items;
  final List<AdminFacility> facilityList;

  /// Every action taken, as "action:target:detail" (what tests check).
  final actions = <String>[];

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<List<ReviewItem>> reviewItems() async => List.of(items);

  @override
  Future<List<AdminFacility>> facilities() async => List.of(facilityList);

  @override
  Future<void> resolve(String itemId, String action, String note) async {
    actions.add('$action:$itemId:$note');
    items.removeWhere((i) => i.id == itemId);
  }

  @override
  Future<void> setStatus(String facilityId, String status, String note) async {
    actions.add('status:$facilityId:$status');
    final i = facilityList.indexWhere((f) => f.id == facilityId);
    if (i < 0) return;
    final f = facilityList[i];
    facilityList[i] = AdminFacility(
      id: f.id,
      name: f.name,
      nameHe: f.nameHe,
      address: f.address,
      city: f.city,
      phone: f.phone,
      website: f.website,
      facilityType: f.facilityType,
      reviewStatus: status,
      lastCheckedAt: f.lastCheckedAt,
      lastConfirmedAt: status == 'approved' ? DateTime.now() : f.lastConfirmedAt,
      claims: f.claims,
    );
  }

  @override
  Future<void> setClaim(
    String facilityId, {
    required String key,
    required Object value,
    required String sourceUrl,
    required String sourceKind,
    required String note,
  }) async {
    actions.add('claim:$facilityId:$key=$value@$sourceUrl');
    _replaceClaim(
      facilityId,
      key,
      AdminClaim(
        key: key,
        value: value,
        status: 'current',
        sourceUrl: sourceUrl,
        sourceKind: sourceKind,
        checkedAt: DateTime.now(),
        confirmedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> withdrawClaim(String facilityId, String key, String note) async {
    actions.add('withdraw:$facilityId:$key');
    final f = facilityList.firstWhere((f) => f.id == facilityId);
    final old = f.claim(key);
    if (old == null) return;
    _replaceClaim(
      facilityId,
      key,
      AdminClaim(key: key, value: old.value, status: 'withdrawn', sourceUrl: old.sourceUrl, sourceKind: old.sourceKind),
    );
  }

  void _replaceClaim(String facilityId, String key, AdminClaim claim) {
    final i = facilityList.indexWhere((f) => f.id == facilityId);
    if (i < 0) return;
    final f = facilityList[i];
    facilityList[i] = AdminFacility(
      id: f.id,
      name: f.name,
      nameHe: f.nameHe,
      address: f.address,
      city: f.city,
      phone: f.phone,
      website: f.website,
      facilityType: f.facilityType,
      reviewStatus: f.reviewStatus,
      lastCheckedAt: f.lastCheckedAt,
      lastConfirmedAt: f.lastConfirmedAt,
      claims: [...f.claims.where((c) => c.key != key), claim],
    );
  }

  static List<ReviewItem> _demoItems() => [
    ReviewItem(
      id: 'demo-item-1',
      facilityId: 'demo-4',
      facilityName: 'Demo Night Clinic',
      kind: 'emergency_evidence_missing',
      severity: 'high',
      details: const {'sourceUrl': 'https://example.org/petloop-demo/night', 'httpStatus': 404},
      createdAt: DateTime(2025, 6, 9),
    ),
    ReviewItem(
      id: 'demo-item-2',
      facilityId: 'demo-2',
      facilityName: 'Demo Veterinary Hospital',
      kind: 'phone_conflict',
      severity: 'medium',
      details: const {'stored': '000-0000002', 'found': ['000-0000009']},
      createdAt: DateTime(2025, 6, 9),
    ),
  ];

  static List<AdminFacility> _demoFacilities() => [
    const AdminFacility(
      id: 'demo-2',
      name: 'Demo Veterinary Hospital',
      address: 'Demo road 20',
      phone: '000-0000002',
      facilityType: 'hospital',
      reviewStatus: 'approved',
      claims: [
        AdminClaim(
          key: 'emergency',
          value: {'schedule': '24/7'},
          status: 'current',
          sourceUrl: 'https://example.org/petloop-demo/hospital',
          sourceKind: 'facility_site',
        ),
      ],
    ),
    const AdminFacility(
      id: 'demo-4',
      name: 'Demo Night Clinic',
      address: 'Demo lane 4',
      phone: '000-0000004',
      facilityType: 'clinic',
      reviewStatus: 'needs_review',
      claims: [
        AdminClaim(
          key: 'emergency',
          value: {'schedule': 'Nights 20:00-08:00'},
          status: 'unverified',
          sourceUrl: 'https://example.org/petloop-demo/night',
          sourceKind: 'facility_site',
        ),
      ],
    ),
    const AdminFacility(
      id: 'demo-5',
      name: 'Demo Pending Hospital',
      facilityType: 'hospital',
      reviewStatus: 'pending',
    ),
  ];
}
