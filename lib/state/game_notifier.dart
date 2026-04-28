import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/dallimmon.dart';

// ── Step milestones (GDD v5) ─────────────────────────────
const _stepMilestones = [
  (steps: 500,   exp: 10,  label: '500보'),
  (steps: 1000,  exp: 25,  label: '1,000보'),
  (steps: 3000,  exp: 60,  label: '3,000보'),
  (steps: 5000,  exp: 120, label: '5,000보'),
  (steps: 10000, exp: 250, label: '10,000보'),
  (steps: 15000, exp: 400, label: '15,000보'),
];

// ── Immutable snapshot of game state ─────────────────────
class GameState {
  final bool onboardingDone;

  // Player (주인공)
  final int playerLevel;
  final int playerExp;
  final int totalSteps;
  final int todaySteps;

  // Resources
  final int normalTickets;
  final int offlineExpPending;

  // Dallimmons
  final List<OwnedDallimmon> dallimmons;
  final int activeDallimmonIndex;

  // Dungeon progress
  final int highestDungeonCleared;
  final int dungeonClearCount;

  // Quest progress (daily, reset each day)
  final int dungeonClearedToday;
  final int idleCollectedToday;
  final int newDallimmonToday;
  final String questResetDate; // yyyy-MM-dd
  final List<Egg> eggs;
  final List<int> partyIndices; // current team indices (up to 3)

  // PvP Stats (GDD v5)
  final int pvpPoints;
  final int victoryTokens;

  const GameState({
    this.onboardingDone = false,
    this.playerLevel = 1,
    this.playerExp = 0,
    this.totalSteps = 0,
    this.todaySteps = 0,
    this.normalTickets = 3,
    this.offlineExpPending = 0,
    this.dallimmons = const [],
    this.activeDallimmonIndex = 0,
    this.highestDungeonCleared = 0,
    this.dungeonClearCount = 0,
    this.dungeonClearedToday = 0,
    this.idleCollectedToday = 0,
    this.newDallimmonToday = 0,
    this.questResetDate = '',
    this.eggs = const [],
    this.partyIndices = const [0],
    this.pvpPoints = 1000,
    this.victoryTokens = 0,
  });

  int get playerExpToNext => playerLevel * 100;
  double get playerExpRatio =>
      (playerExp / playerExpToNext).clamp(0.0, 1.0);

  OwnedDallimmon? get activeDallimmon {
    if (dallimmons.isEmpty) return null;
    return dallimmons[activeDallimmonIndex.clamp(0, dallimmons.length - 1)];
  }

  Set<int> get discoveredDefIds =>
      dallimmons.map((d) => d.defId).toSet();

    GameState copyWith({
    bool? onboardingDone,
    int? playerLevel,
    int? playerExp,
    int? totalSteps,
    int? todaySteps,
    int? normalTickets,
    int? offlineExpPending,
    List<OwnedDallimmon>? dallimmons,
    int? activeDallimmonIndex,
    int? highestDungeonCleared,
    int? dungeonClearCount,
    int? dungeonClearedToday,
    int? idleCollectedToday,
    int? newDallimmonToday,
    String? questResetDate,
    List<Egg>? eggs,
    List<int>? partyIndices,
    int? pvpPoints,
    int? victoryTokens,
  }) =>
      GameState(
        onboardingDone: onboardingDone ?? this.onboardingDone,
        playerLevel: playerLevel ?? this.playerLevel,
        playerExp: playerExp ?? this.playerExp,
        totalSteps: totalSteps ?? this.totalSteps,
        todaySteps: todaySteps ?? this.todaySteps,
        normalTickets: normalTickets ?? this.normalTickets,
        offlineExpPending: offlineExpPending ?? this.offlineExpPending,
        dallimmons: dallimmons ?? this.dallimmons,
        activeDallimmonIndex:
            activeDallimmonIndex ?? this.activeDallimmonIndex,
        highestDungeonCleared:
            highestDungeonCleared ?? this.highestDungeonCleared,
        dungeonClearCount: dungeonClearCount ?? this.dungeonClearCount,
        dungeonClearedToday:
            dungeonClearedToday ?? this.dungeonClearedToday,
        idleCollectedToday: idleCollectedToday ?? this.idleCollectedToday,
        newDallimmonToday: newDallimmonToday ?? this.newDallimmonToday,
        questResetDate: questResetDate ?? this.questResetDate,
        eggs: eggs ?? this.eggs,
        partyIndices: partyIndices ?? this.partyIndices,
        pvpPoints: pvpPoints ?? this.pvpPoints,
        victoryTokens: victoryTokens ?? this.victoryTokens,
      );
}

// ── GameNotifier ──────────────────────────────────────────
class GameNotifier extends StateNotifier<GameState> {
  GameNotifier() : super(const GameState()) {
    _init();
  }

  final Random _rng = Random();
  Timer? _idleTimer;
  SharedPreferences? _prefs;
  bool _loaded = false;

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _load();
    _loaded = true;
    _checkQuestReset();
    _calculateOfflineExp();
    _startIdleTimer();
  }

  bool get isLoaded => _loaded;

  void _startIdleTimer() {
    // 20 EXP/min online = 1 EXP per 3 seconds
    _idleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _addPlayerExpSilent(1);
      _distributeToDallimmonsSilent(1);
      _saveLastOnline();
    });
  }

  void _calculateOfflineExp() {
    final prefs = _prefs;
    if (prefs == null) return;

    final lastStr = prefs.getString('last_online');
    if (lastStr == null) { _saveLastOnline(); return; }

    final last = DateTime.tryParse(lastStr);
    if (last == null) return;

    final offlineMins = DateTime.now().difference(last).inMinutes;
    if (offlineMins < 1) return;

    // 10 EXP/min offline, max 8 hours
    final capped = offlineMins.clamp(0, 480);
    final exp    = capped * 10;

    if (exp > 0) {
      state = state.copyWith(offlineExpPending: exp);
      _save();
    }
  }

  void _saveLastOnline() {
    _prefs?.setString('last_online', DateTime.now().toIso8601String());
  }

  void _checkQuestReset() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (state.questResetDate != today) {
      state = state.copyWith(
        dungeonClearedToday: 0,
        idleCollectedToday: 0,
        newDallimmonToday: 0,
        questResetDate: today,
        todaySteps: 0,
      );
    }
  }

  // ── Onboarding ────────────────────────────────────────
  void completeOnboarding(int starterDefId) {
    final starter = OwnedDallimmon(defId: starterDefId);
    state = state.copyWith(
      onboardingDone: true,
      dallimmons: [starter],
    );
    _save();
  }

  // ── Offline EXP ──────────────────────────────────────
  void collectOfflineExp() {
    _checkQuestReset();
    if (state.offlineExpPending <= 0) return;
    final exp = state.offlineExpPending;

    state = state.copyWith(
      offlineExpPending: 0,
      idleCollectedToday: state.idleCollectedToday + 1,
    );
    _addPlayerExpSilent(exp);
    _distributeToDallimmonsSilent(exp);
    _save();
  }

  // ── Steps (Phase 6 mock + future real pedometer) ──────
  void addSteps(int steps) {
    _checkQuestReset();
    final prev = state.todaySteps;
    final next = prev + steps;
    int bonusExp = 0;
    int bonusTickets = 0;

    for (final m in _stepMilestones) {
      if (prev < m.steps && next >= m.steps) bonusExp += m.exp;
    }
    if (prev < 5000 && next >= 5000) bonusTickets++;

    // Update dallimmon cumulative steps
    final updatedDallimmons = state.dallimmons
        .map((d) => OwnedDallimmon.fromJson({
              ...d.toJson(),
              'cumulativeSteps': d.cumulativeSteps + steps,
            }))
        .toList();

    // Update eggs
    final updatedEggs = state.eggs.map((e) {
      final next = e.currentSteps + steps;
      return Egg.fromJson({...e.toJson(), 'currentSteps': next.clamp(0, e.stepsRequired)});
    }).toList();

    state = state.copyWith(
      todaySteps: next,
      totalSteps: state.totalSteps + steps,
      normalTickets: state.normalTickets + bonusTickets,
      dallimmons: updatedDallimmons,
      eggs: updatedEggs,
    );

    // Base reward (e.g. 1 EXP per 100 steps) to ensure progress is always visible
    final baseExp = (steps / 100).ceil();
    final totalBonusExp = bonusExp + baseExp;

    if (totalBonusExp > 0) {
      _addPlayerExpSilent(totalBonusExp);
      _distributeToDallimmonsSilent(totalBonusExp ~/ 2);
    }
    _save();
  }

  // ── Dungeon result ────────────────────────────────────
  void onDungeonResult({
    required bool won,
    required int expGained,
    required int dungeonLevel,
  }) {
    _checkQuestReset();
    int newHighest = state.highestDungeonCleared;
    int newClearCount = state.dungeonClearCount;
    int clearedToday = state.dungeonClearedToday;
    int tickets = state.normalTickets;

    tickets = max(0, tickets - 1);

    if (won) {
      newHighest = max(newHighest, dungeonLevel);
      newClearCount++;
      clearedToday++;

      final updatedDallimmons = state.dallimmons
          .map((d) => OwnedDallimmon.fromJson({
                ...d.toJson(),
                'dungeonClears': d.dungeonClears + 1,
              }))
          .toList();
      state = state.copyWith(dallimmons: updatedDallimmons);
    }

    state = state.copyWith(
      highestDungeonCleared: newHighest,
      dungeonClearCount: newClearCount,
      dungeonClearedToday: clearedToday,
      normalTickets: tickets,
    );

    _addPlayerExpSilent(expGained);
    _distributeToDallimmonsSilent(expGained);

    // Drop egg chance (20%)
    if (won && _rng.nextDouble() < 0.2) {
      final rarity = _rng.nextDouble() < 0.1 ? Rarity.legendary : (_rng.nextDouble() < 0.4 ? Rarity.rare : Rarity.common);
      addEgg(rarity);
    }
    
    _save();
  }

  void addEgg(Rarity rarity) {
    final egg = Egg.generate(rarity);
    state = state.copyWith(eggs: [...state.eggs, egg]);
    _save();
  }

  void hatchEgg(String eggId) {
    final idx = state.eggs.indexWhere((e) => e.id == eggId);
    if (idx == -1) return;
    final egg = state.eggs[idx];
    if (!egg.canHatch) return;

    // Generate random dallimmon based on rarity
    final candidates = dallimmonCatalog.where((d) => d.rarity == egg.rarity).toList();
    if (candidates.isEmpty) return;
    final def = candidates[_rng.nextInt(candidates.length)];
    final newPet = OwnedDallimmon(defId: def.id);

    state = state.copyWith(
      eggs: List.from(state.eggs)..removeAt(idx),
      dallimmons: [...state.dallimmons, newPet],
      newDallimmonToday: state.newDallimmonToday + 1,
    );
    _save();
  }

  // ── PvP result (GDD v5) ────────────────────────────────
  void onPvPResult({
    required bool won,
    required int points,
    required int tokens,
  }) {
    state = state.copyWith(
      pvpPoints: max(0, state.pvpPoints + points),
      victoryTokens: state.victoryTokens + tokens,
    );
    
    // Bonus EXP for PvP battle
    _addPlayerExpSilent(won ? 50 : 10);
    _distributeToDallimmonsSilent(won ? 30 : 5);
    
    _save();
  }

  void setParty(List<int> indices) {
    state = state.copyWith(partyIndices: indices);
    _save();
  }

  // ── Quest helpers ─────────────────────────────────────
  int questProgress(String questId) {
    switch (questId) {
      case 'dungeon_clear': return state.dungeonClearedToday;
      case 'walk_3000':     return state.todaySteps;
      case 'idle_collect':  return state.idleCollectedToday;
      case 'new_dallimmon': return state.newDallimmonToday;
      case 'weekly_dungeon': return state.dungeonClearCount;
      case 'weekly_steps':   return state.totalSteps;
      default:              return 0;
    }
  }

  // ── EXP helpers (silent = don't trigger extra saves) ─
  void _addPlayerExpSilent(int amount) {
    var level  = state.playerLevel;
    var current = state.playerExp + amount;

    while (level < 99 && current >= level * 100) {
      current -= level * 100;
      level++;
    }
    state = state.copyWith(playerLevel: level, playerExp: current);
  }

  void _distributeToDallimmonsSilent(int exp) {
    if (state.dallimmons.isEmpty || exp <= 0) return;
    final updated = List<OwnedDallimmon>.from(state.dallimmons);
    
    // Only party members get exp, or if no party defined, the first one
    final targets = state.partyIndices.isNotEmpty ? state.partyIndices : [0];
    
    for (final idx in targets) {
      if (idx >= 0 && idx < updated.length) {
        final d = updated[idx];
        final clone = OwnedDallimmon.fromJson(d.toJson());
        clone.addExp(exp, playerLevel: state.playerLevel);
        updated[idx] = clone;
      }
    }
    state = state.copyWith(dallimmons: updated);
  }

  // ── Persistence ──────────────────────────────────────
  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final data = {
      'onboardingDone': state.onboardingDone,
      'playerLevel': state.playerLevel,
      'playerExp': state.playerExp,
      'totalSteps': state.totalSteps,
      'todaySteps': state.todaySteps,
      'normalTickets': state.normalTickets,
      'highestDungeonCleared': state.highestDungeonCleared,
      'dungeonClearCount': state.dungeonClearCount,
      'dungeonClearedToday': state.dungeonClearedToday,
      'idleCollectedToday': state.idleCollectedToday,
      'newDallimmonToday': state.newDallimmonToday,
      'questResetDate': state.questResetDate,
      'dallimmons': state.dallimmons.map((d) => d.toJson()).toList(),
      'activeDallimmonIndex': state.activeDallimmonIndex,
      'eggs': state.eggs.map((e) => e.toJson()).toList(),
      'partyIndices': state.partyIndices,
      'pvpPoints': state.pvpPoints,
      'victoryTokens': state.victoryTokens,
    };
    await prefs.setString('game_state', jsonEncode(data));
    _saveLastOnline();
  }

  Future<void> _load() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final raw = prefs.getString('game_state');
    if (raw == null) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final dallimmons = (json['dallimmons'] as List<dynamic>?)
              ?.map((d) => OwnedDallimmon.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [];

      state = GameState(
        onboardingDone: (json['onboardingDone'] as bool?) ?? false,
        playerLevel: (json['playerLevel'] as int?) ?? 1,
        playerExp: (json['playerExp'] as int?) ?? 0,
        totalSteps: (json['totalSteps'] as int?) ?? 0,
        todaySteps: (json['todaySteps'] as int?) ?? 0,
        normalTickets: (json['normalTickets'] as int?) ?? 3,
        highestDungeonCleared: (json['highestDungeonCleared'] as int?) ?? 0,
        dungeonClearCount: (json['dungeonClearCount'] as int?) ?? 0,
        dungeonClearedToday: (json['dungeonClearedToday'] as int?) ?? 0,
        idleCollectedToday: (json['idleCollectedToday'] as int?) ?? 0,
        newDallimmonToday: (json['newDallimmonToday'] as int?) ?? 0,
        questResetDate: (json['questResetDate'] as String?) ?? '',
        dallimmons: dallimmons,
        activeDallimmonIndex: (json['activeDallimmonIndex'] as int?) ?? 0,
        eggs: (json['eggs'] as List<dynamic>?)
                ?.map((e) => Egg.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        partyIndices: (json['partyIndices'] as List<dynamic>?)
                ?.map((i) => i as int)
                .toList() ??
            [0],
        pvpPoints: (json['pvpPoints'] as int?) ?? 1000,
        victoryTokens: (json['victoryTokens'] as int?) ?? 0,
      );
    } catch (_) {
      // Corrupt save - reset
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────
final gameProvider =
    StateNotifierProvider<GameNotifier, GameState>((ref) => GameNotifier());
