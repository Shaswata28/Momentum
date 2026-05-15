// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eod_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EODLogAdapter extends TypeAdapter<EODLog> {
  @override
  final int typeId = 6;

  @override
  EODLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EODLog(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      totalTasks: fields[2] as int,
      completedTasks: fields[3] as int,
      skippedTasks: fields[4] as int,
      rescheduledTasks: fields[5] as int,
      userNote: fields[6] as String?,
      closedAt: fields[7] as DateTime,
      healthScore: fields[8] as double,
      grade: fields[9] as String,
      energyLevel: fields[10] as int,
      motivation: fields[11] as String,
      stuckToBudget: fields[12] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, EODLog obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.totalTasks)
      ..writeByte(3)
      ..write(obj.completedTasks)
      ..writeByte(4)
      ..write(obj.skippedTasks)
      ..writeByte(5)
      ..write(obj.rescheduledTasks)
      ..writeByte(6)
      ..write(obj.userNote)
      ..writeByte(7)
      ..write(obj.closedAt)
      ..writeByte(8)
      ..write(obj.healthScore)
      ..writeByte(9)
      ..write(obj.grade)
      ..writeByte(10)
      ..write(obj.energyLevel)
      ..writeByte(11)
      ..write(obj.motivation)
      ..writeByte(12)
      ..write(obj.stuckToBudget);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EODLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
