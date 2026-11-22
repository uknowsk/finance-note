import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'card_sms.dart';

/// 받은 문자 한 통.
typedef Sms = ({String address, String body, DateTime date});

/// 폰의 받은 문자함. 문자는 폰 안에서만 읽고, 고른 지출만 장부에 저장해요.
abstract class SmsSource {
  /// 이 폰에서 쓸 수 있는지 (안드로이드 앱에서만).
  bool get available;
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<List<Sms>> inbox(DateTime since);

  static SmsSource of({required bool demo}) => demo ? DemoSmsSource() : PlatformSmsSource();

  /// [since] 이후 카드 승인 문자 중, 고른 카드이고 아직 장부에 없고 넘기지 않은 것 (최근 것부터).
  Future<List<CardSpend>> pending({
    required DateTime since,
    DateTime? until,
    required LedgerSettings settings,
    required Iterable<Txn> txns,
  }) async {
    final done = {for (final t in txns) ?t.smsKey, ...settings.smsIgnored};
    final seen = <String>{};
    final out = <CardSpend>[];
    for (final m in await inbox(since)) {
      final s = CardSms.parse(m.body, m.date);
      if (s == null || s.cancelled) continue;
      if (s.at.isBefore(since) || (until != null && s.at.isAfter(until))) continue;
      if (!CardSms.matches(s, settings.cardFilters)) continue;
      if (done.contains(s.key) || !seen.add(s.key)) continue;
      out.add(s);
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }
}

class PlatformSmsSource extends SmsSource {
  static const _ch = MethodChannel('chongmu_note/sms');

  @override
  bool get available => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> hasPermission() async {
    if (!available) return false;
    try {
      return await _ch.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!available) return false;
    return await _ch.invokeMethod<bool>('requestPermission') ?? false;
  }

  @override
  Future<List<Sms>> inbox(DateTime since) async {
    if (!available) return const [];
    final list = await _ch.invokeListMethod<Map>('inbox', {'since': since.millisecondsSinceEpoch}) ?? const [];
    return [
      for (final m in list)
        (
          address: '${m['address'] ?? ''}',
          body: '${m['body'] ?? ''}',
          date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),
        ),
    ];
  }
}

/// 체험 모드: 예시 카드 문자 몇 통.
class DemoSmsSource extends SmsSource {
  @override
  bool get available => true;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<List<Sms>> inbox(DateTime since) async {
    final now = DateTime.now();
    String md(DateTime d) => '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final a = now.subtract(const Duration(hours: 3));
    final b = now.subtract(const Duration(days: 1, hours: 2));
    final c = now.subtract(const Duration(days: 2, hours: 5));
    return [
      (address: '15447200', body: '[Web발신]\n신한카드(1234)승인 오*우 86,000원(일시불)${md(a)} 한우마을 누적386,000원', date: a),
      (address: '15881688', body: '[Web발신]\nKB국민카드5678승인\n오*우님\n12,500원 일시불\n${md(b)}\nGS25역삼점', date: b),
      (address: '15447200', body: '[Web발신]\n신한카드(1234)승인 오*우 180,000원(일시불)${md(c)} 해운대펜션', date: c),
      (address: '010', body: '이번 모임 언제야?', date: c),
    ].where((m) => !m.date.isBefore(since)).toList();
  }
}
