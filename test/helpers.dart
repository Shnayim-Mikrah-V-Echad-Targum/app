import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/app.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/features/community/data/backend.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/services/reminder_planner.dart';
import 'package:shnayim_mikra/services/tts.dart';

ParshaRepository? _repo;

Future<ParshaRepository> loadRepo() async => _repo ??= await ParshaRepository.load();

/// Pumps the whole app with in-memory storage and the demo backend (or
/// [forums], when given), and notifications disabled (or [notifications]),
/// and any further [overrides].
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(onboardingComplete: true),
  DateTime? now,
  ProgressState? progress,
  ForumRepository? forums,
  NotificationService? notifications,
  List<Override> overrides = const [],
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
    notificationServiceProvider.overrideWithValue(notifications ?? NotificationService.disabled()),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ShnayimMikraApp()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

/// Text-to-speech that records what it is asked to say, and says nothing.
/// Override [ttsProvider] with it.
class RecordingTts extends TtsService {
  RecordingTts() : super(engine: _SilentEngine());

  /// Each text asked for, with its language.
  final spoken = <(String, String)>[];

  @override
  Future<bool?> hasHebrewVoice() async => true;

  @override
  Future<void> speak(String text, {required String language, double rate = 0.45}) async => spoken.add((text, language));
}

class _SilentEngine extends Fake implements FlutterTts {
  @override
  void setStartHandler(VoidCallback callback) {}
  @override
  void setCompletionHandler(VoidCallback callback) {}
  @override
  void setCancelHandler(VoidCallback callback) {}
  @override
  void setErrorHandler(ErrorHandler handler) {}
  @override
  Future<dynamic> stop() async => 1;
}

/// Reminders as on a phone, where they are available: for pages that show
/// their settings. Schedules nothing.
class PhoneNotifications extends NotificationService {
  PhoneNotifications() : super.withPlugin(_NoPlugin());

  @override
  Future<void> reschedule(
          List<PlannedReminder> reminders, AppLocalizations l, ReminderCopy Function(PlannedReminder) describe) async {}
}

class _NoPlugin extends Fake implements FlutterLocalNotificationsPlugin {}
