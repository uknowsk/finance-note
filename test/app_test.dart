import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:chongmu_note/data/demo_repository.dart';
import 'package:chongmu_note/data/demo_seed.dart';
import 'package:chongmu_note/main.dart';
import 'package:chongmu_note/models/models.dart';
import 'package:chongmu_note/state/app_state.dart';
import 'package:chongmu_note/models/meeting_math.dart';
import 'package:chongmu_note/ui/pages/ledger_page.dart';
import 'package:chongmu_note/ui/pages/meetings_page.dart';
import 'package:chongmu_note/ui/pages/notices_page.dart';
import 'package:chongmu_note/ui/pages/txn_editor.dart';
import 'package:chongmu_note/ui/widgets/charts.dart';
import 'package:chongmu_note/ui/widgets/common.dart';
import 'package:chongmu_note/data/firestore_repository.dart';
import 'package:chongmu_note/ui/invite.dart';
import 'package:chongmu_note/ui/pages/card_import_page.dart';
import 'package:chongmu_note/ui/sign_in.dart';
import 'package:chongmu_note/ui/pages/support_page.dart';
import 'package:chongmu_note/ui/format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ChongmuNoteApp(useFirebase: false));
    await tester.pumpAndSettle();
  }

  testWidgets('처음 열면 총무노트 아이콘과 이름이 보이고, 곧 앱으로 넘어간다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ChongmuNoteApp(useFirebase: false));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('총무노트'), findsOneWidget);
    expect(find.bySemanticsLabel('총무노트'), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('총무노트'), findsNothing);
    // 홈 제목은 모임 이름
    expect(find.text('우리 모임'), findsWidgets);
    expect(find.text('지금 잔고'), findsOneWidget);
  });

  testWidgets('세로 화면: 하단 탭 6개가 보이고 탭을 옮겨 다닐 수 있다', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('지금 잔고'), findsOneWidget);
    for (final tab in ['장부', '회비', '모임', '소식', '설정']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('가로 화면: 왼쪽 메뉴로 바뀐다', (tester) async {
    await pumpAt(tester, const Size(844, 390));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('작은 폰에서도 넘치지 않는다', (tester) async {
    await pumpAt(tester, const Size(320, 640));
    for (final tab in ['장부', '회비', '모임', '소식', '설정', '홈']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('폰 글씨를 크게 해도 넘치지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpAt(tester, const Size(360, 740));
    for (final tab in ['장부', '회비', '모임', '소식', '설정', '홈']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('기록 추가·이자 입력·기록 상세 창이 뜬다', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    for (final b in ['기록 추가', '이자 입력']) {
      await tester.tap(find.text(b));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TxnEditor), findsOneWidget, reason: b);
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.byType(TxnEditor), findsNothing);
    }
    // 장부 탭: + 버튼과 기록 누르기
    await tester.tap(find.text('장부').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TxnEditor), findsOneWidget);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TxnTile).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TxnDetail), findsOneWidget);
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TxnEditor), findsOneWidget);
    Navigator.of(tester.element(find.byType(TxnEditor))).pop();
    await tester.pumpAndSettle();
    // 회비 탭: 회원 카드 누르기
    await tester.tap(find.text('회비').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('김민준'), 200);
    await tester.tap(find.text('김민준'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('홈에 그래프 3개가 그려진다', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.byType(BalanceTrendCard), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(ExpenseDonutCard), 300);
    expect(find.byType(MonthlyFlowCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('아래 창 버튼이 폰 하단 뒤로가기 줄에 가리지 않는다', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    await pumpAt(tester, const Size(390, 844));
    await tester.tap(find.text('장부').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TxnTile).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final fix = tester.getRect(find.ancestor(of: find.text('수정'), matching: find.byType(FilledButton)));
    expect(fix.bottom, lessThanOrEqualTo(844 - 48));
  });

  Future<AppState> pumpAs(WidgetTester tester, String name) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(DemoRepository(), myMemberId: memberIdOf(name));
    await tester.pumpWidget(ChongmuNoteApp(useFirebase: false, demoState: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정').last);
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> toggleExempt(WidgetTester tester, String name, String action) async {
    await tester.scrollUntilVisible(find.text(name), 200);
    await Scrollable.ensureVisible(tester.element(find.text(name).last), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('회장(이서연)은 배지만 있고 면제 메뉴는 없다', (tester) async {
    final s = await pumpAs(tester, '이서연');
    expect(s.isPresident, isTrue);
    expect(s.canManageExempt, isFalse);
    expect(find.text('회장'), findsWidgets);
    await tester.scrollUntilVisible(find.text('장수아').last, 200);
    await Scrollable.ensureVisible(tester.element(find.text('장수아').last), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('장수아').last);
    await tester.pumpAndSettle();
    expect(find.text('면제 풀기'), findsNothing);
  });

  testWidgets('총무는 회원 목록에서 면제를 걸고 풀 수 있다', (tester) async {
    final t = await pumpAs(tester, seedTreasurer);
    expect(t.canManageExempt, isTrue);
    final year = DateTime.now().year;
    bool exempt() => t.memberById(memberIdOf('김민준'))!.isExempt(year);
    await toggleExempt(tester, '김민준', '회비 면제하기');
    expect(exempt(), isTrue);
    await toggleExempt(tester, '김민준', '회비 면제 풀기');
    expect(exempt(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('일반 회원은 면제 메뉴가 없다', (tester) async {
    final m = await pumpAs(tester, '김민준');
    expect(m.canManageExempt, isFalse);
    await tester.scrollUntilVisible(find.text('박도윤'), 200);
    await Scrollable.ensureVisible(tester.element(find.text('박도윤').last), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('박도윤').last);
    await tester.pumpAndSettle();
    expect(find.text('회비 면제하기'), findsNothing);
  });

  testWidgets('총무가 회원 목록에서 생일을 넣고 지운다', (tester) async {
    final t = await pumpAs(tester, seedTreasurer);
    await toggleExempt(tester, '박도윤', '생일 넣기');
    expect(find.text('박도윤 생일'), findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(t.memberById(memberIdOf('박도윤'))!.birthday, '01-01');
    expect(find.text('🎂 1월 1일'), findsOneWidget);
    await toggleExempt(tester, '박도윤', '생일 지우기');
    expect(t.memberById(memberIdOf('박도윤'))!.birthday, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이번 달 생일자가 홈에 보인다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(DemoRepository(), myMemberId: memberIdOf('김민준'));
    final now = DateTime.now();
    await tester.pumpWidget(ChongmuNoteApp(useFirebase: false, demoState: state));
    await tester.pumpAndSettle();
    expect(find.text('${now.month}월 생일'), findsNothing);
    await state.repo.setBirthday(memberIdOf('장수아'), Member.birthdayKey(now.month, 12));
    // 새로 생긴 카드가 살짝 늦게 떠오르는 효과(타이머)까지 흘려보내요.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('${now.month}월 생일'), findsOneWidget);
    expect(find.text('장수아 12일'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('장부에서 월간·연간 수입/지출을 본다', (tester) async {
    for (final size in [const Size(390, 844), const Size(320, 640), const Size(844, 390)]) {
      await tester.pumpWidget(const SizedBox());
      await pumpAt(tester, size);
      await tester.tap(find.text('장부').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('월간'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      expect(find.text('${now.year}년 ${now.month}월'), findsOneWidget);
      await tester.tap(find.byTooltip('이전'));
      await tester.pumpAndSettle();
      final prev = DateTime(now.year, now.month - 1);
      expect(find.text('${prev.year}년 ${prev.month}월'), findsOneWidget);
      expect(find.text('지출 항목별'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size 월간');
      await tester.tap(find.text('연간'));
      await tester.pumpAndSettle();
      expect(find.text('${now.year}년'), findsOneWidget);
      expect(find.byType(MonthlyFlowCard), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('ym1')), 200);
      await Scrollable.ensureVisible(tester.element(find.byKey(const ValueKey('ym1'))), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ym1')));
      await tester.pumpAndSettle();
      expect(find.text('${now.year}년 1월'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size 연간');
      await tester.pump(const Duration(seconds: 1));
    }
  });

  test('분류: 기본 목록이 있고, 수입에는 늘 회비가 맨 앞', () {
    for (final c in ['숙박', '교통', '식사', '경조사']) {
      expect(Categories.expense, contains(c));
    }
    final st = LedgerSettings.fromMap(const {
      'incomeCategories': ['후원금'],
      'expenseCategories': ['회식'],
    });
    expect(st.categoriesOf(TxnType.income), ['회비', '후원금']);
    expect(st.categoriesOf(TxnType.expense), ['회식']);
    expect(LedgerSettings.fromMap(const {}).categoriesOf(TxnType.expense), Categories.expense);
  });

  Future<AppState> openTab(WidgetTester tester, String name, String tab, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(DemoRepository(), myMemberId: memberIdOf(name));
    await tester.pumpWidget(ChongmuNoteApp(useFirebase: false, demoState: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tab).last);
    await tester.pumpAndSettle();
    return state;
  }

  test('장소 로테이션: 마지막 정기모임 다음 지역, 기록 없으면 첫 지역', () {
    const order = Regions.all;
    expect(MeetingMath.nextRegion(order, const []), '서울·경기');
    final ms = [
      Meeting(id: 'a', date: DateTime(2026, 3), kind: MeetingKind.regular, region: '경상'),
      Meeting(id: 'b', date: DateTime(2026, 6), kind: MeetingKind.regular, region: '부산'),
      Meeting(id: 'c', date: DateTime(2026, 7), kind: MeetingKind.flash, region: '충청'),
    ];
    expect(MeetingMath.nextRegion(order, ms), '서울·경기', reason: '부산 다음은 처음으로, 번개는 안 셈');
    expect(MeetingMath.nextRegion(['부산', '경상', '충청', '서울·경기'], ms), '경상');
  });

  test('참석률: 모임 종류·연도별로 센다', () {
    final mem = [
      for (final n in ['가', '나']) Member(id: n, name: n),
    ];
    final ms = [
      Meeting(id: '1', date: DateTime(2026, 1), kind: MeetingKind.regular, attendeeIds: const ['가', '나']),
      Meeting(id: '2', date: DateTime(2026, 2), kind: MeetingKind.flash, attendeeIds: const ['가']),
      Meeting(id: '3', date: DateTime(2025, 2), kind: MeetingKind.regular, attendeeIds: const ['나']),
    ];
    final all = MeetingMath.attendance(mem, ms);
    expect(all.first.member.name, '가');
    expect((all.first.attended, all.first.total), (2, 3));
    final y = MeetingMath.attendance(mem, ms, year: 2026, kind: MeetingKind.regular);
    expect([for (final a in y) a.percent], [100, 100]);
  });

  test('공지·투표는 저장 형식으로 바꿨다 되돌려도 같다', () {
    final n = Notice(
      id: 'x',
      authorId: 'm',
      authorName: '총무',
      title: '날짜',
      createdAt: DateTime(2026, 11, 1),
      poll: Poll(options: const ['A', 'B'], multi: true, deadline: DateTime(2026, 11, 5)),
      votes: const {
        'p': [0, 1],
        'q': [1],
        'r': [],
      },
    );
    final back = Notice.fromMap('x', n.toMap());
    expect(back.counts, [1, 2]);
    expect(back.voters, 2);
    expect(back.poll!.multi, isTrue);
    expect(back.isOpen(DateTime(2026, 11, 4)), isTrue);
    expect(back.isOpen(DateTime(2026, 11, 6)), isFalse);
    expect(back.copyWith(closed: true).isOpen(DateTime(2026, 11, 2)), isFalse);
    final m = Meeting(
      id: 'm',
      date: DateTime(2026, 5, 2),
      kind: MeetingKind.flash,
      place: '대전',
      attendeeIds: const ['a'],
    );
    final mb = Meeting.fromMap('m', m.toMap());
    expect((mb.kind, mb.place, mb.region), (MeetingKind.flash, '대전', null));
    expect(mb.attendeeIds, ['a']);
    final st = LedgerSettings.fromMap(const {
      'rotation': ['부산', '경상'],
    });
    expect(st.rotation, ['부산', '경상']);
    // 새 모임은 지역 돌아가기·회비 없이 시작
    expect(LedgerSettings.fromMap(const {}).rotation, isEmpty);
    expect(LedgerSettings.fromMap(const {}).usesDues, isFalse);
    final g = Group.fromMap('g', const Group(id: 'g', name: '등산 모임', inviteCode: 'ABC234').toMap());
    expect((g.name, g.inviteCode, g.initial), ('등산 모임', 'ABC234', '등'));
  });

  testWidgets('모임 탭: 다음 차례 지역이 보이고, 총무가 참석자와 함께 모임을 기록한다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '모임');
    // 데모: 마지막 정기모임이 서울·경기 → 다음은 충청
    expect(find.text('다음은 충청 차례', findRichText: true), findsOneWidget);
    await tester.tap(find.byTooltip('모임 기록하기'));
    await tester.pumpAndSettle();
    expect(find.byType(MeetingEditor), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '장소 (예: 대전 유성 ○○식당)'), '청주');
    await tester.tap(find.text('모두 넣기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilterChip, '김민준'));
    await tester.tap(find.widgetWithText(FilterChip, '김민준'));
    await tester.pumpAndSettle();
    expect(find.text('참석자 ${s.members.length - 1}명'), findsOneWidget);
    await tester.ensureVisible(find.text('저장'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final saved = s.meetings.first;
    expect((saved.region, saved.place, saved.attendeeIds.length), ('충청', '청주', s.members.length - 1));
    expect(saved.attendeeIds, isNot(contains(memberIdOf('김민준'))));
    expect(find.text('다음은 경상 차례', findRichText: true), findsOneWidget);
    // 참석률 보기
    await tester.tap(find.text('참석률'));
    await tester.pumpAndSettle();
    expect(find.text('모임 4번'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('총무가 장소 순서를 바꾼다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '모임');
    await tester.tap(find.text('바꾸기'));
    await tester.pumpAndSettle();
    expect(find.text('지역 돌아가기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await s.repo.setRotation(const ['부산', '경상', '충청', '서울·경기']);
    await tester.pumpAndSettle();
    expect(s.settings!.rotation.first, '부산');
  });

  testWidgets('일반 회원은 모임을 기록할 수 없고 보기만 한다', (tester) async {
    await openTab(tester, '김민준', '모임');
    expect(find.byTooltip('모임 기록하기'), findsNothing);
    expect(find.text('순서 바꾸기'), findsNothing);
    await tester.tap(find.textContaining('부산').last);
    await tester.pumpAndSettle();
    expect(find.text('수정'), findsNothing);
  });

  testWidgets('회원이 투표하고, 단일 투표는 하나만 골라진다', (tester) async {
    final s = await openTab(tester, '김민준', '소식');
    expect(find.text('12월 정기모임 날짜 정해요'), findsOneWidget);
    expect(find.byTooltip('새 공지'), findsNothing);
    final me = memberIdOf('김민준');
    await tester.tap(find.text('12월 6일 (토)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12월 20일 (토)'));
    await tester.pumpAndSettle();
    expect(s.notices.first.choicesOf(me), [0, 2], reason: '여러 개 고르기');
    // 단일 투표 하나 올려서 확인
    await s.repo.postNotice(
      Notice(
        id: '',
        authorId: 't',
        authorName: '총무',
        title: '장소 하나만',
        createdAt: DateTime.now(),
        poll: const Poll(options: ['청주', '대전']),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('청주'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대전'));
    await tester.pumpAndSettle();
    expect(s.notices.first.choicesOf(me), [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('총무가 날짜 투표를 올리고 마감한다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '소식');
    await tester.tap(find.byTooltip('새 공지'));
    await tester.pumpAndSettle();
    expect(find.byType(NoticeEditor), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '제목 (예: 12월 정기모임 날짜)'), '송년회 장소');
    await tester.tap(find.text('투표 붙이기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '항목 1 (날짜나 장소)'), '대전');
    await tester.enterText(find.widgetWithText(TextField, '항목 2 (날짜나 장소)'), '청주');
    await tester.ensureVisible(find.text('항목 추가'));
    await tester.tap(find.text('항목 추가'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '항목 3 (날짜나 장소)'), findsOneWidget);
    await tester.ensureVisible(find.text('올리기'));
    await tester.tap(find.text('올리기'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final n = s.notices.first;
    expect((n.title, n.poll!.multi), ('송년회 장소', false));
    expect(n.poll!.options, ['대전', '청주']);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('투표 마감하기'));
    await tester.pumpAndSettle();
    expect(s.notices.first.closed, isTrue);
    expect(find.text('마감'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈에 진행 중 투표와 다음 모임 지역 카드가 보인다', (tester) async {
    await openTab(tester, '김민준', '홈');
    expect(find.text('진행 중인 투표 1개'), findsOneWidget);
    expect(find.text('다음 정기모임은 충청 차례'), findsOneWidget);
    await tester.tap(find.byKey(const Key('homePolls')));
    await tester.pumpAndSettle();
    expect(find.byType(NoticesView), findsOneWidget);
  });

  testWidgets('작은 폰·큰 글씨에서 모임·소식 화면이 넘치지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openTab(tester, seedTreasurer, '모임', size: const Size(320, 640));
    await tester.tap(find.text('참석률'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('모임 기록하기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(MeetingEditor))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('소식').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('새 공지'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('투표 붙이기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('회장(이서연)도 모임 기록과 공지를 쓸 수 있다', (tester) async {
    final s = await openTab(tester, '이서연', '모임');
    expect(s.canManageEvents, isTrue);
    expect(find.byTooltip('모임 기록하기'), findsOneWidget);
    expect(find.text('순서 바꾸기'), findsNothing, reason: '장소 순서는 총무만');
    await tester.tap(find.text('소식').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('새 공지'), findsOneWidget);
  });

  // ───────── 누구나 쓰는 모임 기능 ─────────

  test('초대코드는 헷갈리는 글자 없이 6자리, 초대 글에 코드와 앱 주소가 들어간다', () {
    for (var i = 0; i < 200; i++) {
      final c = GroupDirectory.randomCode();
      expect(c, hasLength(6));
      expect(c, isNot(matches(RegExp('[01OIL]'))));
    }
    final msg = inviteMessage(const Group(id: 'g', name: '등산 모임', inviteCode: 'ABC234'));
    expect(msg, contains('ABC234'));
    expect(msg, contains('등산 모임'));
    expect(msg, contains(appDownloadUrl));
  });

  testWidgets('총무가 설정에서 회원을 넣고 뺀다', (tester) async {
    final t = await pumpAs(tester, seedTreasurer);
    final before = t.members.length;
    await tester.scrollUntilVisible(find.text('+ 회원 넣기'), 200);
    await Scrollable.ensureVisible(tester.element(find.text('+ 회원 넣기')), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ 회원 넣기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('askText')), '새친구');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(t.members.length, before + 1);
    await toggleExempt(tester, '새친구', '명단에서 빼기');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(t.members.any((m) => m.name == '새친구'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('일반 회원은 회원 넣기·모임 설정이 없고, 초대코드는 볼 수 있다', (tester) async {
    await pumpAs(tester, '김민준');
    expect(find.text('모임 설정'), findsNothing);
    expect(find.text('DEMO00'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('박도윤'), 200);
    expect(find.text('+ 회원 넣기'), findsNothing);
  });

  testWidgets('회비 없는 모임: 회비 탭은 안내만, 홈에 내 회비 카드가 없다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '회비');
    await s.repo.saveSettings(s.settings!.copyWith(monthlyDues: 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('noDues')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('지역 돌아가기를 끄면 홈 카드가 사라지고 모임 탭에 켜기 버튼이 생긴다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '홈');
    expect(find.byKey(const Key('homeNextRegion')), findsOneWidget);
    await s.repo.setRotation(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeNextRegion')), findsNothing);
    await tester.tap(find.text('모임').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rotationOn')));
    await tester.pumpAndSettle();
    // 예시 지역으로 시작해요. 하나 더 넣고 저장
    await tester.enterText(find.byKey(const Key('regionAdd')), '제주');
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('저장'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(s.settings!.rotation, [...Regions.all, '제주']);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('총무가 바꾼 분류가 기록 추가 화면에 나온다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '장부');
    await s.repo.saveSettings(s.settings!.copyWith(expenseCategories: const ['회식', '기타']));
    await tester.pumpAndSettle();
    await tester.tap(find.text('홈').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();
    expect(find.byType(TxnEditor), findsOneWidget);
    expect(find.text('회식'), findsOneWidget);
    expect(find.text('숙박'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모임 이름을 바꾸면 홈 제목이 바뀐다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '홈');
    await s.repo.updateGroup(s.group!.copyWith(name: '토요 축구회'));
    await tester.pumpAndSettle();
    expect(find.text('토요 축구회'), findsWidgets);
  });

  // ───────── 카드 문자로 지출 넣기 ─────────

  Future<AppState> openCardImportAs(WidgetTester tester) async {
    final s = await openTab(tester, seedTreasurer, '홈');
    await tester.tap(find.text('카드 문자'));
    await tester.pumpAndSettle();
    expect(find.byType(CardImportPage), findsOneWidget);
    // 처음엔 꺼져 있어요 → 스위치로 켜기
    expect(s.settings!.smsEnabled, isFalse);
    await tester.tap(find.byKey(const Key('smsSwitch')));
    await tester.pumpAndSettle();
    expect(s.settings!.smsEnabled, isTrue);
    return s;
  }

  testWidgets('카드 문자 스위치를 끄면 꺼지고, 홈 알림도 사라진다', (tester) async {
    final s = await openCardImportAs(tester);
    expect(find.text('새 카드 결제 3건'), findsOneWidget);
    await tester.tap(find.byKey(const Key('smsSwitch')));
    await tester.pumpAndSettle();
    expect(s.settings!.smsEnabled, isFalse);
    expect(find.text('새 카드 결제 3건'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeSms')), findsNothing);
  });

  testWidgets('달력에서 고른 날짜의 카드 문자만 읽는다', (tester) async {
    await openCardImportAs(tester);
    final now = DateTime.now();
    final target = DateUtils.dateOnly(now.subtract(const Duration(days: 1, hours: 2)));
    final demoDays = [
      now.subtract(const Duration(hours: 3)),
      now.subtract(const Duration(days: 1, hours: 2)),
      now.subtract(const Duration(days: 2, hours: 5)),
    ].map(DateUtils.dateOnly);
    final expected = demoDays.where((d) => d == target).length;

    await tester.ensureVisible(find.byKey(const Key('pickDates')));
    await tester.tap(find.byKey(const Key('pickDates')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모두 지우기'));
    await tester.pump();
    if (target.month != now.month) {
      await tester.tap(find.byTooltip('지난달'));
      await tester.pump();
    }
    await tester.tap(find.byKey(Key('day-${target.month}-${target.day}')));
    await tester.pump();
    expect(find.text('1일 골랐어요'), findsOneWidget);
    await tester.tap(find.byKey(const Key('datesDone')));
    await tester.pumpAndSettle();
    expect(find.text('새 카드 결제 $expected건'), findsOneWidget);
    expect(find.text('${target.month}/${target.day} (${weekday(target)})'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 640), Size(360, 760), Size(844, 390)]) {
    testWidgets('카드 문자 화면이 좁거나 가로인 화면에서도 깨지지 않는다 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await openCardImportAs(tester);
      expect(tester.takeException(), isNull);
      // 체크 끄고 켜기
      final before = find.textContaining('장부에 넣기');
      expect(before, findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.textContaining('2건 ·'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.textContaining('3건 ·'), findsOneWidget);
      // 날짜 칩 글자가 세로로 쪼개지지 않게: 한 줄 높이
      final chip = find.byType(InputChip).first;
      expect(tester.getSize(chip).height, lessThan(60));
      expect(s.settings!.smsEnabled, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('총무가 카드 문자 3건을 분류 확인 후 장부에 넣고, 다시는 안 나온다', (tester) async {
    final s = await openCardImportAs(tester);
    expect(find.text('새 카드 결제 3건'), findsOneWidget);
    // 가게 이름으로 분류를 짐작 (펜션 → 숙박)
    expect(find.text('숙박'), findsOneWidget);
    final before = s.txns.length;
    await tester.ensureVisible(find.byKey(const Key('smsSave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('smsSave')));
    await tester.pumpAndSettle();
    expect(s.txns.length, before + 3);
    final pension = s.txns.firstWhere((t) => t.item == '해운대펜션');
    expect((pension.amount, pension.category, pension.type), (180000, '숙박', TxnType.expense));
    expect(pension.smsKey, isNotNull);
    expect(s.settings!.smsEnabled, isTrue);
    expect(find.text('새 카드 결제 0건'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 홈으로 돌아가도 '새 카드 결제' 알림은 없어요 (모두 넣음)
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeSms')), findsNothing);
  });

  testWidgets('카드를 고르면 그 카드 문자만, 넘긴 문자는 다시 안 나온다', (tester) async {
    final s = await openCardImportAs(tester);
    await s.repo.saveSettings(s.settings!.copyWith(cardFilters: const ['신한 1234']));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('다시 찾기'));
    await tester.pumpAndSettle();
    expect(find.text('새 카드 결제 2건'), findsOneWidget);
    await tester.tap(find.text('넘기기').first);
    await tester.pumpAndSettle();
    expect(s.settings!.smsIgnored, hasLength(1));
    await tester.tap(find.byTooltip('다시 찾기'));
    await tester.pumpAndSettle();
    expect(find.text('새 카드 결제 1건'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('카드 문자를 켠 총무 홈에 새 결제 알림이 뜬다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '홈');
    await s.repo.saveSettings(s.settings!.copyWith(smsEnabled: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeSms')), findsOneWidget);
    await tester.tap(find.byKey(const Key('homeSms')));
    await tester.pumpAndSettle();
    expect(find.byType(CardImportPage), findsOneWidget);
  });

  testWidgets('일반 회원 홈에는 카드 문자 버튼이 없다', (tester) async {
    await openTab(tester, '김민준', '홈');
    expect(find.text('카드 문자'), findsNothing);
  });

  // ───────── 초대코드로 들어가기 ─────────

  test('복사한 초대 글에서 코드를 찾는다', () {
    final msg = inviteMessage(const Group(id: 'g', name: '등산 모임', inviteCode: 'ABC234'));
    expect(extractInviteCode(msg), 'ABC234');
    expect(extractInviteCode('  xyz789 '), 'XYZ789');
    expect(extractInviteCode('초대코드: Q2W3E4 입니다'), 'Q2W3E4');
    expect(extractInviteCode('오늘 저녁 7시 모여요'), isNull);
    expect(extractInviteCode(''), isNull);
  });

  for (final size in [const Size(390, 844), const Size(320, 640), const Size(844, 390)]) {
    testWidgets('초대코드 화면에 입력칸이 보이고, 복사한 코드가 자동으로 들어간다 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: JoinGroupPage(
            dir: GroupDirectory(),
            uid: 'u1',
            // 실제 서버 대신: 찾기는 실패해도 화면은 그대로여야 해요.
            readClipboard: () async => '[총무노트] 초대\n초대코드: ABC234',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('inviteCode')), findsOneWidget);
      expect(find.byKey(const Key('findGroup')), findsOneWidget);
      expect(find.text('ABC234'), findsOneWidget);
      expect(find.textContaining('자동으로'), findsNothing);
      expect(find.textContaining('코드를 찾아 넣었어요'), findsOneWidget);
    });
  }

  // ───────── 개발자 후원 ─────────

  testWidgets('설정에서 개발자 후원 화면이 열린다', (tester) async {
    await openTab(tester, '김민준', '설정');
    await tester.scrollUntilVisible(find.text('☕ 개발자 후원하기'), 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('☕ 개발자 후원하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 640), Size(390, 844), Size(844, 390)]) {
    testWidgets('후원: 금액을 고르면 토스 링크에 금액이 들어간다 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final opened = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: SupportPage(
          info: const SupportInfo(
              tossId: 'devid', kakaoPayUrl: 'https://qr.kakaopay.com/abc', bank: '토스뱅크', account: '1000-1234-5678', holder: '개발자'),
          open: (u) async {
            opened.add(u);
            return true;
          },
        ),
      ));
      await tester.tap(find.byKey(const Key('amount-5000')));
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const Key('payToss')), 80, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('payToss')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('payToss')));
      await tester.pump();
      expect(opened.last, 'https://toss.me/devid/5000');
      await tester.scrollUntilVisible(find.byKey(const Key('payKakao')), 80, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('payKakao')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('payKakao')));
      await tester.pump();
      expect(opened.last, 'https://qr.kakaopay.com/abc');
      await tester.scrollUntilVisible(find.byKey(const Key('copyAccount')), 80, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('copyAccount')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('후원: 토스 아이디가 없으면 계좌로 토스 송금 화면을 연다', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: SupportPage(
        info: const SupportInfo(bank: '국민은행', account: '123-45-6789', holder: '개발자'),
        open: (u) async {
          opened.add(u);
          return true;
        },
      ),
    ));
    expect(find.byKey(const Key('payKakao')), findsNothing);
    await tester.tap(find.byKey(const Key('amount-2000')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('payToss')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('payToss')));
    await tester.pump();
    final u = Uri.parse(opened.single);
    expect((u.scheme, u.host), ('supertoss', 'send'));
    expect(u.queryParameters, {'amount': '2000', 'bank': '국민은행', 'accountNo': '123456789'});
  });

  testWidgets('후원 받을 곳이 비어 있으면 준비 중 안내만', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SupportPage(info: SupportInfo())));
    expect(find.textContaining('준비하고 있어요'), findsOneWidget);
    expect(find.byKey(const Key('payToss')), findsNothing);
  });
}
