/// 카드 승인 문자 → 지출 한 건. 카드사마다 문자 모양이 달라서
/// "카드 이름, 금액(…원), 날짜·시각(MM/DD HH:MM), 가게 이름"을 각각 찾아요.
library;

class CardSpend {
  /// 같은 문자를 두 번 넣지 않게 쓰는 이름표.
  final String key;

  /// 예: 신한카드, KB국민카드
  final String card;

  /// 카드 끝 번호 (예: 1234, 1*3*). 문자에 없으면 null.
  final String? last4;
  final int amount;
  final String merchant;
  final DateTime at;

  /// 승인 취소 문자.
  final bool cancelled;
  final String raw;

  const CardSpend({
    required this.key,
    required this.card,
    this.last4,
    required this.amount,
    required this.merchant,
    required this.at,
    this.cancelled = false,
    this.raw = '',
  });

  String get cardLabel => last4 == null ? card : '$card $last4';
}

class CardSms {
  static final _card = RegExp(r'([A-Za-z가-힣]{1,8})\s?카드');
  static final _last4 = [
    RegExp(r'카드\s*[\(\[]\s*([0-9\*]{4})\s*[\)\]]'),
    RegExp(r'카드\s*([0-9][0-9\*]{3})(?=\s*승인|\s*\(|\s)'),
    RegExp(r'승인\s+([0-9][0-9\*]{3})\s'),
    RegExp(r'\s([0-9]\*[0-9]\*|[0-9]{4})\s*승인'),
  ];
  static final _amount = RegExp(r'(-?\d{1,3}(?:,\d{3})+|-?\d+)\s*원');
  static final _when = RegExp(r'(\d{1,2})[/.\-](\d{1,2})\s*(\d{1,2}):(\d{2})');
  static final _junk = [
    RegExp(r'\[?Web발신\]?'),
    RegExp(r'(누적|잔액|잔여|한도|가능)\s*:?\s*-?[\d,]+\s*원'),
    RegExp(r'-?\d{1,3}(?:,\d{3})+\s*원|-?\d+\s*원'),
    RegExp(r'일시불|할부|\d+\s*개월|승인취소|취소|승인|체크|신용'),
    RegExp(r'[가-힣]\*[가-힣]{1,2}님?|[가-힣]{1,3}님'),
    RegExp(r'[\(\)\[\]]'),
  ];

  /// 카드 승인 문자가 아니면 null. [received]는 문자를 받은 시각 (연도 정할 때 써요).
  static CardSpend? parse(String body, DateTime received) {
    final text = body.replaceAll('\r', '');
    if (!text.contains('승인') || !text.contains('원')) return null;
    if (text.contains('거절') || text.contains('승인요청') || text.contains('인증번호')) return null;

    // 금액: 누적·잔액·한도 금액은 빼고 첫 번째
    int? amount;
    int amountEnd = -1;
    for (final m in _amount.allMatches(text)) {
      final before = text.substring((m.start - 6).clamp(0, m.start), m.start);
      if (RegExp(r'누적|잔액|잔여|한도|가능').hasMatch(before)) continue;
      amount = int.tryParse(m.group(1)!.replaceAll(',', ''));
      amountEnd = m.end;
      break;
    }
    if (amount == null || amount == 0) return null;

    final cm = _card.firstMatch(text);
    final card = cm == null ? '카드' : '${cm.group(1)!.replaceAll('[', '').replaceAll('Web발신', '')}카드';
    String? last4;
    for (final r in _last4) {
      final m = r.firstMatch(text);
      if (m != null) {
        last4 = m.group(1);
        break;
      }
    }

    // 날짜: 문자에 적힌 월/일 시:분. 받은 날보다 미래면 작년 것.
    var at = received;
    final wm = _when.firstMatch(text);
    if (wm != null) {
      final mo = int.parse(wm.group(1)!), d = int.parse(wm.group(2)!);
      final h = int.parse(wm.group(3)!), mi = int.parse(wm.group(4)!);
      var y = received.year;
      var t = DateTime(y, mo, d, h, mi);
      if (t.isAfter(received.add(const Duration(days: 2)))) t = DateTime(y - 1, mo, d, h, mi);
      at = t;
    }

    // 가게: 시각 뒤 글자에서 군더더기를 빼고 첫 줄. 없으면 금액 앞쪽.
    String clean(String s) {
      var out = s;
      if (cm != null) out = out.replaceAll(cm.group(0)!, ' ');
      if (last4 != null) out = out.replaceAll(last4, ' ');
      for (final j in _junk) {
        out = out.replaceAll(j, ' ');
      }
      final lines = out
          .split('\n')
          .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((l) => l.length >= 2 && !RegExp(r'^[\d\s:/.\-\*]+$').hasMatch(l))
          .toList();
      return lines.isEmpty ? '' : lines.first;
    }

    var merchant = wm == null ? '' : clean(text.substring(wm.end));
    if (merchant.isEmpty && wm != null) merchant = clean(text.substring(0, wm.start).split('\n').last);
    if (merchant.isEmpty && amountEnd > 0) merchant = clean(text.substring(amountEnd));
    if (merchant.isEmpty) merchant = '카드 결제';

    final cancelled = text.contains('취소');
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${at.year}${two(at.month)}${two(at.day)}${two(at.hour)}${two(at.minute)}';
    return CardSpend(
      key: '$card|${last4 ?? ''}|$stamp|$amount|$merchant${cancelled ? '|x' : ''}',
      card: card,
      last4: last4,
      amount: amount.abs(),
      merchant: merchant,
      at: at,
      cancelled: cancelled,
      raw: text,
    );
  }

  /// 총무가 고른 카드인지. [filters]가 비면 모든 카드.
  /// 필터 예: "신한카드", "신한 1234", "KB국민카드 1*3*"
  static bool matches(CardSpend s, List<String> filters) {
    if (filters.isEmpty) return true;
    String norm(String v) => v.replaceAll(' ', '').replaceAll('카드', '').toUpperCase();
    for (final f in filters) {
      final digits = RegExp(r'[0-9][0-9\*]{3}').firstMatch(f)?.group(0);
      final name = norm(digits == null ? f : f.replaceAll(digits, ''));
      final nameOk = name.isEmpty || norm(s.card).contains(name) || name.contains(norm(s.card));
      final numOk = digits == null || (s.last4 != null && _sameNumber(digits, s.last4!));
      if (nameOk && numOk) return true;
    }
    return false;
  }

  /// 1234 와 1*3* 처럼 별표는 아무 숫자로 봐요.
  static bool _sameNumber(String a, String b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != '*' && b[i] != '*' && a[i] != b[i]) return false;
    }
    return true;
  }

  static const _hints = <String, List<String>>{
    '식사': ['식당', '김밥', '치킨', '고기', '국밥', '갈비', '삼겹', '족발', '피자', '버거', '맥도날드', '롯데리아', '짬뽕', '반점', '분식',
      '한식', '일식', '횟집', '수산', '레스토랑', '커피', '카페', '스타벅스', '투썸', '이디야', '메가', '베이커리', '파리바게', '뚜레쥬르',
      '주점', '호프', '포차', '맥주', '배달의민족', '요기요', '쿠팡이츠'],
    '숙박': ['호텔', '모텔', '펜션', '리조트', '숙박', '에어비앤비', '야놀자', '여기어때', '게스트하우스'],
    '교통': ['주유', '오일', 'SK에너지', 'GS칼텍스', 'S-OIL', '택시', '카카오T', '코레일', 'KTX', 'SRT', '버스', '고속도로', '하이패스',
      '도로공사', '렌터카', '쏘카'],
    '주차': ['주차'],
    '마트': ['마트', '이마트', '홈플러스', '코스트코', '편의점', 'GS25', 'CU', '세븐일레븐', '이마트24', '하나로'],
    '경조사': ['꽃', '화환', '플라워', '장례'],
    '선물': ['선물', '기프트', '백화점'],
    '생일선물': ['선물', '기프트', '케이크'],
    '시설이용': ['볼링', '골프', '노래', '당구', '스크린', '체육', '캠핑'],
  };

  /// 가게 이름으로 분류 짐작. [choices]에 있는 것만 골라요. 모르면 '기타'(없으면 첫 번째).
  static String guessCategory(String merchant, List<String> choices) {
    final m = merchant.toUpperCase();
    for (final c in choices) {
      for (final k in _hints[c] ?? const <String>[]) {
        if (m.contains(k.toUpperCase())) return c;
      }
    }
    return choices.contains('기타') ? '기타' : choices.first;
  }
}
