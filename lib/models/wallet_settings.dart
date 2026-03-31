import 'package:hive/hive.dart';

part 'wallet_settings.g.dart';

@HiveType(typeId: 12)
class WalletSettings {
  @HiveField(0)
  final double initialBalance;
  @HiveField(1)
  final double monthlyBudget;
  @HiveField(2)
  final double semesterGoal;

  WalletSettings({
    this.initialBalance = 0.0,
    this.monthlyBudget = 0.0,
    this.semesterGoal = 0.0,
  });
}
