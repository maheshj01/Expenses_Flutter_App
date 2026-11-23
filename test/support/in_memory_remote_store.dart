import 'package:three_bucks/data/sync/remote_store.dart';
import 'package:three_bucks/data/sync/sync_record.dart';

/// A tiny server: stores records per collection and hands out a
/// monotonically increasing sequence number as the pull cursor.
class InMemoryRemoteStore implements RemoteStore {
  InMemoryRemoteStore({this.pageSize = 100});

  final int pageSize;
  final Map<String, Map<String, (int seq, SyncRecord record)>> _data = {};
  int _seq = 0;
  bool failNext = false;
  int pushCalls = 0;

  /// Change to simulate another account signing in.
  String accountIdValue = 'user-1';

  @override
  String get displayName => 'Memory';

  @override
  String? get accountId => accountIdValue;

  @override
  Future<void> connect() async {
    if (failNext) {
      failNext = false;
      throw StateError('server unavailable');
    }
  }

  @override
  Future<void> push(String collection, List<SyncRecord> records) async {
    pushCalls++;
    final col = _data.putIfAbsent(collection, () => {});
    for (final r in records) {
      final existing = col[r.id];
      if (existing != null && existing.$2.updatedAt > r.updatedAt) continue;
      col[r.id] = (++_seq, r);
    }
  }

  @override
  Future<PullResult> pull(String collection, {String? cursor}) async {
    final since = int.tryParse(cursor ?? '') ?? 0;
    final changed =
        (_data[collection]?.values ?? const <(int, SyncRecord)>[])
            .where((e) => e.$1 > since)
            .toList()
          ..sort((a, b) => a.$1.compareTo(b.$1));
    final page = changed.take(pageSize).toList();
    return PullResult(
      records: page.map((e) => e.$2).toList(),
      cursor: page.isEmpty ? cursor : '${page.last.$1}',
      hasMore: changed.length > page.length,
    );
  }

  int count(String collection) => _data[collection]?.length ?? 0;

  SyncRecord? get(String collection, String id) => _data[collection]?[id]?.$2;
}
