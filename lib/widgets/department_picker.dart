import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

IconData departmentIcon(String d) => switch (d) {
  'Computer Science & Engineering' => CupertinoIcons.desktopcomputer,
  'Information Technology' => CupertinoIcons.globe,
  'Electronics & Communication' => CupertinoIcons.antenna_radiowaves_left_right,
  'Electrical & Electronics' => CupertinoIcons.bolt_fill,
  'Mechanical Engineering' => CupertinoIcons.gear_alt_fill,
  'Civil Engineering' => CupertinoIcons.building_2_fill,
  'MBA' => CupertinoIcons.chart_bar_alt_fill,
  'Administration' => CupertinoIcons.briefcase_fill,
  _ => CupertinoIcons.square_grid_2x2_fill,
};

/// Bottom sheet to choose a department: search, icon, short code, tick.
/// With [allowAll], the first row is "All departments" (returns '').
Future<String?> pickDepartment(
  BuildContext context, {
  String? current,
  bool allowAll = false,
  String title = 'Department',
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) =>
      _DeptSheet(current: current, allowAll: allowAll, title: title),
);

class _DeptSheet extends StatefulWidget {
  final String? current;
  final bool allowAll;
  final String title;
  const _DeptSheet({
    required this.current,
    required this.allowAll,
    required this.title,
  });
  @override
  State<_DeptSheet> createState() => _DeptSheetState();
}

class _DeptSheetState extends State<_DeptSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final items = [
      if (widget.allowAll) '',
      ...departments.where(
        (d) =>
            q.isEmpty ||
            d.toLowerCase().contains(q) ||
            deptShort(d).toLowerCase().contains(q),
      ),
    ];
    final maxH = MediaQuery.sizeOf(context).height * .78;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.all(6),
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.pop(context),
                      child: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: Color(0xFFC9CCD6),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: CupertinoSearchTextField(
                  placeholder: 'Search department',
                  backgroundColor: const Color(0xFFF4F5F8),
                  borderRadius: BorderRadius.circular(14),
                  onChanged: (v) => setState(() => _q = v.trim()),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final d = items[i];
                    final sel = d == (widget.current ?? '\u0000');
                    final all = d.isEmpty;
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.accentLight : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sel
                                ? AppColors.accent
                                : const Color(0xFFECEEF3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.accent
                                    : AppColors.accentLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                all
                                    ? CupertinoIcons.square_stack_3d_up_fill
                                    : departmentIcon(d),
                                size: 19,
                                color: sel ? Colors.white : AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    all ? 'All departments' : d,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  if (!all && deptShort(d) != d)
                                    Text(
                                      deptShort(d),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (sel)
                              const Icon(
                                CupertinoIcons.checkmark_alt_circle_fill,
                                color: AppColors.accent,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
