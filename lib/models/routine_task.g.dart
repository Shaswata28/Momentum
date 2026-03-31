// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoutineTaskAdapter extends TypeAdapter<RoutineTask> {
  @override
  final int typeId = 4;

  @override
  RoutineTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutineTask(
      id: fields[0] as String,
      title: fields[1] as String,
      taskType: fields[2] as TaskType,
      scheduledTime: fields[3] as TimeOfDay?,
      flexWindowStart: fields[4] as TimeOfDay?,
      flexWindowEnd: fields[5] as TimeOfDay?,
      durationMinutes: fields[6] as int,
      daysOfWeek: (fields[7] as List).cast<int>(),
      enableDND: fields[8] as bool,
      bufferAfterMin: fields[9] as int,
      color: fields[10] as String?,
      isActive: fields[11] as bool,
      routinePeriodId: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, RoutineTask obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.taskType)
      ..writeByte(3)
      ..write(obj.scheduledTime)
      ..writeByte(4)
      ..write(obj.flexWindowStart)
      ..writeByte(5)
      ..write(obj.flexWindowEnd)
      ..writeByte(6)
      ..write(obj.durationMinutes)
      ..writeByte(7)
      ..write(obj.daysOfWeek)
      ..writeByte(8)
      ..write(obj.enableDND)
      ..writeByte(9)
      ..write(obj.bufferAfterMin)
      ..writeByte(10)
      ..write(obj.color)
      ..writeByte(11)
      ..write(obj.isActive)
      ..writeByte(12)
      ..write(obj.routinePeriodId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
