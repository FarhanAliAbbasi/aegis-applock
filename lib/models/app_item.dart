import 'dart:typed_data';

class AppItem {
  final String name;
  final String packageName;
  final bool isSystemApp;
  final bool isLocked;
  final Uint8List? iconBytes;

  const AppItem({
    required this.name,
    required this.packageName,
    this.isSystemApp = false,
    this.isLocked = false,
    this.iconBytes,
  });

  AppItem copyWith({
    String? name,
    String? packageName,
    bool? isSystemApp,
    bool? isLocked,
    Uint8List? iconBytes,
  }) {
    return AppItem(
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      isSystemApp: isSystemApp ?? this.isSystemApp,
      isLocked: isLocked ?? this.isLocked,
      iconBytes: iconBytes ?? this.iconBytes,
    );
  }

  factory AppItem.fromMap(Map<dynamic, dynamic> map) {
    return AppItem(
      name: map['name'] as String? ?? 'Unknown',
      packageName: map['packageName'] as String? ?? '',
      isSystemApp: map['isSystemApp'] as bool? ?? false,
      isLocked: map['isLocked'] as bool? ?? false,
      iconBytes: map['iconBytes'] != null
          ? Uint8List.fromList(List<int>.from(map['iconBytes'] as List))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'packageName': packageName,
      'isSystemApp': isSystemApp,
      'isLocked': isLocked,
      'iconBytes': iconBytes,
    };
  }

  bool get isSocialOrMessenger {
    final lower = packageName.toLowerCase();
    return lower.contains('whatsapp') ||
        lower.contains('instagram') ||
        lower.contains('facebook') ||
        lower.contains('messenger') ||
        lower.contains('telegram') ||
        lower.contains('twitter') ||
        lower.contains('x.android') ||
        lower.contains('snapchat') ||
        lower.contains('tiktok') ||
        lower.contains('discord') ||
        lower.contains('reddit');
  }

  bool get isSensitiveOrFinancial {
    final lowerPkg = packageName.toLowerCase();
    final lowerName = name.toLowerCase();
    return lowerPkg.contains('bank') ||
        lowerName.contains('bank') ||
        lowerPkg.contains('pay') ||
        lowerName.contains('pay') ||
        lowerPkg.contains('wallet') ||
        lowerName.contains('wallet') ||
        lowerPkg.contains('crypto') ||
        lowerName.contains('crypto') ||
        lowerPkg.contains('binance') ||
        lowerPkg.contains('settings') ||
        lowerName.contains('settings') ||
        lowerPkg.contains('gallery') ||
        lowerName.contains('gallery') ||
        lowerPkg.contains('photos') ||
        lowerName.contains('photos');
  }
}
