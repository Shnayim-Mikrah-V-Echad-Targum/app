import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/app.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/features/community/data/backend.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/notifications.dart';

ParshaRepository? _repo;

Future<ParshaRepository> loadRepo() async => _repo ??= await ParshaRepository.load();

/// Pumps the whole app with in-memory storage and the demo backend (or
/// [forums], when given).
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(onboardingComplete: true),
  DateTime? now,
  ProgressState? progress,
  ForumRepository? forums,
}) async {
  TodayController.autoRollover = false;
  if (now != null) TodayController.now = () => now;
  SharedPreferences.setMockInitialValues({
    'flutter.settings.v1': jsonEncode(settings.toJson()),
    if (progress != null) 'flutter.progress.v1': jsonEncode(progress.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  final repo = await tester.runAsync(loadRepo);
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    parshaRepositoryProvider.overrideWithValue(repo!),
    backendProvider.overrideWithValue(Backend(forums ?? DemoForumRepository())),
    notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ShnayimMikraApp()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}
