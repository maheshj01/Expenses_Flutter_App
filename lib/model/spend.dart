import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
part 'spend.freezed.dart';

enum SpendType { once, monthly, weekly }

@freezed
class Spend with _$Spend {
  const Spend._();
  const factory Spend(
      {@Default(0.0) double value,
      String? description,
      @Default(SpendType.once) SpendType type}) = _Spend;
}
