import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates globally unique ids so records created offline on different
/// devices never collide when they sync.
String newId() => _uuid.v7();
