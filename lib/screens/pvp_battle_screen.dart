import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../domain/dallimmon.dart';
import '../domain/dungeon.dart';
import '../domain/pet_type.dart';

class PvPBattleScreen extends StatefulWidget {
  final PvPOpponent opponent;
  final List<OwnedDallimmon> myTeamOwned;
  final int myPlayerLevel;

  const PvPBattleScreen({
    super.key,
    required this.opponent,
    required this.myTeamOwned,
    required this.myPlayerLevel,
  });

  @override
  State<PvPBattleScreen> createState() => _PvPBattleScreenState();
}

class _PvPBattleScreenState extends State<PvPBattleScreen> {
  late List<BattleUnit> _myTeam;
  late List<BattleUnit> _enemyTeam;
  
  String _lastLog = "PvP 배틀 준비!";
  int? _latestDamage;
  bool _isCrit = false;
  bool _isAnimating = false;
  bool _done = false;
  bool _won = false;
  
  // Handicap multipliers (GDD v5)
  double _myBonus = 1.0;
  double _enemyBonus = 1.0;

  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _initTeams();
    _startBattleLoop();
  }

  void _initTeams() {
    _myTeam = widget.myTeamOwned.map((o) => BattleUnit.fromOwned(o)).toList();
    _enemyTeam = widget.opponent.team.map((o) => BattleUnit.fromOwned(o)).toList();
    
    // Apply Handicap (GDD v5)
    final diff = (widget.myPlayerLevel - widget.opponent.level).abs();
    double bonus = 1.0;
    if (diff > 30) bonus = 1.35;
    else if (diff > 15) bonus = 1.25;
    else if (diff > 5) bonus = 1.15;
    
    if (widget.myPlayerLevel < widget.opponent.level) {
      _myBonus = bonus;
      _enemyBonus = 1.0;
    } else {
      _myBonus = 1.0;
      _enemyBonus = bonus;
    }
    
    // Apply HP bonus immediately (since it's a state field)
    for (var u in _myTeam) {
       u.hp = (u.hp * _myBonus).round();
    }
    for (var u in _enemyTeam) {
       u.hp = (u.hp * _enemyBonus).round();
    }
  }

  Future<void> _startBattleLoop() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    int turnCount = 0;
    while (!_done && turnCount < 50) { // Limit turns to avoid infinite loop
      turnCount++;
      
      // Player team acts
      for (int i = 0; i < _myTeam.length; i++) {
        if (_done) break;
        if (_myTeam[i].isAlive) {
          await _performAction(_myTeam[i], _enemyTeam, _myBonus);
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
      
      if (_enemyTeam.every((e) => !e.isAlive)) {
        _finishBattle(true);
        break;
      }

      // Enemy team acts
      for (int i = 0; i < _enemyTeam.length; i++) {
        if (_done) break;
        if (_enemyTeam[i].isAlive) {
          await _performAction(_enemyTeam[i], _myTeam, _enemyBonus);
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }

      if (_myTeam.every((e) => !e.isAlive)) {
        _finishBattle(false);
        break;
      }
    }
    
    if (!_done) {
      // Draw or timeout -> check HP ratio
      final myHpSum = _myTeam.fold(0, (sum, u) => sum + u.hp);
      final enemyHpSum = _enemyTeam.fold(0, (sum, u) => sum + u.hp);
      _finishBattle(myHpSum >= enemyHpSum);
    }
  }

  Future<void> _performAction(BattleUnit attacker, List<BattleUnit> targetTeam, double bonus) async {
    final livingTargets = targetTeam.where((u) => u.isAlive).toList();
    if (livingTargets.isEmpty) return;

    final target = livingTargets[_rng.nextInt(livingTargets.length)];
    
    if (!mounted) return;
    setState(() {
      _isAnimating = true;
    });

    // Damage logic (simplified for auto-battle)
    final isMagic = _rng.nextBool();
    final mult = typeMultiplier(attacker.type, target.type);
    final isCrit = _rng.nextDouble() < attacker.critRate;
    
    final baseAtk = (isMagic ? attacker.matk : attacker.atk) * bonus;
    final raw = baseAtk - target.def ~/ 2;
    final dmg = max(1, (raw * mult * (isCrit ? 1.5 : 1.0)).round());

    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!mounted) return;
    setState(() {
      target.takeDamage(dmg);
      _latestDamage = dmg;
      _isCrit = isCrit;
      _lastLog = "${attacker.name}의 ${isMagic ? '마법' : '물리'} 공격! ${target.name}에게 -${dmg}HP";
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _latestDamage = null;
      _isAnimating = false;
    });
  }

  void _finishBattle(bool won) {
    if (_done) return;
    setState(() {
      _done = true;
      _won = won;
      _lastLog = won ? "🎉 PvP 승리!" : "💀 PvP 패배...";
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0518),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildUnitRow(_enemyTeam, true),
              _buildDamageDisplay(),
              _buildVsDivider(),
              _buildUnitRow(_myTeam, false),
              const Spacer(),
              _buildLogBar(),
              if (_done) _buildResultBar(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text('🔥 PvP 리그 배틀 🔥', 
            style: TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PlayerInfo(name: '나 (Lv.${widget.myPlayerLevel})', bonus: _myBonus),
              const Text('VS', style: TextStyle(color: AppColors.textHint, fontWeight: FontWeight.bold)),
              _PlayerInfo(name: '${widget.opponent.name} (Lv.${widget.opponent.level})', bonus: _enemyBonus, isRight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitRow(List<BattleUnit> team, bool isEnemy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: team.map((u) => _PvPUnitCard(unit: u)).toList(),
      ),
    );
  }

  Widget _buildDamageDisplay() {
    return SizedBox(
      height: 60,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _latestDamage != null
              ? Text(
                  '-$_latestDamage ${_isCrit ? "💥" : "✦"}',
                  style: TextStyle(
                    color: _isCrit ? AppColors.accent : AppColors.danger,
                    fontSize: _isCrit ? 36 : 28,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildVsDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Divider(color: Colors.white24, thickness: 1),
    );
  }

  Widget _buildLogBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.black38,
      child: Text(_lastLog, 
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildResultBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'won': _won,
            'points': _won ? 25 : -10,
            'tokens': _won ? 10 : 2,
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: _won ? AppColors.success : AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(_won ? '보상 수령 및 나가기' : '전투 종료', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }
}

class _PlayerInfo extends StatelessWidget {
  final String name;
  final double bonus;
  final bool isRight;
  const _PlayerInfo({required this.name, required this.bonus, this.isRight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        if (bonus > 1.0)
          Text('핸디캡 보정 +${((bonus - 1) * 100).round()}%', 
            style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PvPUnitCard extends StatelessWidget {
  final BattleUnit unit;
  const _PvPUnitCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    final color = unit.type.color;
    final alive = unit.isAlive;
    return Opacity(
      opacity: alive ? 1.0 : 0.3,
      child: Container(
        width: 65,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: alive ? color.withOpacity(0.5) : Colors.white10),
        ),
        child: Column(
          children: [
            Text(unit.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: unit.hpRatio,
                minHeight: 3,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
