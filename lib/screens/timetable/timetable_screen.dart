import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import '../../widgets/ios.dart';
import '../home/home_screen.dart';

const _dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _dayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _dur(int mins) {
  final h = mins ~/ 60, m = mins % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Weekly timetable: week strip, the day's classes on a timeline,
/// add / edit / delete, and "quiet during classes".
class TimetableScreen extends StatefulWidget {
  final AppUser me;
  const TimetableScreen({super.key, required this.me});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  int _day = DateTime.now().weekday;
  late final _stream = usersCol.doc(widget.me.uid).snapshots();

  Future<void> _save(List<Period> all) async {
    try {
      await TimetableService.save(widget.me.uid, all);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e');
    }
  }

  Future<void> _edit(List<Period> all, [Period? old]) async {
    final res = await showCupertinoModalPopup<_SheetResult>(
      context: context,
      builder: (_) => _PeriodSheet(day: _day, initial: old, all: all),
    );
    if (res == null) return;
    final next = [...all];
    if (old != null) next.remove(old);
    if (!res.delete) next.addAll(res.periods);
    await _save(next);
    if (mounted && res.periods.length > 1) {
      showSnack(context, 'Added to ${res.periods.length} days.');
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _stream,
    builder: (_, snap) {
      final me = snap.hasData && snap.data!.exists
          ? AppUser.fromDoc(snap.data!)
          : widget.me;
      final all = me.timetable;
      final day = all.where((p) => p.day == _day).toList();
      final mins = day.fold(0, (a, p) => a + (p.endMin - p.startMin));
      final top = MediaQuery.paddingOf(context).top;

      return Scaffold(
        backgroundColor: HomeColors.bg,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 2,
          onPressed: () => _edit(all),
          icon: const Icon(CupertinoIcons.add),
          label: const Text(
            'Add class',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: Responsive(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, top + 8, 16, 110),
            children: [
              // Header
              Row(
                children: [
                  _Round(
                    icon: CupertinoIcons.chevron_back,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Timetable',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: HomeColors.ink,
                          ),
                        ),
                        Text(
                          '${all.length} class${all.length == 1 ? '' : 'es'} a week',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: HomeColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _WeekStrip(
                selected: _day,
                counts: [
                  for (var d = 1; d <= 7; d++)
                    all.where((p) => p.day == d).length,
                ],
                onPick: (d) => setState(() => _day = d),
              ),
              const SizedBox(height: 20),
              // Day title + summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        _day == DateTime.now().weekday
                            ? 'Today · ${_dayLong[_day - 1]}'
                            : _dayLong[_day - 1],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.ink,
                        ),
                      ),
                    ),
                    if (day.isNotEmpty)
                      Text(
                        '${day.length} class${day.length == 1 ? '' : 'es'} · ${_dur(mins)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: HomeColors.sub,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (day.isEmpty)
                _EmptyDay(day: _day, onAdd: () => _edit(all))
              else
                for (var i = 0; i < day.length; i++)
                  _TimelineItem(
                    p: day[i],
                    today: _day == DateTime.now().weekday,
                    last: i == day.length - 1,
                    gapAfter: i < day.length - 1
                        ? day[i + 1].startMin - day[i].endMin
                        : 0,
                    onTap: () => _edit(all, day[i]),
                  ),
              const SizedBox(height: 20),
              // Quiet during classes
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: HomeColors.blueBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        CupertinoIcons.bell_slash_fill,
                        color: HomeColors.blue,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quiet during classes',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: HomeColors.ink,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Bells come silently while you teach. Urgent bells still ring.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: HomeColors.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: me.quietInClass,
                      activeTrackColor: AppColors.accent,
                      onChanged: (v) =>
                          TimetableService.setQuietInClass(me.uid, v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
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
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: HomeColors.ink),
    ),
  );
}

/// Mon … Sun with this week's dates and a dot per day that has classes.
class _WeekStrip extends StatelessWidget {
  final int selected;
  final List<int> counts;
  final ValueChanged<int> onPick;
  const _WeekStrip({
    required this.selected,
    required this.counts,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (var d = 1; d <= 7; d++)
            Expanded(
              child: GestureDetector(
                onTap: () => onPick(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: d == selected
                        ? AppColors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _dayShort[d - 1],
                        style: TextStyle(
                          fontSize: 12,
                          color: d == selected
                              ? const Color(0xFFC9D4F2)
                              : HomeColors.sub,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${monday.add(Duration(days: d - 1)).day}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: d == selected
                              ? Colors.white
                              : d == now.weekday
                              ? AppColors.accent
                              : HomeColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: counts[d - 1] == 0
                              ? Colors.transparent
                              : d == selected
                              ? Colors.white
                              : AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final int day;
  final VoidCallback onAdd;
  const _EmptyDay({required this.day, required this.onAdd});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: HomeColors.blueBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.calendar_badge_plus,
            color: HomeColors.blue,
            size: 26,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'No classes on ${_dayLong[day - 1]}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: HomeColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Add your periods so people know when you are free.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: HomeColors.sub),
        ),
        const SizedBox(height: 14),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          minimumSize: Size.zero,
          color: HomeColors.blueBg,
          borderRadius: BorderRadius.circular(99),
          onPressed: onAdd,
          child: const Text(
            'Add a class',
            style: TextStyle(
              color: HomeColors.blue,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// One class on the timeline: times | dot + line | card.
class _TimelineItem extends StatelessWidget {
  final Period p;
  final bool today, last;
  final int gapAfter;
  final VoidCallback onTap;
  const _TimelineItem({
    required this.p,
    required this.today,
    required this.last,
    required this.gapAfter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final m = n.hour * 60 + n.minute;
    final live = today && p.startMin <= m && m < p.endMin;
    final done = today && p.endMin <= m;
    final ink = done ? HomeColors.muted : HomeColors.ink;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.start,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  Text(
                    p.end,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: HomeColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 17),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: live
                        ? AppColors.accent
                        : done
                        ? const Color(0xFFD5DAE6)
                        : Colors.white,
                    border: Border.all(
                      color: done ? const Color(0xFFD5DAE6) : AppColors.accent,
                      width: 2.5,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFDDE2EC)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: live ? AppColors.accent : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    color: live ? Colors.white : ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (p.place.isNotEmpty) ...[
                                      Icon(
                                        CupertinoIcons.location_solid,
                                        size: 12,
                                        color: live
                                            ? const Color(0xFFC9D4F2)
                                            : HomeColors.sub,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          p.place,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: live
                                                ? const Color(0xFFC9D4F2)
                                                : HomeColors.sub,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Icon(
                                      CupertinoIcons.time,
                                      size: 12,
                                      color: live
                                          ? const Color(0xFFC9D4F2)
                                          : HomeColors.sub,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _dur(p.endMin - p.startMin),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: live
                                            ? const Color(0xFFC9D4F2)
                                            : HomeColors.sub,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (live)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                'Now',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            )
                          else
                            Icon(
                              done
                                  ? CupertinoIcons.checkmark_alt
                                  : CupertinoIcons.chevron_forward,
                              size: 16,
                              color: HomeColors.muted,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (gapAfter >= 15)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        'Free · ${_dur(gapAfter)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HomeColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetResult {
  final List<Period> periods;
  final bool delete;
  const _SheetResult(this.periods, {this.delete = false});
}

/// Add / edit one class. When adding you can pick several days at once.
class _PeriodSheet extends StatefulWidget {
  final int day;
  final Period? initial;
  final List<Period> all;
  const _PeriodSheet({required this.day, required this.all, this.initial});
  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _place = TextEditingController(text: widget.initial?.place);
  late String _start = widget.initial?.start ?? _suggestStart();
  late String _end =
      widget.initial?.end ?? _fmtMin(Period.minutes(_start) + 50);
  late final Set<int> _days = {widget.day};
  String? _error;

  bool get _editing => widget.initial != null;

  /// New class starts when the day's last class ends (or 09:00).
  String _suggestStart() {
    final today = widget.all.where((p) => p.day == widget.day).toList();
    if (today.isEmpty) return '09:00';
    return today.last.end;
  }

  static String _fmtMin(int m) {
    m = m.clamp(0, 23 * 60 + 55);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final cur = Period.minutes(start ? _start : _end);
    var picked = DateTime(2000, 1, 1, cur ~/ 60, cur % 60 - cur % 5);
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 290,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    start ? 'Starts at' : 'Ends at',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                minuteInterval: 5,
                initialDateTime: picked,
                onDateTimeChanged: (t) => picked = t,
              ),
            ),
          ],
        ),
      ),
    );
    final v = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        final len = Period.minutes(_end) - Period.minutes(_start);
        _start = _fmtMin(v);
        // Keep the same length when the start moves.
        _end = _fmtMin(v + (len > 0 ? len : 50));
      } else {
        _end = _fmtMin(v);
      }
      _error = null;
    });
  }

  /// A class already in that slot on one of the chosen days, if any.
  String? _clash() {
    final s = Period.minutes(_start), e = Period.minutes(_end);
    for (final p in widget.all) {
      if (p == widget.initial || !_days.contains(p.day)) continue;
      if (s < p.endMin && p.startMin < e) {
        return '${_dayShort[p.day - 1]} ${p.start}–${p.end} already has ${p.title}.';
      }
    }
    return null;
  }

  void _done() {
    final t = _title.text.trim();
    if (t.isEmpty) return setState(() => _error = 'Enter the class name.');
    if (Period.minutes(_end) <= Period.minutes(_start)) {
      return setState(() => _error = 'End time must be after start time.');
    }
    if (_days.isEmpty) return setState(() => _error = 'Pick at least one day.');
    final clash = _clash();
    if (clash != null) return setState(() => _error = clash);
    final days = _editing ? {widget.initial!.day} : _days;
    Navigator.pop(
      context,
      _SheetResult([
        for (final d in days.toList()..sort())
          Period(
            day: d,
            start: _start,
            end: _end,
            title: t,
            place: _place.text.trim(),
          ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: HomeColors.soft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: HomeColors.sub),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: c,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: AppColors.accent,
                style: const TextStyle(fontSize: 16),
                decoration: plainInput(hint),
              ),
            ),
          ],
        ),
      );

  Widget _time(String label, String value, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          color: HomeColors.soft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: HomeColors.sub),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: HomeColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.clock, size: 17, color: HomeColors.sub),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final len = Period.minutes(_end) - Period.minutes(_start);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDADAD6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? 'Edit class' : 'Add class',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: HomeColors.ink,
                      ),
                    ),
                  ),
                  if (_editing)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.pop(
                        context,
                        const _SheetResult([], delete: true),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            CupertinoIcons.trash,
                            size: 17,
                            color: IosColors.red,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: IosColors.red,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _field(
                _title,
                'Class, e.g. Operating systems',
                CupertinoIcons.book,
              ),
              const SizedBox(height: 10),
              _field(
                _place,
                'Room, e.g. CSE 3B · Lab 2',
                CupertinoIcons.location,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _time('Starts', _start, () => _pick(true)),
                  const SizedBox(width: 10),
                  _time('Ends', _end, () => _pick(false)),
                ],
              ),
              if (len > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Length ${_dur(len)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: HomeColors.sub,
                    ),
                  ),
                ),
              if (!_editing) ...[
                const SizedBox(height: 14),
                const Text(
                  'Repeat on',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.sub,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var d = 1; d <= 7; d++) ...[
                      if (d > 1) const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _days.contains(d) ? _days.remove(d) : _days.add(d);
                            _error = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _days.contains(d)
                                  ? AppColors.accent
                                  : HomeColors.soft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _dayShort[d - 1].substring(0, 1),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _days.contains(d)
                                    ? Colors.white
                                    : HomeColors.sub,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: IosColors.red, fontSize: 13.5),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: _done,
                  child: Text(
                    _editing
                        ? 'Save changes'
                        : _days.length > 1
                        ? 'Add to ${_days.length} days'
                        : 'Add class',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
