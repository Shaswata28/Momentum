// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_period.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoutinePeriodAdapter extends TypeAdapter<RoutinePeriod> {
  @override
  final int typeId = 3;

  @override
  RoutinePeriod read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutinePeriod(
      id: fields[0] as String,
      label: fields[1] as String,
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime,
      isActive: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RoutinePeriod obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutinePeriodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
