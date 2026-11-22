import 'package:chongmu_note/data/firestore_repository.dart';
import 'package:chongmu_note/models/models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late GroupDirectory dir;
  late String gid;

  setUp(() async {
    db = FakeFirebaseFirestore();
    dir = GroupDirectory(db: db);
    gid = await dir.create(
      uid: 'boss',
      myName: '총무',
      group: const Group(id: '', name: '토요 축구회'),
      settings: LedgerSettings(openingBalance: 0, openingDate: DateTime(2026, 1, 1)),
    );
    final g = db.collection('groups').doc(gid);
    await g.collection('members').doc('m2').set({'name': '회원', 'uid': 'kim'});
    await g.collection('accounts').doc('kim').set({'memberId': 'm2', 'role': 'member'});
    await db.collection('users').doc('kim').set({'groups': [gid], 'lastGroup': gid});
    for (var i = 0; i < 5; i++) {
      await g.collection('transactions').add({'amount': 1000});
    }
    await g.collection('notices').add({'title': '공지'});
    await g.collection('messages').add({'text': '안녕'});
  });

  test('모임 지우기: 모임과 그 안의 모든 기록, 초대코드가 사라진다', () async {
    final code = (await db.collection('groups').doc(gid).get()).data()!['inviteCode'] as String;
    expect((await db.collection('invites').doc(code).get()).exists, isTrue);

    await dir.deleteGroup(gid, 'boss');

    final g = db.collection('groups').doc(gid);
    expect((await g.get()).exists, isFalse);
    for (final c in ['transactions', 'members', 'accounts', 'notices', 'messages', 'config']) {
      expect((await g.collection(c).get()).docs, isEmpty, reason: c);
    }
    expect((await db.collection('invites').doc(code).get()).exists, isFalse);
    final me = (await db.collection('users').doc('boss').get()).data()!;
    expect(me['groups'], isNot(contains(gid)));
    expect(me.containsKey('lastGroup'), isFalse);
  });

  test('모임 나가기: 내 계정 연결만 풀리고 명단 이름은 남는다', () async {
    await dir.leave(gid, 'kim');
    final g = db.collection('groups').doc(gid);
    expect((await g.collection('accounts').doc('kim').get()).exists, isFalse);
    final m = (await g.collection('members').doc('m2').get()).data()!;
    expect((m['name'], m['uid']), ('회원', null));
    expect((await db.collection('users').doc('kim').get()).data()!['groups'], isEmpty);
    expect((await g.get()).exists, isTrue);
  });

  test('총무는 나갈 수 없다', () async {
    expect(() => dir.leave(gid, 'boss'), throwsStateError);
    expect((await db.collection('groups').doc(gid).collection('accounts').doc('boss').get()).exists, isTrue);
  });
}
