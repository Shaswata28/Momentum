// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SimpleGoalAdapter extends TypeAdapter<SimpleGoal> {
  @override
  final int typeId = 14;

  @override
  SimpleGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SimpleGoal(
      id: fields[0] as String,
      title: fields[1] as String,
      isHabit: fields[2] as bool,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SimpleGoal obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.isHabit)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpleGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
