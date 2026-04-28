import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../domain/dallimmon.dart';
import '../state/game_notifier.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _selectedDefId = 0; // default: 테라몬

  @override
  Widget build(BuildContext context) {
    final selectedDef = getDef(_selectedDefId);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0A2A), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Step indicator
              const Text('STEP 1 OF 1',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  )),
              const SizedBox(height: 16),
              // Title
              const Text('어떤 알을 깨울까요? 🥚',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 6),
              const Text('선택한 알에서 당신의 첫 달리몬이 부화합니다',
                  style: TextStyle(color: AppColors.textSub, fontSize: 13)),
              const SizedBox(height: 28),
              // Type grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: starterDefIds.length,
                    itemBuilder: (ctx, i) {
                      final defId = starterDefIds[i];
                      final def   = getDef(defId);
                      final isSelected = defId == _selectedDefId;
                      return _TypeCard(
                        def: def,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedDefId = defId),
                      );
                    },
                  ),
                ),
              ),
              // Hint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lightbulb_outline, color: AppColors.textHint, size: 14),
                    SizedBox(width: 6),
                    Text('알 타입은 이후에도 바꿀 수 있어요',
                        style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                  ],
                ),
              ),
              // CTA button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 6,
                      shadowColor: AppColors.primary.withOpacity(0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(selectedDef.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Text('${selectedDef.name} 선택 →',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm() {
    ref.read(gameProvider.notifier).completeOnboarding(_selectedDefId);
  }
}

class _TypeCard extends StatelessWidget {
  final DallimmonDef def;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.def,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = def.type.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? typeColor.withOpacity(0.18)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? typeColor : AppColors.cardBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: typeColor.withOpacity(0.35), blurRadius: 16)]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(def.type.emoji,
                  style: const TextStyle(fontSize: 38)),
              const SizedBox(height: 10),
              Text('${def.name.replaceAll('몬', '')} 알',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 4),
              Text(def.type.gpsZone,
                  style: const TextStyle(
                      color: AppColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(def.type.battleRole,
                    style: TextStyle(
                        color: typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
