import 'package:chongmu_note/sms/card_sms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final got = DateTime(2026, 11, 21, 23, 0);

  final samples = <String, (String, String?, int, String, String)>{
    '[Web발신]\n신한카드(1234)승인 홍*동 45,000원(일시불)11/21 19:32 김밥천국 누적1,234,567원':
        ('신한카드', '1234', 45000, '김밥천국', '2026-11-21 19:32'),
    '[Web발신]\nKB국민카드1234승인\n홍*동님\n12,000원 일시불\n11/21 12:30\nGS25역삼점\n누적100,000원':
        ('KB국민카드', '1234', 12000, 'GS25역삼점', '2026-11-21 12:30'),
    '[Web발신]\n삼성카드승인 5678 홍*동 11/21 18:20 35,000원 일시불 스타벅스강남':
        ('삼성카드', '5678', 35000, '스타벅스강남', '2026-11-21 18:20'),
    '[Web발신]\n현대카드 M 승인\n홍*동\n52,300원 일시불\n11/21 20:11\n이마트 성수점\n누적1,052,300원':
        ('현대카드', null, 52300, '이마트 성수점', '2026-11-21 20:11'),
    '[Web발신]\n롯데카드 1*2* 승인 홍*동 8,500원 일시불 11/21 08:10 파리바게뜨':
        ('롯데카드', '1*2*', 8500, '파리바게뜨', '2026-11-21 08:10'),
    '[Web발신]\n하나카드(5*7*)승인 홍*동 일시불 30,000원 11/21 13:05 교촌치킨 누적 230,000원':
        ('하나카드', '5*7*', 30000, '교촌치킨', '2026-11-21 13:05'),
    '[Web발신]\nNH농협카드 승인 홍*동 3개월 240,000원 11/20 21:40 해운대펜션':
        ('NH농협카드', null, 240000, '해운대펜션', '2026-11-20 21:40'),
  };

  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  test('카드사별 승인 문자에서 카드·금액·가게·시각을 뽑는다', () {
    for (final e in samples.entries) {
      final s = CardSms.parse(e.key, got);
      expect(s, isNotNull, reason: e.key);
      expect((s!.card, s.last4, s.amount, s.merchant, fmt(s.at)), e.value, reason: e.key);
      expect(s.cancelled, isFalse);
    }
  });

  test('카드 문자가 아니면 무시, 취소 문자는 표시', () {
    expect(CardSms.parse('[Web발신] 인증번호 [123456]를 입력해 주세요', got), isNull);
    expect(CardSms.parse('엄마: 저녁 먹었니?', got), isNull);
    expect(CardSms.parse('신한카드(1234) 승인거절 잔액부족 45,000원', got), isNull);
    final c = CardSms.parse('[Web발신]\n신한카드(1234)승인취소 홍*동 45,000원 11/21 19:40 김밥천국', got)!;
    expect(c.cancelled, isTrue);
    expect(c.key, isNot(CardSms.parse(samples.keys.first, got)!.key));
  });

  test('1월에 받은 12월 문자는 작년으로', () {
    final s = CardSms.parse('신한카드(1234)승인 홍*동 10,000원 12/31 23:50 편의점', DateTime(2027, 1, 1, 0, 5))!;
    expect(s.at, DateTime(2026, 12, 31, 23, 50));
  });

  test('고른 카드만 통과 (이름·끝번호, 별표는 아무 숫자)', () {
    final shinhan = CardSms.parse(samples.keys.first, got)!;
    final lotte = CardSms.parse(samples.keys.elementAt(4), got)!;
    expect(CardSms.matches(shinhan, const []), isTrue);
    expect(CardSms.matches(shinhan, const ['신한카드']), isTrue);
    expect(CardSms.matches(shinhan, const ['신한 1234']), isTrue);
    expect(CardSms.matches(shinhan, const ['신한 9999']), isFalse);
    expect(CardSms.matches(shinhan, const ['국민']), isFalse);
    expect(CardSms.matches(lotte, const ['롯데 1023']), isTrue);
    expect(CardSms.matches(lotte, const ['롯데 2023']), isFalse);
  });

  test('가게 이름으로 분류를 짐작한다', () {
    const cats = ['정기모임', '번개', '식사', '숙박', '교통', '경조사', '선물', '기타'];
    expect(CardSms.guessCategory('스타벅스강남', cats), '식사');
    expect(CardSms.guessCategory('해운대펜션', cats), '숙박');
    expect(CardSms.guessCategory('GS칼텍스 주유소', cats), '교통');
    expect(CardSms.guessCategory('알수없는가게', cats), '기타');
    expect(CardSms.guessCategory('이마트 성수점', [...cats, '마트']), '마트');
  });
}
