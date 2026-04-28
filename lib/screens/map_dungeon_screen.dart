import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../domain/dallimmon.dart';
import '../domain/dungeon.dart';
import '../domain/pet_type.dart';
import '../state/game_notifier.dart';
import 'dungeon_battle_screen.dart';
import 'pvp_battle_screen.dart';

class MapDungeonScreen extends ConsumerStatefulWidget {
  const MapDungeonScreen({super.key});

  @override
  ConsumerState<MapDungeonScreen> createState() => _MapDungeonScreenState();
}

class _MapDungeonScreenState extends ConsumerState<MapDungeonScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isSearching = true;
  bool _isPvPMode = false;
  int _selectedIndex = 0;

  final List<(String, String, PetType, String)> _wildDallimmons = [
    ('화염술사', '🔥', PetType.fire, '150m'),
    ('바위거인', '⛰️', PetType.earth, '320m'),
    ('바람정령', '🌪️', PetType.wind, '480m'),
  ];

  final List<PvPOpponent> _challengers = [
    PvPOpponent(
      name: '동네고수', 
      level: 12, 
      team: [
        OwnedDallimmon(defId: 0, level: 10),
        OwnedDallimmon(defId: 4, level: 8),
        OwnedDallimmon(defId: 1, level: 5),
      ]
    ),
    PvPOpponent(
      name: '길가던행인', 
      level: 5, 
      team: [
        OwnedDallimmon(defId: 2, level: 4),
        OwnedDallimmon(defId: 3, level: 3),
      ]
    ),
    PvPOpponent(
      name: '챌린저K', 
      level: 45, 
      team: [
        OwnedDallimmon(defId: 7, level: 42),
        OwnedDallimmon(defId: 11, level: 40),
        OwnedDallimmon(defId: 5, level: 38),
        OwnedDallimmon(defId: 10, level: 35),
        OwnedDallimmon(defId: 8, level: 35),
      ]
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _simulateSearch();
  }

  void _simulateSearch() {
    setState(() => _isSearching = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startMapBattle() {
    if (_isPvPMode) {
      _startPvPBattle();
      return;
    }

    final gs = ref.read(gameProvider);
    final party = gs.partyIndices
        .where((idx) => idx < gs.dallimmons.length)
        .map((idx) => gs.dallimmons[idx])
        .toList();

    if (party.isEmpty) {
      _showError('파티가 설정되어 있지 않습니다.');
      return;
    }

    final selectedWild = _wildDallimmons[_selectedIndex];
    final level = (gs.highestDungeonCleared + 1).clamp(1, 100);
    final enemy = BattleUnit.enemy(selectedWild.$1, selectedWild.$2, selectedWild.$3, level);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DungeonBattleScreen(
          dungeonLevel: level,
          partyDallimmons: party,
          isMapBattle: true,
          customEnemies: [enemy],
        ),
      ),
    ).then((result) {
      if (result is Map && context.mounted) {
        ref.read(gameProvider.notifier).onDungeonResult(
          won: result['won'] as bool,
          expGained: result['expGained'] as int,
          dungeonLevel: result['level'] as int,
        );
        _simulateSearch();
      }
    });
  }

  void _startPvPBattle() {
    final gs = ref.read(gameProvider);
    final party = gs.partyIndices
        .where((idx) => idx < gs.dallimmons.length)
        .map((idx) => gs.dallimmons[idx])
        .toList();

    if (party.isEmpty) {
      _showError('파티가 설정되어 있지 않습니다.');
      return;
    }

    final opponent = _challengers[_selectedIndex];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PvPBattleScreen(
          opponent: opponent,
          myTeamOwned: party,
          myPlayerLevel: gs.playerLevel,
        ),
      ),
    ).then((result) {
      if (result is Map && context.mounted) {
        ref.read(gameProvider.notifier).onPvPResult(
          won: result['won'] as bool,
          points: result['points'] as int,
          tokens: result['tokens'] as int,
        );
        _simulateSearch();
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0518),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('주변 탐색', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('PvP 모드', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Switch(
                    value: _isPvPMode, 
                    onChanged: (v) => setState(() {
                      _isPvPMode = v;
                      _selectedIndex = 0;
                    }),
                    activeColor: AppColors.accent,
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildMapGrid(),
          if (_isSearching)
            _buildSearchingOverlay()
          else
            _buildFoundOverlay(),
        ],
      ),
    );
  }

  Widget _buildMapGrid() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF0D1120)),
      child: CustomPaint(
        painter: GridPainter(),
        child: Container(),
      ),
    );
  }

  Widget _buildSearchingOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 200 * _pulseController.value,
                    height: 200 * _pulseController.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(1 - _pulseController.value), width: 2),
                    ),
                  ),
                  const Icon(Icons.my_location, color: AppColors.primary, size: 40),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          const Text('주변을 스캔하고 있습니다...', 
              style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFoundOverlay() {
    final count = _isPvPMode ? _challengers.length : _wildDallimmons.length;
    final typeText = _isPvPMode ? '도전자' : '야생 달리몬';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationCard(count, typeText),
          const Spacer(),
          Text('발견된 $typeText (대상을 선택하세요)', 
              style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              itemBuilder: (context, index) {
                if (_isPvPMode) {
                  final opp = _challengers[index];
                  return _ChallengerCard(
                    opponent: opp,
                    isSelected: _selectedIndex == index,
                    onTap: () => setState(() => _selectedIndex = index),
                  );
                } else {
                  final wild = _wildDallimmons[index];
                  return _WildCard(
                    name: wild.$1,
                    emoji: wild.$2,
                    dist: wild.$4,
                    isSelected: _selectedIndex == index,
                    onTap: () => setState(() => _selectedIndex = index),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildBattleButton(),
        ],
      ),
    );
  }

  Widget _buildLocationCard(int count, String typeText) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_fixed, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('현재 위치: 강남역 인근', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                Text('반경 500m 내에 $count명의 $typeText이 있습니다.', style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleButton() {
    final name = _isPvPMode ? _challengers[_selectedIndex].name : _wildDallimmons[_selectedIndex].$1;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _startMapBattle,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isPvPMode ? AppColors.accent : AppColors.primary,
          foregroundColor: _isPvPMode ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
        ),
        child: Text('$name와 ${_isPvPMode ? "PvP 배틀" : "전투"} 시작', 
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _WildCard extends StatelessWidget {
  final String name, emoji, dist;
  final bool isSelected;
  final VoidCallback onTap;

  const _WildCard({required this.name, required this.emoji, required this.dist, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1),
            const Spacer(),
            Text(dist, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _ChallengerCard extends StatelessWidget {
  final PvPOpponent opponent;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChallengerCard({required this.opponent, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.cardBorder, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            const Icon(Icons.person, color: AppColors.accent, size: 36),
            const SizedBox(height: 8),
            Text(opponent.name, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1),
            Text('Lv.${opponent.level}', style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
            const Spacer(),
            Text('${opponent.team.length}마리', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 1.0;
    const step = 40.0;
    for (double i = 0; i < size.width; i += step) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += step) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
