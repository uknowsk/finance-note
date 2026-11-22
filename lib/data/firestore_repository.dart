import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'repository.dart';

/// Firestore 구조 (모임마다 따로 보관해서 다른 모임 기록은 절대 안 섞여요)
/// - users/{uid}                     내 계정: 들어간·신청한 모임 목록, 마지막으로 본 모임
/// - invites/{코드}                  초대코드 → 모임 id
/// - groups/{gid}                    모임 이름·색·사진·초대코드
///   - accounts/{uid}                로그인 계정 ↔ 회원 연결 + 역할. 보안 규칙이 역할을 여기서 읽어요.
///   - members/{memberId}            회원 명단 (이름, 역할, 연결된 uid, 면제 연도, 생일)
///   - joinRequests/{uid}            가입 신청 (총무가 승인)
///   - transactions/{id}             입출금 기록
///   - messages/{id}                 메시지
///   - config/settings               시작 잔고, 월 회비, 분류, 회장, 지역 순서
///   - meetings/{id}                 모임 기록 (참석자 포함)
///   - notices/{id}                  공지·투표 (votes.{회원id} = 고른 번호들)
class FirestoreRepository implements LedgerRepository {
  FirestoreRepository(this.groupId, {FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final String groupId;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _group => _db.collection('groups').doc(groupId);
  CollectionReference<Map<String, dynamic>> get _members => _group.collection('members');
  CollectionReference<Map<String, dynamic>> get _accounts => _group.collection('accounts');
  CollectionReference<Map<String, dynamic>> get _txns => _group.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _messages => _group.collection('messages');
  CollectionReference<Map<String, dynamic>> get _meetings => _group.collection('meetings');
  CollectionReference<Map<String, dynamic>> get _notices => _group.collection('notices');
  CollectionReference<Map<String, dynamic>> get _requests => _group.collection('joinRequests');
  DocumentReference<Map<String, dynamic>> get _settings => _group.collection('config').doc('settings');

  @override
  Stream<Group> group() => _group.snapshots().map((d) => Group.fromMap(d.id, d.data() ?? const {}));

  @override
  Future<void> updateGroup(Group g) =>
      _group.set({'name': g.name, 'color': g.color, 'logo': g.logo}, SetOptions(merge: true));

  @override
  Future<void> saveSettings(LedgerSettings st) => _settings.set(st.toMap(), SetOptions(merge: true));

  @override
  Future<void> addMember(String name) => _members.add(Member(id: '', name: name).toMap());

  @override
  Future<void> removeMember(String memberId) async {
    final m = Member.fromMap(memberId, (await _members.doc(memberId).get()).data() ?? {});
    if (m.uid != null) throw StateError('${m.name}님은 앱에 가입해 있어서 뺄 수 없어요.');
    await _members.doc(memberId).delete();
  }

  /// 초대코드 새로 만들기 (총무). 예전 코드는 바로 못 쓰게 돼요.
  Future<String> renewInviteCode(String oldCode) async {
    final code = await GroupDirectory(db: _db).freeCode();
    final b = _db.batch()
      ..set(_db.collection('invites').doc(code), {'groupId': groupId})
      ..set(_group, {'inviteCode': code}, SetOptions(merge: true));
    if (oldCode.isNotEmpty) b.delete(_db.collection('invites').doc(oldCode));
    await b.commit();
    return code;
  }

  @override
  bool get isDemo => false;

  @override
  Stream<List<Member>> members() =>
      _members.snapshots().map((s) => [for (final d in s.docs) Member.fromMap(d.id, d.data())]);

  @override
  Stream<List<Txn>> txns() =>
      _txns.snapshots().map((s) => [for (final d in s.docs) Txn.fromMap(d.id, d.data())]);

  @override
  Stream<List<Message>> messages() => _messages
      .orderBy('createdAt')
      .limitToLast(300)
      .snapshots()
      .map((s) => [for (final d in s.docs) Message.fromMap(d.id, d.data())]);

  @override
  Stream<LedgerSettings> settings() =>
      _settings.snapshots().map((d) => LedgerSettings.fromMap(d.data() ?? const {}));

  @override
  Stream<List<Meeting>> meetings() =>
      _meetings.snapshots().map((s) => [for (final d in s.docs) Meeting.fromMap(d.id, d.data())]);

  @override
  Stream<List<Notice>> notices() => _notices
      .orderBy('createdAt')
      .limitToLast(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) Notice.fromMap(d.id, d.data())]);

  @override
  Future<void> saveMeeting(Meeting m) {
    final data = {...m.toMap(), 'updatedAt': FieldValue.serverTimestamp()};
    return m.id.isEmpty ? _meetings.add(data) : _meetings.doc(m.id).set(data);
  }

  @override
  Future<void> deleteMeeting(String id) => _meetings.doc(id).delete();

  @override
  Future<void> setRotation(List<String> order) => _settings.set({'rotation': order}, SetOptions(merge: true));

  @override
  Future<void> postNotice(Notice n) => _notices.add({
        ...n.toMap(),
        'votes': <String, dynamic>{},
        'closed': false,
        'authorUid': FirebaseAuth.instance.currentUser?.uid,
      });

  @override
  Future<void> deleteNotice(String id) => _notices.doc(id).delete();

  @override
  Future<void> setNoticeClosed(String id, bool closed) => _notices.doc(id).update({'closed': closed});

  @override
  Future<void> vote(String noticeId, String memberId, List<int> choices) =>
      _notices.doc(noticeId).update({FieldPath(['votes', memberId]): choices});

  @override
  Future<void> saveTxn(Txn t) {
    final data = {
      ...t.toMap(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return t.id.isEmpty ? _txns.add(data) : _txns.doc(t.id).set(data);
  }

  @override
  Future<void> deleteTxn(String id) => _txns.doc(id).delete();

  @override
  Future<void> setExempt(String memberId, int year, bool exempt) => _members.doc(memberId).update({
        'exemptYears': exempt ? FieldValue.arrayUnion([year]) : FieldValue.arrayRemove([year]),
      });

  @override
  Future<void> setBirthday(String memberId, String? mmdd) =>
      _members.doc(memberId).update({'birthday': mmdd ?? FieldValue.delete()});

  @override
  Future<void> setPresident(String memberId) =>
      _settings.set({'presidentId': memberId}, SetOptions(merge: true));

  @override
  Future<void> transferTreasurer(String fromMemberId, String toMemberId) async {
    final from = Member.fromMap(fromMemberId, (await _members.doc(fromMemberId).get()).data() ?? {});
    final to = Member.fromMap(toMemberId, (await _members.doc(toMemberId).get()).data() ?? {});
    if (to.uid == null) {
      throw StateError('${to.name}님은 아직 앱에 가입하지 않았어요.');
    }
    // 한 번에 묶어서 저장해요. 중간에 끊겨도 총무가 0명이나 2명이 되지 않아요.
    final b = _db.batch()
      ..update(_members.doc(toMemberId), {'role': 'treasurer'})
      ..set(_accounts.doc(to.uid), {'role': 'treasurer'}, SetOptions(merge: true))
      ..update(_members.doc(fromMemberId), {'role': 'member'});
    if (from.uid != null) b.set(_accounts.doc(from.uid), {'role': 'member'}, SetOptions(merge: true));
    await b.commit();
  }

  @override
  Future<void> setPinned(String messageId, bool pinned) => _messages.doc(messageId).update({'pinned': pinned});

  @override
  Future<void> postMessage(Message m) => _messages.add({
        ...m.toMap(),
        'authorUid': FirebaseAuth.instance.currentUser?.uid,
      });

  @override
  Future<void> deleteMessage(String id) => _messages.doc(id).delete();

  // ---- 가입 ----

  Stream<List<JoinRequest>> joinRequests() => _requests.snapshots().map((s) => [
        for (final d in s.docs)
          JoinRequest(
            uid: d.id,
            memberId: d.data()['memberId'] as String?,
            name: d.data()['name'] as String?,
            email: d.data()['email'] as String?,
          ),
      ]);

  /// 총무가 가입 신청을 승인. 명단에 없던 새 이름이면 회원을 새로 만들어요.
  Future<void> approveJoin(JoinRequest r) async {
    final memberRef = r.memberId != null ? _members.doc(r.memberId) : _members.doc();
    final b = _db.batch();
    if (r.memberId == null) {
      b.set(memberRef, Member(id: '', name: (r.name ?? '').trim(), uid: r.uid).toMap());
    } else {
      b.update(memberRef, {'uid': r.uid});
    }
    b
      ..set(_accounts.doc(r.uid), {'memberId': memberRef.id, 'role': 'member', 'email': r.email})
      ..delete(_requests.doc(r.uid));
    await b.commit();
  }

  /// 총무가 가입 신청을 거절.
  Future<void> rejectJoin(String uid) => _requests.doc(uid).delete();
}

class JoinRequest {
  final String uid;

  /// 명단에서 고른 회원. 새 이름으로 신청했으면 null이고 [name]이 있어요.
  final String? memberId;
  final String? name;
  final String? email;

  const JoinRequest({required this.uid, this.memberId, this.name, this.email});
}

/// 내 모임 목록 한 줄.
enum MyGroupStatus { joined, pending, none }

/// 모임 찾기·만들기·가입 신청 (모임 바깥에서 하는 일).
class GroupDirectory {
  GroupDirectory({FirebaseFirestore? db}) : _dbOverride = db;

  final FirebaseFirestore? _dbOverride;

  /// 실제로 쓸 때 연결해요 (화면만 그리는 테스트에선 Firebase 없이도 만들 수 있게).
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _group(String gid) => _db.collection('groups').doc(gid);

  /// 헷갈리는 글자(0/O, 1/I/L)는 빼요.
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String randomCode([Random? rnd]) {
    final r = rnd ?? Random.secure();
    return [for (var i = 0; i < 6; i++) _alphabet[r.nextInt(_alphabet.length)]].join();
  }

  /// 아직 안 쓰인 초대코드.
  Future<String> freeCode() async {
    for (var i = 0; i < 8; i++) {
      final c = randomCode();
      if (!(await _db.collection('invites').doc(c).get()).exists) return c;
    }
    throw StateError('초대코드를 만들지 못했어요. 다시 해 주세요.');
  }

  /// 내가 들어간·신청한 모임 id들과 마지막으로 본 모임.
  Stream<(List<String>, String?)> myGroupIds(String uid) => _user(uid).snapshots().map((d) => (
        [for (final g in (d.data()?['groups'] as List? ?? const [])) '$g'],
        d.data()?['lastGroup'] as String?,
      ));

  Future<void> setLastGroup(String uid, String gid) =>
      _user(uid).set({'lastGroup': gid}, SetOptions(merge: true));

  Stream<Group?> group(String gid) =>
      _group(gid).snapshots().map((d) => d.exists ? Group.fromMap(d.id, d.data()!) : null);

  /// 이 모임에서 내 상태: 가입됨 / 승인 기다리는 중 / 신청 없음(거절됨).
  Stream<MyGroupStatus> status(String gid, String uid) async* {
    await for (final acc in _group(gid).collection('accounts').doc(uid).snapshots()) {
      if (acc.exists) {
        yield MyGroupStatus.joined;
        continue;
      }
      final req = await _group(gid).collection('joinRequests').doc(uid).get();
      yield req.exists ? MyGroupStatus.pending : MyGroupStatus.none;
    }
  }

  /// 이 모임에서 내 계정과 연결된 회원 id. 승인 전이면 null.
  Stream<String?> memberIdIn(String gid, String uid) =>
      _group(gid).collection('accounts').doc(uid).snapshots().map((d) => d.data()?['memberId'] as String?);

  /// 내 가입 신청이 아직 있는지 (승인되면 사라져요).
  Stream<bool> hasRequest(String gid, String uid) =>
      _group(gid).collection('joinRequests').doc(uid).snapshots().map((d) => d.exists);

  /// 초대코드로 모임 찾기. 없으면 null.
  Future<Group?> findByCode(String code) async {
    final c = code.trim().toUpperCase();
    if (c.length != 6) return null;
    final inv = await _db.collection('invites').doc(c).get();
    final gid = inv.data()?['groupId'] as String?;
    if (gid == null) return null;
    final g = await _group(gid).get();
    return g.exists ? Group.fromMap(g.id, g.data()!) : null;
  }

  /// 가입 화면에서 이름 고를 때 보는 명단 (아직 앱에 안 들어온 사람만).
  Future<List<Member>> openSeats(String gid) async {
    final s = await _group(gid).collection('members').get();
    return [
      for (final d in s.docs)
        if (d.data()['uid'] == null) Member.fromMap(d.id, d.data()),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 가입 신청. [memberId]가 없으면 [name]으로 새 회원 신청.
  Future<void> requestJoin({
    required String gid,
    required String uid,
    String? memberId,
    String? name,
    String? email,
  }) async {
    await _group(gid).collection('joinRequests').doc(uid).set({
      'memberId': memberId,
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _user(uid).set({
      'groups': FieldValue.arrayUnion([gid]),
      'lastGroup': gid,
    }, SetOptions(merge: true));
  }

  /// 신청을 거두거나 거절된 모임을 내 목록에서 빼요.
  Future<void> forget(String gid, String uid) async {
    try {
      await _group(gid).collection('joinRequests').doc(uid).delete();
    } catch (_) {
      // 이미 없으면 괜찮아요.
    }
    await _user(uid).set({'groups': FieldValue.arrayRemove([gid])}, SetOptions(merge: true));
  }

  /// 모임 나가기 (총무는 못 나가요: 먼저 총무를 넘기거나 모임을 지워요).
  /// 명단에 이름은 남고, 내 계정 연결만 풀려요.
  Future<void> leave(String gid, String uid) async {
    final acc = await _group(gid).collection('accounts').doc(uid).get();
    if (acc.data()?['role'] == 'treasurer') {
      throw StateError('총무는 나갈 수 없어요. 먼저 총무를 넘기거나 모임을 지워 주세요.');
    }
    final memberId = acc.data()?['memberId'] as String?;
    if (memberId != null) {
      await _group(gid).collection('members').doc(memberId).update({'uid': null});
    }
    if (acc.exists) await acc.reference.delete();
    await _forgetGroup(gid, uid);
  }

  /// 모임 지우기 (총무·회장). 기록·명단·공지·메시지까지 모두 지워요. 되돌릴 수 없어요.
  Future<void> deleteGroup(String gid, String uid) async {
    final g = _group(gid);
    // 1단계: 내용물. (설정·계정은 마지막까지 남겨야 권한 확인이 돼요)
    for (final name in const ['transactions', 'meetings', 'notices', 'messages', 'members', 'joinRequests']) {
      await _deleteAll(g.collection(name));
    }
    // 2단계: 설정 + 계정 + 초대코드 + 모임 한 번에
    final code = (await g.get()).data()?['inviteCode'] as String?;
    final accounts = await g.collection('accounts').get();
    final b = _db.batch();
    for (final d in (await g.collection('config').get()).docs) {
      b.delete(d.reference);
    }
    for (final d in accounts.docs) {
      b.delete(d.reference);
    }
    if (code != null) b.delete(_db.collection('invites').doc(code));
    b.delete(g);
    await b.commit();
    await _forgetGroup(gid, uid);
  }

  Future<void> _deleteAll(CollectionReference<Map<String, dynamic>> c) async {
    while (true) {
      final page = await c.limit(400).get();
      if (page.docs.isEmpty) return;
      final b = _db.batch();
      for (final d in page.docs) {
        b.delete(d.reference);
      }
      await b.commit();
    }
  }

  Future<void> _forgetGroup(String gid, String uid) => _user(uid).set({
        'groups': FieldValue.arrayRemove([gid]),
        'lastGroup': FieldValue.delete(),
      }, SetOptions(merge: true));

  /// 새 모임 만들기. 만든 사람이 총무가 돼요. 만든 모임 id를 돌려줘요.
  Future<String> create({
    required String uid,
    required String myName,
    required Group group,
    required LedgerSettings settings,
    String? email,
  }) async {
    final g = _db.collection('groups').doc();
    final code = await freeCode();
    final memberRef = g.collection('members').doc();
    // 1단계: 모임 + 내 총무 계정 + 초대코드 (보안 규칙이 "만든 사람"만 허용)
    await (_db.batch()
          ..set(g, {
            ...group.toMap(),
            'inviteCode': code,
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..set(g.collection('accounts').doc(uid), {'memberId': memberRef.id, 'role': 'treasurer', 'email': email})
          ..set(_db.collection('invites').doc(code), {'groupId': g.id})
          ..set(_user(uid), {
            'groups': FieldValue.arrayUnion([g.id]),
            'lastGroup': g.id,
            'email': email,
          }, SetOptions(merge: true)))
        .commit();
    // 2단계: 이제 총무라서 명단·설정을 쓸 수 있어요.
    await (_db.batch()
          ..set(memberRef, Member(id: '', name: myName.trim(), role: Role.treasurer, uid: uid).toMap())
          ..set(g.collection('config').doc('settings'), settings.toMap()))
        .commit();
    return g.id;
  }
}
