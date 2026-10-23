import 'package:flutter/material.dart';
import 'package:app_starter/features/onboarding/bank_select_page.dart';
import 'package:app_starter/features/onboarding/guide_page.dart';
import 'package:app_starter/features/onboarding/interest_page.dart';
import 'package:app_starter/features/onboarding/job_page.dart';
import 'package:app_starter/features/onboarding/plan_setup_page.dart';
import 'package:app_starter/features/onboarding/scene_page.dart';
import 'package:app_starter/features/onboarding/self_assess_page.dart';
import 'package:app_starter/features/profile/user_profile.dart';
import 'package:app_starter/features/shell/main_shell.dart';

/// 按 `onboarding_step` 决定登录后 / 冷启动落地页。
Widget pageForOnboardingStep(String? step) {
  switch (step) {
    case 'scene':
      return const ScenePage();
    case 'job':
      return const JobPage();
    case 'assess':
      return const SelfAssessPage();
    case 'bank':
      return const BankSelectPage();
    case 'plan':
      return const PlanSetupPage();
    case 'done':
      return const MainShell();
    case 'interest':
    default:
      return const InterestPage();
  }
}

void goOnboardingRoot(BuildContext context, UserProfile? profile) {
  final step = profile?.onboardingStep;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) =>
          profile?.isOnboardingDone == true
              ? const MainShell()
              : pageForOnboardingStep(step),
    ),
    (_) => false,
  );
}

Future<void> onboardingBack(
  BuildContext context, {
  required Widget fallback,
}) async {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
    return;
  }
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => fallback),
  );
}

Widget interestFallback() => const GuidePage();

Widget sceneFallback() => const InterestPage();

Widget jobFallback() => const ScenePage();
