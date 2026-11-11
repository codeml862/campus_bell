import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import '../../widgets/ios.dart';
import '../announce/announce_screen.dart';
import '../directory/directory_screen.dart';
import '../history/history_screen.dart';
import '../request_details/request_details_screen.dart';
import '../timetable/timetable_screen.dart';
import 'ring_group_screen.dart';
import '../../widgets/photo.dart';

/// Home colours (match the approved mockup).
class HomeColors {
  static const bg = Color(0xFFF7F6F3);
  static const card = Colors.white;
  static const ink = Color(0xFF1F1F1D);
  static const sub = Color(0xFF6B6B66);
  static const muted = Color(0xFFA3A39C);
  static const line = Color(0xFFECEBE6);
  static const soft = Color(0xFFF1F0EB);

  // Deep blue only (brand), with its pale tint.
  static const blue = Color(0xFF1E3A8A);
  static const blueBg = Color(0xFFE8EEFB);
  static const blueText = Color(0xFF1E3A8A);

  static const greenBg = Color(0xFFCDEBC9);
  static const greenText = Color(0xFF2B6A12);

  static const amberBg = Color(0xFFFBE5BC);
  static const amberText = Color(0xFF85520A);
  static const amber = Color(0xFFF2B02E);

  static const redBg = Color(0xFFF9DADA);
  static const redText = Color(0xFFB3261E);
}

/// Home: greeting, offline banner, notice carousel, actions,
/// today's timetable and meet requests.
class HomeScreen extends StatefulWidget {
  final AppUser me;
  final ValueChanged<int> goToTab;
  const HomeScreen({super.key, required this.me, required this.goToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppUser _me = widget.me;
  StreamSubscription? _sub;
  Timer? _offTimer, _clock;
  bool _offline = false, _retrying = false;

  @override
  void initState() {
    super.initState();
    _sub = usersCol
        .doc(widget.me.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(_onUser, onError: (_) {});
    // Refresh "Now" / "in 25 min" once a minute.
    _clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  void _onUser(DocumentSnapshot<Map<String, dynamic>> d) {
    if (!mounted) return;
    if (d.exists) setState(() => _me = AppUser.fromDoc(d));
    if (d.metadata.isFromCache) {
      // Only call it offline if the server stays unreachable for a bit.
      _offTimer ??= Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _offline = true);
      });
    } else {
      _offTimer?.cancel();
      _offTimer = null;
      if (_offline) setState(() => _offline = false);
    }
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await usersCol.doc(_me.uid).get(const GetOptions(source: Source.server));
      if (mounted) setState(() => _offline = false);
    } catch (_) {
      if (mounted) showSnack(context, 'Still offline. Check your internet.');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _offTimer?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  void _push(Widget page) => Navigator.push(context, iosRoute(page));

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final canCall = Roles.canCallAnyone(me.role);
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: HomeColors.bg,
      child: Responsive(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, top + 12, 16, 120),
          children: [
            _Header(me: me, onAvatar: () => widget.goToTab(4)),
            if (_offline) ...[
              const SizedBox(height: 14),
              _OfflineBanner(busy: _retrying, onRetry: _retry),
            ],
            const SizedBox(height: 16),
            _NoticeCarousel(me: me, push: _push),
            const SizedBox(height: 16),
            if (canCall) ...[
              _RingCircle(
                icon: CupertinoIcons.bell_fill,
                title: 'Ring person',
                subtitle: 'Their phone rings with your message',
                onTap: () => _push(DirectoryScreen(me: me, callMode: true)),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _RingGroupTile(me: me, onTap: _push),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AnnounceTile(me: me, onTap: _push),
                  ),
                ],
              ),
            ] else ...[
              _RingCircle(
                icon: CupertinoIcons.hand_raised_fill,
                title: 'Request to meet',
                subtitle: 'Ask a staff member for a meeting',
                onTap: () => _push(DirectoryScreen(me: me)),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AnnounceTile(me: me, onTap: _push),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tile(
                      icon: CupertinoIcons.clock,
                      title: 'History',
                      subtitle: 'Your bells and requests',
                      onTap: () =>
                          _push(HistoryScreen(me: me, standalone: true)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _SectionHead(
              'My timetable',
              trailing: _Link(
                'Full week',
                onTap: () => _push(TimetableScreen(me: me)),
              ),
            ),
            _TimetableCard(
              me: me,
              onAdd: () => _push(TimetableScreen(me: me)),
            ),
            _MeetRequests(me: me),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ basics

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color = HomeColors.card,
  });
  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
    return onTap == null ? box : _Pressable(onTap: onTap!, child: box);
  }
}

/// Slight shrink on press.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) {
      setState(() => _down = false);
      widget.onTap();
    },
    child: AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      child: widget.child,
    ),
  );
}

class _SectionHead extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _SectionHead(this.text, {this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: HomeColors.ink,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _Link extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Link(this.text, {required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14.5, color: HomeColors.blueText),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _Badge(this.text, {required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12.5, color: fg, fontWeight: FontWeight.w500),
    ),
  );
}

class _Initials extends StatelessWidget {
  final String name;
  final double size;
  const _Initials(this.name, {this.size = 40});
  @override
  Widget build(BuildContext context) {
    final ini = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && !p.endsWith('.'))
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: HomeColors.blueBg,
        shape: BoxShape.circle,
      ),
      child: Text(
        ini.isEmpty ? '?' : ini,
        style: TextStyle(
          color: HomeColors.blueText,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ header

class _Header extends StatelessWidget {
  final AppUser me;
  final VoidCallback onAvatar;
  const _Header({required this.me, required this.onAvatar});

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
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

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final hello = n.hour < 12
        ? 'Good morning'
        : n.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final first = displayName(me.name);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_days[n.weekday - 1]}, ${n.day} ${_months[n.month - 1]}',
                style: const TextStyle(fontSize: 13.5, color: HomeColors.sub),
              ),
              const SizedBox(height: 6),
              Text(
                hello,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: HomeColors.sub,
                ),
              ),
              Text(
                first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: HomeColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onAvatar,
          child: UserPhoto(
            uid: me.uid,
            size: 48,
            fallback: _Initials(me.name, size: 48),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ offline

class _OfflineBanner extends StatelessWidget {
  final bool busy;
  final VoidCallback onRetry;
  const _OfflineBanner({required this.busy, required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
    decoration: BoxDecoration(
      color: HomeColors.amberBg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          color: HomeColors.amberText,
          size: 22,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You're offline",
                style: TextStyle(
                  color: HomeColors.amberText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "Bells can't be sent until you're back online",
                style: TextStyle(color: HomeColors.amberText, fontSize: 12.5),
              ),
            ],
          ),
        ),
        busy
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: CupertinoActivityIndicator(color: HomeColors.amberText),
              )
            : CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: HomeColors.amberText,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ],
    ),
  );
}

// ------------------------------------------------------------ carousel

class _Slide {
  final IconData icon;
  final String label, title, body;
  final String? footer;
  final String link;
  final VoidCallback onOpen;
  final Announcement? notice;
  const _Slide({
    required this.icon,
    required this.label,
    required this.title,
    required this.body,
    required this.link,
    required this.onOpen,
    this.footer,
    this.notice,
  });
}

class _NoticeCarousel extends StatefulWidget {
  final AppUser me;
  final void Function(Widget) push;
  const _NoticeCarousel({required this.me, required this.push});
  @override
  State<_NoticeCarousel> createState() => _NoticeCarouselState();
}

class _NoticeCarouselState extends State<_NoticeCarousel> {
  final _page = PageController();
  late final Stream<List<Announcement>> _stream = AnnouncementService.forMe(
    widget.me,
    limit: 5,
  );
  Timer? _auto;
  int _i = 0, _count = 0;

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_count < 2 || !_page.hasClients) return;
      _page.animateToPage(
        (_i + 1) % _count,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _page.dispose();
    super.dispose();
  }

  /// Three fixed slides, each with a link to a feature.
  List<_Slide> _features() {
    final me = widget.me;
    final canCall = Roles.canCallAnyone(me.role);
    return [
      canCall
          ? _Slide(
              icon: CupertinoIcons.person_3,
              label: 'Groups',
              title: 'Ring a whole group',
              body: 'Everyone rings at once. The first to accept goes.',
              link: 'Open groups',
              onOpen: () => widget.push(RingGroupScreen(me: me)),
            )
          : _Slide(
              icon: CupertinoIcons.hand_raised,
              label: 'Meet',
              title: 'Need to meet a lecturer?',
              body: 'Send a quiet request. They answer from their phone.',
              link: 'Send request',
              onOpen: () => widget.push(DirectoryScreen(me: me)),
            ),
      _Slide(
        icon: CupertinoIcons.calendar,
        label: 'Timetable',
        title: 'Add your classes',
        body: 'Bells go quiet automatically while you teach.',
        link: 'Set timetable',
        onOpen: () => widget.push(TimetableScreen(me: me)),
      ),
      _Slide(
        icon: CupertinoIcons.clock,
        label: 'History',
        title: 'Every bell, in one place',
        body: 'See who accepted, declined or missed your bells.',
        link: 'View history',
        onOpen: () => widget.push(HistoryScreen(me: me, standalone: true)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Announcement>>(
    stream: _stream,
    builder: (_, snap) {
      final slides = [
        for (final a in snap.data ?? const <Announcement>[])
          _Slide(
            icon: a.forEveryone ? CupertinoIcons.speaker_2 : CupertinoIcons.pin,
            label: a.forEveryone ? 'For everyone' : 'Notice',
            title: a.title,
            body: a.message,
            footer: '${a.senderName} · ${timeAgo(a.createdAt)}',
            link: 'Read notice',
            notice: a,
            onOpen: () => showCupertinoModalPopup(
              context: context,
              builder: (_) => NoticeSheet(notice: a),
            ),
          ),
        ..._features(),
      ];
      _count = slides.length;
      if (_i >= _count) _i = 0;
      final shown = slides[_i].notice;
      if (shown != null) AnnouncementService.markSeen(shown, widget.me.uid);
      return Column(
        children: [
          SizedBox(
            height: 156,
            child: PageView.builder(
              controller: _page,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: _SlideCard(slide: slides[i], dark: i.isEven),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var k = 0; k < slides.length; k++)
                GestureDetector(
                  onTap: () => _page.animateToPage(
                    k,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: k == _i ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: k == _i
                          ? HomeColors.blue
                          : const Color(0xFFD5DAE6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}

/// Deep blue (dark) or pale blue slide with a link button at the bottom.
class _SlideCard extends StatelessWidget {
  final _Slide slide;
  final bool dark;
  const _SlideCard({required this.slide, required this.dark});
  @override
  Widget build(BuildContext context) {
    final s = slide;
    final fg = dark ? Colors.white : HomeColors.blue;
    final soft = dark ? const Color(0xFFC9D4F2) : const Color(0xFF4A5B8C);
    return _Card(
      color: dark ? HomeColors.blue : HomeColors.blueBg,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      onTap: s.onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(s.icon, size: 15, color: soft),
              const SizedBox(width: 6),
              Text(s.label, style: TextStyle(fontSize: 13, color: soft)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            s.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: soft),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.footer ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: soft),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
                decoration: BoxDecoration(
                  color: dark ? Colors.white : HomeColors.blue,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.link,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: dark ? HomeColors.blue : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 14,
                      color: dark ? HomeColors.blue : Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ actions

/// The main action: a big deep-blue circle with the bell in the middle.
class _RingCircle extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _RingCircle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => _Card(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 136,
          height: 136,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: HomeColors.blueBg,
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: HomeColors.blue,
            ),
            child: Icon(icon, color: Colors.white, size: 50),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            color: HomeColors.ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: HomeColors.sub, fontSize: 13.5),
        ),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget? badge;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
  @override
  Widget build(BuildContext context) => _Card(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: HomeColors.blueBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: HomeColors.blueText, size: 22),
            ),
            const Spacer(),
            ?badge,
          ],
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: HomeColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, color: HomeColors.sub),
        ),
      ],
    ),
  );
}

class _RingGroupTile extends StatelessWidget {
  final AppUser me;
  final void Function(Widget) onTap;
  const _RingGroupTile({required this.me, required this.onTap});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Group>>(
    stream: GroupService.mine(me),
    builder: (_, snap) {
      final n = ringableGroups(me, snap.data ?? const []).length;
      return _Tile(
        icon: CupertinoIcons.person_2,
        title: 'Ring group',
        subtitle: 'First to accept goes',
        badge: snap.hasData
            ? Text(
                '$n group${n == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 13.5, color: HomeColors.sub),
              )
            : null,
        onTap: () => onTap(RingGroupScreen(me: me)),
      );
    },
  );
}

class _AnnounceTile extends StatelessWidget {
  final AppUser me;
  final void Function(Widget) onTap;
  const _AnnounceTile({required this.me, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!AnnouncementService.canPost(me)) {
      return StreamBuilder<List<Announcement>>(
        stream: AnnouncementService.forMe(me),
        builder: (_, snap) {
          final unseen = (snap.data ?? const <Announcement>[])
              .where((a) => !a.seenBy.contains(me.uid))
              .length;
          return _Tile(
            icon: CupertinoIcons.speaker_2,
            title: 'Notices',
            subtitle: 'From your department',
            badge: unseen > 0
                ? _Badge(
                    '$unseen new',
                    bg: HomeColors.redBg,
                    fg: HomeColors.redText,
                  )
                : null,
            onTap: () => onTap(NoticesScreen(me: me)),
          );
        },
      );
    }
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementService.sentBy(me.uid),
      builder: (_, snap) {
        final last = (snap.data ?? const <Announcement>[]).firstOrNull;
        return _Tile(
          icon: CupertinoIcons.speaker_2,
          title: 'Announce',
          subtitle: 'Notice to dept or year',
          badge: last == null ? null : SeenBadge(notice: last),
          onTap: () => onTap(AnnounceScreen(me: me)),
        );
      },
    );
  }
}

// ------------------------------------------------------------ timetable

String _until(int mins) {
  if (mins < 60) return 'in $mins min';
  final h = mins ~/ 60, m = mins % 60;
  return m == 0 ? 'in ${h}h' : 'in ${h}h ${m}m';
}

class _TimetableCard extends StatelessWidget {
  final AppUser me;
  final VoidCallback onAdd;
  const _TimetableCard({required this.me, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final today = me.timetable.where((p) => p.day == now.weekday).toList();
    final nextIndex = today.indexWhere((p) => p.startMin > nowMin);

    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          if (today.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.calendar,
                    color: HomeColors.muted,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No classes today',
                      style: TextStyle(fontSize: 15, color: HomeColors.sub),
                    ),
                  ),
                  _Link('Add classes', onTap: onAdd),
                ],
              ),
            ),
          for (var i = 0; i < today.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: HomeColors.line),
            _PeriodRow(p: today[i], nowMin: nowMin, isNext: i == nextIndex),
          ],
          const Divider(height: 1, color: HomeColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(
                  me.quietInClass
                      ? CupertinoIcons.bell_slash
                      : CupertinoIcons.bell,
                  size: 17,
                  color: HomeColors.sub,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    me.quietInClass
                        ? 'Bells go quiet during your classes'
                        : 'Bells ring even during your classes',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: HomeColors.sub,
                    ),
                  ),
                ),
                _Link(
                  'Change',
                  onTap: () async {
                    try {
                      await TimetableService.setQuietInClass(
                        me.uid,
                        !me.quietInClass,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        showSnack(context, 'Could not change it: $e');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final Period p;
  final int nowMin;
  final bool isNext;
  const _PeriodRow({
    required this.p,
    required this.nowMin,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    final done = p.endMin <= nowMin;
    final live = p.startMin <= nowMin && nowMin < p.endMin;
    final bar = live
        ? HomeColors.blue
        : isNext
        ? HomeColors.amber
        : const Color(0xFFDAD9D3);
    final ink = done ? HomeColors.muted : HomeColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            SizedBox(
              width: 54,
              child: Text(
                p.start,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: done ? FontWeight.w400 : FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
            Container(
              width: 3,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: bar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
                      fontWeight: live ? FontWeight.w600 : FontWeight.w400,
                      color: ink,
                    ),
                  ),
                  if (p.place.isNotEmpty)
                    Text(
                      p.place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: done ? HomeColors.muted : HomeColors.sub,
                      ),
                    ),
                ],
              ),
            ),
            if (done)
              const Icon(
                CupertinoIcons.checkmark,
                size: 17,
                color: HomeColors.muted,
              )
            else if (live)
              const _Badge(
                'Now',
                bg: HomeColors.blueBg,
                fg: HomeColors.blueText,
              )
            else if (isNext)
              _Badge(
                _until(p.startMin - nowMin),
                bg: HomeColors.amberBg,
                fg: HomeColors.amberText,
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ meet requests

class _MeetRequests extends StatefulWidget {
  final AppUser me;
  const _MeetRequests({required this.me});
  @override
  State<_MeetRequests> createState() => _MeetRequestsState();
}

class _MeetRequestsState extends State<_MeetRequests> {
  late final Stream<List<BellRequest>> _stream = BellService.received(
    widget.me.uid,
  );
  final _later = <String>{};
  final _busy = <String>{};

  Future<void> _accept(BellRequest r) async {
    setState(() => _busy.add(r.id));
    try {
      await BellService.respond(r.id, accept: true);
      if (mounted) showSnack(context, '${r.senderName} has been told to come.');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not answer: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<BellRequest>>(
    stream: _stream,
    builder: (_, snap) {
      final open = (snap.data ?? const <BellRequest>[])
          .where(
            (b) =>
                b.isRequest &&
                (b.status == BellStatus.pending ||
                    b.status == BellStatus.delivered) &&
                !_later.contains(b.id),
          )
          .toList();
      if (open.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHead(
              'Meet requests',
              trailing: _Badge(
                '${open.length} new',
                bg: HomeColors.redBg,
                fg: HomeColors.redText,
              ),
            ),
            for (final r in open.take(3)) ...[
              _Card(
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.push(
                        context,
                        iosRoute(
                          RequestDetailsScreen(me: widget.me, requestId: r.id),
                        ),
                      ),
                      child: Row(
                        children: [
                          UserPhoto(
                            uid: r.senderUid,
                            size: 40,
                            fallback: _Initials(r.senderName),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.senderName,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    color: HomeColors.ink,
                                  ),
                                ),
                                Text(
                                  r.message.isEmpty
                                      ? 'Wants to meet you'
                                      : r.message,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: HomeColors.sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _short(r.createdAt),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: HomeColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _busy.contains(r.id)
                        ? const SizedBox(
                            height: 40,
                            child: Center(child: CupertinoActivityIndicator()),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _Btn(
                                  'Later',
                                  bg: HomeColors.soft,
                                  fg: HomeColors.sub,
                                  onTap: () => setState(() => _later.add(r.id)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _Btn(
                                  'Accept',
                                  bg: HomeColors.blue,
                                  fg: Colors.white,
                                  onTap: () => _accept(r),
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
    },
  );
}

String _short(DateTime? t) {
  if (t == null) return 'now';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}

class _Btn extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final VoidCallback onTap;
  const _Btn(
    this.text, {
    required this.bg,
    required this.fg,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => _Pressable(
    onTap: onTap,
    child: Container(
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// Text field look with no outline at all (overrides the app-wide outlined
/// input theme, which drew a border on focus).
InputDecoration plainInput(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: HomeColors.muted),
  filled: false,
  isDense: true,
  counterText: '',
  contentPadding: EdgeInsets.zero,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
);

/// Groups [me] may ring: own groups, or any the role can manage.
List<Group> ringableGroups(AppUser me, List<Group> all) => all
    .where((g) => g.ownerUid == me.uid || GroupService.canManage(me, g))
    .toList();
