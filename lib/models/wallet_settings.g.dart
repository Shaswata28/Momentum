// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WalletSettingsAdapter extends TypeAdapter<WalletSettings> {
  @override
  final int typeId = 12;

  @override
  WalletSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WalletSettings(
      initialBalance: fields[0] as double,
      monthlyBudget: fields[1] as double,
      semesterGoal: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, WalletSettings obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.initialBalance)
      ..writeByte(1)
      ..write(obj.monthlyBudget)
      ..writeByte(2)
      ..write(obj.semesterGoal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
