// 체험 모드(연결 전 미리보기)와 테스트에 쓰는 예시 모임 데이터.
// 이름은 모두 지어낸 예시예요. 날짜는 그 달 1일로 넣었어요.
import '../models/models.dart';

const seedMemberNames = [
  '김민준', '이서연', '박도윤', '최지우', '정하준', '강서윤',
  '조은우', '윤지호', '장수아', '임시우', '한예린', '오현우',
];

/// 현재 총무.
const seedTreasurer = '오현우';

/// 2026년 회비 면제 회원.
const seedExempt2026 = {'장수아', '한예린'};

final seedSettings = LedgerSettings(
  rotation: Regions.all,
  openingBalance: 1000000,
  openingDate: DateTime(2026, 1, 1),
  monthlyDues: 30000,
  presidentId: memberIdOf(seedPresident),
);

/// 회장. 처음 설정 때 들어가고, 예전에 설정한 장부에 값이 없을 때도 기본값이에요.
const seedGroup = Group(id: 'demo', name: '우리 모임', inviteCode: 'DEMO00');

const seedPresident = '이서연';

String memberIdOf(String name) => 'm_$name';

List<Member> seedMembers() => [
      for (final n in seedMemberNames)
        Member(
          id: memberIdOf(n),
          name: n,
          role: n == seedTreasurer ? Role.treasurer : Role.member,
          exemptYears: seedExempt2026.contains(n) ? const [2026] : const [],
        ),
    ];

/// (월, 분류, 항목, 금액, 관련 회원 이름)
typedef _Row = (int, String, String, int, String?);

const List<_Row> _income = [
  // 회비
  (1, '회비', '회비', 240000, '김민준'),
  (4, '회비', '회비', 120000, '김민준'),
  (1, '회비', '회비', 240000, '이서연'),
  (4, '회비', '회비', 120000, '이서연'),
  (6, '회비', '회비', 180000, '박도윤'),
  (9, '회비', '회비', 180000, '박도윤'),
  (4, '회비', '회비', 360000, '정하준'),
  (3, '회비', '회비', 240000, '강서윤'),
  (4, '회비', '회비', 120000, '강서윤'),
  (4, '회비', '회비', 360000, '오현우'),
  // 이자
  (1, '이자', '저축 이자', 18, null),
  (2, '이자', '저축 이자', 12, null),
  (3, '이자', '저축 이자', 54, null),
  (4, '이자', '저축 이자', 49, null),
  (6, '이자', '저축 이자', 8, null),
  (7, '이자', '저축 이자', 9, null),
  (8, '이자', '저축 이자', 10, null),
  (1, '이자', '세이프박스 이자', 3122, null),
  (2, '이자', '세이프박스 이자', 9072, null),
  (3, '이자', '세이프박스 이자', 7194, null),
  (4, '이자', '세이프박스 이자', 7318, null),
  (5, '이자', '세이프박스 이자', 7857, null),
  (6, '이자', '세이프박스 이자', 10910, null),
  (7, '이자', '세이프박스 이자', 9396, null),
  (8, '이자', '세이프박스 이자', 10571, null),
  // 기타
  (3, '기타', '입회비', 370211, '강서윤'),
  (1, '기타', '기잔고', 153, null),
  (4, '기타', '캐쉬백', 3900, null),
];

const List<_Row> _expense = [
  (4, '정기모임', '숙박', 314222, null),
  (4, '정기모임', '1차', 364000, null),
  (4, '정기모임', '2차', 107000, null),
  (4, '정기모임', '3차', 42000, null),
  (4, '정기모임', '4차', 75500, null),
  (4, '정기모임', '5차', 43300, null),
  (4, '정기모임', '6차', 92000, null),
  (1, '번개', '숙박', 230000, null),
  (1, '번개', '1차', 463000, null),
  (1, '번개', '2차', 111000, null),
  (1, '번개', '3차', 42200, null),
  (6, '경조사', '하준 빙부 근조화환', 99000, '정하준'),
  (1, '생일선물', '생일선물', 50000, '한예린'),
  (1, '생일선물', '생일선물', 50000, '조은우'),
  (2, '생일선물', '생일선물', 50000, '정하준'),
  (2, '생일선물', '생일선물', 50000, '최지우'),
  (3, '생일선물', '생일선물', 50000, '임시우'),
  (4, '생일선물', '생일선물', 50000, '박도윤'),
  (6, '생일선물', '생일선물', 50000, '이서연'),
  (8, '생일선물', '생일선물', 50000, '김민준'),
  (9, '생일선물', '생일선물', 50000, '강서윤'),
  (10, '생일선물', '생일선물', 50000, '장수아'),
];

List<Txn> seedTxns() {
  var n = 0;
  Txn make(_Row r, TxnType type) => Txn(
        id: 'seed_${n++}',
        date: DateTime(2026, r.$1, 1),
        type: type,
        category: r.$2,
        item: r.$3,
        amount: r.$4,
        memberId: r.$5 == null ? null : memberIdOf(r.$5!),
      );
  return [
    for (final r in _income) make(r, TxnType.income),
    for (final r in _expense) make(r, TxnType.expense),
  ];
}
