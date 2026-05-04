import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../domain/dallimmon.dart';
import '../domain/dungeon.dart';
import '../state/game_notifier.dart';
import 'dungeon_battle_screen.dart';
import 'map_dungeon_screen.dart';

class DungeonSelectScreen extends ConsumerWidget {
  const DungeonSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameProvider);
    final nextLevel = gs.highestDungeonCleared + 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0518),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildTicketRow(gs),
                    const SizedBox(height: 24),
                    _buildSectionTitle('나의 파티 (최대 3마리)'),
                    const SizedBox(height: 12),
                    _buildPartySetup(context, ref, gs),
                    const SizedBox(height: 32),
                    _buildSectionTitle('던전 선택'),
                    const SizedBox(height: 12),
                    _buildDungeonCard(
                      context: context,
                      ref: ref,
                      gs: gs,
                      icon: '🏰',
                      title: '일반 던전',
                      subtitle: '레벨 순서대로 스테이지 클리어\n5연속 턴제 배틀',
                      tags: ['PvE', '턴제전투', '순차클리어'],
                      tagColors: [AppColors.surface, AppColors.surface, AppColors.surface],
                      gradient: const [Color(0xFF2A1060), Color(0xFF150830)],
                      borderColor: const Color(0xFF5A2FB0),
                      onTap: gs.normalTickets > 0 && gs.partyIndices.isNotEmpty
                          ? () => _enterNormalDungeon(context, ref, gs, nextLevel)
                          : null,
                      locked: gs.normalTickets <= 0 || gs.partyIndices.isEmpty,
                      lockLabel: gs.partyIndices.isEmpty ? '파티를 설정하세요' : '입장권 부족',
                    ),
                    const SizedBox(height: 14),
                    _buildDungeonCard(
                      context: context,
                      ref: ref,
                      gs: gs,
                      icon: '🗺️',
                      title: '지도 던전',
                      subtitle: 'GPS 기반 주변 탐험\n야생 달리몬 & 유저 배틀',
                      tags: ['GPS', '위치기반', '야생'],
                      tagColors: [Colors.green, Colors.blue, Colors.orange],
                      gradient: const [Color(0xFF0D3A1A), Color(0xFF0B1A10)],
                      borderColor: const Color(0xFF2E7D32),
                      onTap: () => ref.read(navIndexProvider.notifier).state = 0,
                      locked: false,
                    ),
                    const SizedBox(height: 24),
                    _buildProgress(gs, nextLevel),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900));
  }

  Widget _buildHeader(BuildContext context) {
    final isFromNav = ModalRoute.of(context)?.isFirst ?? true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (!isFromNav) Navigator.pop(context);
            },
            child: const Icon(Icons.close, color: AppColors.text, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('던전 탐험', style: TextStyle(
                  color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w900)),
              Text('파티를 구성하여 던전을 정복하세요',
                  style: TextStyle(color: AppColors.textSub, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketRow(GameState gs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Text('🎫', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('일반 던전 입장권',
              style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${gs.normalTickets}개 보유 중',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPartySetup(BuildContext context, WidgetRef ref, GameState gs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(3, (i) {
              final hasMember = i < gs.partyIndices.length;
              final memberIdx = hasMember ? gs.partyIndices[i] : -1;
              final pet = (hasMember && memberIdx < gs.dallimmons.length) ? gs.dallimmons[memberIdx] : null;

              return _PartySlot(
                pet: pet,
                onTap: () => _showPartyPicker(context, ref, gs),
              );
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showPartyPicker(context, ref, gs),
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('파티 번호 및 멤버 변경', style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDungeonCard({
    required BuildContext context,
    required WidgetRef ref,
    required GameState gs,
    required String icon,
    required String title,
    required String subtitle,
    required List<String> tags,
    required List<Color> tagColors,
    required List<Color> gradient,
    required Color borderColor,
    required VoidCallback? onTap,
    required bool locked,
    String? lockLabel,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: locked ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(color: borderColor.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSub, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
              if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(lockLabel ?? '잠김', style: const TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.text, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(GameState gs, int nextLevel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('현재 진행도', style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('Lv.${gs.highestDungeonCleared}', style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (gs.highestDungeonCleared % 10) / 10.0,
            minHeight: 8,
            backgroundColor: AppColors.card,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  void _showPartyPicker(BuildContext context, WidgetRef ref, GameState gs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141025),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return _PartyPickerSheet(gs: gs);
      },
    );
  }

  void _enterNormalDungeon(BuildContext context, WidgetRef ref, GameState gs, int level) {
    final party = gs.partyIndices
        .where((idx) => idx < gs.dallimmons.length)
        .map((idx) => gs.dallimmons[idx])
        .toList();

    if (party.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DungeonBattleScreen(
          dungeonLevel: level.clamp(1, 100),
          partyDallimmons: party,
        ),
      ),
    ).then((result) {
      if (result is Map && context.mounted) {
        ref.read(gameProvider.notifier).onDungeonResult(
          won: result['won'] as bool,
          expGained: result['expGained'] as int,
          dungeonLevel: result['level'] as int,
        );
      }
    });
  }
}

class _PartySlot extends StatelessWidget {
  final OwnedDallimmon? pet;
  final VoidCallback onTap;

  const _PartySlot({this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final def = pet != null ? getDef(pet!.defId) : null;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: pet != null ? def!.type.color.withOpacity(0.15) : Colors.white10,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: pet != null ? def!.type.color.withOpacity(0.5) : AppColors.cardBorder,
                width: 2,
              ),
            ),
            child: Center(
              child: pet != null
                  ? Text(def!.emoji, style: const TextStyle(fontSize: 34))
                  : const Icon(Icons.add, color: AppColors.textHint, size: 30),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pet != null ? def!.name : '비어있음',
            style: TextStyle(
              color: pet != null ? AppColors.text : AppColors.textHint,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PartyPickerSheet extends ConsumerStatefulWidget {
  final GameState gs;
  const _PartyPickerSheet({required this.gs});

  @override
  ConsumerState<_PartyPickerSheet> createState() => _PartyPickerSheetState();
}

class _PartyPickerSheetState extends ConsumerState<_PartyPickerSheet> {
  late List<int> _selectedIndices;

  @override
  void initState() {
    super.initState();
    _selectedIndices = List.from(widget.gs.partyIndices);
  }

  void _togglePet(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        if (_selectedIndices.length < 3) {
          _selectedIndices.add(index);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Text('파티원 선택', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_selectedIndices.length} / 3', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.gs.dallimmons.length,
              itemBuilder: (context, i) {
                final pet = widget.gs.dallimmons[i];
                final def = getDef(pet.defId);
                final isSelected = _selectedIndices.contains(i);

                return ListTile(
                  onTap: () => _togglePet(i),
                  leading: Text(def.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(def.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                  subtitle: Text('Lv.${pet.level} · ATK ${pet.calcAtk(def.baseAtk)} / MATK ${pet.calcMatk(def.baseMatk)}', 
                               style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? AppColors.primary : AppColors.textHint,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(gameProvider.notifier).setParty(_selectedIndices);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('파티 설정 완료', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
