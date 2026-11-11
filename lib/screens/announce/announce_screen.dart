import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import '../../widgets/ios.dart';
import '../home/home_screen.dart';

/// HOD / administrator: write a notice, then see who has read past ones.
class AnnounceScreen extends StatefulWidget {
  final AppUser me;
  const AnnounceScreen({super.key, required this.me});
  @override
  State<AnnounceScreen> createState() => _AnnounceScreenState();
}

class _AnnounceScreenState extends State<AnnounceScreen> {
  static const _maxTitle = 80, _maxMsg = 500;
  final _title = TextEditingController();
  final _msg = TextEditingController();
  late String _dept = widget.me.isAdmin ? '' : widget.me.department;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _msg.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _msg.dispose();
    super.dispose();
  }

  bool get _ready =>
      _title.text.trim().isNotEmpty && _msg.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_ready) {
      return showSnack(context, 'Add a title and a message first.');
    }
    setState(() => _busy = true);
    try {
      await AnnouncementService.post(
        me: widget.me,
        title: _title.text,
        message: _msg.text,
        department: _dept,
      );
      _title.clear();
      _msg.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        showSnack(context, 'Notice sent.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not send: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Announcement a) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('Delete this notice?'),
        content: Text('"${a.title}" will be removed for everyone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AnnouncementService.delete(a.id);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not delete: $e');
    }
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: HomeColors.sub,
        letterSpacing: .2,
      ),
    ),
  );

  Widget _box(Widget child, {EdgeInsets? padding}) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Widget _audience() {
    final me = widget.me;
    if (!me.isAdmin) {
      return Wrap(
        children: [
          _AudienceChip(
            label: deptShort(me.department),
            selected: true,
            icon: CupertinoIcons.lock_fill,
          ),
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _AudienceChip(
            label: 'Everyone',
            selected: _dept.isEmpty,
            onTap: () => setState(() => _dept = ''),
          ),
          for (final d in departments)
            _AudienceChip(
              label: deptShort(d),
              selected: _dept == d,
              onTap: () => setState(() => _dept = d),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final top = MediaQuery.paddingOf(context).top;
    final who = _dept.isEmpty
        ? 'everyone in the college'
        : 'everyone in $_dept';
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: Responsive(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, 32),
          children: [
            Row(
              children: [
                _RoundButton(
                  icon: CupertinoIcons.chevron_back,
                  onTap: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New notice',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: HomeColors.ink,
                        ),
                      ),
                      Text(
                        'Shows on Home for the people you pick',
                        style: TextStyle(fontSize: 13.5, color: HomeColors.sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _label('SEND TO'),
            _audience(),
            const SizedBox(height: 20),
            _label('NOTICE'),
            _box(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _title,
                    maxLength: _maxTitle,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    cursorColor: HomeColors.blue,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.ink,
                    ),
                    decoration: plainInput(
                      'Title, e.g. Lab exam moved to Friday',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: HomeColors.line),
                  ),
                  TextField(
                    controller: _msg,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: _maxMsg,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: HomeColors.blue,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: HomeColors.ink,
                    ),
                    decoration: plainInput(
                      'Write the details, e.g. Bring record books to Lab 2 at 10 AM.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_msg.text.length}/$_maxMsg',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HomeColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  CupertinoIcons.info_circle,
                  size: 15,
                  color: HomeColors.sub,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Goes to $who.',
                    style: const TextStyle(fontSize: 13, color: HomeColors.sub),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: HomeColors.blue,
                disabledColor: HomeColors.blue.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(16),
                onPressed: _busy || !_ready ? null : _send,
                child: _busy
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.paperplane_fill,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Send notice',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            StreamBuilder<List<Announcement>>(
              stream: AnnouncementService.sentBy(me.uid),
              builder: (_, snap) {
                final list = snap.data ?? const <Announcement>[];
                if (list.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('SENT'),
                      for (final a in list) ...[
                        _SentCard(
                          notice: a,
                          onOpen: () => showCupertinoModalPopup(
                            context: context,
                            builder: (_) => NoticeSheet(notice: a),
                          ),
                          onDelete: () => _delete(a),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});
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
      child: Icon(icon, color: HomeColors.ink, size: 20),
    ),
  );
}

class _AudienceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;
  const _AudienceChip({
    required this.label,
    required this.selected,
    this.icon,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? HomeColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : HomeColors.sub,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : HomeColors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A sent notice with a "seen" progress bar.
class _SentCard extends StatelessWidget {
  final Announcement notice;
  final VoidCallback onOpen, onDelete;
  const _SentCard({
    required this.notice,
    required this.onOpen,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final a = notice;
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${a.forEveryone ? 'Everyone' : deptShort(a.department)} · ${timeAgo(a.createdAt)}',
                    style: const TextStyle(fontSize: 13, color: HomeColors.sub),
                  ),
                  const SizedBox(height: 10),
                  _SeenBar(notice: a),
                ],
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              minimumSize: Size.zero,
              onPressed: onDelete,
              child: const Icon(
                CupertinoIcons.trash,
                size: 19,
                color: HomeColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeenBar extends StatelessWidget {
  final Announcement notice;
  const _SeenBar({required this.notice});
  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: audienceOf(notice.department),
    builder: (_, snap) {
      final seen = notice.seenBy.length;
      final total = snap.data ?? 0;
      final f = total == 0 ? 0.0 : (seen / total).clamp(0.0, 1.0);
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: f,
                minHeight: 6,
                backgroundColor: HomeColors.blueBg,
                valueColor: const AlwaysStoppedAnimation(HomeColors.blue),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            snap.hasData ? '$seen of $total seen' : '$seen seen',
            style: const TextStyle(fontSize: 12.5, color: HomeColors.sub),
          ),
        ],
      );
    },
  );
}

final _audienceCache = <String, Future<int>>{};

/// Cached size of a notice's audience.
Future<int> audienceOf(String department) => _audienceCache.putIfAbsent(
  department,
  () => AnnouncementService.audience(department),
);

/// Everyone else: notices for my department and for everyone.
class NoticesScreen extends StatelessWidget {
  final AppUser me;
  const NoticesScreen({super.key, required this.me});
  @override
  Widget build(BuildContext context) => IosPage(
    title: 'Notices',
    backLabel: 'Home',
    body: StreamBuilder<List<Announcement>>(
      stream: AnnouncementService.forMe(me),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No notices yet.',
              style: TextStyle(color: IosColors.secondary, fontSize: 16),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            IosSection(
              indent: 16,
              children: [
                for (final a in list)
                  IosRow(
                    title: a.title,
                    titleColor: a.seenBy.contains(me.uid)
                        ? null
                        : HomeColors.blueText,
                    subtitle: '${a.senderName} · ${timeAgo(a.createdAt)}',
                    chevron: true,
                    onTap: () {
                      AnnouncementService.markSeen(a, me.uid);
                      showCupertinoModalPopup(
                        context: context,
                        builder: (_) => NoticeSheet(notice: a),
                      );
                    },
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

/// The full notice as a bottom sheet.
class NoticeSheet extends StatelessWidget {
  final Announcement notice;
  const NoticeSheet({super.key, required this.notice});
  @override
  Widget build(BuildContext context) {
    final a = notice;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        22,
        10,
        22,
        MediaQuery.paddingOf(context).bottom + 18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 18),
            Text(
              a.forEveryone ? 'For everyone' : deptShort(a.department),
              style: const TextStyle(fontSize: 13, color: HomeColors.blueText),
            ),
            const SizedBox(height: 4),
            Text(
              a.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${a.senderName} (${a.senderRole}) · ${timeAgo(a.createdAt)}',
              style: const TextStyle(fontSize: 13.5, color: HomeColors.sub),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .45,
              ),
              child: SingleChildScrollView(
                child: Text(
                  a.message,
                  style: const TextStyle(fontSize: 16, height: 1.45),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: HomeColors.soft,
                borderRadius: BorderRadius.circular(14),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "42/60" — how many of the audience have seen [notice].
class SeenBadge extends StatefulWidget {
  final Announcement notice;
  const SeenBadge({super.key, required this.notice});
  @override
  State<SeenBadge> createState() => _SeenBadgeState();
}

class _SeenBadgeState extends State<SeenBadge> {
  late final Future<int> _total = audienceOf(widget.notice.department);

  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: _total,
    builder: (_, snap) {
      final seen = widget.notice.seenBy.length;
      final text = snap.hasData ? '$seen/${snap.data}' : '$seen seen';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: HomeColors.blueBg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            color: HomeColors.blueText,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    },
  );
}
