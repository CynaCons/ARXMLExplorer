class _Tracing {
  List<String> _trace = const [];
  List<String> get lastTrace => List.unmodifiable(_trace);
  void _add(String msg) {
    if (_trace.length > 5000) {
      _trace = _trace.sublist(_trace.length - 4000);
    }
    _trace = [..._trace, msg];
  }
}
