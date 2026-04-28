import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../domain/dallimmon.dart';
import '../state/game_notifier.dart';
import 'dungeon_select_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gs  = ref.watch(gameProvider);
    final mon = gs.activeDallimmon;
    final def = mon != null ? getDef(mon.defId) : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(gs),
            if (gs.offlineExpPending > 0) _buildOfflineBanner(gs),
            Expanded(child: _buildCenter(gs, mon, def)),
          ],
        ),
      ),
    );
  }

  // ── Top stats bar ─────────────────────────────────────
  Widget _buildTopBar(GameState gs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _StatChip(label: 'LEVEL', value: 'Lv.${gs.playerLevel}',
              valueColor: AppColors.primary),
          const SizedBox(width: 10),
          _StatChip(label: 'EXP',
              value: _fmt(gs.playerExp), valueColor: AppColors.accent),
          const SizedBox(width: 10),
          _StatChip(label: '오늘 걸음',
              value: '${_fmt(gs.todaySteps)}보', valueColor: AppColors.text),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: const Icon(Icons.notifications_none_rounded,
                color: AppColors.accent, size: 26),
          ),
        ],
      ),
    );
  }

  // ── Offline reward banner ─────────────────────────────
  Widget _buildOfflineBanner(GameState gs) {
    return GestureDetector(
      onTap: () => ref.read(gameProvider.notifier).collectOfflineExp(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2A1A),
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
                  const Text('오프라인 보상!',
                      style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text('방치 보상 → EXP +${_fmt(gs.offlineExpPending)}',
                      style: const TextStyle(
                          color: AppColors.textSub, fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('수령!',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Center dallimmon display ──────────────────────────
  Widget _buildCenter(GameState gs, OwnedDallimmon? mon, DallimmonDef? def) {
    if (def == null) {
      return const Center(
          child: Text('달리몬이 없습니다', style: TextStyle(color: AppColors.textSub)));
    }

    final typeColor = def.type.color;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Floating dallimmon
        AnimatedBuilder(
          animation: _floatAnim,
          builder: (_, child) =>
              Transform.translate(offset: Offset(0, _floatAnim.value), child: child),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow
              Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    typeColor.withOpacity(0.25),
                    Colors.transparent,
                  ]),
                ),
              ),
              Text(def.emoji, style: const TextStyle(fontSize: 100)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Name
        Text(def.name,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 26,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        // Type · Level · Evolution badge
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BadgePill(
              text: '${def.type.emoji} ${def.type.label}',
              color: typeColor,
            ),
            const SizedBox(width: 6),
            _BadgePill(text: 'Lv.${mon!.level}', color: AppColors.surface),
            const SizedBox(width: 6),
            _BadgePill(text: mon.evolutionStage, color: AppColors.surface),
          ],
        ),
        const SizedBox(height: 20),
        // EXP bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: mon.expRatio,
                  minHeight: 10,
                  backgroundColor: AppColors.card,
                  valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                ),
              ),
              const SizedBox(height: 5),
              Text('${_fmt(mon.exp)} / ${_fmt(mon.expToNext)} EXP',
                  style: const TextStyle(
                      color: AppColors.textSub, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 36),
        // Dungeon button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _goDungeon(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: AppColors.primary.withOpacity(0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('⚔️', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Text('던전 입장',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Phase 6: Step mock buttons
        _StepMockPanel(),
      ],
    );
  }

  void _goDungeon(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const DungeonSelectScreen()));
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
}

// ── Step mock panel (Phase 6) ─────────────────────────────
class _StepMockPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('👟 걸음 추가 (테스트)',
              style: TextStyle(color: AppColors.textSub, fontSize: 11)),
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
                    child: Text('+$s',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────
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
        Text(label,
            style: const TextStyle(
                color: AppColors.textHint, fontSize: 9, letterSpacing: 1)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String text;
  final Color color;
  const _BadgePill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color == AppColors.surface ? AppColors.textSub : color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}
