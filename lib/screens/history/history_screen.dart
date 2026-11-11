import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/ios.dart';
import '../home/home_screen.dart';
import '../request_details/request_details_screen.dart';

const _green = Color(0xFF1E8E3E);
const _greenBg = Color(0xFFE3F4E8);
const _amber = Color(0xFF9A6200);
const _amberBg = Color(0xFFFFF1DC);

/// All / Sent / Received bells as compact cards, grouped by day, with search.
class HistoryScreen extends StatefulWidget {
  final AppUser me;
  final int initialTab;
  final bool standalone;
  const HistoryScreen({
    super.key,
    required this.me,
    this.initialTab = 0,
    this.standalone = false,
  });
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late int _tab = widget.initialTab;
  bool _searching = false;
  String _q = '';
  late final _sent = BellService.sent(widget.me.uid);
  late final _received = BellService.received(widget.me.uid);
  late final _group = BellService.receivedGroup(widget.me.uid);

  static String _day(DateTime t) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final d = today.difference(DateTime(t.year, t.month, t.day)).inDays;
    if (d == 0) return 'Today';
    if (d == 1) return 'Yesterday';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${t.day} ${m[t.month - 1]}${t.year == n.year ? '' : ' ${t.year}'}';
  }

  static String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  if (widget.standalone)
                    _Round(
                      icon: CupertinoIcons.chevron_back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'History',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: HomeColors.ink,
                      ),
                    ),
                  ),
                  _Round(
                    icon: _searching
                        ? CupertinoIcons.xmark
                        : CupertinoIcons.search,
                    onTap: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _q = '';
                    }),
                  ),
                ],
              ),
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: CupertinoSearchTextField(
                  autofocus: true,
                  placeholder: 'Search name or message',
                  backgroundColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (final (i, label) in [
                      (0, 'All'),
                      (1, 'Sent'),
                      (2, 'Received'),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _tab == i
                                  ? AppColors.accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _tab == i
                                    ? Colors.white
                                    : HomeColors.sub,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: _list(me)),
          ],
        ),
      ),
    );
  }

  Widget _list(AppUser me) => StreamBuilder<List<BellRequest>>(
    stream: _sent,
    builder: (_, sentSnap) => StreamBuilder<List<BellRequest>>(
      stream: _received,
      builder: (_, recSnap) => StreamBuilder<List<BellRequest>>(
        // Group bells I'm a member of count as received.
        stream: _group,
        builder: (_, grpSnap) {
          final err = sentSnap.error ?? recSnap.error;
          if (err != null) return Center(child: Text('Could not load: $err'));
          if (!sentSnap.hasData || !recSnap.hasData) {
            return const Center(child: CupertinoActivityIndicator());
          }
          final now = DateTime.now();
          var items = <BellRequest>[
            if (_tab != 2) ...sentSnap.data!,
            if (_tab != 1) ...recSnap.data!,
            if (_tab != 1) ...?grpSnap.data,
          ]..sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
          if (_q.isNotEmpty) {
            items = items.where((r) {
              final who =
                  (r.senderUid == me.uid ? r.recipientName : r.senderName)
                      .toLowerCase();
              return who.contains(_q) || r.message.toLowerCase().contains(_q);
            }).toList();
          }
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.clock,
                    size: 40,
                    color: HomeColors.muted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _q.isEmpty ? 'No bells yet' : 'No matches',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Bells you send or receive appear here.',
                    style: TextStyle(fontSize: 14, color: HomeColors.sub),
                  ),
                ],
              ),
            );
          }
          final groups = <String, List<BellRequest>>{};
          for (final r in items) {
            groups.putIfAbsent(_day(r.createdAt ?? now), () => []).add(r);
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              widget.standalone ? 24 : 120,
            ),
            children: [
              for (final e in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                  child: Text(
                    '${e.key} · ${e.value.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.sub,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < e.value.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 64,
                            color: HomeColors.line,
                          ),
                        _BellRow(
                          me: me,
                          r: e.value[i],
                          time: _time(e.value[i].createdAt ?? now),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _Round extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Round({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: HomeColors.ink, size: 19),
    ),
  );
}

/// One bell: avatar with direction badge | name, message | time, status.
class _BellRow extends StatelessWidget {
  final AppUser me;
  final BellRequest r;
  final String time;
  const _BellRow({required this.me, required this.r, required this.time});

  (String, Color, Color) get _status => switch (r.status) {
    BellStatus.accepted => ('Accepted', _green, _greenBg),
    BellStatus.declined => ('Declined', HomeColors.redText, HomeColors.redBg),
    BellStatus.delivered => ('Delivered', HomeColors.blue, HomeColors.blueBg),
    BellStatus.failed ||
    BellStatus.rejected => ('Failed', HomeColors.redText, HomeColors.redBg),
    _ => ('Pending', _amber, _amberBg),
  };

  @override
  Widget build(BuildContext context) {
    final sent = r.senderUid == me.uid;
    final name = sent ? r.recipientName : r.senderName;
    final (label, fg, bg) = _status;
    final ini = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && !p.endsWith('.'))
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return InkWell(
      onTap: () => Navigator.push(
        context,
        iosRoute(RequestDetailsScreen(me: me, requestId: r.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: HomeColors.blueBg,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      ini.isEmpty ? '?' : ini,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: HomeColors.blue,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: HomeColors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        sent
                            ? CupertinoIcons.arrow_up_right
                            : CupertinoIcons.arrow_down_left,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: HomeColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: HomeColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.isRequest
                              ? 'Request · ${r.message.isEmpty ? 'Wants to meet' : r.message}'
                              : (r.message.isEmpty ? 'Please come' : r.message),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: HomeColors.sub,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (r.priority == Priority.urgent)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            CupertinoIcons.exclamationmark_circle_fill,
                            size: 15,
                            color: HomeColors.redText,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
