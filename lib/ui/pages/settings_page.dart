import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/firestore_repository.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../update/update_prompt.dart';
import '../../update/updater.dart';
import '../format.dart';
import '../invite.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/group_avatar.dart';
import '../widgets/sheet.dart';
import 'card_import_page.dart';
import 'ledger_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.onSignOut, this.onSwitchGroup});

  final VoidCallback? onSignOut;
  final VoidCallback? onSwitchGroup;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final me = s.me;
    final repo = s.repo;

    Widget group(List<Widget> rows) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final (i, r) in rows.indexed) ...[
                if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 16, color: Theme.of(context).dividerColor),
                r,
              ],
            ]),
          ),
        );

    Widget tile(String title, {String? value, Widget? trailing, VoidCallback? onTap, Color? color}) {
      final row = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Expanded(child: Text(title, style: tt.bodyLarge!.copyWith(color: color))),
          if (value != null) Text(value, style: tt.bodyLarge!.copyWith(color: AppColors.gray)),
          ?trailing,
          if (onTap != null && trailing == null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.gray),
        ]),
      );
      return onTap == null ? row : Pressable(onTap: onTap, child: row);
    }

    return LargeTitlePage(
      title: '설정',
      slivers: [
        SliverList.list(children: [
          if (repo.isDemo) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppCard(
                child: Row(children: [
                  const Icon(Icons.science_rounded, color: AppColors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('체험 모드예요. 예시 모임으로 미리 보는 중이고, 바꾼 내용은 저장되지 않아요.',
                        style: tt.bodyMedium),
                  ),
                ]),
              ),
            ),
            const SectionHeader('누구로 볼까요?'),
            group([
              tile('보는 사람', value: me?.name, onTap: () => _pickMember(context, '누구로 볼까요?', (m) => s.actAs(m.id))),
            ]),
          ],
          const SectionHeader('내 정보'),
          group([
            tile('이름', value: me?.name ?? '-'),
            tile('역할',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (s.isPresident) ...[const Badge2('회장', color: AppColors.orange), const SizedBox(width: 6)],
                  if (s.isTreasurer) const Badge2('총무', color: AppColors.blue),
                  if (!s.isPresident && !s.isTreasurer) const Badge2('회원', color: AppColors.gray),
                ])),
            if (onSignOut != null) tile('로그아웃', color: AppColors.red, onTap: onSignOut),
          ]),
          const SectionHeader('모임'),
          group([
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                GroupAvatar(group: s.group!, size: 40),
                const SizedBox(width: 12),
                Expanded(child: Text(s.group!.name, style: tt.titleMedium)),
              ]),
            ),
            tile('초대코드',
                value: s.group!.inviteCode,
                onTap: () => showAppSheet(context, (_) => const _InviteSheet(), scrollable: false)),
            if (onSwitchGroup != null) tile('다른 모임 보기 · 새 모임', onTap: onSwitchGroup),
          ]),
          if (s.isTreasurer) ...[
            const SectionHeader('모임 설정'),
            group([
              tile('이름 · 사진 · 색',
                  onTap: () => showAppSheet(context, (_) => const _GroupEditor())),
              tile('한 달 회비 · 시작 잔고',
                  value: s.settings!.usesDues ? won(s.settings!.monthlyDues) : '회비 없음',
                  onTap: () => showAppSheet(context, (_) => const _MoneyEditor())),
              tile('수입 · 지출 분류',
                  onTap: () => showAppSheet(context, (_) => const _CategoryEditor())),
              tile('카드 문자로 지출 넣기', onTap: () => openCardImport(context)),
            ]),
          ],
          SectionHeader('회원 명단 · ${s.members.length}명'),
          group([
            for (final m in s.members)
              tile(m.name,
                  onTap: s.isTreasurer ? () => _memberMenu(context, m) : null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (m.birthdayLabel != null) ...[
                      Text('🎂 ${m.birthdayLabel}', style: tt.bodySmall!.copyWith(color: AppColors.gray)),
                      const SizedBox(width: 6),
                    ],
                    if (m.isExempt(DateTime.now().year)) const Badge2('면제', color: AppColors.gray),
                    if (s.isPresidentMember(m)) ...[
                      const SizedBox(width: 6),
                      const Badge2('회장', color: AppColors.orange),
                    ],
                    if (m.isTreasurer) ...[
                      const SizedBox(width: 6),
                      const Badge2('총무', color: AppColors.blue),
                    ],
                    if (s.isTreasurer) const Icon(Icons.chevron_right_rounded, color: AppColors.gray),
                  ])),
            if (s.isTreasurer)
              tile('+ 회원 넣기', color: AppColors.blue, onTap: () => _addMember(context)),
          ]),
          if (s.isTreasurer)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
              child: Text('이름을 누르면 생일, ${DateTime.now().year}년 회비 면제를 정하거나 명단에서 뺄 수 있어요. 앱에 아직 안 들어온 회원도 미리 넣어 두면 회비를 기록할 수 있어요.',
                  style: tt.bodySmall!.copyWith(color: AppColors.gray)),
            ),
          if (s.isTreasurer) ...[
            const SectionHeader('총무 메뉴'),
            group([
              tile('회장 정하기',
                  value: s.memberById(s.presidentId)?.name,
                  onTap: () => _pickMember(context, '누가 회장인가요?', (m) => _run(context, () => repo.setPresident(m.id)))),
              tile('총무 넘기기', onTap: () => _pickMember(context, '누구에게 넘길까요?', (to) async {
                    if (to.id == me!.id) return;
                    final ok = await confirm(context, '${to.name}님에게 총무를 넘길까요?', '넘기면 바로 회원 권한으로 바뀌어요.');
                    if (!ok) return;
                    try {
                      await repo.transferTreasurer(me.id, to.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  })),
            ]),
            if (repo is FirestoreRepository) _JoinRequests(repo: repo),
          ],
          const SectionHeader('앱 정보'),
          group([
            tile('버전', trailing: const _VersionText()),
            if (UpdateWatcher.of(context)?.enabled ?? false)
              tile('업데이트 확인', onTap: () => UpdateWatcher.of(context)!.check(manual: true)),
            tile('데이터', value: repo.isDemo ? '체험 모드' : '실시간 동기화'),
          ]),
        ]),
      ],
    );
  }

  /// 총무: 회원 한 명의 생일과 올해 회비 면제를 정하는 메뉴.
  void _memberMenu(BuildContext context, Member m) {
    final s = AppScope.of(context);
    final year = DateTime.now().year;
    final exempt = m.isExempt(year);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: Text(m.name),
        message: Text('생일 ${m.birthdayLabel ?? '미입력'} · $year년 회비 ${exempt ? '면제 중' : '내는 중'}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(c);
              _pickBirthday(context, m);
            },
            child: Text(m.birthday == null ? '생일 넣기' : '생일 바꾸기'),
          ),
          if (m.birthday != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(c);
                _run(context, () => s.repo.setBirthday(m.id, null));
              },
              child: const Text('생일 지우기'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: exempt,
            onPressed: () {
              Navigator.pop(c);
              _run(context, () => s.repo.setExempt(m.id, year, !exempt));
            },
            child: Text(exempt ? '회비 면제 풀기' : '회비 면제하기'),
          ),
          if (m.uid == null && !m.isTreasurer)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(c);
                final ok = await confirm(context, '${m.name}님을 명단에서 뺄까요?', '이미 남긴 기록은 그대로 있어요.');
                if (ok && context.mounted) _run(context, () => s.repo.removeMember(m.id));
              },
              child: const Text('명단에서 빼기'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(c), child: const Text('취소')),
      ),
    );
  }

  /// 총무: 명단에 회원 넣기.
  Future<void> _addMember(BuildContext context) async {
    final s = AppScope.of(context);
    final name = await askText(context, '회원 넣기', hint: '이름');
    if (name == null || name.isEmpty || !context.mounted) return;
    if (s.members.any((m) => m.name == name)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name님은 이미 명단에 있어요')));
      return;
    }
    await _run(context, () => s.repo.addMember(name));
  }

  /// 월·일 두 바퀴로 생일 고르기.
  void _pickBirthday(BuildContext context, Member m) {
    final s = AppScope.of(context);
    var month = m.birthMonth ?? 1;
    var day = m.birthDay ?? 1;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (c) {
        final bg = CupertinoColors.systemBackground.resolveFrom(c);
        return Container(
          color: bg,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                CupertinoButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
                Expanded(
                  child: Text('${m.name} 생일',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                ),
                CupertinoButton(
                  onPressed: () {
                    Navigator.pop(c);
                    // 2월 30일 같은 날은 그 달 마지막 날로 (2월은 29일까지 허용).
                    final last = DateTime(2024, month + 1, 0).day;
                    final d = day > last ? last : day;
                    _run(context, () => s.repo.setBirthday(m.id, Member.birthdayKey(month, d)));
                  },
                  child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
              SizedBox(
                height: 200,
                child: Row(children: [
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 36,
                      scrollController: FixedExtentScrollController(initialItem: month - 1),
                      onSelectedItemChanged: (i) => month = i + 1,
                      children: [for (var i = 1; i <= 12; i++) Center(child: Text('$i월'))],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 36,
                      scrollController: FixedExtentScrollController(initialItem: day - 1),
                      onSelectedItemChanged: (i) => day = i + 1,
                      children: [for (var i = 1; i <= 31; i++) Center(child: Text('$i일'))],
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  /// 저장하다 실패하면(권한 없음 등) 아래에 짧게 알려줘요.
  Future<void> _run(BuildContext context, Future<void> Function() job) async {
    try {
      await job();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장하지 못했어요: $e')));
      }
    }
  }

  void _pickMember(BuildContext context, String title, void Function(Member) onPick) {
    final s = AppScope.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final m in s.members)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(c);
                onPick(m);
              },
              child: Text(m.isTreasurer ? '${m.name} (총무)' : m.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(c), child: const Text('취소')),
      ),
    );
  }
}

/// 총무: 가입 신청 승인.
class _JoinRequests extends StatelessWidget {
  const _JoinRequests({required this.repo});

  final FirestoreRepository repo;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return StreamBuilder(
      stream: repo.joinRequests(),
      builder: (context, snap) {
        final reqs = snap.data ?? const [];
        if (reqs.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeader('가입 신청 · ${reqs.length}건'),
          for (final r in reqs)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AppCard(
                child: Row(children: [
                  Expanded(
                    child: Text(
                        '${r.memberId != null ? (s.memberById(r.memberId)?.name ?? '?') : '${r.name} (새 회원)'}'
                        ' · ${r.email ?? ''}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  TextButton(
                    onPressed: () => repo.rejectJoin(r.uid),
                    child: const Text('거절', style: TextStyle(color: AppColors.red)),
                  ),
                  TextButton(onPressed: () => repo.approveJoin(r), child: const Text('승인')),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

/// 지금 깔린 앱 버전 (설치 파일에서 읽어요).
class _VersionText extends StatelessWidget {
  const _VersionText();

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: Updater.currentVersion(),
        builder: (context, snap) => Text(snap.hasData ? 'v${snap.data}' : '-',
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: AppColors.gray)),
      );
}

/// 한 줄 글자 묻기. 취소하면 null.
Future<String?> askText(BuildContext context, String title, {String hint = '', String initial = ''}) =>
    showDialog<String>(context: context, builder: (_) => _AskText(title: title, hint: hint, initial: initial));

class _AskText extends StatefulWidget {
  const _AskText({required this.title, required this.hint, required this.initial});

  final String title;
  final String hint;
  final String initial;

  @override
  State<_AskText> createState() => _AskTextState();
}

class _AskTextState extends State<_AskText> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          key: const Key('askText'),
          controller: _c,
          autofocus: true,
          decoration: InputDecoration(hintText: widget.hint),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, _c.text.trim()), child: const Text('확인')),
        ],
      );
}

/// 초대코드 보기·복사·새로 만들기.
class _InviteSheet extends StatelessWidget {
  const _InviteSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final g = s.group!;
    final repo = s.repo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('회원 초대하기', style: tt.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        AppCard(
          child: Column(children: [
            Text('초대코드', style: tt.labelMedium),
            const SizedBox(height: 6),
            SelectableText(g.inviteCode,
                key: const Key('inviteCodeText'),
                style: tt.displaySmall!.copyWith(letterSpacing: 6, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        Text('초대 글을 복사해서 카톡방에 붙여넣으면, 받은 사람이 앱을 깔고 코드를 넣어 가입 신청해요. '
            '신청은 설정 화면에서 총무가 승인해요.', style: tt.bodySmall),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.copy_rounded),
          label: const Text('초대 글 복사'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await copyInvite(g);
            HapticFeedback.selectionClick();
            showDone(messenger, '복사했어요. 카톡에 붙여넣어 주세요');
          },
        ),
        if (s.isTreasurer && repo is FirestoreRepository) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              final ok = await confirm(context, '초대코드를 새로 만들까요?', '지금 코드는 더 이상 못 써요. 이미 가입한 회원은 그대로예요.');
              if (!ok || !context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              try {
                await repo.renewInviteCode(g.inviteCode);
                showDone(messenger, '새 초대코드를 만들었어요');
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('못 만들었어요: $e')));
              }
            },
            child: const Text('초대코드 새로 만들기'),
          ),
        ],
      ]),
    );
  }
}

/// 총무: 모임 이름·사진·색 바꾸기.
class _GroupEditor extends StatefulWidget {
  const _GroupEditor();

  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  late Group _g = AppScope.of(context).group!;
  late final _name = TextEditingController(text: _g.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('모임 꾸미기', style: tt.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(child: GroupAvatar(group: _g.copyWith(name: _name.text), size: 88)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: () async {
              final l = await pickGroupLogo();
              if (l != null) setState(() => _g = _g.copyWith(logo: l));
            },
            child: Text(_g.logo == null ? '사진 넣기' : '사진 바꾸기'),
          ),
          if (_g.logo != null)
            TextButton(
              onPressed: () => setState(() => _g = _g.copyWith(clearLogo: true)),
              child: const Text('사진 빼기', style: TextStyle(color: AppColors.red)),
            ),
        ]),
        const SizedBox(height: 8),
        Text('모임 이름', style: tt.labelMedium),
        const SizedBox(height: 6),
        TextField(key: const Key('editGroupName'), controller: _name, onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        Text('모임 색', style: tt.labelMedium),
        const SizedBox(height: 8),
        ColorDots(value: _g.color, onPick: (c) => setState(() => _g = _g.copyWith(color: c))),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () async {
                  final s = AppScope.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  await s.repo.updateGroup(_g.copyWith(name: _name.text.trim()));
                  showDone(messenger, '저장했어요');
                },
          child: const Text('저장'),
        ),
      ]),
    );
  }
}

/// 총무: 한 달 회비, 시작 잔고와 그 날짜.
class _MoneyEditor extends StatefulWidget {
  const _MoneyEditor();

  @override
  State<_MoneyEditor> createState() => _MoneyEditorState();
}

class _MoneyEditorState extends State<_MoneyEditor> {
  late final LedgerSettings _st = AppScope.of(context).settings!;
  late final _dues = TextEditingController(text: _st.monthlyDues == 0 ? '' : '${_st.monthlyDues}');
  late final _opening = TextEditingController(text: '${_st.openingBalance}');
  late DateTime _date = _st.openingDate;

  @override
  void dispose() {
    _dues.dispose();
    _opening.dispose();
    super.dispose();
  }

  int _num(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('회비 · 시작 잔고', style: tt.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text('한 달 회비', style: tt.labelMedium),
        const SizedBox(height: 6),
        TextField(
          key: const Key('editDues'),
          controller: _dues,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '회비가 없으면 비워 두세요', suffixText: '원'),
        ),
        const SizedBox(height: 4),
        Text('1년치를 한 번에 받아도 돼요. 낸 금액만큼 몇 달 치가 채워졌는지 자동으로 계산해요.', style: tt.bodySmall),
        const SizedBox(height: 14),
        Text('장부 시작 잔고', style: tt.labelMedium),
        const SizedBox(height: 6),
        TextField(
          key: const Key('editOpening'),
          controller: _opening,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: '원'),
        ),
        const SizedBox(height: 8),
        Text('이 날짜부터의 기록으로 잔고를 계산해요', style: tt.bodySmall),
        const SizedBox(height: 6),
        DateButton(date: _date, onPicked: (d) => setState(() => _date = d)),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            final s = AppScope.of(context);
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(context);
            await s.repo.saveSettings(
                _st.copyWith(monthlyDues: _num(_dues), openingBalance: _num(_opening), openingDate: _date));
            showDone(messenger, '저장했어요');
          },
          child: const Text('저장'),
        ),
      ]),
    );
  }
}

/// 총무: 수입·지출 분류 더하고 빼기. '회비'는 늘 있어요.
class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor();

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final LedgerSettings _st = AppScope.of(context).settings!;
  late final List<String> _income = _st.categoriesOf(TxnType.income).where((c) => c != Categories.dues).toList();
  late final List<String> _expense = [..._st.categoriesOf(TxnType.expense)];

  Widget _chips(String title, List<String> list) {
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: tt.labelMedium),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (identical(list, _income)) const Chip(label: Text(Categories.dues)),
        for (final c in list)
          InputChip(
            label: Text(c),
            onDeleted: list.length <= 1 ? null : () => setState(() => list.remove(c)),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 18),
          label: const Text('더하기'),
          onPressed: () async {
            final v = await askText(context, '$title 더하기', hint: '예: 회식');
            if (v != null && v.isNotEmpty && !list.contains(v) && v != Categories.dues) setState(() => list.add(v));
          },
        ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('수입 · 지출 분류', style: tt.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('✕를 누르면 빠져요. 이미 남긴 기록은 그대로예요.', style: tt.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        _chips('수입 분류', _income),
        const SizedBox(height: 16),
        _chips('지출 분류', _expense),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            final s = AppScope.of(context);
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(context);
            await s.repo.saveSettings(_st.copyWith(
              incomeCategories: [Categories.dues, ..._income],
              expenseCategories: [..._expense],
            ));
            showDone(messenger, '분류를 저장했어요');
          },
          child: const Text('저장'),
        ),
      ]),
    );
  }
}
