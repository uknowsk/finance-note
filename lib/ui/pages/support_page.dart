import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 개발자 후원을 받을 곳. 비어 있는 방법은 화면에 안 나와요.
class SupportInfo {
  const SupportInfo({
    this.tossId = '',
    this.kakaoPayUrl = '',
    this.bank = '',
    this.account = '',
    this.holder = '',
  });

  /// 토스 아이디 (toss.me/아이디)
  final String tossId;

  /// 카카오페이 송금 링크 (https://qr.kakaopay.com/...)
  final String kakaoPayUrl;
  final String bank;
  final String account;
  final String holder;

  bool get hasToss => tossId.isNotEmpty;
  bool get hasKakao => kakaoPayUrl.isNotEmpty;
  bool get hasAccount => account.isNotEmpty;
  bool get isEmpty => !hasToss && !hasKakao && !hasAccount;

  /// 금액까지 들어간 토스 송금 링크
  String tossUrl(int amount) => 'https://toss.me/$tossId/$amount';

  /// 토스 앱 송금 화면 (계좌·금액 채워서). 토스 아이디가 없어도 돼요.
  String tossAccountUrl(int amount) => Uri(
        scheme: 'supertoss',
        host: 'send',
        queryParameters: {
          'amount': '$amount',
          'bank': bank,
          'accountNo': account.replaceAll(RegExp(r'[^0-9]'), ''),
        },
      ).toString();

  /// 토스로 보내기 버튼을 보여줄지 (아이디나 계좌 중 하나만 있어도)
  bool get canToss => hasToss || hasAccount;
  String tossLink(int amount) => hasToss ? tossUrl(amount) : tossAccountUrl(amount);

  /// 앱에 들어가는 실제 후원 정보 (개발자가 채워요).
  static const app = SupportInfo();
}

/// 고를 수 있는 후원 금액
const supportAmounts = [2000, 3000, 5000, 10000];

/// 링크 열기 (안드로이드). 못 열면 false.
Future<bool> openLink(String url) async {
  if (kIsWeb) return false;
  try {
    return await const MethodChannel('chongmu_note/update').invokeMethod<bool>('openUrl', {'url': url}) ?? false;
  } catch (_) {
    return false;
  }
}

/// 개발자 후원하기 화면.
class SupportPage extends StatefulWidget {
  const SupportPage({super.key, this.info = SupportInfo.app, this.open = openLink});

  final SupportInfo info;
  final Future<bool> Function(String url) open;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  int _amount = 3000;

  SupportInfo get _info => widget.info;

  Future<void> _go(String url, String name) async {
    HapticFeedback.selectionClick();
    final ok = await widget.open(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_info.hasAccount ? '$name을 열지 못했어요. 계좌번호를 복사해 둘게요' : '$name을 열지 못했어요'),
      ));
      if (_info.hasAccount) await _copyAccount();
    }
  }

  Future<void> _copyAccount() async {
    await Clipboard.setData(ClipboardData(text: '${_info.bank} ${_info.account}'));
    HapticFeedback.selectionClick();
    if (mounted) showDone(ScaffoldMessenger.of(context), '계좌번호를 복사했어요. 은행 앱에서 ${won(_amount)}을 보내 주세요');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('개발자 후원하기')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                AppCard(
                  child: Column(children: [
                    const Text('☕', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 8),
                    Text('총무노트는 무료예요', style: tt.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '잘 쓰고 계시다면 커피 한 잔 값으로 응원해 주세요.\n'
                      '서버 비용과 새 기능 만드는 데 써요. 안 해도 기능은 똑같아요 🙂',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium!.copyWith(color: AppColors.gray),
                    ),
                  ]),
                ),
                if (_info.isEmpty) ...[
                  const SizedBox(height: 16),
                  AppCard(child: Text('후원 받을 곳을 준비하고 있어요. 조금만 기다려 주세요!', style: tt.bodyMedium)),
                ] else ...[
                  const SectionHeader('얼마를 보낼까요?'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final a in supportAmounts)
                      ChoiceChip(
                        key: Key('amount-$a'),
                        label: Text(won(a)),
                        selected: _amount == a,
                        onSelected: (_) => setState(() => _amount = a),
                      ),
                  ]),
                  const SectionHeader('어떻게 보낼까요?'),
                  if (_info.canToss) ...[
                    FilledButton.icon(
                      key: const Key('payToss'),
                      onPressed: () => _go(_info.tossLink(_amount), '토스'),
                      icon: const Icon(Icons.send_rounded),
                      label: Text('토스로 ${won(_amount)} 보내기'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_info.hasKakao) ...[
                    FilledButton.icon(
                      key: const Key('payKakao'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE500),
                        foregroundColor: const Color(0xFF191919),
                      ),
                      onPressed: () => _go(_info.kakaoPayUrl, '카카오페이'),
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: const Text('카카오페이로 보내기'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
                      child: Text('카카오페이에서는 금액(${won(_amount)})을 직접 넣어 주세요.', style: tt.bodySmall),
                    ),
                  ],
                  if (_info.hasAccount)
                    OutlinedButton.icon(
                      key: const Key('copyAccount'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _copyAccount,
                      icon: const Icon(Icons.copy_rounded),
                      label: Text('${_info.bank} ${_info.account} 복사', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  if (_info.hasAccount && _info.holder.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('받는 분: ${_info.holder}', textAlign: TextAlign.center, style: tt.bodySmall),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
