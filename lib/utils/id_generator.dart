class IDGenerator {
  static final IDGenerator _instance = IDGenerator._internal();
  factory IDGenerator() => _instance;
  IDGenerator._internal();

  int _lastId = 0;

  String generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _lastId++;
    return '${timestamp}_${_lastId}';
  }
}