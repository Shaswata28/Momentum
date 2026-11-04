<p align="center">
  <img src="assets/images/app_icon_transparent.png" width="96" alt="Momentum app icon" />
</p>

<h1 align="center">Momentum</h1>

<p align="center">
  A personal daily routine, habit, and finance tracker for Android.
</p>

<p align="center">
  <a href="#-download">
    <img src="https://img.shields.io/badge/Download-APK-brightgreen?style=for-the-badge&logo=android" alt="Download APK" />
  </a>
  &nbsp;
  <img src="https://img.shields.io/badge/Version-1.2.0-blue?style=for-the-badge" alt="Version 1.2.0" />
  &nbsp;
  <img src="https://img.shields.io/badge/Platform-Android-blue?style=for-the-badge&logo=android" alt="Android" />
  &nbsp;
  <img src="https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter" alt="Flutter" />
  &nbsp;
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="MIT License" />
</p>

---

Momentum helps you structure your day through scheduled task blocks, track your finances month by month, and reflect on your performance with end-of-day logging and weekly analytics — all stored privately on your device.

---

## 📸 Screenshots

<p align="center">
  <img src="screenshots/Dashboard.png" width="19%" />
  <img src="screenshots/Wallet.png" width="19%" />
  <img src="screenshots/Wallet2.png" width="19%" />
  <img src="screenshots/Routine Builder.png" width="19%" />
  <img src="screenshots/Routine Builder2.png" width="19%" />
</p>

---

## 🚀 What's New in v1.2.0

- 🌓 **Full Light Theme Mode**: Things 3 & Apple-inspired minimalist light aesthetic with pure white cards (`#FFFFFF`), Apple System Grouped Gray background (`#F2F2F7`), crisp Slate typography, accessible Focus Blue accent (`#2563EB`), and a 3-way segmented toggle (**System**, **Dark**, **Light**) in Profile settings.
- 🛡️ **Focus Shield (App Blocker)**: Automatically prevents distractions during active Do Not Disturb tasks. Features a calming Mindful Friction overlay screen and 3 emergency passes per day.
- 🗓️ **Friday & Saturday Weekend Logic**: Workday schedule shifted to Sunday through Thursday, recognizing Friday and Saturday as weekends for academic and regional calendars.
- 🧙‍♂️ **Step-by-Step Task Wizard**: Interactive routine creation with smart suggestions, duration presets, custom DND, and buffer time configuration.
- 🎨 **UI & Typography Polish**: Overhauled spacing, card borders, and responsive layouts across Today, Wallet, Insights, Routine, and Profile screens.

---

## ✨ Features

### 🌓 Appearance & Themes
- Seamless 3-way theme selection: **System**, **Dark**, and **Light**
- Dynamic token adaptation: cards, elevated surfaces, borders, and typography instantly switch
- Things 3 / Apple minimalist design language with 6% subtle borders and high-contrast semantic indicators

### 🗓️ Today (Dashboard)
- Personalized greeting with time-aware salutation
- Live progress pill and animated health score
- Wallet summary card with inline income/expense logging
- Friday & Saturday weekend recognition (Sunday–Thursday workweek)
- Task list grouped by time block (Morning · Afternoon · Evening)
- Task cards with expand-to-act: mark done, skip, or reschedule
- Collapsible completed tasks and quick-add for ad-hoc tasks

### 🛡️ Focus Shield (Distraction Blocker)
- Native Android accessibility service monitoring foreground app launches
- Blocks distracting apps during active DND tasks
- Mindful Friction screen with breath-pacing pause and return-to-task shortcut
- 3 daily emergency passes for essential interruptions
- Granular app selection organized by category (Social, Games, Media, Messages)

### 💰 Wallet
- Running monthly balance with opening balance carry-forward
- Log income (tuition / freelance / other) and expenses (fixed / variable / borrowed / lent)
- Monthly budget progress bar with over-budget warning
- Semester savings goal tracker
- Full transaction history for the current month

### 📊 Insights
- Weekly health score ring with animated arc and letter grade (A–F)
- Energy bar chart (Sun–Sat) from end-of-day logs
- 35-day consistency heatmap with score-based color intensity
- Income vs. Spend bar chart
- Budget discipline indicator and spending pace metrics

### 🌙 End-of-Day Log
- Triggered via the **Close Day** button after 9 PM
- Logs energy level, motivation, budget adherence, and free-text notes
- Calculates a health score from task completion weighted by type
- Displays a read-only summary card if today is already logged

### 🔧 Routine Builder & Task Wizard
- 7-column weekly planner (Sun–Sat)
- Task types: **Fixed** (exact time), **Floating** (flex window), **Adhoc** (one-off)
- Interactive Task Wizard with presets and suggestion tags
- Per-task settings: duration, buffer time, Do Not Disturb toggle

### 🔔 Background & System
- Scheduled notifications for task reminders and EOD prompt
- Auto Do Not Disturb during tasks with DND enabled
- Android home screen widget — shows current task, next task, and daily progress
- WorkManager periodic refresh keeps the widget live without opening the app
- Automatic month rollover carrying wallet balance forward

---

## 📥 Download

> **The app is not yet on the Play Store.** You can download the latest APK directly from GitHub Releases.

1. Go to the [**Releases**](../../releases) page.
2. Download the latest `Momentum.apk` (v1.2.0).
3. On your Android device, allow installation from unknown sources if prompted (**Settings → Apps → Special app access → Install unknown apps**).
4. Open the downloaded APK and install.

Requires **Android 5.0 (API 21)** or higher.

---

## 🔒 Privacy

All your data stays **on your device**. Momentum uses no cloud sync, no account, and no internet connection. Everything is stored locally using [Hive](https://pub.dev/packages/hive).

---

## 🛠️ Developer Guide

Everything below is for contributors and developers who want to build or modify Momentum.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, 3.x)
- Android Studio or VS Code with the Flutter & Dart extensions
- Android device or emulator (API 21+)

### Getting Started

```bash
# 1. Clone the repo
git clone https://github.com/Shaswata28/Momentum.git
cd Momentum

# 2. Install dependencies
flutter pub get

# 3. Generate Hive type adapters
dart run build_runner build --delete-conflicting-outputs

# 4. Run in debug mode
flutter run

# 5. Build a release APK
flutter build apk --release
```

The release APK will be at `build/app/outputs/flutter-apk/app-release.apk` (or `Momentum.apk`).

### Tech Stack

| Layer | Library |
|---|---|
| UI | Flutter + Material 3 |
| State | Riverpod |
| Storage | Hive (offline, no cloud) |
| Notifications | flutter_local_notifications + timezone |
| Home Widget | home_widget + WorkManager |
| Charts | fl_chart |

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
