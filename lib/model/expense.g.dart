// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Expense _$$_ExpenseFromJson(Map<String, dynamic> json) => _$_Expense(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      type: $enumDecodeNullable(_$SpendTypeEnumMap, json['type']) ??
          SpendType.once,
      dateTime: json['dateTime'] == null
          ? null
          : DateTime.parse(json['dateTime'] as String),
      labels: (json['labels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$_ExpenseToJson(_$_Expense instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'description': instance.description,
      'type': _$SpendTypeEnumMap[instance.type],
      'dateTime': instance.dateTime?.toIso8601String(),
      'labels': instance.labels,
    };

const _$SpendTypeEnumMap = {
  SpendType.once: 'once',
  SpendType.monthly: 'monthly',
  SpendType.weekly: 'weekly',
};
