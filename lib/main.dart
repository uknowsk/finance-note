import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/demo_repository.dart';
import 'data/demo_seed.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';
import 'ui/group_exit.dart';
import 'ui/shell.dart';
import 'ui/sign_in.dart';
import 'ui/splash.dart';
import 'ui/theme.dart';
import 'update/update_prompt.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options != null) {
    await Firebase.initializeApp(options: options);
  }
  runApp(ChongmuNoteApp(useFirebase: options != null, checkUpdates: true));
}

class ChongmuNoteApp extends StatelessWidget {
  const ChongmuNoteApp({super.key, required this.useFirebase, this.demoState, this.demoExit, this.checkUpdates = false});

  final bool useFirebase;

  /// 새 버전 확인·업데이트 알림. 실제 앱에서만 켜요 (테스트에서는 꺼요).
  final bool checkUpdates;

  /// 테스트에서 미리 만든 상태를 넣을 때.
  final AppState? demoState;

  /// 체험 모드에서 모임 나가기·지우기를 눌렀을 때 (테스트용).
  final GroupExit? demoExit;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '총무노트',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // 폰 글씨 크기 설정은 따르되, 화면이 깨지지 않게 1.3배까지만.
        builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
        home: UpdateWatcher(
          enabled: checkUpdates,
          push: useFirebase,
          child: SplashGate(child: useFirebase ? const AuthGate() : _DemoRoot(state: demoState, exit: demoExit)),
        ),
      );
}

class _DemoRoot extends StatefulWidget {
  const _DemoRoot({this.state, this.exit});

  final AppState? state;
  final GroupExit? exit;

  @override
  State<_DemoRoot> createState() => _DemoRootState();
}

class _DemoRootState extends State<_DemoRoot> {
  late final AppState _state = widget.state ?? AppState(DemoRepository(), myMemberId: memberIdOf(seedTreasurer));

  @override
  Widget build(BuildContext context) => AppScope(
        state: _state,
        child: ListenableBuilder(
          listenable: _state,
          builder: (_, _) => _state.ready ? AppShell(exit: widget.exit ?? _demoExit) : const SizedBox.shrink(),
        ),
      );
}

/// 체험 모드: 실제로는 아무것도 안 지워요.
final _demoExit = GroupExit(
  leave: () async => throw StateError('체험 모드라 실제로 나가지는 않아요'),
  delete: () async => throw StateError('체험 모드라 실제로 지우지는 않아요'),
);
