// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'month_summary.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MonthSummaryAdapter extends TypeAdapter<MonthSummary> {
  @override
  final int typeId = 11;

  @override
  MonthSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MonthSummary(
      id: fields[0] as String,
      openingBalance: fields[1] as double,
      totalIncome: fields[2] as double,
      totalExpense: fields[3] as double,
      closingBalance: fields[4] as double,
      budgetLimit: fields[5] as double?,
      isClosed: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MonthSummary obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.openingBalance)
      ..writeByte(2)
      ..write(obj.totalIncome)
      ..writeByte(3)
      ..write(obj.totalExpense)
      ..writeByte(4)
      ..write(obj.closingBalance)
      ..writeByte(5)
      ..write(obj.budgetLimit)
      ..writeByte(6)
      ..write(obj.isClosed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
