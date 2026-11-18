# Privacy Policy for Momentum

**Effective Date:** November 2026  
**Application Version:** 2.0.0  
**Developer:** Shaswata ([https://github.com/Shaswata28](https://github.com/Shaswata28))

---

## 1. Overview & Core Philosophy
Momentum is an offline-first personal Life Operating System designed to help users organize routines, track daily finances, and build long-term focus. We believe your personal data belongs to you alone. Momentum is architected from the ground up to operate completely offline without collecting, transmitting, or monetizing personal information.

---

## 2. Information Collection and Storage

### Local-Only Storage (Hive)
- All user content—including weekly routines, task completions, expense and income transactions, wallet balances, notes, and profile settings—is stored exclusively on your local device storage using Hive.
- **No Cloud Servers:** Momentum operates zero backend servers, user account databases, or remote telemetry systems.
- **No Third-Party Analytics or Ads:** The application contains zero advertising frameworks (e.g. AdMob) and zero analytics SDKs (e.g. Firebase Analytics, Facebook Core).

---

## 3. Permissions & Device Capabilities

### Android AccessibilityService API (Focus Shield)
- **Feature:** Momentum includes an optional "Focus Shield" app-blocking utility to help you stay focused during active deep work sessions.
- **Usage:** When explicitly enabled by you, the Android `AccessibilityService` is used strictly to identify the foreground package name to determine if an app on your restricted list has been launched.
- **Privacy Guarantee:** The service **NEVER** reads, captures, stores, or transmits the contents of your screen, keystrokes, personal messages, banking credentials, or web browsing history. It only prompts the mindful friction screen.
- **User Control:** This feature is entirely optional and can be toggled on or off at any time under *Settings > Focus Shield*.

### Exact Alarms (`USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM`)
- Used solely to trigger timely local notifications for scheduled routine tasks, End-of-Day reviews, and recurring bill reminders.

### Notification Access & Policy (`ACCESS_NOTIFICATION_POLICY`)
- Used optionally to enable Do Not Disturb (DND) during active focus sessions to mute notifications and reduce digital distractions.

---

## 4. Data Retention, Backup, and Deletion
- Because your data is stored solely on your device, you have complete control over it.
- You can permanently purge all stored data at any time from *Settings > Data & Privacy > Wipe All Data*, or by clearing app data in Android System Settings.
- If you uninstall Momentum, all local databases are automatically deleted by the Android operating system.

---

## 5. Children's Privacy
Momentum does not address anyone under the age of 13 and does not knowingly collect personally identifiable information from children.

---

## 6. Contact Us
If you have any questions, feedback, or concerns regarding this Privacy Policy, please open an issue or reach out via GitHub:  
[https://github.com/Shaswata28](https://github.com/Shaswata28)
