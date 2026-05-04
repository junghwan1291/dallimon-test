import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../domain/dallimmon.dart';
import '../domain/pet_type.dart';
import '../state/game_notifier.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  PetType? _filterType;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0518),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0518),
          elevation: 0,
          title: const Text('나의 달리몬', style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: const TabBar(
            indicatorColor: AppColors.purple,
            labelColor: AppColors.purple,
            unselectedLabelColor: AppColors.textHint,
            tabs: [
              Tab(text: '도감'),
              Tab(text: '알 & 부화'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCollectionView(),
            _buildEggView(),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionView() {
    final gs = ref.watch(gameProvider);
    final discovered = gs.discoveredDefIds;
    final total = dallimmonCatalog.length;

    final filtered = _filterType == null
        ? dallimmonCatalog
        : dallimmonCatalog.where((d) => d.type == _filterType).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProgress(discovered.length, total),
        _buildTypeFilter(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final def = filtered[i];
              final owned = gs.dallimmons.where((d) => d.defId == def.id).firstOrNull;
              return _DallimmonCell(
                def: def,
                owned: owned,
                discovered: discovered.contains(def.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgress(int count, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('도감 완성률', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$count / $total종', style: const TextStyle(color: AppColors.purple, fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: count / total,
              minHeight: 6,
              backgroundColor: AppColors.card,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _FilterChip(
            label: '전체',
            emoji: null,
            selected: _filterType == null,
            color: AppColors.primary,
            onTap: () => setState(() => _filterType = null),
          ),
          ...PetType.values.map((t) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _FilterChip(
                  label: t.label,
                  emoji: t.emoji,
                  selected: _filterType == t,
                  color: t.color,
                  onTap: () => setState(() => _filterType = t),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEggView() {
    final gs = ref.watch(gameProvider);
    final eggs = gs.eggs;

    if (eggs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🥚', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('보유한 알이 없습니다.', style: TextStyle(color: AppColors.textHint, fontSize: 15)),
            Text('던전을 클리어해 알을 획득해 보세요!', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: eggs.length,
      itemBuilder: (context, index) {
        final egg = eggs[index];
        return _EggCard(egg: egg);
      },
    );
  }
}

class _EggCard extends ConsumerWidget {
  final Egg egg;
  const _EggCard({required this.egg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = egg.rarity.color;
    final canHatch = egg.canHatch;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: canHatch ? color : AppColors.cardBorder, width: canHatch ? 2 : 1),
        boxShadow: canHatch ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)] : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(canHatch ? '✨🥚✨' : '🥚', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(egg.rarity.label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: egg.progress,
              minHeight: 8,
              backgroundColor: Colors.black26,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Text('${egg.currentSteps} / ${egg.stepsRequired}보', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
          const Spacer(),
          ElevatedButton(
            onPressed: canHatch ? () => ref.read(gameProvider.notifier).hatchEgg(egg.id) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(canHatch ? '부화하기' : '부화 대기 중', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.25) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.cardBorder,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    color: selected ? color : AppColors.textSub,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _DallimmonCell extends StatelessWidget {
  final DallimmonDef def;
  final OwnedDallimmon? owned;
  final bool discovered;

  const _DallimmonCell({
    required this.def,
    required this.owned,
    required this.discovered,
  });

  @override
  Widget build(BuildContext context) {
    final level = owned?.level;
    final typeColor = def.type.color;

    return Container(
      decoration: BoxDecoration(
        color: discovered ? typeColor.withOpacity(0.1) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: discovered ? typeColor.withOpacity(0.35) : AppColors.cardBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (discovered) ...[
            Text(def.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(def.name,
                style: const TextStyle(color: AppColors.text, fontSize: 10, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (level != null)
              Text('Lv.$level', style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w800)),
          ] else ...[
            const Text('❓', style: TextStyle(fontSize: 26, color: AppColors.textHint)),
            const SizedBox(height: 4),
            const Text('???', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
            const Text('미발견', style: TextStyle(color: AppColors.textHint, fontSize: 9)),
          ],
        ],
      ),
    );
  }
}
