// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'spend.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more informations: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
class _$SpendTearOff {
  const _$SpendTearOff();

  _Spend call(
      {double value = 0.0,
      String? description,
      SpendType type = SpendType.once,
      String label = 'other',
      DateTime? date}) {
    return _Spend(
      value: value,
      description: description,
      type: type,
      label: label,
      date: date,
    );
  }
}

/// @nodoc
const $Spend = _$SpendTearOff();

/// @nodoc
mixin _$Spend {
  double get value => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  SpendType get type => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  DateTime? get date => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $SpendCopyWith<Spend> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpendCopyWith<$Res> {
  factory $SpendCopyWith(Spend value, $Res Function(Spend) then) =
      _$SpendCopyWithImpl<$Res>;
  $Res call(
      {double value,
      String? description,
      SpendType type,
      String label,
      DateTime? date});
}

/// @nodoc
class _$SpendCopyWithImpl<$Res> implements $SpendCopyWith<$Res> {
  _$SpendCopyWithImpl(this._value, this._then);

  final Spend _value;
  // ignore: unused_field
  final $Res Function(Spend) _then;

  @override
  $Res call({
    Object? value = freezed,
    Object? description = freezed,
    Object? type = freezed,
    Object? label = freezed,
    Object? date = freezed,
  }) {
    return _then(_value.copyWith(
      value: value == freezed
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      description: description == freezed
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      type: type == freezed
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SpendType,
      label: label == freezed
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      date: date == freezed
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
abstract class _$SpendCopyWith<$Res> implements $SpendCopyWith<$Res> {
  factory _$SpendCopyWith(_Spend value, $Res Function(_Spend) then) =
      __$SpendCopyWithImpl<$Res>;
  @override
  $Res call(
      {double value,
      String? description,
      SpendType type,
      String label,
      DateTime? date});
}

/// @nodoc
class __$SpendCopyWithImpl<$Res> extends _$SpendCopyWithImpl<$Res>
    implements _$SpendCopyWith<$Res> {
  __$SpendCopyWithImpl(_Spend _value, $Res Function(_Spend) _then)
      : super(_value, (v) => _then(v as _Spend));

  @override
  _Spend get _value => super._value as _Spend;

  @override
  $Res call({
    Object? value = freezed,
    Object? description = freezed,
    Object? type = freezed,
    Object? label = freezed,
    Object? date = freezed,
  }) {
    return _then(_Spend(
      value: value == freezed
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      description: description == freezed
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      type: type == freezed
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SpendType,
      label: label == freezed
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      date: date == freezed
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$_Spend extends _Spend with DiagnosticableTreeMixin {
  const _$_Spend(
      {this.value = 0.0,
      this.description,
      this.type = SpendType.once,
      this.label = 'other',
      this.date})
      : super._();

  @JsonKey()
  @override
  final double value;
  @override
  final String? description;
  @JsonKey()
  @override
  final SpendType type;
  @JsonKey()
  @override
  final String label;
  @override
  final DateTime? date;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Spend(value: $value, description: $description, type: $type, label: $label, date: $date)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'Spend'))
      ..add(DiagnosticsProperty('value', value))
      ..add(DiagnosticsProperty('description', description))
      ..add(DiagnosticsProperty('type', type))
      ..add(DiagnosticsProperty('label', label))
      ..add(DiagnosticsProperty('date', date));
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Spend &&
            const DeepCollectionEquality().equals(other.value, value) &&
            const DeepCollectionEquality()
                .equals(other.description, description) &&
            const DeepCollectionEquality().equals(other.type, type) &&
            const DeepCollectionEquality().equals(other.label, label) &&
            const DeepCollectionEquality().equals(other.date, date));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(value),
      const DeepCollectionEquality().hash(description),
      const DeepCollectionEquality().hash(type),
      const DeepCollectionEquality().hash(label),
      const DeepCollectionEquality().hash(date));

  @JsonKey(ignore: true)
  @override
  _$SpendCopyWith<_Spend> get copyWith =>
      __$SpendCopyWithImpl<_Spend>(this, _$identity);
}

abstract class _Spend extends Spend {
  const factory _Spend(
      {double value,
      String? description,
      SpendType type,
      String label,
      DateTime? date}) = _$_Spend;
  const _Spend._() : super._();

  @override
  double get value;
  @override
  String? get description;
  @override
  SpendType get type;
  @override
  String get label;
  @override
  DateTime? get date;
  @override
  @JsonKey(ignore: true)
  _$SpendCopyWith<_Spend> get copyWith => throw _privateConstructorUsedError;
}
