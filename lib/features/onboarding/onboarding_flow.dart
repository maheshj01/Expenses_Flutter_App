import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/category.dart';
import '../../shared/animations/motion.dart';
import 'onboarding_draft.dart';
import 'steps/categories_step.dart';
import 'steps/goals_step.dart';
import 'steps/income_step.dart';
import 'steps/plan_step.dart';
import 'steps/sharing_step.dart';
import 'steps/spending_step.dart';
import 'steps/welcome_step.dart';

enum OnboardingStep { welcome, income, spending, goals, categories, sharing, plan }

/// First-run setup. Also opened from Settings ([editing]) to adjust the
/// plan, in which case it skips the welcome and pops when done.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, this.editing = false});

  final bool editing;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late final OnboardingDraft _draft = OnboardingDraft.from(ref.read(settingsProvider));
  late final List<OnboardingStep> _steps = widget.editing
      ? OnboardingStep.values.skip(1).toList()
      : OnboardingStep.values;
  int _index = 0;
  int _direction = 1;
  bool _saving = false;

  OnboardingStep get _step => _steps[_index];

  bool get _isLast => _index == _steps.length - 1;

  void _changed() => setState(() {});

  /// Spending categories to offer: existing ones, then suggestions.
  List<Category> _choices(List<Category> all) {
    final existing = all.where((c) => c.kind == CategoryKind.spending).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final ids = {for (final c in all) c.id};
    return [...existing, ...suggestedCategories.where((s) => !ids.contains(s.id))];
  }

  void _initCategorySelection(List<Category> all) {
    if (_draft.categoryIds != null || all.isEmpty) return;
    final spending = all.where((c) => c.kind == CategoryKind.spending);
    final returning = widget.editing || ref.read(settingsProvider).onboarded;
    _draft.categoryIds = returning
        ? {for (final c in spending.where((c) => !c.archived)) c.id}
        : {
            ...spending.map((c) => c.id).where(defaultSelectedCategoryIds.contains),
            if (_draft.goals.contains(MoneyGoal.payOffDebt)) 'debt',
          };
  }

  bool get _canContinue => switch (_step) {
    OnboardingStep.categories => (_draft.categoryIds?.isNotEmpty ?? false),
    _ => !_saving,
  };

  String get _cta => switch (_step) {
    OnboardingStep.welcome => 'Let’s go',
    OnboardingStep.income when _draft.incomeCents == 0 => 'Skip for now',
    OnboardingStep.spending when _draft.spendingCents == 0 => 'Skip for now',
    OnboardingStep.sharing when _draft.sharesBills == null => 'Skip',
    OnboardingStep.categories when !_canContinue => 'Pick at least one',
    OnboardingStep.plan => widget.editing ? 'Save changes' : 'Start tracking',
    _ => 'Continue',
  };

  void _next() {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    if (_isLast) {
      _finish();
      return;
    }
    setState(() {
      _direction = 1;
      _index++;
    });
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_index == 0) {
      if (widget.editing) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _direction = -1;
      _index--;
    });
  }

  Future<void> _skipAll() async {
    final settings = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).update(settings.copyWith(onboarded: true));
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final repo = ref.read(categoryRepositoryProvider);
    final selected = _draft.categoryIds;
    if (selected != null) {
      final all = await repo.getAll();
      for (final c in all.where((c) => c.kind == CategoryKind.spending)) {
        final archive = !selected.contains(c.id);
        if (c.archived != archive) await repo.setArchived(c.id, archived: archive);
      }
      final existing = {for (final c in all) c.id};
      for (final s in suggestedCategories) {
        if (selected.contains(s.id) && !existing.contains(s.id)) await repo.save(s);
      }
    }
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.update(_draft.applyTo(ref.read(settingsProvider)));
    if (mounted && widget.editing) Navigator.of(context).pop();
  }

  Widget _buildStep(List<Category> categories) {
    return switch (_step) {
      OnboardingStep.welcome => WelcomeStep(draft: _draft, onChanged: _changed),
      OnboardingStep.income => IncomeStep(draft: _draft, onChanged: _changed),
      OnboardingStep.spending => SpendingStep(draft: _draft, onChanged: _changed),
      OnboardingStep.goals => GoalsStep(draft: _draft, onChanged: _changed),
      OnboardingStep.categories => CategoriesStep(
        draft: _draft,
        choices: _choices(categories),
        onChanged: _changed,
      ),
      OnboardingStep.sharing => SharingStep(draft: _draft, onChanged: _changed),
      OnboardingStep.plan => PlanStep(draft: _draft),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    if (_step == OnboardingStep.categories) _initCategorySelection(categories);
    final progress = _steps.length == 1 ? 1.0 : _index / (_steps.length - 1);
    final duration = Motion.of(context, Motion.medium);

    return PopScope(
      canPop: widget.editing && _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                child: Row(
                  children: [
                    AnimatedOpacity(
                      opacity: _index > 0 || widget.editing ? 1 : 0,
                      duration: duration,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: _index > 0 || widget.editing ? _back : null,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 6,
                          color: c.sunk,
                          alignment: Alignment.centerLeft,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: progress),
                            duration: duration,
                            curve: Motion.enter,
                            builder: (context, v, _) => FractionallySizedBox(
                              widthFactor: v.clamp(0.02, 1),
                              child: Container(color: c.lived),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: _step == OnboardingStep.welcome
                          ? TextButton(
                              onPressed: _skipAll,
                              child: Text('Skip', style: TextStyle(color: c.muted)),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  layoutBuilder: (current, previous) =>
                      Stack(fit: StackFit.expand, children: [...previous, ?current]),
                  transitionBuilder: (child, animation) {
                    // Incoming steps slide in from the direction of travel;
                    // outgoing ones leave the opposite way.
                    final incoming = child.key == ValueKey(_step);
                    final from = Offset(0.25 * (incoming ? _direction : -_direction), 0);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(begin: from, end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(key: ValueKey(_step), child: _buildStep(categories)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                child: FilledButton(
                  onPressed: _canContinue && !_saving ? _next : null,
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.fast),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.9, end: 1.0).animate(a),
                        child: child,
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            key: ValueKey('saving'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_cta, key: ValueKey(_cta)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
