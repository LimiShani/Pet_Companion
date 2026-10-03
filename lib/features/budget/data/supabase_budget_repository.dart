import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import 'budget_models.dart';
import 'budget_repository.dart';

typedef Row = Map<String, dynamic>;

/// [BudgetRepository] on the `expenses` and `basket_items` tables of
/// `supabase/migrations/0010_budget_basket.sql`. Row level security keeps
/// every row to its owner; `owner_id` is filled in by the database.
class SupabaseBudgetRepository implements BudgetRepository {
  SupabaseBudgetRepository(this._client);

  final sb.SupabaseClient _client;

  static const _expenses = 'expenses';
  static const _basket = 'basket_items';

  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  static void _checkPet(String? petId) {
    if (petId != null && !_uuid.hasMatch(petId)) throw const BudgetException(BudgetFailure.petNotStored);
  }

  @override
  Future<List<Expense>> fetchExpenses() => _guard(() async {
    final rows = await _client.from(_expenses).select().order('spent_on', ascending: false);
    return [for (final row in rows) expenseFromRow(row)];
  });

  @override
  Future<Expense> saveExpense(Expense expense) => _guard(() async {
    _checkPet(expense.petId);
    final row = expenseToRow(expense);
    final Row saved;
    if (expense.isNew) {
      saved = await _client.from(_expenses).insert(row).select().single();
    } else {
      final rows = await _client.from(_expenses).update(row).eq('id', expense.id).select();
      if (rows.isEmpty) throw const BudgetException(BudgetFailure.gone);
      saved = rows.first;
    }
    return expenseFromRow(saved);
  });

  @override
  Future<void> deleteExpense(String id) => _guard(() async {
    await _client.from(_expenses).delete().eq('id', id);
  });

  @override
  Future<List<BasketItem>> fetchBasket() => _guard(() async {
    final rows = await _client.from(_basket).select().order('created_at');
    return [for (final row in rows) basketItemFromRow(row)];
  });

  @override
  Future<BasketItem> saveBasketItem(BasketItem item) => _guard(() async {
    _checkPet(item.petId);
    final row = basketItemToRow(item);
    final Row saved;
    if (item.isNew) {
      saved = await _client.from(_basket).insert(row).select().single();
    } else {
      final rows = await _client.from(_basket).update(row).eq('id', item.id).select();
      if (rows.isEmpty) throw const BudgetException(BudgetFailure.gone);
      saved = rows.first;
    }
    return basketItemFromRow(saved);
  });

  @override
  Future<void> deleteBasketItem(String id) => _guard(() async {
    await _client.from(_basket).delete().eq('id', id);
  });

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on BudgetException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == '42501' || message.contains('row-level security')) {
        throw BudgetException(BudgetFailure.notAllowed, e.message);
      }
      if (e.code == 'PGRST301' || message.contains('jwt')) throw BudgetException(BudgetFailure.sessionEnded, e.message);
      if (e.code == '23514' || e.code == '22P02') throw BudgetException(BudgetFailure.invalid, e.message);
      if (e.code == '23503') throw BudgetException(BudgetFailure.gone, e.message);
      // Undefined table or column: the migration has not been run yet.
      if (e.code == '42P01' || e.code == 'PGRST205' || e.code == '42703' || e.code == 'PGRST204') {
        throw BudgetException(BudgetFailure.needsUpdate, e.message);
      }
      throw BudgetException(BudgetFailure.unknown, e.message);
    } catch (e) {
      throw BudgetException(BudgetFailure.offline, '$e');
    }
  }
}

double? _number(Object? value) => (value as num?)?.toDouble();

DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Expense expenseFromRow(Row row) => Expense(
  id: row['id'] as String,
  petId: row['pet_id'] as String?,
  amount: _number(row['amount']) ?? 0,
  currency: (row['currency'] as String?) ?? AppConfig.defaultCurrency,
  category: ExpenseCategory.fromDb(row['category'] as String?),
  spentOn: _date(row['spent_on'])!,
  note: (row['note'] as String?) ?? '',
  frequency: ExpenseFrequency.fromDb(row['frequency'] as String?),
  source: ExpenseSource.fromDb(row['source'] as String?),
  basketItemId: row['basket_item_id'] as String?,
  endedOn: _date(row['ended_on']),
);

Row expenseToRow(Expense e) => {
  'pet_id': e.petId,
  'amount': e.amount,
  'currency': e.currency,
  'category': e.category.dbValue,
  'spent_on': _day(e.spentOn),
  'note': e.note,
  'frequency': e.frequency.dbValue,
  'source': e.source.dbValue,
  'basket_item_id': e.basketItemId,
  'ended_on': e.endedOn == null ? null : _day(e.endedOn!),
};

BasketItem basketItemFromRow(Row row) => BasketItem(
  id: row['id'] as String,
  petId: row['pet_id'] as String,
  name: (row['name'] as String?) ?? '',
  kind: BasketKind.fromDb(row['kind'] as String?),
  packageSize: _number(row['package_size']) ?? 1,
  unit: BasketUnit.fromDb(row['package_unit'] as String?),
  lastPrice: _number(row['last_price']),
  currency: (row['currency'] as String?) ?? AppConfig.defaultCurrency,
  lastBoughtOn: _date(row['last_bought_on']),
  lastsDays: (row['lasts_days'] as num?)?.toInt(),
);

Row basketItemToRow(BasketItem i) => {
  'pet_id': i.petId,
  'name': i.name,
  'kind': i.kind.dbValue,
  'package_size': i.packageSize,
  'package_unit': i.unit.dbValue,
  'last_price': i.lastPrice,
  'currency': i.currency,
  'last_bought_on': i.lastBoughtOn == null ? null : _day(i.lastBoughtOn!),
  'lasts_days': i.lastsDays,
};
