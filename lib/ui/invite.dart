import 'package:flutter/services.dart';

import '../models/models.dart';

/// 앱 설치 파일 고정 주소 (항상 최신 버전).
const appDownloadUrl = 'https://github.com/uknowsk/finance-note/releases/latest/download/chongmu-note.apk';

/// 카톡 등에 붙여넣을 초대 글.
String inviteMessage(Group g) => '[총무노트] "${g.name}" 모임에 초대해요!\n'
    '1) 앱 받기: $appDownloadUrl\n'
    '2) 구글 로그인 → "초대코드로 들어가기"\n'
    '3) 초대코드: ${g.inviteCode}';

Future<void> copyInvite(Group g) => Clipboard.setData(ClipboardData(text: inviteMessage(g)));
