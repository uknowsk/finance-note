import 'package:flutter/services.dart';

import '../models/models.dart';

/// 앱 설치 파일 고정 주소 (항상 최신 버전).
const appDownloadUrl = 'https://github.com/uknowsk/finance-note/releases/latest/download/chongmu-note.apk';

/// 카톡 등에 붙여넣을 초대 글.
String inviteMessage(Group g) => '[총무노트] "${g.name}" 모임에 초대해요!\n'
    '1) 이 글을 길게 눌러 복사해 두세요\n'
    '2) 앱 받기: $appDownloadUrl\n'
    '3) 구글 로그인 → "초대코드로 들어가기" (코드가 자동으로 들어가요)\n'
    '초대코드: ${g.inviteCode}';

Future<void> copyInvite(Group g) => Clipboard.setData(ClipboardData(text: inviteMessage(g)));

/// 복사한 글에서 초대코드 찾기. "초대코드: ABC234" 또는 코드 6자리만 복사한 경우.
String? extractInviteCode(String text) {
  final t = text.trim();
  final labeled = RegExp(r'초대\s*코드\s*[:：]?\s*([A-Za-z0-9]{6})(?![A-Za-z0-9])').firstMatch(t);
  if (labeled != null) return labeled.group(1)!.toUpperCase();
  if (RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(t)) return t.toUpperCase();
  return null;
}
