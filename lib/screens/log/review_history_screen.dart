import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/review_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_back_button.dart';
import 'eod_log_screen.dart';

class ReviewHistoryScreen extends ConsumerWidget {
  const ReviewHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 64,
        leading: const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Center(child: AppBackButton()),
        ),
        title: Text(
          'Review History',
          style: AppTypography.displayHeading.copyWith(
            fontSize: AppColors.isRetro ? 15 : 22,
            letterSpacing: AppColors.isRetro ? 0.0 : -0.4,
          ),
        ),
      ),
      body: ref
          .watch(reviewHistoryProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(reviewHistoryProvider),
                child: const Text('Could not load reviews. Retry'),
              ),
            ),
            data: (logs) => logs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No reviews yet',
                            style: AppTypography.cardTitle,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Save a snapshot of today, with your reflection and task progress.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EODLogScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.rate_review_outlined),
                            label: const Text('Review Day'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Card(
                        child: ListTile(
                          title: Text(DateFormat.yMMMMd().format(log.date)),
                          subtitle: Text(
                            'Grade ${log.grade} | ${log.completedTasks} of ${log.totalTasks} completed',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EODLogScreen(savedLog: log),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
    );
  }
}
