import 'package:flutter/widgets.dart';

/// Keys on the parts of a screen that matter most in store screenshots.
///
/// The screenshot run (integration_test/onboarding_flow_test.dart) reports
/// where each one is, in screenshot pixels, so a screenshot design can point
/// at it: zoom in on the amount, circle the import summary, and so on.
abstract final class RegionKeys {
  // Home
  static const budgetHero = Key('budget-hero');
  static const monthTiles = Key('month-tiles');
  static const goalCard = Key('goal-card');

  // Adding an entry
  static const entryAmount = Key('entry-amount');
  static const quickEntry = Key('quick-entry');
  static const entryCategories = Key('entry-categories');
  static const saveButton = Key('save-button');

  // Onboarding
  static const goalGrid = Key('goal-grid');
  static const planCard = Key('plan-card');

  // History
  static const monthChart = Key('month-chart');

  // Splitting
  static const splitSheet = Key('split-sheet');
  static const splitButton = Key('split-button');
  static const shareLine = Key('share-line');

  // Import and export
  static const importSummary = Key('import-summary');
  static const importCategories = Key('import-categories');
  static const monthPreview = Key('month-preview');
  static const exportSheet = Key('export-sheet');
  static const emailButton = Key('email-button');
}
