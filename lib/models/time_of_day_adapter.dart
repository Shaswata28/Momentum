import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class TimeOfDayAdapter extends TypeAdapter<TimeOfDay> {
  @override
  final int typeId = 0;

  @override
  TimeOfDay read(BinaryReader reader) {
    final minutes = reader.readInt();
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  @override
  void write(BinaryWriter writer, TimeOfDay obj) {
    writer.writeInt(obj.hour * 60 + obj.minute);
  }
}
