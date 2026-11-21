import '../models/models.dart';

/// 앱이 데이터를 읽고 쓰는 창구.
/// 실제 서비스는 Firestore, 연결 전에는 체험용 데모 데이터를 써요.
abstract class LedgerRepository {
  bool get isDemo;

  /// 이 장부가 속한 모임 (이름·사진·초대코드).
  Stream<Group> group();

  Stream<List<Member>> members();
  Stream<List<Txn>> txns();
  Stream<List<Message>> messages();
  Stream<LedgerSettings> settings();
  Stream<List<Meeting>> meetings();
  Stream<List<Notice>> notices();

  // 총무만 (서버 보안 규칙에서도 막혀 있어요)
  /// 모임 이름·색·사진 바꾸기.
  Future<void> updateGroup(Group g);

  /// 시작 잔고·회비·분류 같은 장부 설정 저장.
  Future<void> saveSettings(LedgerSettings s);

  /// 명단에 회원 넣기 (앱 가입 전이어도 회비 기록을 남길 수 있게).
  Future<void> addMember(String name);

  /// 아직 앱에 가입 안 한 회원을 명단에서 빼기.
  Future<void> removeMember(String memberId);

  Future<void> saveTxn(Txn t);
  Future<void> deleteTxn(String id);
  Future<void> setExempt(String memberId, int year, bool exempt);

  /// 회장 정하기 (총무만).
  Future<void> setPresident(String memberId);

  /// 생일 넣기·지우기 (총무만). [mmdd]가 null이면 지워요.
  Future<void> setBirthday(String memberId, String? mmdd);
  Future<void> transferTreasurer(String fromMemberId, String toMemberId);
  Future<void> setPinned(String messageId, bool pinned);

  /// 모임 기록 (총무만). id가 비어 있으면 새로 만들어요.
  Future<void> saveMeeting(Meeting m);
  Future<void> deleteMeeting(String id);

  /// 정기모임 지역 순서 (총무만).
  Future<void> setRotation(List<String> order);

  /// 공지·투표 올리기 (총무만).
  Future<void> postNotice(Notice n);
  Future<void> deleteNotice(String id);
  Future<void> setNoticeClosed(String id, bool closed);

  // 누구나
  /// 내 표 넣기. [choices]가 비면 표를 거둬요.
  Future<void> vote(String noticeId, String memberId, List<int> choices);

  Future<void> postMessage(Message m);
  Future<void> deleteMessage(String id);
}
