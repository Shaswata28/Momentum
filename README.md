# Momentum

<p align="center">
  <img src="assets/images/app_icon_transparent.png" width="96" alt="Momentum app icon" />
</p>

> A personal daily routine, habit, and finance tracker for Android — built with Flutter.

Momentum helps you structure your day through scheduled task blocks, track your finances month by month, and reflect on your performance with end-of-day logging and weekly analytics.

---

## Features

### Today (Dashboard)
- Personalized greeting with time-aware salutation
- Live progress pill and animated health score
- Wallet summary card with inline income/expense logging
- Monthly Focus — scrolling goal and habit chip strip with daily reminders
- Task list grouped by time block (morning / afternoon / evening)
- Task cards with expand-to-act: mark done, skip, reschedule
- Completed tasks collapsible toggle
- Quick-add button for ad-hoc tasks

### Wallet
- Running monthly balance with opening balance carry-forward
- Log income (tuition / freelance / other) and expenses (fixed / variable / borrowed / lent)
- Monthly budget progress bar with over-budget warning
- Semester savings goal tracker
- Full transaction history for the current month

### Insights
- Weekly health score ring with animated arc and letter grade (A–F)
- Energy bar chart (Mon–Sun) from EOD logs
- 35-day consistency heatmap with score-based color intensity
- Income vs Spend bar chart
- Budget discipline indicator

### EOD Log
- Triggered via Close Day button after 9 PM
- Logs energy level, motivation, budget adherence, and free-text notes
- Calculates a health score from task completion weighted by type
- Read-only summary card shown if today is already logged

### Routine Builder
- 7-column weekly planner (Mon–Sun)
- Task types: Fixed (exact time), Floating (flex window), Adhoc (one-off)
- Per-task: duration, buffer time, DND toggle

### Background & System
- Scheduled notifications for task reminders and EOD prompt
- Auto Do Not Disturb during tasks with DND enabled
- Android home screen widget — shows current task, next task, and daily progress
- WorkManager periodic refresh so the widget stays live without opening the app
- Automatic month rollover carrying wallet balance forward

---

## Tech Stack

| Layer | Library |
|---|---|
| UI | Flutter + Material 3 |
| State | Riverpod |
| Storage | Hive (offline, no cloud) |
| Notifications | flutter_local_notifications + timezone |
| Home Widget | home_widget + WorkManager |
| Charts | fl_chart |
| Fonts | Google Fonts (DM Sans + JetBrains Mono) |

---

## Getting Started

### Prerequisites

- Flutter SDK (stable channel, 3.x)
- Android Studio or VS Code with Flutter/Dart extensions
- Android device or emulator (API 21+)

### Setup

```bash
# Install dependencies
flutter pub get

# Generate Hive type adapters
dart run build_runner build --delete-conflicting-outputs

# Run in debug mode
flutter run

# Build release APK
flutter build apk --release
```

---

## Project Structure

```
lib/
├── constants/       # Avatar icon list
├── models/          # Hive data models + generated adapters
├── providers/       # Riverpod state providers
├── repositories/    # Hive box access layer
├── screens/         # All app screens
│   ├── dashboard/   # Today tab
│   ├── wallet/      # Wallet tab
│   ├── insights/    # Insights tab
│   ├── log/         # EOD log screen
│   ├── profile/     # Profile & settings
│   ├── routine/     # Routine builder
│   └── onboarding/  # First-launch flow
├── services/        # Notifications, DND, widget sync, health score
├── theme/           # AppColors, AppTypography
└── widgets/         # Shared UI components

android/
└── app/src/main/kotlin/
    └── com/example/daily_tracker/
        ├── MainActivity.kt
        ├── DailyTrackerWidgetProvider.kt  # RemoteViews widget
        ├── WidgetRefreshWorker.kt         # WorkManager periodic refresh
        └── BootReceiver.kt                # Re-schedules worker on boot

packages/
└── flutter_dnd/     # Local plugin for Do Not Disturb control
```

---

## Data Storage

All data is stored locally on-device using Hive. No account, no cloud sync.

| Box | Contents |
|---|---|
| `routineTasks` | Weekly routine task templates |
| `dailyTaskInstances` | Per-day task instances |
| `eodLogs` | End-of-day performance logs |
| `transactions` | Wallet income and expense records |
| `monthSummaries` | Monthly financial rollup |
| `walletSettings` | Budget limit and semester savings goal |
| `userSettings` | Name, avatar, first-launch flag |
| `simple_goals` | Monthly focus goals and habits |

---

## License

[MIT](LICENSE) © 2026 Shaswata Das
