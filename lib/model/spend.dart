import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'spend.freezed.dart';

enum SpendType { once, monthly, weekly }

@freezed
class Spend with _$Spend {
  const factory Spend(double value, SpendType type, String description) =
      _Spend;
}
