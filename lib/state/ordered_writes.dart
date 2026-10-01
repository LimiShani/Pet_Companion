/// Sends the writes about one item (a pet, a deal, a post) one after the
/// other, in the order they were made.
///
/// Requests sent at the same time can finish in any order, so without this
/// a quick second change could reach the backend first and be overwritten
/// by the older one. Writes about different items still run side by side.
class OrderedWrites {
  /// The last write of each item that is still on its way; never fails.
  final _tails = <Object, Future<void>>{};

  /// Whether a write about [key] is still on its way.
  bool busy(Object key) => _tails.containsKey(key);

  /// Runs [write] once every earlier write about [key] has finished,
  /// whether it worked or not, and returns what [write] returns.
  Future<T> run<T>(Object key, Future<T> Function() write) {
    final result = (_tails[key] ?? Future<void>.value()).then((_) => write());
    final done = result.then<void>((_) {}, onError: (Object _) {});
    _tails[key] = done;
    done.then((_) {
      if (identical(_tails[key], done)) _tails.remove(key);
    });
    return result;
  }
}
