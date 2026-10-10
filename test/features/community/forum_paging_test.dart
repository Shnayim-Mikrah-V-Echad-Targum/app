import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';

void main() {
  group('threads', () {
    test('a new weekly thread is not pinned', () async {
      final repo = DemoForumRepository();
      final id = await repo.weeklyThread(parshaNumber: 1, hebrewYear: 5787, title: 'Bereshit · בראשית · 5787');
      expect((await repo.thread(id)).pinned, isFalse);
    });
  });
}
