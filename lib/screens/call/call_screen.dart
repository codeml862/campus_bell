import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/cb.dart';
import '../../widgets/common.dart';
import '../../widgets/ios.dart';
import 'sending_screen.dart';

/// Compose and send:
/// - a bell to one person below you (loud ring),
/// - a bell to a [group] (everyone rings; first to accept goes), or
/// - with [request], a quiet "request to meet" to someone above you.
class CallScreen extends StatefulWidget {
  final AppUser me;
  final AppUser? to;
  final Group? group;
  final bool request;
  final bool focusMessage;
  const CallScreen({
    super.key,
    required this.me,
    this.to,
    this.group,
    this.request = false,
    this.focusMessage = false,
  }) : assert(to != null || group != null);
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final String _title = widget.group?.name ?? widget.to!.name;
  late final String _first = widget.group != null
      ? 'Team'
      : shortName(widget.to!.name);
  late final _msg = TextEditingController(
    text: widget.request
        ? 'Sir/Madam, may I come to meet you?'
        : widget.group != null
        ? 'One of you, please come to the ${widget.me.role} office.'
        : '$_first, please come to the ${widget.me.role} office.',
  );
  final _focus = FocusNode();
  late final List<String> _quick = widget.request
      ? const [
          'May I come to meet you?',
          'I need help with an assignment',
          'Can I collect my documents?',
          'I need your signature',
          'Can we meet today?',
        ]
      : const [
          'Please come to my office',
          'Come immediately',
          'Meeting in 5 minutes',
          'Bring the files',
          'Call me back',
        ];
  String _fill(String q) => widget.request ? q : '$_first, ${q.toLowerCase()}.';

  static IconData _quickIcon(String q) {
    final t = q.toLowerCase();
    if (t.contains('immediately') || t.contains('urgent')) {
      return CupertinoIcons.bolt_fill;
    }
    if (t.contains('meeting') || t.contains('meet')) {
      return CupertinoIcons.person_2_fill;
    }
    if (t.contains('file') || t.contains('document')) {
      return CupertinoIcons.doc_text_fill;
    }
    if (t.contains('call')) return CupertinoIcons.phone_fill;
    if (t.contains('signature')) return CupertinoIcons.pencil;
    if (t.contains('assignment') || t.contains('help')) {
      return CupertinoIcons.book_fill;
    }
    return CupertinoIcons.building_2_fill;
  }

  int _priority = 0;
  bool _persistent = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = widget.group != null
          ? await BellService.createGroup(
              me: widget.me,
              group: widget.group!,
              message: _msg.text.trim(),
              priority: Priority.all[_priority],
              persistent: _persistent,
            )
          : await BellService.create(
              me: widget.me,
              to: widget.to!,
              message: _msg.text.trim(),
              priority: Priority.all[_priority],
              persistent: _persistent,
              request: widget.request,
            );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        iosRoute(SendingScreen(requestId: id, recipientName: _title)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final to = widget.to;
    final group = widget.group;
    final request = widget.request;
    final typing = _focus.hasFocus;
    return Scaffold(
      backgroundColor: Cb.page,
      body: SafeArea(
        child: Responsive(
          maxWidth: 520,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    CbHeader(
                      request
                          ? 'Request to meet'
                          : group != null
                          ? 'Ring group'
                          : 'Ring',
                    ),
                    if (group != null)
                      CbBlueCard(
                        name: group.name,
                        line2: 'Everyone rings · first to accept goes',
                        pill:
                            '${group.memberUids.length} member${group.memberUids.length == 1 ? '' : 's'}',
                      )
                    else
                      CbBlueCard(
                        name: to!.name,
                        line2: to.email,
                        pill: '${to.roleLabel} · ${deptShort(to.department)}',
                      ),
                    if (request)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(6, 12, 6, 0),
                        child: Text(
                          'They get a quiet notification. If they are free they '
                          'accept and you are told to come; if not, they decline '
                          'with a reason.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Cb.sub,
                          ),
                        ),
                      ),
                    const CbSection('Quick message'),
                    LayoutBuilder(
                      builder: (_, box) {
                        final w = (box.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final q in _quick)
                              _QuickTile(
                                width: w,
                                text: q,
                                icon: _quickIcon(q),
                                selected: _msg.text == _fill(q),
                                onTap: () =>
                                    setState(() => _msg.text = _fill(q)),
                              ),
                          ],
                        );
                      },
                    ),
                    const CbSection('Message'),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: typing ? AppColors.accent : Cb.line,
                          width: typing ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CupertinoTextField.borderless(
                            controller: _msg,
                            focusNode: _focus,
                            autofocus: widget.focusMessage,
                            maxLength: 200,
                            minLines: 4,
                            // Keep the box (and the Ring button below it)
                            // clear of the keyboard while typing.
                            scrollPadding: const EdgeInsets.fromLTRB(
                              20,
                              20,
                              20,
                              170,
                            ),
                            maxLines: 8,
                            padding: EdgeInsets.zero,
                            placeholder: 'Type your message',
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: Cb.ink,
                            ),
                            cursorColor: AppColors.accent,
                            onChanged: (_) => setState(() {}),
                          ),
                          Text(
                            '${_msg.text.length}/200',
                            style: const TextStyle(fontSize: 12, color: Cb.sub),
                          ),
                        ],
                      ),
                    ),
                    if (!request) ...[
                      const CbSection('Priority'),
                      Row(
                        children: [
                          for (final (i, label) in [
                            (0, 'Normal'),
                            (1, 'High'),
                            (2, 'Urgent'),
                          ]) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _priority = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _priority == i
                                        ? AppColors.accent
                                        : Cb.tile,
                                    borderRadius: BorderRadius.circular(21),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _priority == i
                                          ? Colors.white
                                          : AppColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      CbCard(
                        children: [
                          CbItem(
                            icon: CupertinoIcons.repeat,
                            title: 'Keep ringing',
                            subtitle: 'Rings up to 1 minute until they stop it',
                            trailing: CupertinoSwitch(
                              value: _persistent,
                              activeTrackColor: AppColors.accent,
                              onChanged: (v) => setState(() => _persistent = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, left: 4),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFE5484D),
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Full-width Ring button, always visible.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: AppColors.accent,
                    disabledColor: AppColors.accent.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(27),
                    onPressed: _busy ? null : _send,
                    child: _busy
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                request
                                    ? CupertinoIcons.hand_raised_fill
                                    : CupertinoIcons.bell_fill,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                request
                                    ? 'Send request'
                                    : group != null
                                    ? 'Ring group'
                                    : 'Ring $_first',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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

/// A big, easy-to-tap quick message (two per row).
class _QuickTile extends StatelessWidget {
  final double width;
  final String text;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _QuickTile({
    required this.width,
    required this.text,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppColors.accent : Cb.line),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: selected ? Colors.white.withValues(alpha: .18) : Cb.tile,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Cb.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
