part of 'saving_goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavingGoalAdapter extends TypeAdapter<SavingGoal> {
  @override
  final int typeId = 16;

  @override
  SavingGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final rawDeposits = fields[4] as Map?;
    final deposits = <String, double>{};
    if (rawDeposits != null) {
      rawDeposits.forEach((k, v) {
        if (k != null && v != null) {
          deposits[k.toString()] = (v as num).toDouble();
        }
      });
    }
    return SavingGoal(
      id: fields[0] as String,
      name: fields[1] as String,
      targetAmount: (fields[2] as num).toDouble(),
      monthlyTarget: (fields[3] as num).toDouble(),
      deposits: deposits,
      createdAt: fields[5] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, SavingGoal obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.targetAmount)
      ..writeByte(3)
      ..write(obj.monthlyTarget)
      ..writeByte(4)
      ..write(obj.deposits)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
