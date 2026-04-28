import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../domain/quest.dart';
import '../state/game_notifier.dart';

class QuestScreen extends ConsumerStatefulWidget {
  const QuestScreen({super.key});

  @override
  ConsumerState<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends ConsumerState<QuestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _QuestList(quests: dailyQuests, isWeekly: false),
                  _QuestList(quests: weeklyQuests, isWeekly: true),
                  _AchievementsPlaceholder(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Calculate reset time (next midnight)
    final now      = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff     = tomorrow.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          const Text('📋', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('퀘스트',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                Text('일일 퀘스트 초기화: ${h}시간 ${m}분 후',
                    style: const TextStyle(
                        color: AppColors.textSub, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Text('🎁', style: TextStyle(fontSize: 14)),
                SizedBox(width: 4),
                Text('전체 완료 보상',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TabBar(
          controller: _tab,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSub,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: '일일'),
            Tab(text: '주간'),
            Tab(text: '업적'),
          ],
        ),
      ),
    );
  }
}

// ── Quest list ────────────────────────────────────────────
class _QuestList extends ConsumerWidget {
  final List<QuestDef> quests;
  final bool isWeekly;

  const _QuestList({required this.quests, required this.isWeekly});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      itemCount: quests.length,
      itemBuilder: (ctx, i) {
        final q        = quests[i];
        final progress = ref.read(gameProvider.notifier).questProgress(q.id);
        final isDone   = progress >= q.target;

        return _QuestCard(
          quest: q,
          progress: progress,
          isDone: isDone,
        );
      },
    );
  }
}

class _QuestCard extends StatelessWidget {
  final QuestDef quest;
  final int progress;
  final bool isDone;

  const _QuestCard({
    required this.quest,
    required this.progress,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (progress / quest.target).clamp(0.0, 1.0);
    final typeIcon = _iconForType(quest.type);
    final progressColor = isDone ? AppColors.success : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFF0D2A0D)
            : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? AppColors.success.withOpacity(0.4)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(typeIcon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quest.title,
                        style: TextStyle(
                            color: isDone
                                ? AppColors.success
                                : AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text(quest.subtitle,
                        style: const TextStyle(
                            color: AppColors.textSub, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Reward or done badge
              if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withOpacity(0.4)),
                  ),
                  child: const Text('✅ 완료!',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                )
              else
                Text(quest.rewardLabel,
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _progressLabel(quest, progress),
              style: const TextStyle(
                  color: AppColors.textHint, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  String _iconForType(QuestType t) {
    switch (t) {
      case QuestType.dungeon:    return '🏰';
      case QuestType.steps:      return '👟';
      case QuestType.idle:       return '💤';
      case QuestType.collection: return '📖';
    }
  }

  String _progressLabel(QuestDef q, int p) {
    if (q.type == QuestType.steps) return '${p.clamp(0, q.target)} / ${q.target}보';
    return '${p.clamp(0, q.target)} / ${q.target}${q.type == QuestType.idle ? '회' : '종'}';
  }
}

class _AchievementsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏅', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('업적 시스템',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('v1.5에서 오픈 예정',
              style: TextStyle(color: AppColors.textSub)),
        ],
      ),
    );
  }
}
