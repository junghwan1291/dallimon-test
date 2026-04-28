import 'package:flutter/material.dart';

// Dart 3 enhanced enum — methods on the enum itself, safe for web/DDC
enum PetType {
  earth,
  fire,
  water,
  wind,
  plant,
  dark,
  light;

  String get emoji {
    switch (this) {
      case PetType.earth: return '🌍';
      case PetType.fire:  return '🔥';
      case PetType.water: return '💧';
      case PetType.wind:  return '💨';
      case PetType.plant: return '🌿';
      case PetType.dark:  return '🌑';
      case PetType.light: return '✨';
    }
  }

  String get label {
    switch (this) {
      case PetType.earth: return '대지';
      case PetType.fire:  return '불꽃';
      case PetType.water: return '물';
      case PetType.wind:  return '바람';
      case PetType.plant: return '식물';
      case PetType.dark:  return '어둠';
      case PetType.light: return '빛';
    }
  }

  String get battleRole {
    switch (this) {
      case PetType.earth: return '방어형';
      case PetType.fire:  return '공격형';
      case PetType.water: return '회복형';
      case PetType.wind:  return '속도형';
      case PetType.plant: return '균형형';
      case PetType.dark:  return '특수형';
      case PetType.light: return '지원형';
    }
  }

  String get gpsZone {
    switch (this) {
      case PetType.earth: return '산 · 숲길 · 자연';
      case PetType.fire:  return '도심 · 학교 근처';
      case PetType.water: return '강변 · 해변';
      case PetType.wind:  return '공원 · 운동장';
      case PetType.plant: return '숲 · 식물원';
      case PetType.dark:  return '야간 전용';
      case PetType.light: return '광장 · 명소';
    }
  }

  Color get color {
    switch (this) {
      case PetType.earth: return const Color(0xFF8D6E63);
      case PetType.fire:  return const Color(0xFFFF5722);
      case PetType.water: return const Color(0xFF2196F3);
      case PetType.wind:  return const Color(0xFF80DEEA);
      case PetType.plant: return const Color(0xFF4CAF50);
      case PetType.dark:  return const Color(0xFF9C27B0);
      case PetType.light: return const Color(0xFFFFD600);
    }
  }

  // v5: 물→불→식물→대지→바람→물 / 빛↔어둠
  PetType get strongAgainst {
    switch (this) {
      case PetType.water: return PetType.fire;
      case PetType.fire:  return PetType.plant;
      case PetType.plant: return PetType.earth;
      case PetType.earth: return PetType.wind;
      case PetType.wind:  return PetType.water;
      case PetType.light: return PetType.dark;
      case PetType.dark:  return PetType.light;
    }
  }
}

// 강점 ×1.5 / 약점 ×0.7 / 중립 ×1.0
double typeMultiplier(PetType attacker, PetType defender) {
  if (attacker.strongAgainst == defender) return 1.5;
  if (defender.strongAgainst == attacker) return 0.7;
  return 1.0;
}
