import 'package:flutter/material.dart';
import 'pet_type.dart';

// ── Rarity ───────────────────────────────────────────────
enum Rarity { common, rare, legendary }

extension RarityX on Rarity {
  String get label {
    switch (this) {
      case Rarity.common:    return '일반';
      case Rarity.rare:      return '희귀';
      case Rarity.legendary: return '전설';
    }
  }

  Color get color {
    switch (this) {
      case Rarity.common:    return const Color(0xFF9E9E9E);
      case Rarity.rare:      return const Color(0xFF2196F3);
      case Rarity.legendary: return const Color(0xFFFFD600);
    }
  }
}

// ── Egg definition ────────────────────────────────────────
class Egg {
  final String id;
  final Rarity rarity;
  final int stepsRequired;
  int currentSteps;
  final DateTime obtainedAt;

  Egg({
    required this.id,
    required this.rarity,
    required this.stepsRequired,
    this.currentSteps = 0,
    DateTime? obtainedAt,
  }) : obtainedAt = obtainedAt ?? DateTime.now();

  double get progress => (currentSteps / stepsRequired).clamp(0.0, 1.0);
  bool get canHatch => currentSteps >= stepsRequired;

  Map<String, dynamic> toJson() => {
    'id': id,
    'rarity': rarity.index,
    'stepsRequired': stepsRequired,
    'currentSteps': currentSteps,
    'obtainedAt': obtainedAt.toIso8601String(),
  };

  factory Egg.fromJson(Map<String, dynamic> j) => Egg(
    id: j['id'] as String,
    rarity: Rarity.values[j['rarity'] as int? ?? 0],
    stepsRequired: j['stepsRequired'] as int? ?? 1000,
    currentSteps: j['currentSteps'] as int? ?? 0,
    obtainedAt: DateTime.tryParse(j['obtainedAt'] as String? ?? ''),
  );

  factory Egg.generate(Rarity rarity) {
    int steps;
    switch (rarity) {
      case Rarity.common:    steps = 2000; break;
      case Rarity.rare:      steps = 5000; break;
      case Rarity.legendary: steps = 15000; break;
    }
    return Egg(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      rarity: rarity,
      stepsRequired: steps,
    );
  }
}

// ── Catalog definition (template per species) ────────────
class DallimmonDef {
  final int id;
  final String name;
  final String emoji;
  final PetType type;
  final Rarity rarity;
  final int baseHp;
  final int baseAtk;
  final int baseMatk;
  final int baseDef;
  final int baseSpd;

  const DallimmonDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
    required this.rarity,
    required this.baseHp,
    required this.baseAtk,
    required this.baseMatk,
    required this.baseDef,
    required this.baseSpd,
  });
}

// ── Owned instance ────────────────────────────────────────
class OwnedDallimmon {
  final int defId;
  int level;
  int exp;
  int cumulativeSteps;
  int dungeonClears;
  int streakDays;
  int dailyMilestonesHit;

  OwnedDallimmon({
    required this.defId,
    this.level = 1,
    this.exp = 0,
    this.cumulativeSteps = 0,
    this.dungeonClears = 0,
    this.streakDays = 0,
    this.dailyMilestonesHit = 0,
  });

  int get expToNext => level * 50 + 50;
  double get expRatio => (exp / expToNext).clamp(0.0, 1.0);

  // GDD v5 stat formulas
  int calcAtk(int baseAtk)   => baseAtk + level * 2 + (cumulativeSteps * 0.001).floor();
  int calcMatk(int baseMatk) => baseMatk + level * 2 + (cumulativeSteps * 0.001).floor();
  int calcDef(int baseDef)   => baseDef + (level * 1.5).floor() + dungeonClears * 5;
  int calcHp(int baseHp)     => baseHp + 200 + level * 10 + dailyMilestonesHit * 5;
  int calcSpd(int baseSpd)   => baseSpd + level + streakDays * 2;
  double get critRate        => (level * 0.002).clamp(0.0, 0.20);

  String get evolutionStage {
    if (level < 10) return '기초형';
    if (level < 25) return '1진화';
    if (level < 50) return '2진화';
    if (level < 80) return '3진화';
    if (level < 100) return '최종형';
    return '프레스티지형';
  }

  // Returns number of levels gained
  int addExp(int amount, {required int playerLevel}) {
    exp += amount;
    int gained = 0;
    while (exp >= expToNext && level < playerLevel) {
      exp -= expToNext;
      level++;
      gained++;
    }
    return gained;
  }

  Map<String, dynamic> toJson() => {
    'defId': defId,
    'level': level,
    'exp': exp,
    'cumulativeSteps': cumulativeSteps,
    'dungeonClears': dungeonClears,
    'streakDays': streakDays,
    'dailyMilestonesHit': dailyMilestonesHit,
  };

  factory OwnedDallimmon.fromJson(Map<String, dynamic> j) => OwnedDallimmon(
    defId: j['defId'] as int,
    level: (j['level'] as int?) ?? 1,
    exp: (j['exp'] as int?) ?? 0,
    cumulativeSteps: (j['cumulativeSteps'] as int?) ?? 0,
    dungeonClears: (j['dungeonClears'] as int?) ?? 0,
    streakDays: (j['streakDays'] as int?) ?? 0,
    dailyMilestonesHit: (j['dailyMilestonesHit'] as int?) ?? 0,
  );
}

// ── PvP Opponent ──────────────────────────────────────────
class PvPOpponent {
  final String name;
  final int level;
  final List<OwnedDallimmon> team;

  const PvPOpponent({
    required this.name,
    required this.level,
    required this.team,
  });
}

// ── Catalog ───────────────────────────────────────────────
const List<DallimmonDef> dallimmonCatalog = [
  DallimmonDef(id: 0,  name: '테라몬',   emoji: '🦕', type: PetType.earth, rarity: Rarity.common,    baseHp: 120, baseAtk: 18, baseMatk: 10, baseDef: 14, baseSpd: 6),
  DallimmonDef(id: 1,  name: '아쿠아몬', emoji: '💧', type: PetType.water, rarity: Rarity.common,    baseHp: 110, baseAtk: 14, baseMatk: 23, baseDef: 8,  baseSpd: 8),
  DallimmonDef(id: 2,  name: '바람몬',   emoji: '🌪️', type: PetType.wind,  rarity: Rarity.common,    baseHp: 80,  baseAtk: 18, baseMatk: 26, baseDef: 5,  baseSpd: 14),
  DallimmonDef(id: 3,  name: '풀몬',     emoji: '🌿', type: PetType.plant, rarity: Rarity.common,    baseHp: 100, baseAtk: 15, baseMatk: 15, baseDef: 7,  baseSpd: 9),
  DallimmonDef(id: 4,  name: '불꽃몬',   emoji: '🔥', type: PetType.fire,  rarity: Rarity.common,    baseHp: 90,  baseAtk: 26, baseMatk: 12, baseDef: 6,  baseSpd: 11),
  DallimmonDef(id: 5,  name: '빛나몬',   emoji: '✨', type: PetType.light, rarity: Rarity.rare,      baseHp: 105, baseAtk: 18, baseMatk: 20, baseDef: 10, baseSpd: 10),
  DallimmonDef(id: 6,  name: '어둠몬',   emoji: '🌑', type: PetType.dark,  rarity: Rarity.common,    baseHp: 95,  baseAtk: 24, baseMatk: 18, baseDef: 7,  baseSpd: 12),
  DallimmonDef(id: 7,  name: '드래곤몬', emoji: '🐲', type: PetType.dark,  rarity: Rarity.legendary, baseHp: 180, baseAtk: 45, baseMatk: 40, baseDef: 25, baseSpd: 15),
  DallimmonDef(id: 8,  name: '용암몬',   emoji: '🌋', type: PetType.fire,  rarity: Rarity.rare,      baseHp: 130, baseAtk: 35, baseMatk: 15, baseDef: 12, baseSpd: 8),
  DallimmonDef(id: 9,  name: '대지신몬', emoji: '🗿', type: PetType.earth, rarity: Rarity.rare,      baseHp: 200, baseAtk: 15, baseMatk: 15, baseDef: 35, baseSpd: 4),
  DallimmonDef(id: 10, name: '폭풍몬',   emoji: '⛈️', type: PetType.wind,  rarity: Rarity.rare,      baseHp: 100, baseAtk: 25, baseMatk: 40, baseDef: 8,  baseSpd: 18),
  DallimmonDef(id: 11, name: '성수몬',   emoji: '🌊', type: PetType.water, rarity: Rarity.legendary, baseHp: 160, baseAtk: 24, baseMatk: 32, baseDef: 20, baseSpd: 12),
];

DallimmonDef getDef(int id) =>
    dallimmonCatalog.firstWhere((d) => d.id == id, orElse: () => dallimmonCatalog.first);

// Starters shown in onboarding (one per base type)
const List<int> starterDefIds = [0, 4, 1, 2, 3, 6, 5]; // earth, fire, water, wind, plant, dark, light
