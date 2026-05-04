import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../core/theme.dart';
import '../domain/dallimmon.dart';
import '../domain/dungeon.dart';
import '../domain/pet_type.dart';
import '../state/game_notifier.dart';
import 'dungeon_battle_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'pvp_battle_screen.dart';

class MapDungeonScreen extends ConsumerStatefulWidget {
  const MapDungeonScreen({super.key});

  @override
  ConsumerState<MapDungeonScreen> createState() => _MapDungeonScreenState();
}

class _MapDungeonScreenState extends ConsumerState<MapDungeonScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _moveController;
  LatLng? _animStartLocation;
  LatLng? _animTargetLocation;
  Timer? _moveTimer;
  StreamSubscription? _raidSubscription;

  bool _isSearching = true;
  bool _isPvPMode = false;
  int _selectedIndex = 0;
  double _currentRotation = 45.0; // 쿼터뷰 기본 각도 (다이아몬드 형태)
  
  LatLng? _currentLocation;
  final MapController _mapController = MapController();

  final List<(String, String, String, String, PetType, String, LatLng)> _mapDungeons = [];
  final List<(PvPOpponent, LatLng)> _challengers = [];
  (String, int, String, LatLng)? _raidBoss; // (이름, 레벨, 거리 문자열, 좌표)
  bool _isRaidSelected = false;
  List<Map<String, dynamic>> _serverRaidsData = []; // 반경 내 보스들 저장용

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

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_animStartLocation != null && _animTargetLocation != null) {
          final t = Curves.easeInOutCubic.transform(_moveController.value);
          final lat = _animStartLocation!.latitude + (_animTargetLocation!.latitude - _animStartLocation!.latitude) * t;
          final lng = _animStartLocation!.longitude + (_animTargetLocation!.longitude - _animStartLocation!.longitude) * t;
          setState(() {
            _currentLocation = LatLng(lat, lng);
            _mapController.move(_currentLocation!, _mapController.camera.zoom);
            _updateDistances();
          });
        }
      });

    _initLocation();
    _subscribeToWorldRaids();
  }

  void _subscribeToWorldRaids() {
    if (_currentLocation == null) return;
    
    print("📡 [서버 연결 시도] 내 위치 주변 5km 레이드 스캔 중..."); 

    final geoCollection = GeoCollectionReference(FirebaseFirestore.instance.collection('world_raids'));
    
    _raidSubscription?.cancel();
    _raidSubscription = geoCollection.subscribeWithin(
      center: GeoFirePoint(GeoPoint(_currentLocation!.latitude, _currentLocation!.longitude)),
      radiusInKm: 5.0,
      field: 'geo',
      geopointFrom: (data) => (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
      queryBuilder: (query) => query.where('status', isEqualTo: 'active'),
      strictMode: true,
    ).listen((docs) {
      print("🔥 [서버 데이터 수신] 5km 반경 내 보스 마리 수: ${docs.length}"); 
      _serverRaidsData = docs.map((d) => d.data() as Map<String, dynamic>).toList();
      _updateRaidBossFromData();
    }, onError: (error) {
      print("❌ [Firestore 에러] 원인: $error"); 
    });
  }

  void _updateRaidBossFromData() {
    if (_serverRaidsData.isEmpty || _currentLocation == null) {
      setState(() => _raidBoss = null);
      return;
    }

    Map<String, dynamic>? closestRaid;
    double minDistance = double.infinity;
    LatLng? closestPos;

    for (final data in _serverRaidsData) {
      double raidLat = 0;
      double raidLng = 0;

      if (data['location'] is GeoPoint) {
        GeoPoint gp = data['location'];
        raidLat = gp.latitude;
        raidLng = gp.longitude;
      } else if (data['location'] is Map) {
        final loc = data['location'] as Map;
        GeoPoint? nestedGp;
        loc.forEach((key, value) {
          if (value is GeoPoint) nestedGp = value;
        });

        if (nestedGp != null) {
          raidLat = nestedGp!.latitude;
          raidLng = nestedGp!.longitude;
        } else {
          final latVal = loc['lat'] ?? loc['latitude'];
          final lngVal = loc['lng'] ?? loc['longitude'];
          if (latVal != null && lngVal != null) {
            raidLat = (latVal as num).toDouble();
            raidLng = (lngVal as num).toDouble();
          } else {
            continue; // 좌표 오류 패스
          }
        }
      } else {
        continue; // 형식 오류 패스
      }

      double dLat = (_currentLocation!.latitude - raidLat) * 111000;
      double dLng = (_currentLocation!.longitude - raidLng) * 111000 * cos(_currentLocation!.latitude * pi / 180);
      double dist = sqrt(dLat * dLat + dLng * dLng);

      if (dist < minDistance) {
        minDistance = dist;
        closestRaid = data;
        closestPos = LatLng(raidLat, raidLng);
      }
    }

    if (closestRaid != null && closestPos != null) {
      setState(() {
        _raidBoss = (
          closestRaid!['bossName'] ?? '미지의 보스',
          (closestRaid!['level'] as num?)?.toInt() ?? 1,
          '${minDistance.toInt()}m',
          closestPos!
        );
      });
    } else {
      setState(() => _raidBoss = null);
    }
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
    _subscribeToWorldRaids();
    
    if (mounted) {
      setState(() => _isSearching = false);
    }
  }
  
  void _useFallbackLocation() {
    // 강남역 부근 Fallback
    _currentLocation = const LatLng(37.498095, 127.027610);
    _generateSurroundingEntities();
    _subscribeToWorldRaids();
    if (mounted) {
      setState(() => _isSearching = false);
    }
  }
  
  bool _isTooClose(LatLng pos, double minRadius) {
    if (_currentLocation == null) return true;
    
    // 플레이어와의 거리 체크
    double dLatP = (_currentLocation!.latitude - pos.latitude) * 111000;
    double dLngP = (_currentLocation!.longitude - pos.longitude) * 111000 * cos(_currentLocation!.latitude * pi / 180);
    if (sqrt(dLatP*dLatP + dLngP*dLngP) < minRadius) return true;

    // 다른 던전과의 거리 체크
    for (var existing in _mapDungeons) {
      double dLat = (existing.$7.latitude - pos.latitude) * 111000;
      double dLng = (existing.$7.longitude - pos.longitude) * 111000 * cos(_currentLocation!.latitude * pi / 180);
      if (sqrt(dLat*dLat + dLng*dLng) < minRadius) return true;
    }
    // 도전자와의 거리 체크
    for (var existing in _challengers) {
      double dLat = (existing.$2.latitude - pos.latitude) * 111000;
      double dLng = (existing.$2.longitude - pos.longitude) * 111000 * cos(_currentLocation!.latitude * pi / 180);
      if (sqrt(dLat*dLat + dLng*dLng) < minRadius) return true;
    }
    return false;
  }

  void _generateSurroundingEntities() {
    if (_currentLocation == null) return;
    
    _mapDungeons.clear();
    _challengers.clear();
    _raidBoss = null;
    
    // BUG FIX: 선택된 인덱스 초기화 방지 로직 (범위 밖 접근 방지)
    _selectedIndex = 0;
    _isRaidSelected = false;
    
    final lat = _currentLocation!.latitude;
    final lng = _currentLocation!.longitude;
    final today = DateTime.now().day;
    
    // 격자 크기 설정 (약 100m)
    final double gridLat = 0.0009;
    final double gridLng = 0.0009 / cos(lat * pi / 180);
    
    final int centerGridX = (lat / gridLat).floor();
    final int centerGridY = (lng / gridLng).floor();
    
    // 주변 10x10 격자 순회 (반경 약 500m)
    for (int dx = -5; dx <= 5; dx++) {
      for (int dy = -5; dy <= 5; dy++) {
        int gx = centerGridX + dx;
        int gy = centerGridY + dy;
        
        // 고유 시드 생성 (격자 X좌표 + 격자 Y좌표 + 오늘 날짜)
        int seed = gx ^ (gy << 16) ^ today;
        Random r = Random(seed);
        
        double chance = r.nextDouble();
        
        // 격자 내에서 몬스터가 뜰 고정된 위치 (셀 중앙부 40% 구역 안에서 랜덤)
        // 이를 통해 던전 간 겹침이 수학적으로 발생하지 않음 (최소 60m 이상 이격 보장)
        double spawnLat = (gx + 0.3 + r.nextDouble() * 0.4) * gridLat;
        double spawnLng = (gy + 0.3 + r.nextDouble() * 0.4) * gridLng;
        LatLng pos = LatLng(spawnLat, spawnLng);
        
        // 플레이어와의 거리 계산
        double distLat = (lat - spawnLat) * 111000;
        double distLng = (lng - spawnLng) * 111000 * cos(lat * pi / 180);
        double distMeters = sqrt(distLat*distLat + distLng*distLng);
        
        if (distMeters > 500) continue; // 500m 밖은 무시
        
        if (chance < 0.25) {
          // 25% 확률로 던전 스폰
          var t = _dungeonTemplates[r.nextInt(_dungeonTemplates.length)];
          _mapDungeons.add((t.$1, t.$2, t.$3, t.$4, t.$5, '${distMeters.toInt()}m', pos));
        } else if (chance < 0.35) {
          // 10% 확률로 도전자 스폰
          var opp = PvPOpponent(
            name: '도전자 ${gx.abs() % 100}${gy.abs() % 100}', 
            level: 5 + r.nextInt(20), 
            team: [
              OwnedDallimmon(defId: r.nextInt(10), level: r.nextInt(20) + 1),
              OwnedDallimmon(defId: r.nextInt(10), level: r.nextInt(20) + 1),
            ]
          );
          _challengers.add((opp, pos));
        }
      }
    }
    // 기존 임시 랜덤 레이드 보스 생성 로직 제거 (이제 서버 데이터를 사용함)
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _moveController.dispose();
    _moveTimer?.cancel();
    _raidSubscription?.cancel();
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
            
          // 5. Movement Test D-Pad
          if (_currentLocation != null && !_isSearching)
            Positioned(
              left: 16,
              bottom: 340, // 하단 UI 위쪽
              child: _buildDPad(),
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

  // ── Test D-Pad ───────────────────────────────────────────
  void _startContinuousMove(double dx, double dy) {
    _moveLocationScreen(dx, dy); // 처음 한 번 이동
    _moveTimer?.cancel();
    _moveTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _moveLocationScreen(dx, dy);
    });
  }

  void _stopContinuousMove() {
    _moveTimer?.cancel();
    _moveTimer = null;
  }

  Widget _buildDPad() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dPadButton(Icons.north_west, () => _startContinuousMove(-0.0000135, 0.0000135), _stopContinuousMove),
              const SizedBox(width: 4),
              _dPadButton(Icons.arrow_upward, () => _startContinuousMove(0, 0.0000135), _stopContinuousMove),
              const SizedBox(width: 4),
              _dPadButton(Icons.north_east, () => _startContinuousMove(0.0000135, 0.0000135), _stopContinuousMove),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dPadButton(Icons.arrow_back, () => _startContinuousMove(-0.0000135, 0), _stopContinuousMove),
              const SizedBox(width: 44, height: 40), // 중앙 빈 공간
              _dPadButton(Icons.arrow_forward, () => _startContinuousMove(0.0000135, 0), _stopContinuousMove),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dPadButton(Icons.south_west, () => _startContinuousMove(-0.0000135, -0.0000135), _stopContinuousMove),
              const SizedBox(width: 4),
              _dPadButton(Icons.arrow_downward, () => _startContinuousMove(0, -0.0000135), _stopContinuousMove),
              const SizedBox(width: 4),
              _dPadButton(Icons.south_east, () => _startContinuousMove(0.0000135, -0.0000135), _stopContinuousMove),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dPadButton(IconData icon, VoidCallback onStart, VoidCallback onStop) {
    return GestureDetector(
      onTapDown: (_) => onStart(),
      onTapUp: (_) => onStop(),
      onTapCancel: () => onStop(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.8),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  void _moveLocationScreen(double dx, double dy) {
    if (_currentLocation == null) return;
    
    // 현재 카메라 회전값(도)을 라디안으로 변환
    // 쿼터뷰에서 화면의 상하좌우가 실제 지도의 방향과 맞도록 보정
    double r = -_currentRotation * pi / 180; 
    
    double latOffset = dy * cos(r) - dx * sin(r);
    // 경도는 위도에 따라 거리가 달라지므로 cos(latitude)로 보정
    double lngOffset = (dx * cos(r) + dy * sin(r)) / cos(_currentLocation!.latitude * pi / 180);
    
    _animStartLocation = _currentLocation;
    _animTargetLocation = LatLng(
      _currentLocation!.latitude + latOffset, 
      _currentLocation!.longitude + lngOffset
    );
    
    _moveController.forward(from: 0.0);
    
    // 실제 걸음 수 반영 (+2보) -> EXP 획득, 알 부화, 퀘스트 등에 자동 적용됨
    ref.read(gameProvider.notifier).addSteps(2);
  }

  void _updateDistances() {
    if (_currentLocation == null) return;
    
    for (int i = 0; i < _mapDungeons.length; i++) {
      var d = _mapDungeons[i];
      // 간단한 피타고라스 거리 계산 (m 단위 근사치)
      double latDiff = (d.$7.latitude - _currentLocation!.latitude) * 111000;
      double lngDiff = (d.$7.longitude - _currentLocation!.longitude) * 111000 * cos(_currentLocation!.latitude * pi / 180);
      double dist = sqrt(latDiff * latDiff + lngDiff * lngDiff);
      
      _mapDungeons[i] = (d.$1, d.$2, d.$3, d.$4, d.$5, '${dist.toInt()}m', d.$7);
    }

    // 반경 5km 스캔 리스트가 있다면 다시 갱신
    if (_serverRaidsData.isNotEmpty) {
      _updateRaidBossFromData();
    }
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 30),
                      // 튜토리얼용 2.5D 스프라이트 GIF 적용 예시
                      // 실제 게임에서는 Image.asset('assets/images/my_character.gif') 로 변경하시면 됩니다!
                      Image.network(
                        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/25.gif',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person_pin_circle, color: AppColors.primary, size: 40);
                        },
                      ),
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
        width: 100, // 너비를 넉넉하게 주어 오버플로우 방지
        height: 160, // 던전 이미지 교체 후 약간 커진 전체 높이(142px)를 커버하기 위해 160으로 여유 할당
        alignment: Alignment.topCenter,
        rotate: true,
        child: RepaintBoundary( // <--- 회전 시 렉 최소화를 위한 렌더링 캐싱
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = i;
                _isRaidSelected = false;
              });
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

    // 레이드 보스 마커 추가
    if (_raidBoss != null) {
      final raidM = Marker(
        point: _raidBoss!.$4,
        width: 140, // 거대 보스이므로 너비를 넓게
        height: 200, // 높이도 넓게
        alignment: Alignment.topCenter,
        rotate: true,
        child: RepaintBoundary(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isRaidSelected = true;
                // 기존 다른 선택 해제
                // _selectedIndex = 0; // 이건 딱히 의미 없을지도
              });
            },
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()..rotateX(-mapTilt),
              child: _RaidMarker(
                distance: _raidBoss!.$3,
                isSelected: _isRaidSelected,
              ),
            ),
          ),
        ),
      );
      
      // 선택된 경우 가장 위에 그리도록
      if (_isRaidSelected) {
        markers.add(raidM);
      } else {
        markers.insert(1, raidM); // 본인 위치 바로 다음으로 (다른 것들 아래)
      }
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
            maxWidth: constraints.maxWidth * 1.5, // 회전 렉 방지를 위해 불필요하게 넓은 공간 축소 (기존 2.0 -> 1.5)
            maxHeight: constraints.maxHeight * 1.9, // 기존 2.5 -> 1.9
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
                  tileProvider: CancellableNetworkTileProvider(),
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
    if (_isRaidSelected && _raidBoss != null) {
      return _buildRaidOverlay();
    }

    final count = _isPvPMode ? _challengers.length : _mapDungeons.length;
    final typeText = _isPvPMode ? '도전자' : '던전';

    if (count == 0) return const SizedBox();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
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

  Widget _buildRaidOverlay() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.red.shade900, width: 2)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.whatshot, color: Colors.redAccent, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔴 월드 레이드 출현!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text(
                      '${_raidBoss!.$1} (Lv.${_raidBoss!.$2})',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Text(_raidBoss!.$3, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
                shadowColor: Colors.redAccent,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('레이드 전투는 업데이트 준비 중입니다!')),
                );
              },
              child: const Text('레이드 입장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
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
    bool isPvP = distance == 'PvP';

    if (!isPvP) {
      // 🌟 새로운 판타지 던전 이미지 모드
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 36),
            ),
          // 거리 표시 라벨
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              distance,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          // 던전 3D 에셋 이미지 (테두리 및 배경 박스 모두 제거)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 80 : 64,
            height: isSelected ? 80 : 64,
            child: ColorFiltered(
              // 속성 색상을 은은하게 입힘
              colorFilter: ColorFilter.mode(color.withOpacity(0.3), BlendMode.srcATop),
              child: Image.asset(
                'assets/images/dungeon.png',
                fit: BoxFit.contain, // 원형 클리핑 없이 이미지 원본 비율 유지
              ),
            ),
          ),
        ],
      );
    }

    // 🧑 기존 PvP 도전자 모드 (박스 스타일 유지)
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 36),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            border: Border.all(color: Colors.transparent, width: 0),
          ),
          child: Text(
            distance,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 50 : 42,
          height: isSelected ? 66 : 56,
          decoration: BoxDecoration(
            color: color.withOpacity(isSelected ? 0.9 : 0.6),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4), 
              topRight: Radius.circular(4), 
              bottomLeft: Radius.circular(12), 
              bottomRight: Radius.circular(12)
            ),
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

class _RaidMarker extends StatelessWidget {
  final bool isSelected;
  final String distance;

  const _RaidMarker({
    required this.isSelected,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Icon(Icons.keyboard_arrow_down, color: Colors.redAccent, size: 40),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.redAccent, blurRadius: 8),
            ]
          ),
          child: Text(
            'RAID: $distance',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 6),
        // 레이드 에셋 (드래곤)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 120 : 96,
          height: isSelected ? 120 : 96,
          child: Image.asset(
            'assets/images/dragon.png',
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
