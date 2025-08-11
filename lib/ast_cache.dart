import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arxml_explorer/elementnode.dart';

class AstCacheEntry {
  final List<ElementNode> nodes;
  final DateTime timestamp;
  AstCacheEntry(this.nodes) : timestamp = DateTime.now();
}

class AstLruCache {
  final int capacity;
  final Map<String, AstCacheEntry> _map = {};
  final List<String> _lru = [];

  AstLruCache({this.capacity = 8});

  List<ElementNode>? get(String path) {
    final entry = _map[path];
    if (entry == null) return null;
    _bump(path);
    return entry.nodes;
  }

  void put(String path, List<ElementNode> nodes) {
    if (_map.containsKey(path)) {
      _map[path] = AstCacheEntry(nodes);
      _bump(path);
      return;
    }
    if (_lru.length >= capacity) {
      final evict = _lru.removeAt(0);
      _map.remove(evict);
    }
    _map[path] = AstCacheEntry(nodes);
    _lru.add(path);
  }

  void _bump(String path) {
    _lru.remove(path);
    _lru.add(path);
  }

  int get size => _map.length;
  List<String> get keys => List.unmodifiable(_lru);
}

final astCacheProvider =
    Provider<AstLruCache>((ref) => AstLruCache(capacity: 8));
