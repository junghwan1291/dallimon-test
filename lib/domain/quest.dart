enum QuestCategory { daily, weekly }
enum QuestType { dungeon, steps, idle, collection }

class QuestDef {
  final String id;
  final String title;
  final String subtitle;
  final QuestType type;
  final QuestCategory category;
  final int target;
  final String rewardLabel;

  const QuestDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.category,
    required this.target,
    required this.rewardLabel,
  });
}

const List<QuestDef> dailyQuests = [
  QuestDef(
    id: 'dungeon_clear',
    title: '던전 1스테이지 이상 클리어',
    subtitle: '일일 던전 도전',
    type: QuestType.dungeon,
    category: QuestCategory.daily,
    target: 1,
    rewardLabel: '+🎫×1',
  ),
  QuestDef(
    id: 'walk_3000',
    title: '오늘 3,000보 걷기',
    subtitle: '만보기 연동 퀘스트',
    type: QuestType.steps,
    category: QuestCategory.daily,
    target: 3000,
    rewardLabel: '+EXP 80',
  ),
  QuestDef(
    id: 'idle_collect',
    title: '방치 수익 3회 수령하기',
    subtitle: '오프라인 보상 수령',
    type: QuestType.idle,
    category: QuestCategory.daily,
    target: 3,
    rewardLabel: '+EXP 100',
  ),
  QuestDef(
    id: 'new_dallimmon',
    title: '달리몬 도감 신규 등록 1종',
    subtitle: '새로운 달리몬 발견',
    type: QuestType.collection,
    category: QuestCategory.daily,
    target: 1,
    rewardLabel: '+🥚 희귀 아이템',
  ),
];

const List<QuestDef> weeklyQuests = [
  QuestDef(
    id: 'weekly_dungeon',
    title: '던전 Lv.5 이상 10회 클리어',
    subtitle: '주간 던전 도전',
    type: QuestType.dungeon,
    category: QuestCategory.weekly,
    target: 10,
    rewardLabel: '희귀 달리몬 보장 뽑기권',
  ),
  QuestDef(
    id: 'weekly_steps',
    title: '주간 총 50,000보 달성',
    subtitle: '주간 만보 목표',
    type: QuestType.steps,
    category: QuestCategory.weekly,
    target: 50000,
    rewardLabel: 'EXP ×2 부스터 (4시간)',
  ),
];
