import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

/// Simple counts from your own bells (last 100 sent / received).
class AnalyticsScreen extends StatelessWidget {
  final AppUser me;
  const AnalyticsScreen({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Analytics',
      child: StreamBuilder<List<BellRequest>>(
        stream: BellService.sent(me.uid),
        builder: (_, s) => StreamBuilder<List<BellRequest>>(
          stream: BellService.received(me.uid),
          builder: (_, r) {
            if (!s.hasData || !r.hasData)
              return const Center(child: CircularProgressIndicator());
            final sent = s.data!, rec = r.data!;
            final delivered = sent
                .where((x) => x.status == BellStatus.delivered)
                .length;
            final failed = sent
                .where(
                  (x) =>
                      x.status == BellStatus.failed ||
                      x.status == BellStatus.rejected,
                )
                .length;
            final today = DateTime.now();
            bool isToday(BellRequest x) =>
                x.createdAt != null &&
                x.createdAt!.year == today.year &&
                x.createdAt!.month == today.month &&
                x.createdAt!.day == today.day;
            final stats = [
              (
                'Bells sent',
                '${sent.length}',
                CupertinoIcons.paperplane,
                AppColors.primary,
              ),
              (
                'Delivered',
                '$delivered',
                CupertinoIcons.checkmark_circle,
                AppColors.success,
              ),
              (
                'Not delivered',
                '$failed',
                CupertinoIcons.xmark_circle,
                AppColors.danger,
              ),
              (
                'Bells received',
                '${rec.length}',
                CupertinoIcons.tray_arrow_down,
                AppColors.warning,
              ),
              (
                'Sent today',
                '${sent.where(isToday).length}',
                CupertinoIcons.calendar_today,
                AppColors.primary,
              ),
              (
                'Received today',
                '${rec.where(isToday).length}',
                CupertinoIcons.bell,
                AppColors.primary,
              ),
            ];
            return LayoutBuilder(
              builder: (_, c) {
                final cols = c.maxWidth > 420 ? 3 : 2;
                return GridView.count(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    for (final (label, value, icon, color) in stats)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(icon, color: color, size: 28),
                            Text(
                              value,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              label,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
