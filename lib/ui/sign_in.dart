import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/auth_service.dart';
import '../data/firestore_repository.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/group_avatar.dart';

/// Firebase가 연결된 뒤의 흐름:
/// 구글 로그인 → 내 모임 고르기 (없으면 만들기 / 초대코드로 신청) → 총무 승인 → 그 모임 장부.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const _Splash();
          final user = snap.data;
          if (user == null) return const _SignInPage();
          return _GroupGate(key: ValueKey(user.uid), user: user);
        },
      );
}

class _GroupGate extends StatefulWidget {
  const _GroupGate({super.key, required this.user});

  final User user;

  @override
  State<_GroupGate> createState() => _GroupGateState();
}

class _GroupGateState extends State<_GroupGate> {
  final _dir = GroupDirectory();

  /// 지금 열어둔 모임. null이면 모임 고르는 화면.
  String? _open;

  /// 앱을 켜고 처음 한 번은 마지막으로 보던 모임을 바로 열어요.
  bool _autoOpened = false;

  void _openGroup(String gid) {
    setState(() => _open = gid);
    _dir.setLastGroup(widget.user.uid, gid);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<(List<String>, String?)>(
        stream: _dir.myGroupIds(widget.user.uid),
        builder: (context, snap) {
          if (!snap.hasData) return const _Splash();
          final (ids, last) = snap.data!;
          if (!_autoOpened) {
            _autoOpened = true;
            if (last != null && ids.contains(last)) _open = last;
          }
          final open = _open;
          if (open != null && ids.contains(open)) {
            return _GroupView(
              key: ValueKey(open),
              gid: open,
              user: widget.user,
              dir: _dir,
              onSwitch: () => setState(() => _open = null),
            );
          }
          return GroupPickerPage(dir: _dir, user: widget.user, ids: ids, onOpen: _openGroup);
        },
      );
}

/// 모임 하나를 열었을 때: 승인됐으면 장부, 아니면 기다리는 화면.
class _GroupView extends StatefulWidget {
  const _GroupView({super.key, required this.gid, required this.user, required this.dir, required this.onSwitch});

  final String gid;
  final User user;
  final GroupDirectory dir;
  final VoidCallback onSwitch;

  @override
  State<_GroupView> createState() => _GroupViewState();
}

class _GroupViewState extends State<_GroupView> {
  AppState? _state;

  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
        stream: widget.dir.memberIdIn(widget.gid, widget.user.uid),
        builder: (context, snap) {
          if (!snap.hasData && snap.connectionState == ConnectionState.waiting) return const _Splash();
          final memberId = snap.data;
          if (memberId == null) {
            return _PendingPage(gid: widget.gid, user: widget.user, dir: widget.dir, onBack: widget.onSwitch);
          }
          _state ??= AppState(FirestoreRepository(widget.gid), myMemberId: memberId);
          return AppScope(
            state: _state!,
            child: ListenableBuilder(
              listenable: _state!,
              builder: (_, _) => _state!.ready
                  ? AppShell(onSignOut: AuthService.signOut, onSwitchGroup: widget.onSwitch)
                  : const _Splash(),
            ),
          );
        },
      );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CupertinoActivityIndicator(radius: 14)));
}

class _SignInPage extends StatefulWidget {
  const _SignInPage();

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/brand/app_icon.png', width: 96, height: 96),
                const SizedBox(height: 20),
                Text('총무노트', style: tt.displaySmall),
                const SizedBox(height: 8),
                Text('우리 모임 돈, 투명하게', style: tt.bodyMedium!.copyWith(color: AppColors.gray)),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await AuthService.signInWithGoogle();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('구글 계정으로 시작하기'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 내 모임 고르기 ─────────────────────────

class GroupPickerPage extends StatelessWidget {
  const GroupPickerPage({super.key, required this.dir, required this.user, required this.ids, required this.onOpen});

  final GroupDirectory dir;
  final User user;
  final List<String> ids;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 모임'),
        actions: [TextButton(onPressed: AuthService.signOut, child: const Text('로그아웃'))],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (ids.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
                  child: Text('반가워요! 👋\n총무라면 모임을 새로 만들고, 초대받았다면 초대코드를 넣어 주세요.',
                      style: tt.bodyLarge),
                )
              else
                for (final gid in ids)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GroupTile(dir: dir, gid: gid, uid: user.uid, onOpen: () => onOpen(gid)),
                  ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('createGroup'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('새 모임 만들기'),
                onPressed: () async {
                  final gid = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => CreateGroupPage(dir: dir, user: user)),
                  );
                  if (gid != null) onOpen(gid);
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('joinGroup'),
                icon: const Icon(Icons.vpn_key_rounded),
                label: const Text('초대코드로 들어가기'),
                onPressed: () async {
                  final gid = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => JoinGroupPage(dir: dir, user: user)),
                  );
                  if (gid != null) onOpen(gid);
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.dir, required this.gid, required this.uid, required this.onOpen});

  final GroupDirectory dir;
  final String gid;
  final String uid;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return StreamBuilder<Group?>(
      stream: dir.group(gid),
      builder: (context, g) {
        final group = g.data;
        if (group == null) return const SizedBox.shrink();
        return StreamBuilder<MyGroupStatus>(
          stream: dir.status(gid, uid),
          builder: (context, st) {
            final status = st.data;
            return AppCard(
              padding: EdgeInsets.zero,
              child: Pressable(
                onTap: status == MyGroupStatus.joined ? onOpen : () {},
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    GroupAvatar(group: group),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(group.name, style: tt.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          switch (status) {
                            MyGroupStatus.joined => '눌러서 열기',
                            MyGroupStatus.pending => '총무 승인 기다리는 중',
                            MyGroupStatus.none => '가입 신청이 없어요 (거절됐거나 취소됨)',
                            null => '',
                          },
                          style: tt.bodySmall,
                        ),
                      ]),
                    ),
                    if (status == MyGroupStatus.joined)
                      const Icon(Icons.chevron_right_rounded, color: AppColors.gray)
                    else if (status != null)
                      TextButton(
                        onPressed: () => dir.forget(gid, uid),
                        child: Text(status == MyGroupStatus.pending ? '신청 취소' : '목록에서 빼기'),
                      ),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 승인 기다리는 모임을 열었을 때.
class _PendingPage extends StatelessWidget {
  const _PendingPage({required this.gid, required this.user, required this.dir, required this.onBack});

  final String gid;
  final User user;
  final GroupDirectory dir;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: onBack)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('가입 신청을 보냈어요.\n총무가 승인하면 바로 열려요.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      );
}

// ───────────────────────── 새 모임 만들기 ─────────────────────────

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key, required this.dir, required this.user});

  final GroupDirectory dir;
  final User user;

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _name = TextEditingController();
  late final _me = TextEditingController(text: widget.user.displayName ?? '');
  final _dues = TextEditingController();
  final _opening = TextEditingController();
  int _color = Group.palette.first;
  String? _logo;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _me, _dues, _opening]) {
      c.dispose();
    }
    super.dispose();
  }

  int _num(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _create() async {
    final name = _name.text.trim();
    final me = _me.text.trim();
    if (name.isEmpty || me.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모임 이름과 내 이름을 넣어 주세요')));
      return;
    }
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final gid = await widget.dir.create(
        uid: widget.user.uid,
        myName: me,
        email: widget.user.email,
        group: Group(id: '', name: name, color: _color, logo: _logo),
        settings: LedgerSettings(
          openingBalance: _num(_opening),
          openingDate: DateTime(now.year, now.month, 1),
          monthlyDues: _num(_dues),
        ),
      );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, gid);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('만들지 못했어요: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final preview = Group(id: '', name: _name.text.isEmpty ? '모임' : _name.text, color: _color, logo: _logo);
    return Scaffold(
      appBar: AppBar(title: const Text('새 모임 만들기')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final l = await pickGroupLogo();
                    if (l != null) setState(() => _logo = l);
                  },
                  child: Stack(clipBehavior: Clip.none, children: [
                    GroupAvatar(group: preview, size: 88),
                    const Positioned(
                      right: -4,
                      bottom: -4,
                      child: CircleAvatar(radius: 15, child: Icon(Icons.photo_camera_rounded, size: 16)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              Text('동그라미를 누르면 모임 사진을 넣어요 (선택)', textAlign: TextAlign.center, style: tt.bodySmall),
              const SizedBox(height: 20),
              Text('모임 이름', style: tt.labelMedium),
              const SizedBox(height: 6),
              TextField(
                key: const Key('groupName'),
                controller: _name,
                decoration: const InputDecoration(hintText: '예: 고교 동창회, 등산 모임'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Text('모임 색', style: tt.labelMedium),
              const SizedBox(height: 8),
              ColorDots(value: _color, onPick: (c) => setState(() => _color = c)),
              const SizedBox(height: 14),
              Text('내 이름 (총무)', style: tt.labelMedium),
              const SizedBox(height: 6),
              TextField(key: const Key('myName'), controller: _me, decoration: const InputDecoration(hintText: '회원들이 보는 이름')),
              const SizedBox(height: 14),
              Text('한 달 회비', style: tt.labelMedium),
              const SizedBox(height: 6),
              TextField(
                key: const Key('dues'),
                controller: _dues,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '예: 30000 (회비가 없으면 비워 두세요)', suffixText: '원'),
              ),
              const SizedBox(height: 14),
              Text('지금 모임 통장 잔고', style: tt.labelMedium),
              const SizedBox(height: 6),
              TextField(
                key: const Key('opening'),
                controller: _opening,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '처음이면 0', suffixText: '원'),
              ),
              const SizedBox(height: 8),
              Text('나머지(회원 명단, 지출 분류, 지역 돌아가기)는 만든 뒤 설정에서 바꿀 수 있어요.', style: tt.bodySmall),
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _create, child: Text(_busy ? '만드는 중…' : '모임 만들기')),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 초대코드로 들어가기 ─────────────────────────

class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key, required this.dir, required this.user});

  final GroupDirectory dir;
  final User user;

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final _code = TextEditingController();
  late final _newName = TextEditingController(text: widget.user.displayName ?? '');
  Group? _group;
  List<Member> _seats = const [];

  /// 명단에서 고른 회원. null이면 새 이름으로 신청.
  String? _pick;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _newName.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final g = await widget.dir.findByCode(_code.text);
      if (g == null) {
        setState(() => _error = '그런 초대코드가 없어요. 6자리를 다시 확인해 주세요.');
      } else {
        final seats = await widget.dir.openSeats(g.id);
        setState(() {
          _group = g;
          _seats = seats;
          _pick = null;
        });
      }
    } catch (e) {
      setState(() => _error = '찾지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final g = _group!;
    final name = _newName.text.trim();
    if (_pick == null && name.isEmpty) {
      setState(() => _error = '명단에서 내 이름을 고르거나, 이름을 적어 주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.dir.requestJoin(
        gid: g.id,
        uid: widget.user.uid,
        memberId: _pick,
        name: _pick == null ? name : null,
        email: widget.user.email,
      );
      if (mounted) Navigator.pop(context, g.id);
    } catch (e) {
      if (mounted) setState(() => _error = '신청하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final g = _group;
    return Scaffold(
      appBar: AppBar(title: const Text('초대코드로 들어가기')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text('총무에게 받은 6자리 코드', style: tt.labelMedium),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    key: const Key('inviteCode'),
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    style: tt.titleLarge!.copyWith(letterSpacing: 4),
                    decoration: const InputDecoration(hintText: 'ABC123', counterText: ''),
                    onSubmitted: (_) => _find(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : _find, child: const Text('찾기')),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: tt.bodyMedium!.copyWith(color: AppColors.red)),
              ],
              if (g != null) ...[
                const SizedBox(height: 20),
                AppCard(
                  child: Row(children: [
                    GroupAvatar(group: g, size: 52),
                    const SizedBox(width: 12),
                    Expanded(child: Text(g.name, style: tt.titleLarge)),
                  ]),
                ),
                const SectionHeader('나는 누구인가요?'),
                if (_seats.isNotEmpty) ...[
                  Text('명단에 내 이름이 있으면 눌러 주세요', style: tt.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in _seats)
                      ChoiceChip(
                        label: Text(m.name),
                        selected: _pick == m.id,
                        onSelected: (on) => setState(() => _pick = on ? m.id : null),
                      ),
                  ]),
                  const SizedBox(height: 14),
                ],
                if (_pick == null) ...[
                  Text(_seats.isEmpty ? '내 이름' : '명단에 없으면 이름 적기', style: tt.labelMedium),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('joinName'),
                    controller: _newName,
                    decoration: const InputDecoration(hintText: '회원들이 보는 이름'),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(onPressed: _busy ? null : _send, child: const Text('가입 신청')),
                const SizedBox(height: 6),
                Text('총무가 승인하면 바로 열려요.', textAlign: TextAlign.center, style: tt.bodySmall),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
