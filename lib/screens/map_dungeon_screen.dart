import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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
  double _currentRotation = 45.0; // 쿼터뷰 기본 각도 (다이아몬드 형태)
  
  LatLng? _currentLocation;
  final MapController _mapController = MapController();

  final List<(String, String, String, String, PetType, String, LatLng)> _mapDungeons = [];
  final List<(PvPOpponent, LatLng)> _challengers = [];
  bool _showNotice = true; // 공지사항 표시 여부 제어

  final List<(String, String, String, String, PetType)> _dungeonTemplates = [
    ('화산 던전', '🌋', '화염술사', '🔥', PetType.fire),
    ('바위 동굴', '🪨', '바위거인', '⛰️', PetType.earth),
    ('돌풍 계곡', '🌪️', '바람정령', '🌪️', PetType.wind),
    ('수정 호수', '🌊', '물방울', '💧', PetType.water),
    ('비밀의 숲', '🌲', '나무요정', '🌿', PetType.plant),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() => _isSearching = true);
    
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('위치 서비스를 활성화해주세요.');
      _useFallbackLocation();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('위치 권한이 거부되었습니다.');
        _useFallbackLocation();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('위치 권한이 영구적으로 거부되었습니다.');
      _useFallbackLocation();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _currentLocation = LatLng(position.latitude, position.longitude);
    } catch (e) {
      _useFallbackLocation();
    }
    
    _generateSurroundingEntities();
    
    if (mounted) {
      setState(() => _isSearching = false);
    }
  }
  
  void _useFallbackLocation() {
    // 강남역 부근 Fallback
    _currentLocation = const LatLng(37.498095, 127.027610);
    _generateSurroundingEntities();
    if (mounted) {
      setState(() => _isSearching = false);
    }
  }
  
  void _generateSurroundingEntities() {
    if (_currentLocation == null) return;
    
    final random = Random();
    _mapDungeons.clear();
    _challengers.clear();
    
    // BUG FIX: 선택된 인덱스 초기화 방지 로직 (범위 밖 접근 방지)
    _selectedIndex = 0; 
    
    // Generate 5-8 wild dallimmons within 500m
    int wildCount = 5 + random.nextInt(4);
    for (int i = 0; i < wildCount; i++) {
      var t = _dungeonTemplates[random.nextInt(_dungeonTemplates.length)];
      double dist = random.nextDouble() * 500;
      double angle = random.nextDouble() * pi * 2;
      double latOffset = (dist * cos(angle)) / 111000;
      double lngOffset = (dist * sin(angle)) / (111000 * cos(_currentLocation!.latitude * pi / 180));
      LatLng pos = LatLng(_currentLocation!.latitude + latOffset, _currentLocation!.longitude + lngOffset);
      _mapDungeons.add((t.$1, t.$2, t.$3, t.$4, t.$5, '${dist.toInt()}m', pos));
    }
    
    // Generate 3 challengers
    for (int i = 0; i < 3; i++) {
      double dist = 100 + random.nextDouble() * 400;
      double angle = random.nextDouble() * pi * 2;
      double latOffset = (dist * cos(angle)) / 111000;
      double lngOffset = (dist * sin(angle)) / (111000 * cos(_currentLocation!.latitude * pi / 180));
      LatLng pos = LatLng(_currentLocation!.latitude + latOffset, _currentLocation!.longitude + lngOffset);
      
      var opp = PvPOpponent(
        name: '도전자 ${i+1}', 
        level: 5 + random.nextInt(20), 
        team: [
          OwnedDallimmon(defId: random.nextInt(10), level: random.nextInt(20) + 1),
          OwnedDallimmon(defId: random.nextInt(10), level: random.nextInt(20) + 1),
        ]
      );
      _challengers.add((opp, pos));
    }
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

    if (_mapDungeons.isEmpty) return;

    final gs = ref.read(gameProvider);
    final party = gs.partyIndices
        .where((idx) => idx < gs.dallimmons.length)
        .map((idx) => gs.dallimmons[idx])
        .toList();

    if (party.isEmpty) {
      _showError('파티가 설정되어 있지 않습니다.');
      return;
    }

    final selected = _mapDungeons[_selectedIndex];
    final level = (gs.highestDungeonCleared + 1).clamp(1, 100);
    final enemy = BattleUnit.enemy(selected.$3, selected.$4, selected.$5, level);

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
        _initLocation();
      }
    });
  }

  void _startPvPBattle() {
    if (_challengers.isEmpty) return;

    final gs = ref.read(gameProvider);
    final party = gs.partyIndices
        .where((idx) => idx < gs.dallimmons.length)
        .map((idx) => gs.dallimmons[idx])
        .toList();

    if (party.isEmpty) {
      _showError('파티가 설정되어 있지 않습니다.');
      return;
    }

    final opponent = _challengers[_selectedIndex].$1;

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
        _initLocation();
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(int n) {
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n >= 1000) {
      final k = n ~/ 1000;
      final r = (n % 1000) ~/ 100;
      return r == 0 ? '${k}k' : '$k.${r}k';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD), // 밝은 하늘색 톤으로 변경 (포켓몬GO 느낌)
      body: Stack(
        children: [
          // 1. Map Layer
          _buildMap(),
          
          // 2. Top Bar (Home Screen Integration)
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(gs),
                if (gs.offlineExpPending > 0) _buildOfflineBanner(gs),
                const SizedBox(height: 12),
                _buildStepMockPanel(),
                
                // PvP Mode Toggle
                if (!_isSearching)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('PvP 모드', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(width: 4),
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
                    ),
                  ),
              ],
            ),
          ),
          
          // 3. Bottom Overlays
          if (_isSearching)
            _buildSearchingOverlay()
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildFoundOverlay()
            ),
            
          // 4. Zoom Controls
          if (_currentLocation != null)
            Positioned(
              right: 16,
              bottom: _isSearching ? 220 : 340, // 하단 UI 바로 위쪽
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapControlButton(Icons.add, () {
                    _mapController.move(_currentLocation!, _mapController.camera.zoom + 0.5);
                  }),
                  const SizedBox(height: 8),
                  _buildMapControlButton(Icons.remove, () {
                    _mapController.move(_currentLocation!, _mapController.camera.zoom - 0.5);
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black87,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  // ── Top stats bar (From old home_screen) ─────────────────
  Widget _buildTopBar(GameState gs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _StatChip(label: 'LEVEL', value: 'Lv.${gs.playerLevel}', valueColor: AppColors.primary),
          const SizedBox(width: 12),
          _StatChip(label: 'EXP', value: _fmt(gs.playerExp), valueColor: AppColors.accent),
          const SizedBox(width: 12),
          _StatChip(label: '오늘 걸음', value: '${_fmt(gs.todaySteps)}보', valueColor: Colors.white),
          const Spacer(),
          const Icon(Icons.notifications_none_rounded, color: AppColors.accent, size: 26),
        ],
      ),
    );
  }

  // ── Offline reward banner (From old home_screen) ─────────
  Widget _buildOfflineBanner(GameState gs) {
    return GestureDetector(
      onTap: () => ref.read(gameProvider.notifier).collectOfflineExp(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2A1A).withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Text('💤', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('오프라인 보상!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('방치 보상 → EXP +${_fmt(gs.offlineExpPending)}', style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
              child: const Text('수령!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step mock panel (From old home_screen) ───────────────
  Widget _buildStepMockPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('👟 걸음 추가 (테스트)', style: TextStyle(color: AppColors.textSub, fontSize: 11)),
          Row(
            children: [
              for (final s in [500, 1000, 5000])
                GestureDetector(
                  onTap: () => ref.read(gameProvider.notifier).addSteps(s),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text('+$s', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_currentLocation == null) {
      return Container(color: const Color(0xFFE3F2FD));
    }

    final double mapTilt = 45 * pi / 180; // 각도 감소 (조금 더 수직, 위에서 내려다보는 뷰)

    List<Marker> markers = [];
    
    // My Location Marker
    markers.add(
      Marker(
        point: _currentLocation!,
        width: 120,
        height: 120,
        rotate: true, // 맵 회전 시 마커가 같이 돌지 않게 고정
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Ground Radar (flat on the map)
                Container(
                  width: 120 * _pulseController.value,
                  height: 120 * _pulseController.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity((1 - _pulseController.value) * 0.4),
                    border: Border.all(color: AppColors.primary.withOpacity(1 - _pulseController.value), width: 2),
                  ),
                ),
                // Counter-rotated player indicator (stands up straight)
                Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()..rotateX(-mapTilt),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 30),
                      Icon(Icons.person_pin_circle, color: AppColors.primary, size: 40),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      )
    );

    // Entities Markers
    int listCount = _isPvPMode ? _challengers.length : _mapDungeons.length;
    List<Marker> unselectedMarkers = [];
    Marker? selectedMarker;

    for (int i = 0; i < listCount; i++) {
      LatLng pos = _isPvPMode ? _challengers[i].$2 : _mapDungeons[i].$7;
      bool isSelected = _selectedIndex == i;
      
      final emoji = _isPvPMode ? '🧑' : _mapDungeons[i].$2;
      final typeColor = _isPvPMode ? AppColors.accent : _mapDungeons[i].$5.color;
      final distanceStr = _isPvPMode ? 'PvP' : _mapDungeons[i].$6;

      final m = Marker(
        point: pos,
        width: 80,
        height: 120, // 높이를 넉넉하게 주어 텍스트와 박스가 잘리거나 어긋나지 않게 함
        alignment: Alignment.topCenter,
        rotate: true,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedIndex = i);
          },
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()..rotateX(-mapTilt),
            child: _Pseudo3DMarker(
              emoji: emoji,
              color: typeColor,
              isSelected: isSelected,
              distance: distanceStr,
            ),
          ),
        ),
      );

      if (isSelected) {
        selectedMarker = m;
      } else {
        unselectedMarkers.add(m);
      }
    }

    markers.addAll(unselectedMarkers);
    if (selectedMarker != null) {
      markers.add(selectedMarker);
    }

    return Listener(
      onPointerMove: (event) {
        if (event.delta.dx.abs() > 0.1) {
          _currentRotation -= event.delta.dx * 0.4; // 회전 감도 조절
          _mapController.rotate(_currentRotation);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
        return Transform.translate(
          offset: const Offset(0, -60), // 캐릭터가 하단 UI에 가려지지 않도록 위로 시프트
          child: OverflowBox(
            maxWidth: constraints.maxWidth * 2.0, // Make the map render larger
            maxHeight: constraints.maxHeight * 2.5,
            child: Transform(
              alignment: FractionalOffset.center,
              transform: Matrix4.identity()
                ..rotateX(mapTilt), // 원근감(perspective) 제거 -> 완전한 직교 투영(Orthographic) 쿼터뷰
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation!,
                  initialZoom: 16.5,
                  initialRotation: _currentRotation,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom, // Disable map rotation and drag to keep player centered
                  ),
              ),
              children: [
                TileLayer(
                  // Voyager style - 밝고 화사한 지도 (포켓몬GO 스타일)
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.dallimon_app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ),
        );
      }),
    );
  }

  Widget _buildSearchingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
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
            const Text('GPS 위치를 확인하고 주변을 스캔합니다...', 
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFoundOverlay() {
    final count = _isPvPMode ? _challengers.length : _mapDungeons.length;
    final typeText = _isPvPMode ? '도전자' : '던전';

    if (count == 0) return const SizedBox();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20), // 상단 패딩 살짝 조절
      child: Column(
        mainAxisSize: MainAxisSize.min, // 고정 높이 제거하고 내용물에 맞게 조절
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_showNotice) ...[
            _buildLocationCard(count, typeText),
            const SizedBox(height: 12),
          ],
          _buildDungeonInfoSection(),
          const SizedBox(height: 16),
          _buildBattleButton(),
        ],
      ),
    );
  }

  Widget _buildDungeonInfoSection() {
    if (_isPvPMode) {
      final opp = _challengers[_selectedIndex].$1;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.accent, size: 16),
            const SizedBox(width: 8),
            Text(
              '배틀 특성: PvP 포인트 보너스 확률 UP!',
              style: TextStyle(color: AppColors.accent.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final dungeon = _mapDungeons[_selectedIndex];
    final type = dungeon.$5;
    
    // CLAUDE.md 기반 타입별 특성 정의
    String trait = "";
    String bonusZone = "";
    switch (type) {
      case PetType.earth:
        trait = "반격 데미지 | DEF +40%, HP 회복↑";
        bonusZone = "자연·숲길 구역";
        break;
      case PetType.fire:
        trait = "선공 확률 높음 | ATK +30%";
        bonusZone = "도심·상업지구";
        break;
      case PetType.water:
        trait = "HP 회복·지속 데미지 | HP +30%";
        bonusZone = "강변·수변 공원";
        break;
      case PetType.wind:
        trait = "회피·카운터 강함 | SPD +25%";
        bonusZone = "공원·광장 구역";
        break;
      case PetType.plant:
        trait = "지속 성장·독 효과 | 밸런스형";
        bonusZone = "숲·정원·식물원";
        break;
      case PetType.dark:
        trait = "상태이상 유발 | 크리티컬 +20%";
        bonusZone = "야간 전용·지하도";
        break;
      case PetType.light:
        trait = "아군 버프·회복 | 전 스탯 +10%";
        bonusZone = "광장·명소·랜드마크";
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: type.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                type.label,
                style: TextStyle(color: type.color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dungeon.$1,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.accent, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '배틀 특성: $trait',
                      style: const TextStyle(color: AppColors.textSub, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.map, color: AppColors.primary, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '보너스 구역: $bonusZone',
                      style: const TextStyle(color: AppColors.textSub, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(int count, String typeText) {
    return GestureDetector(
      onTap: () {
        // 공지사항 클릭 시 퀘스트 탭(index 3)으로 이동
        ref.read(navIndexProvider.notifier).state = 3;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F36), // 공지사항 느낌의 어두운 청색
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 8, spreadRadius: 1)
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded, color: AppColors.accent, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📢 공지사항', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(text: '오늘의 이벤트는 '),
                            TextSpan(
                              text: '"바람 달리몬 EXP 획득 2배"', 
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)
                            ),
                            TextSpan(text: ' 입니다!'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24), // X 버튼 공간 확보
              ],
            ),
            // X 닫기 버튼
            Positioned(
              right: -8,
              top: -8,
              child: IconButton(
                onPressed: () {
                  setState(() => _showNotice = false);
                },
                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                splashRadius: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleButton() {
    if (_isPvPMode) {
        final name = _challengers[_selectedIndex].$1.name;
        return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
            onPressed: _startMapBattle,
            style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 8,
            ),
            child: Text('$name와 PvP 배틀 시작', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        );
    } else {
        final d = _mapDungeons[_selectedIndex];
        
        // 거리 파싱 ('m' 제거 후 int 변환)
        int distanceMeters = int.parse(d.$6.replaceAll('m', ''));
        bool isCloseEnough = distanceMeters <= 100;

        return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
            onPressed: isCloseEnough ? _startMapBattle : () {
                _showError('거리가 너무 멉니다! 던전에 입장하려면 100m 이내로 이동하세요.');
            },
            style: ElevatedButton.styleFrom(
            backgroundColor: isCloseEnough ? AppColors.primary : Colors.grey[800],
            foregroundColor: isCloseEnough ? Colors.white : Colors.grey[400],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 8,
            ),
            child: Text(
              isCloseEnough ? '${d.$1} 입장 (보스: ${d.$4} ${d.$3})' : '접근 필요 ($distanceMeters/100m)', 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
        ),
        );
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 9, letterSpacing: 1)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _WildCard extends StatelessWidget {
  final String name, emoji, dist;
  final PetType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _WildCard({
    required this.name, 
    required this.emoji, 
    required this.dist, 
    required this.type,
    required this.isSelected, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    // 타입별 약어 특성 (카드 내 표시용)
    String traitShort = "";
    switch (type) {
      case PetType.earth: traitShort = "DEF/반격"; break;
      case PetType.fire: traitShort = "ATK/선공"; break;
      case PetType.water: traitShort = "HP/지속"; break;
      case PetType.wind: traitShort = "SPD/카운터"; break;
      case PetType.plant: traitShort = "균형/독"; break;
      case PetType.dark: traitShort = "크리/저주"; break;
      case PetType.light: traitShort = "버프/회복"; break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? type.color.withOpacity(0.2) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? type.color : AppColors.cardBorder, 
            width: isSelected ? 2 : 1
          ),
          boxShadow: [
            if (isSelected) BoxShadow(color: type.color.withOpacity(0.3), blurRadius: 8)
          ],
        ),
        child: Column(
          children: [
            // 타입 아이콘 배지
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
                child: const Icon(Icons.star, size: 10, color: Colors.white),
              ),
            ),
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            // 특성 정보
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                traitShort,
                style: TextStyle(color: type.color, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            // 거리 표시 (작게)
            Text(
              dist, 
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSub, 
                fontSize: 11, 
                fontWeight: FontWeight.w600
              )
            ),
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
            const Icon(Icons.person, color: AppColors.accent, size: 32),
            const SizedBox(height: 4),
            Text(opponent.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1),
            Text('Lv.${opponent.level}', style: const TextStyle(color: AppColors.textSub, fontSize: 11)),
            const Spacer(),
            Text('${opponent.team.length}마리', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _Pseudo3DMarker extends StatelessWidget {
  final String emoji;
  final Color color;
  final bool isSelected;
  final String distance;

  const _Pseudo3DMarker({
    required this.emoji,
    required this.color,
    required this.isSelected,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selection Indicator
        if (isSelected)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 36),
          ),

        // Transparent Distance Label (Attached completely to the box)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6), // 반투명 배경
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            border: Border.all(color: Colors.transparent, width: 0),
          ),
          child: Text(
            distance,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),

        // Marker Body
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 50 : 42,
          height: isSelected ? 66 : 56,
          decoration: BoxDecoration(
            color: color.withOpacity(isSelected ? 0.9 : 0.6), // 선택 안 된 마커는 반투명하게
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4), 
              topRight: Radius.circular(4), 
              bottomLeft: Radius.circular(12), 
              bottomRight: Radius.circular(12)
            ), // 텍스트 박스와 자연스럽게 연결되도록 위쪽 모서리 곡률 감소
            boxShadow: [
              if (isSelected)
                BoxShadow(color: color, blurRadius: 20, spreadRadius: 5),
              BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 10, offset: const Offset(0, 5)),
            ],
            border: Border.all(color: Colors.white.withOpacity(isSelected ? 0.9 : 0.5), width: isSelected ? 3 : 1),
          ),
          child: Center(
            child: Container(
              width: isSelected ? 36 : 28,
              height: isSelected ? 36 : 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black45,
              ),
              child: Center(
                child: Text(emoji, style: TextStyle(fontSize: isSelected ? 20 : 16)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
