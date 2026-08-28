import 'package:flutter/material.dart';

enum EarthquakeEffect {
  magma,
  frost,
  voidRift;

  static EarthquakeEffect fromStorage(String? value) {
    return EarthquakeEffect.values.firstWhere(
      (effect) => effect.name == value,
      orElse: () => EarthquakeEffect.magma,
    );
  }

  String get arabicLabel => switch (this) {
        EarthquakeEffect.magma => 'الحمم',
        EarthquakeEffect.frost => 'الصقيع',
        EarthquakeEffect.voidRift => 'الصدع المظلم',
      };

  String get arabicDescription => switch (this) {
        EarthquakeEffect.magma => 'شقوق نارية وانفجار صخري',
        EarthquakeEffect.frost => 'بلورات جليدية وموجة باردة',
        EarthquakeEffect.voidRift => 'تمزق في الشاشة يتفرع منه ضوء الفراغ',
      };

  Color get primaryColor => switch (this) {
        EarthquakeEffect.magma => const Color(0xFFFF9100),
        EarthquakeEffect.frost => const Color(0xFF38BDF8),
        EarthquakeEffect.voidRift => const Color(0xFFA855F7),
      };

  Color get secondaryColor => switch (this) {
        EarthquakeEffect.magma => const Color(0xFFFFD54F),
        EarthquakeEffect.frost => const Color(0xFFBAE6FD),
        EarthquakeEffect.voidRift => const Color(0xFFE879F9),
      };

  Color get debrisColor => switch (this) {
        EarthquakeEffect.magma => const Color(0xFFFF5722),
        EarthquakeEffect.frost => const Color(0xFFE0F2FE),
        EarthquakeEffect.voidRift => const Color(0xFF6D28D9),
      };
}
