import 'dart:typed_data';

class BlockedAppInfo {
  final String name;
  final String packageName;
  final Uint8List? iconBytes;
  final String category;
  final bool isBlocked;

  const BlockedAppInfo({
    required this.name,
    required this.packageName,
    this.iconBytes,
    required this.category,
    this.isBlocked = false,
  });

  BlockedAppInfo copyWith({
    String? name,
    String? packageName,
    Uint8List? iconBytes,
    String? category,
    bool? isBlocked,
  }) {
    return BlockedAppInfo(
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      iconBytes: iconBytes ?? this.iconBytes,
      category: category ?? this.category,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  factory BlockedAppInfo.fromMap(Map<dynamic, dynamic> map, {bool isBlocked = false}) {
    return BlockedAppInfo(
      name: map['name'] as String? ?? 'Unknown App',
      packageName: map['packageName'] as String? ?? '',
      iconBytes: map['icon'] != null ? Uint8List.fromList(List<int>.from(map['icon'])) : null,
      category: map['category'] as String? ?? 'other',
      isBlocked: isBlocked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'packageName': packageName,
      'category': category,
      'isBlocked': isBlocked,
    };
  }
}

