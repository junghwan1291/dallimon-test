import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../domain/dallimmon.dart';
import '../domain/dungeon.dart';
import '../domain/pet_type.dart';

class DungeonBattleScreen extends StatefulWidget {
  final int dungeonLevel;
  final List<OwnedDallimmon> partyDallimmons;
  final bool isMapBattle;
  final List<BattleUnit>? customEnemies;

  const DungeonBattleScreen({
    super.key,
    required this.dungeonLevel,
    required this.partyDallimmons,
    this.isMapBattle = false,
    this.customEnemies,
  });

  @override
  State<DungeonBattleScreen> createState() => _DungeonBattleScreenState();
}

class _DungeonBattleScreenState extends State<DungeonBattleScreen> {
  late List<BattleUnit> _myTeam;
  List<BattleUnit> _currentEnemies = [];
  int _currentStage = 1;
  late final int _maxStages;
  
  bool _isPlayerTurn = true;
  int _attackerIndex = 0; // Which pet in my team is currently choosing action
  
  String _lastLog = "전투 준비 완료!";
  int? _latestDamage;
  bool _isCrit = false;
  bool _isAnimating = false;
  bool _done = false;
  bool _won = false;

  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _maxStages = widget.isMapBattle ? 1 : 5;
    // Lv 1: only first pet joins
    final party = (widget.dungeonLevel == 1 && !widget.isMapBattle)
      ? [widget.partyDallimmons.first] 
      : widget.partyDallimmons;
    _myTeam = party.map((o) => BattleUnit.fromOwned(o)).toList();
    _startStage(1);
  }

  void _startStage(int stageNum) {
    setState(() {
      _currentStage = stageNum;
      if (widget.isMapBattle && widget.customEnemies != null) {
        _currentEnemies = widget.customEnemies!.map((e) => e.clone()).toList();
      } else {
        final enemyTemplates = getEnemySetForStage(widget.dungeonLevel, stageNum);
        _currentEnemies = enemyTemplates
            .map((e) => BattleUnit.enemy(e.$1, e.$2, e.$3, widget.dungeonLevel))
            .toList();
      }
      _isPlayerTurn = true;
      _attackerIndex = 0;
      _lastLog = widget.isMapBattle ? "야생 달리몬과의 전투!" : "STAGE $stageNum 시작!";
      _isAnimating = false;
      
      // Heal my team slightly between stages (30%)
      if (stageNum > 1) {
        for (var u in _myTeam) {
          if (u.isAlive) {
            u.hp = min(u.maxHp, u.hp + (u.maxHp * 0.3).round());
          }
        }
      }
      
      // If first pet is dead, find next alive one
      _findNextAttacker();
    });
  }

  void _findNextAttacker() {
    while (_attackerIndex < _myTeam.length && !_myTeam[_attackerIndex].isAlive) {
      _attackerIndex++;
    }
    
    if (_attackerIndex >= _myTeam.length) {
      // All pets acted, now enemy turn
      _startEnemyTurn();
    }
  }

  Future<void> _handlePlayerAction(bool isMagic) async {
    if (!_isPlayerTurn || _isAnimating || _done) return;

    final attacker = _myTeam[_attackerIndex];
    final livingEnemies = _currentEnemies.where((e) => e.isAlive).toList();
    
    if (livingEnemies.isEmpty) return;
    
    // Pick random target among living enemies
    final target = livingEnemies[_rng.nextInt(livingEnemies.length)];

    setState(() {
      _isAnimating = true;
    });

    // 1. Attack Logic
    final mult = typeMultiplier(attacker.type, target.type);
    final isCrit = _rng.nextDouble() < attacker.critRate;
    
    // Physical (atk) vs Magic (matk)
    final attackPower = isMagic ? attacker.matk : attacker.atk;
    final raw = attackPower - target.def ~/ 2;
    final dmg = max(1, ((raw * mult * (isCrit ? 1.5 : 1.0))).round());

    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!mounted) return;
    setState(() {
      target.takeDamage(dmg);
      _latestDamage = dmg;
      _isCrit = isCrit;
      _lastLog = "${attacker.name}의 ${isMagic ? "마법" : "물리"} 공격! -${dmg}HP";
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() {
      _latestDamage = null;
      if (!target.isAlive) {
        _lastLog = "💀 ${target.name} 쓰러짐!";
      }
    });

    if (_currentEnemies.every((e) => !e.isAlive)) {
      // Stage Cleared
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      if (_currentStage < _maxStages) {
        _startStage(_currentStage + 1);
      } else {
        setState(() {
          _done = true;
          _won = true;
          _lastLog = "🎉 모든 스테이지 클리어!";
        });
      }
    } else {
      setState(() {
        _attackerIndex++;
        _isAnimating = false;
        _findNextAttacker();
      });
    }
  }

  Future<void> _startEnemyTurn() async {
    setState(() {
      _isPlayerTurn = false;
      _isAnimating = true;
      _lastLog = "적의 턴...";
    });

    await Future.delayed(const Duration(milliseconds: 400));

    for (final attacker in _currentEnemies.where((e) => e.isAlive)) {
      if (!mounted) return;
      
      final livingPets = _myTeam.where((u) => u.isAlive).toList();
      if (livingPets.isEmpty) break;

      final target = livingPets[_rng.nextInt(livingPets.length)];
      final mult = typeMultiplier(attacker.type, target.type);
      final raw = attacker.atk - target.def ~/ 2;
      final dmg = max(1, (raw * mult).round());

      setState(() {
        target.takeDamage(dmg);
        _latestDamage = dmg;
        _isCrit = false;
        _lastLog = "${attacker.name}의 반격! ${target.name}에게 -${dmg}HP";
      });

      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      setState(() {
        _latestDamage = null;
        if (!target.isAlive) {
          _lastLog = "💀 ${target.name} 쓰러짐!";
        }
      });
      
      if (_myTeam.every((u) => !u.isAlive)) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;

    if (_myTeam.every((u) => !u.isAlive)) {
      setState(() {
        _done = true;
        _won = false;
        _lastLog = "💀 던전 실패...";
        _isAnimating = false;
      });
    } else {
      setState(() {
        _isPlayerTurn = true;
        _attackerIndex = 0;
        _isAnimating = false;
        _lastLog = "당신의 턴!";
        _findNextAttacker();
      });
    }
  }

  int get _expGained {
    final dungeon = DungeonDef(level: widget.dungeonLevel);
    return _won ? dungeon.clearExp : dungeon.failExp;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done,
      child: Scaffold(
        backgroundColor: widget.isMapBattle ? const Color(0xFF0D1B1E) : const Color(0xFF0A0518),
        body: Container(
          decoration: widget.isMapBattle ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF0D1B1E), Colors.black.withOpacity(0.9)],
            ),
          ) : null,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildEnemyRow(),
                _buildDamageDisplay(),
                _buildVsDivider(),
                _buildMyTeamRow(),
                const Spacer(),
                _buildLogBar(),
                if (!_done && _isPlayerTurn && !_isAnimating) _buildActionButtons(),
                if (_done) _buildResultBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(widget.isMapBattle ? '야생 탐험' : '던전 Lv.${widget.dungeonLevel}',
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isMapBattle ? const Color(0xFF2E7D32).withOpacity(0.3) : const Color(0xFF1A3A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withOpacity(0.5)),
            ),
            child: Text(
              widget.isMapBattle ? '야외 시합' : 'STAGE $_currentStage/$_maxStages',
              style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnemyRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _currentEnemies
            .map((e) => _UnitCard(unit: e, isEnemy: true))
            .toList(),
      ),
    );
  }

  Widget _buildDamageDisplay() {
    return SizedBox(
      height: 70,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _latestDamage != null
              ? Text(
                  key: ValueKey(_latestDamage! + _rng.nextInt(1000)),
                  '-$_latestDamage ${_isCrit ? "💥" : "✦"}',
                  style: TextStyle(
                    color: _isCrit ? AppColors.accent : AppColors.danger,
                    fontSize: _isCrit ? 32 : 26,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: (_isCrit ? AppColors.accent : AppColors.danger)
                            .withOpacity(0.6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildVsDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white12, height: 1)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('VS',
                style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
          ),
          Expanded(child: Divider(color: Colors.white12, height: 1)),
        ],
      ),
    );
  }

  Widget _buildMyTeamRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_myTeam.length, (index) {
          final unit = _myTeam[index];
          final isAttacker = _isPlayerTurn && index == _attackerIndex && !_isAnimating && !_done;
          
          return Column(
            children: [
              _UnitCard(unit: unit, isEnemy: false),
              if (isAttacker)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLogBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(_lastLog,
                style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          if (_isAnimating && !_done)
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final attacker = _myTeam[_attackerIndex];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF141025),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          Text('${attacker.name}의 차례 (ATK: ${attacker.atk} / MATK: ${attacker.matk})',
              style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BattleActionButton(
                  label: '물리 공격',
                  icon: Icons.flash_on,
                  color: AppColors.primary,
                  onPressed: () => _handlePlayerAction(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BattleActionButton(
                  label: '마법 공격',
                  icon: Icons.auto_fix_high,
                  color: Colors.purpleAccent,
                  onPressed: () => _handlePlayerAction(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: _won ? const Color(0xFF0D2A0D) : const Color(0xFF2A0D0D),
        border: Border(
          top: BorderSide(color: _won ? AppColors.success : AppColors.danger, width: 2),
        ),
      ),
      child: Row(
        children: [
          Text(
            _won ? '🏆 승리!' : '💀 패배...',
            style: TextStyle(
                color: _won ? AppColors.success : AppColors.danger,
                fontSize: 18,
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Text('+$_expGained EXP',
              style: const TextStyle(
                  color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'won': _won,
              'expGained': _expGained,
              'level': widget.dungeonLevel,
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: _won ? AppColors.success : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('돌아가기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────

class _BattleActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _BattleActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final BattleUnit unit;
  final bool isEnemy;
  const _UnitCard({required this.unit, required this.isEnemy});

  @override
  Widget build(BuildContext context) {
    final typeColor = unit.type.color;
    final alive = unit.isAlive;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: alive ? 1.0 : 0.25,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [typeColor.withOpacity(0.15), Colors.black45],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: alive ? typeColor.withOpacity(0.5) : Colors.white10),
          boxShadow: alive ? [BoxShadow(color: typeColor.withOpacity(0.1), blurRadius: 8)] : null,
        ),
        child: Column(
          children: [
            Text(unit.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 4),
            Text(unit.name,
                style: const TextStyle(color: AppColors.text, fontSize: 10, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: unit.hpRatio,
                minHeight: 4,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  unit.hpRatio > 0.5 ? AppColors.success : (unit.hpRatio > 0.25 ? Colors.orange : AppColors.danger),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text('${unit.hp}/${unit.maxHp}', style: const TextStyle(color: AppColors.textHint, fontSize: 8)),
          ],
        ),
      ),
    );
  }
}
