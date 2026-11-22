import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../sms/card_sms.dart';
import '../../sms/sms_source.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'settings_page.dart' show askText;

/// 카드 문자 가져오기 화면 열기 (총무).
Future<void> openCardImport(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: AppScope.carry(context, (_) => const CardImportPage())),
    );

/// 총무 폰의 카드 승인 문자를 읽어 지출로 넣는 화면.
/// 카드와 기간을 고르면 아직 안 넣은 결제가 나오고, 분류를 확인해 한 번에 넣어요.
class CardImportPage extends StatefulWidget {
  const CardImportPage({super.key, this.source});

  /// 테스트에서 가짜 문자함을 넣을 때.
  final SmsSource? source;

  @override
  State<CardImportPage> createState() => _CardImportPageState();
}

class _Row {
  _Row(this.spend, this.category) : item = spend.merchant;

  final CardSpend spend;
  String category;
  String item;
  bool picked = true;
}

class _CardImportPageState extends State<CardImportPage> {
  late final SmsSource _src = widget.source ?? SmsSource.of(demo: AppScope.of(context).repo.isDemo);
  late DateTime _from = () {
    final s = AppScope.of(context).settings!;
    final d = DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 30));
    return d.isBefore(s.openingDate) ? s.openingDate : d;
  }();
  DateTime _to = DateUtils.dateOnly(DateTime.now());

  bool? _allowed;
  bool _loading = false;
  bool _saving = false;
  List<_Row> _rows = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allowed == null) _check();
  }

  Future<void> _check() async {
    final ok = await _src.hasPermission();
    if (!mounted) return;
    setState(() => _allowed = ok);
    if (ok) _load();
  }

  Future<void> _ask() async {
    try {
      final ok = await _src.requestPermission();
      if (!mounted) return;
      setState(() => _allowed = ok);
      if (ok) {
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('허락하지 않았어요. 폰 설정 → 애플리케이션 → 총무노트 → 권한 → SMS에서 켤 수 있어요'),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _load() async {
    final s = AppScope.of(context);
    setState(() => _loading = true);
    try {
      final list = await _src.pending(
        since: _from,
        until: _to.add(const Duration(days: 1)),
        settings: s.settings!,
        txns: s.txns,
      );
      final cats = s.settings!.categoriesOf(TxnType.expense);
      if (!mounted) return;
      setState(() => _rows = [for (final p in list) _Row(p, CardSms.guessCategory(p.merchant, cats))]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('문자를 읽지 못했어요: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveFilters(List<String> filters) async {
    final s = AppScope.of(context);
    await s.repo.saveSettings(s.settings!.copyWith(cardFilters: filters));
    if (mounted) _load();
  }

  Future<void> _addFilter() async {
    final v = await askText(context, '어떤 카드만 가져올까요?', hint: '예: 신한카드, 국민 1234');
    if (v == null || v.isEmpty || !mounted) return;
    final now = AppScope.of(context).settings!.cardFilters;
    if (!now.contains(v)) await _saveFilters([...now, v]);
  }

  Future<void> _ignore(_Row r) async {
    final s = AppScope.of(context);
    setState(() => _rows = _rows.where((x) => x != r).toList());
    final ignored = [...s.settings!.smsIgnored, r.spend.key];
    // 너무 길어지지 않게 최근 300개만 기억해요.
    await s.repo.saveSettings(s.settings!.copyWith(
      smsIgnored: ignored.length > 300 ? ignored.sublist(ignored.length - 300) : ignored,
    ));
  }

  Future<void> _save() async {
    final s = AppScope.of(context);
    final picked = _rows.where((r) => r.picked).toList();
    if (picked.isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final r in picked) {
        await s.repo.saveTxn(Txn(
          id: '',
          date: DateUtils.dateOnly(r.spend.at),
          type: TxnType.expense,
          category: r.category,
          item: r.item.trim().isEmpty ? r.spend.merchant : r.item.trim(),
          amount: r.spend.amount,
          memo: '${r.spend.cardLabel} 문자',
          smsKey: r.spend.key,
        ));
      }
      if (!s.settings!.smsEnabled) await s.repo.saveSettings(s.settings!.copyWith(smsEnabled: true));
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('넣지 못했어요: $e')));
      return;
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _rows = _rows.where((r) => !r.picked).toList();
    });
    showDone(messenger, '${picked.length}건을 장부에 넣었어요');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final filters = s.settings!.cardFilters;
    final picked = _rows.where((r) => r.picked).toList();
    final total = picked.fold(0, (a, r) => a + r.spend.amount);

    Widget body;
    if (!_src.available) {
      body = _Note('카드 문자 가져오기는 안드로이드 폰 앱에서만 돼요.');
    } else if (_allowed == null) {
      body = const Center(child: Padding(padding: EdgeInsets.all(32), child: CupertinoActivityIndicator()));
    } else if (_allowed == false) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Note('카드 승인 문자를 읽어서 지출을 자동으로 채워 드려요.\n\n'
            '• 카드 결제 문자만 골라 읽고, 문자는 폰 밖으로 나가지 않아요\n'
            '• 장부에는 총무가 확인하고 고른 지출만 저장돼요\n'
            '• 언제든 폰 설정에서 다시 끌 수 있어요'),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('smsAllow'),
          onPressed: _ask,
          icon: const Icon(Icons.sms_rounded),
          label: const Text('문자 읽기 허락하기'),
        ),
      ]);
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('가져올 카드', style: tt.labelMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (filters.isEmpty) const Chip(label: Text('모든 카드')),
          for (final f in filters)
            InputChip(label: Text(f), onDeleted: () => _saveFilters(filters.where((x) => x != f).toList())),
          ActionChip(
            key: const Key('addCard'),
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('카드 고르기'),
            onPressed: _addFilter,
          ),
        ]),
        const SizedBox(height: 4),
        Text('모임 카드만 넣으려면 카드 이름(끝번호도 가능)을 넣어 두세요.', style: tt.bodySmall),
        const SizedBox(height: 14),
        Text('기간', style: tt.labelMedium),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: DateButton(date: _from, onPicked: (d) => setState(() => _from = d))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('~')),
          Expanded(child: DateButton(date: _to, onPicked: (d) => setState(() => _to = d))),
          IconButton(tooltip: '다시 찾기', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ]),
        SectionHeader(_loading ? '찾는 중…' : '새 카드 결제 ${_rows.length}건',
            trailing: _rows.isEmpty
                ? null
                : GestureDetector(
                    onTap: () => setState(() {
                      final all = _rows.every((r) => r.picked);
                      for (final r in _rows) {
                        r.picked = !all;
                      }
                    }),
                    child: Text(_rows.every((r) => r.picked) ? '모두 빼기' : '모두 고르기',
                        style: tt.labelMedium!.copyWith(color: AppColors.blue)),
                  )),
        if (!_loading && _rows.isEmpty)
          _Note('이 기간에 새로 넣을 카드 결제가 없어요.\n이미 넣었거나 넘긴 결제는 다시 안 나와요.')
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final (i, r) in _rows.indexed) ...[
                if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 52, color: Theme.of(context).dividerColor),
                _SpendTile(
                  key: ValueKey(r.spend.key),
                  row: r,
                  categories: s.settings!.categoriesOf(TxnType.expense),
                  onChanged: () => setState(() {}),
                  onIgnore: () => _ignore(r),
                ),
              ],
            ]),
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('smsSave'),
          onPressed: picked.isEmpty || _saving ? null : _save,
          child: Text(_saving ? '넣는 중…' : (picked.isEmpty ? '고른 결제가 없어요' : '${picked.length}건 · ${won(total)} 장부에 넣기')),
        ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('카드 문자로 지출 넣기')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [body]),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => AppCard(child: Text(text, style: Theme.of(context).textTheme.bodyMedium));
}

class _SpendTile extends StatelessWidget {
  const _SpendTile({
    super.key,
    required this.row,
    required this.categories,
    required this.onChanged,
    required this.onIgnore,
  });

  final _Row row;
  final List<String> categories;
  final VoidCallback onChanged;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final sp = row.spend;
    final when = '${sp.at.month}/${sp.at.day} ${sp.at.hour.toString().padLeft(2, '0')}:${sp.at.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(children: [
        Checkbox(
          value: row.picked,
          onChanged: (v) {
            row.picked = v ?? false;
            onChanged();
          },
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () async {
                final v = await askText(context, '항목 이름', initial: row.item);
                if (v != null && v.isNotEmpty) {
                  row.item = v;
                  onChanged();
                }
              },
              child: Text(row.item, style: tt.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 2),
            Text('$when · ${sp.cardLabel}', style: tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            PopupMenuButton<String>(
              tooltip: '분류 바꾸기',
              initialValue: row.category,
              onSelected: (c) {
                row.category = c;
                onChanged();
              },
              itemBuilder: (_) => [for (final c in categories) PopupMenuItem(value: c, child: Text(c))],
              child: Badge2(row.category, color: AppColors.blue),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(won(sp.amount), style: tt.titleMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          TextButton(
            onPressed: onIgnore,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
            child: Text('넘기기', style: tt.bodySmall),
          ),
        ]),
      ]),
    );
  }
}
