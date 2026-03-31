// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_task_instance.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyTaskInstanceAdapter extends TypeAdapter<DailyTaskInstance> {
  @override
  final int typeId = 5;

  @override
  DailyTaskInstance read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyTaskInstance(
      id: fields[0] as String,
      routineTaskId: fields[1] as String?,
      date: fields[2] as DateTime,
      title: fields[3] as String,
      taskType: fields[4] as TaskType,
      scheduledTime: fields[5] as TimeOfDay?,
      flexWindowStart: fields[6] as TimeOfDay?,
      flexWindowEnd: fields[7] as TimeOfDay?,
      durationMinutes: fields[8] as int,
      status: fields[9] as TaskStatus,
      completedAt: fields[10] as DateTime?,
      rescheduledToDate: fields[11] as DateTime?,
      isBufferBlock: fields[12] as bool,
      enableDND: fields[13] as bool,
      notificationId: fields[14] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyTaskInstance obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.routineTaskId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.taskType)
      ..writeByte(5)
      ..write(obj.scheduledTime)
      ..writeByte(6)
      ..write(obj.flexWindowStart)
      ..writeByte(7)
      ..write(obj.flexWindowEnd)
      ..writeByte(8)
      ..write(obj.durationMinutes)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.completedAt)
      ..writeByte(11)
      ..write(obj.rescheduledToDate)
      ..writeByte(12)
      ..write(obj.isBufferBlock)
      ..writeByte(13)
      ..write(obj.enableDND)
      ..writeByte(14)
      ..write(obj.notificationId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyTaskInstanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
