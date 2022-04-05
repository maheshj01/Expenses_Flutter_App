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

  _Spend call(double value, SpendType type, String description) {
    return _Spend(
      value,
      type,
      description,
    );
  }
}

/// @nodoc
const $Spend = _$SpendTearOff();

/// @nodoc
mixin _$Spend {
  double get value => throw _privateConstructorUsedError;
  SpendType get type => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $SpendCopyWith<Spend> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpendCopyWith<$Res> {
  factory $SpendCopyWith(Spend value, $Res Function(Spend) then) =
      _$SpendCopyWithImpl<$Res>;
  $Res call({double value, SpendType type, String description});
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
    Object? type = freezed,
    Object? description = freezed,
  }) {
    return _then(_value.copyWith(
      value: value == freezed
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      type: type == freezed
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SpendType,
      description: description == freezed
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
abstract class _$SpendCopyWith<$Res> implements $SpendCopyWith<$Res> {
  factory _$SpendCopyWith(_Spend value, $Res Function(_Spend) then) =
      __$SpendCopyWithImpl<$Res>;
  @override
  $Res call({double value, SpendType type, String description});
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
    Object? type = freezed,
    Object? description = freezed,
  }) {
    return _then(_Spend(
      value == freezed
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      type == freezed
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SpendType,
      description == freezed
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$_Spend with DiagnosticableTreeMixin implements _Spend {
  const _$_Spend(this.value, this.type, this.description);

  @override
  final double value;
  @override
  final SpendType type;
  @override
  final String description;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Spend(value: $value, type: $type, description: $description)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'Spend'))
      ..add(DiagnosticsProperty('value', value))
      ..add(DiagnosticsProperty('type', type))
      ..add(DiagnosticsProperty('description', description));
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Spend &&
            const DeepCollectionEquality().equals(other.value, value) &&
            const DeepCollectionEquality().equals(other.type, type) &&
            const DeepCollectionEquality()
                .equals(other.description, description));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(value),
      const DeepCollectionEquality().hash(type),
      const DeepCollectionEquality().hash(description));

  @JsonKey(ignore: true)
  @override
  _$SpendCopyWith<_Spend> get copyWith =>
      __$SpendCopyWithImpl<_Spend>(this, _$identity);
}

abstract class _Spend implements Spend {
  const factory _Spend(double value, SpendType type, String description) =
      _$_Spend;

  @override
  double get value;
  @override
  SpendType get type;
  @override
  String get description;
  @override
  @JsonKey(ignore: true)
  _$SpendCopyWith<_Spend> get copyWith => throw _privateConstructorUsedError;
}
