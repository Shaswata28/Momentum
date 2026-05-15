// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fixed_expense.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FixedExpenseAdapter extends TypeAdapter<FixedExpense> {
  @override
  final int typeId = 15;

  @override
  FixedExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FixedExpense(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: fields[2] as double,
      billingDay: fields[3] as int,
      lastPaidMonthKey: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FixedExpense obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.billingDay)
      ..writeByte(4)
      ..write(obj.lastPaidMonthKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FixedExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
