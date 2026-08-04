import 'package:hive/hive.dart';

export 'package:hive/hive.dart' show Box;

/// 纯内存 Box 实现。
///
/// widget 测试运行在 FakeAsync 中，真实文件 IO 的完成事件无法被驱动：
/// 一旦有写操作（put）在后台排队，`clear()` 等需要等待 IO 队列排空的操作
/// 就会永久挂起（完整套件运行时表现为后续测试卡死）。
/// 注入本实现可完全绕开磁盘 IO。
class InMemoryBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _data = {};

  @override
  Iterable<dynamic> get keys => _data.keys;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _data[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _data.remove(key);
  }

  @override
  Future<int> clear() async {
    final n = _data.length;
    _data.clear();
    return n;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
