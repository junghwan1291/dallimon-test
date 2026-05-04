import 'dart:math';
import 'package:flutter/material.dart';
import 'dallimmon.dart';
import 'pet_type.dart';

// ── Dungeon definition ────────────────────────────────────
class DungeonDef {
  final int level;

  const DungeonDef({required this.level});

  String get name {
    if (level <= 10) return '초급 던전';
    if (level <= 25) return '중급 던전';
    if (level <= 50) return '고급 던전';
    return '영웅 던전';
  }

  Color get color {
    if (level <= 10) return const Color(0xFF4A148C);
    if (level <= 25) return const Color(0xFF1B5E20);
    if (level <= 50) return const Color(0xFFE65100);
    return const Color(0xFFB71C1C);
  }

  int get clearExp {
    if (level <= 10) return 50 + level * 10;
    if (level <= 25) return 200 + level * 8;
    if (level <= 50) return 500 + level * 6;
    return 1000 + level * 5;
  }

  int get failExp => (clearExp * 0.2).round();
  int get stages  => 5;
}

// ── Battle unit (ephemeral, only during combat) ────────────
class BattleUnit {
  final String name;
  final String emoji;
  final PetType type;
  final int maxHp;
  int hp;
  final int atk;
  final int matk;
  final int def;
  final int spd;
  final double critRate;
  final bool isEnemy;

  BattleUnit({
    required this.name,
    required this.emoji,
    required this.type,
    required this.maxHp,
    required this.atk,
    required this.matk,
    required this.def,
    required this.spd,
    required this.critRate,
    required this.isEnemy,
  }) : hp = maxHp;

  bool get isAlive => hp > 0;
  double get hpRatio => maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;

  void takeDamage(int dmg) => hp = (hp - dmg).clamp(0, maxHp);

  factory BattleUnit.fromOwned(OwnedDallimmon owned) {
    final def = getDef(owned.defId);
    return BattleUnit(
      name: def.name,
      emoji: def.emoji,
      type: def.type,
      maxHp: owned.calcHp(def.baseHp),
      atk: owned.calcAtk(def.baseAtk),
      matk: owned.calcMatk(def.baseMatk),
      def: owned.calcDef(def.baseDef),
      spd: owned.calcSpd(def.baseSpd),
      critRate: owned.critRate,
      isEnemy: false,
    );
  }

  factory BattleUnit.enemy(String name, String emoji, PetType type, int dungeonLevel) {
    if (dungeonLevel == 1) {
      return BattleUnit(
        name: name,
        emoji: emoji,
        type: type,
        maxHp: 2, // Die in one hit mostly
        atk: 1,   // Harmless
        matk: 1,
        def: 0,
        spd: 1,
        critRate: 0.0,
        isEnemy: true,
      );
    }
    
    // Smooth progression for early levels
    double statMult = 1.0;
    if (dungeonLevel <= 10) {
      statMult = 0.4 + (dungeonLevel * 0.05); // Significantly weaker at lv 2, scaling up
    }

    final base = (15 + dungeonLevel * 5) * statMult;
    return BattleUnit(
      name: name,
      emoji: emoji,
      type: type,
      maxHp: (base * 7).round(),
      atk: base.round(),
      matk: (base * 0.7).round(),
      def: (dungeonLevel * 1.5).round(),
      spd: 8 + dungeonLevel,
      critRate: 0.02,
      isEnemy: true,
    );
  }

  // Deep copy for battle simulation
  BattleUnit clone() => BattleUnit(
    name: name, emoji: emoji, type: type,
    maxHp: maxHp, atk: atk, matk: matk, def: def, spd: spd,
    critRate: critRate, isEnemy: isEnemy,
  )..hp = hp;
}

// ── Battle log entry ─────────────────────────────────────
class BattleLog {
  final String message;
  final int? damage;
  final bool isCrit;

  const BattleLog(this.message, {this.damage, this.isCrit = false});
}

// ── Battle result ─────────────────────────────────────────
class BattleResult {
  final bool won;
  final int expGained;
  final List<BattleLog> log;
  final List<BattleUnit> finalEnemies;
  final List<BattleUnit> finalMyTeam;

  const BattleResult({
    required this.won,
    required this.expGained,
    required this.log,
    required this.finalEnemies,
    required this.finalMyTeam,
  });
}

// ── Enemy generation helper ──────────────────────────────
List<(String, String, PetType)> getEnemySetForStage(int dungeonLevel, int stage) {
  // Lv 1: only one weak monster
  if (dungeonLevel == 1) {
    return [('꼬마 슬라임', '🟢', PetType.plant)];
  }

  // Lv 2~10: 1 or 2 monsters
  if (dungeonLevel <= 10) {
    final sets = [
      [('숲의 슬라임', '☘️', PetType.plant)],
      [('불의 정령', '🔥', PetType.fire), ('박쥐', '🦇', PetType.wind)],
      [('물뱀', '🐍', PetType.water)],
      [('덩굴 촉수', '🌱', PetType.plant), ('뼈다귀', '🦴', PetType.dark)],
      [('가디언 보스', '👺', PetType.earth)], // Mid-boss style for stage 5
    ];
    final idx = (stage - 1) % sets.length;
    return sets[idx].map((e) => (e.$1, e.$2, e.$3)).toList();
  }

  final isBoss = stage == 5;
  if (isBoss) {
    return [
      ('가디언 보스', '👺', PetType.earth),
      ('어둠의 구체', '🌘', PetType.dark),
      ('어둠의 구체', '🌘', PetType.dark),
    ];
  }
  final sets = [
    [('숲의 슬라임', '☘️', PetType.plant), ('불의 정령', '🔥', PetType.fire), ('박쥐', '🦇', PetType.wind)],
    [('뼈다귀', '🦴', PetType.dark), ('바위 거미', '🕷️', PetType.earth), ('지옥견', '🐕', PetType.fire)],
    [('물뱀', '🐍', PetType.water), ('덩굴 촉수', '🌱', PetType.plant), ('까마귀', '🐦', PetType.wind)],
    [('서리 멧돼지', '🐗', PetType.water), ('화염 괴물', '🌋', PetType.fire), ('맹독충', '🐝', PetType.plant)],
  ];
  final idx = (stage - 1) % sets.length;
  return sets[idx].map((e) => (e.$1, e.$2, e.$3)).toList();
}
