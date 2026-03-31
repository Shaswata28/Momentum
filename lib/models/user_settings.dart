import 'package:hive/hive.dart';

part 'user_settings.g.dart';

@HiveType(typeId: 13)
class UserSettings {
  @HiveField(0)
  final String firstName;

  @HiveField(1)
  final int avatarIndex;

  @HiveField(2)
  final bool isFirstLaunch;

  UserSettings({
    this.firstName = '',
    this.avatarIndex = 0,
    this.isFirstLaunch = true,
  });
}
