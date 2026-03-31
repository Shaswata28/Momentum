// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 10;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      direction: fields[2] as Direction,
      amount: fields[3] as double,
      expenseType: fields[4] as ExpenseType?,
      incomeSource: fields[5] as IncomeSource?,
      note: fields[6] as String,
      isSettled: fields[7] as bool,
      monthId: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.direction)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.expenseType)
      ..writeByte(5)
      ..write(obj.incomeSource)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.isSettled)
      ..writeByte(8)
      ..write(obj.monthId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DirectionAdapter extends TypeAdapter<Direction> {
  @override
  final int typeId = 7;

  @override
  Direction read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Direction.income;
      case 1:
        return Direction.expense;
      default:
        return Direction.income;
    }
  }

  @override
  void write(BinaryWriter writer, Direction obj) {
    switch (obj) {
      case Direction.income:
        writer.writeByte(0);
        break;
      case Direction.expense:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExpenseTypeAdapter extends TypeAdapter<ExpenseType> {
  @override
  final int typeId = 8;

  @override
  ExpenseType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExpenseType.fixed;
      case 1:
        return ExpenseType.variable;
      case 2:
        return ExpenseType.borrowed;
      case 3:
        return ExpenseType.lent;
      default:
        return ExpenseType.fixed;
    }
  }

  @override
  void write(BinaryWriter writer, ExpenseType obj) {
    switch (obj) {
      case ExpenseType.fixed:
        writer.writeByte(0);
        break;
      case ExpenseType.variable:
        writer.writeByte(1);
        break;
      case ExpenseType.borrowed:
        writer.writeByte(2);
        break;
      case ExpenseType.lent:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class IncomeSourceAdapter extends TypeAdapter<IncomeSource> {
  @override
  final int typeId = 9;

  @override
  IncomeSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IncomeSource.tuition;
      case 1:
        return IncomeSource.freelance;
      case 2:
        return IncomeSource.other;
      default:
        return IncomeSource.tuition;
    }
  }

  @override
  void write(BinaryWriter writer, IncomeSource obj) {
    switch (obj) {
      case IncomeSource.tuition:
        writer.writeByte(0);
        break;
      case IncomeSource.freelance:
        writer.writeByte(1);
        break;
      case IncomeSource.other:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
