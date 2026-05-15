# Momentum — Feature Documentation

> Momentum is a personal daily routine and finance tracker for Android. It helps you manage your day through structured task scheduling, financial tracking, and end-of-day performance logging.

---

## Navigation

The app uses a 3-tab bottom navigation bar:

| Tab | Icon | Description |
|-----|------|-------------|
| Today | Dashboard | Daily task list and wallet summary |
| Wallet | Wallet | Full financial management |
| Insights | Chart | Analytics, scores, and EOD logging |

---

## Tab 1 — Today (Dashboard)

The home screen. Shows everything you need to get through the day.

### Header
- Displays the current week and semester period (e.g. `WEEK 3 · SEMESTER`)
- Personalized greeting using your first name
- Progress pill showing tasks completed vs total
- Score pill (populated after EOD log)
- Tap the avatar icon (top-right) to open Profile & Settings

### Wallet Summary Card
An inline balance card embedded in the dashboard for quick access.
- Shows your current running wallet balance
- `+ In` button — inline form to log income (amount + note)
- `− Out` button — inline form to log an expense (amount + note)
- Animates open/closed without leaving the screen

### Task List
Tasks are grouped into time blocks (e.g. `NOW · MORNING BLOCK`).

Each **Task Card** shows:
- Color-coded dot by task type (fixed / floating / adhoc)
- Task title and scheduled time or flex window
- Type tag chip and DND tag (if enabled)
- Tap to expand — reveals duration, and action buttons:
  - `Mark done` — completes the task
  - `Skip` / `Log skipped` / `Tomorrow` — depending on task type
  - `Reschedule` — for fixed and adhoc tasks

Completed tasks are collapsed under a `COMPLETED — N tasks` toggle.

### Monthly Focus
A lightweight goal and habit tracker embedded above the task list.

- Displays active goals and habits as a horizontally scrollable chip list
- Tap the `+` chip to open the **Add Focus** screen and create a new item
- Long-press any chip to delete it (confirmation dialog shown)
- Each item triggers a daily 9 AM local notification to keep momentum going
- Items persist across sessions via the `simple_goals` Hive box

### Quick Add Button
A floating button at the bottom of the task list to add an ad-hoc task for today.

---

## Tab 2 — Wallet

Full financial management screen for the current month.

### Balance Card
- Large display of current running balance
- Shows opening balance carried from the previous month
- Three stat columns: **Income**, **Spent**, **Saved**

### Action Buttons
- `Add income` — opens a bottom sheet to log income with amount, source (tuition / freelance / other), and note
- `Add expense` — opens a bottom sheet to log an expense with amount, type (fixed / variable / borrowed / lent), and note

### Budget Bar
A visual progress bar showing how much of your monthly budget you've spent. Turns warning color as you approach the limit.

### Savings Goal Card
Tracks progress toward your semester savings goal. Shows amount saved vs goal with a percentage progress bar. Set the goal in Profile settings.

### Transaction History
Scrollable list of all transactions for the current month, ordered by date. Each row shows direction (income/expense), amount, note, and date.

---

## Tab 3 — Insights

Analytics and performance tracking. Uses a segmented toggle to switch between two views.

### Routine View

**Weekly Grade Card**
- Letter grade (A–F) based on average health score across logged days this week
- Shows how many of the 7 days have been logged

**Energy This Week**
- Bar chart showing your self-reported energy level (1–10) for each day of the current week
- Today's bar is highlighted in the accent color

**Consistency Map**
- 35-day heatmap grid showing daily log history
- Color intensity reflects health score:
  - Full color = score ≥ 75
  - Medium = score ≥ 50
  - Faint = score < 50
  - Empty = no log
- Tooltip on each cell shows the exact score

**Close Day FAB**
After 9 PM, if no EOD log exists for today, a `Close Day` button appears. Tapping it opens the EOD Log screen.

### Wallet View

**Income vs Spend Chart**
- Side-by-side bar chart comparing total income and total spending for the current month
- Tap bars for exact values
- Stat pills below show Income, Spent, and Net totals

**Semester Savings Goal**
- Progress bar showing how much you've saved toward your semester goal
- If no goal is set, prompts you to configure one in Profile

---

## Add Focus Screen

Accessed by tapping the `+` chip in the Monthly Focus section on the Dashboard.

A minimal, distraction-free entry form:
- Text field — "What is your focus?"
- Segmented toggle to choose between **Goal** and **Habit**
- **Save Focus** button — saves to Hive and schedules a daily 9 AM reminder notification

---

## EOD Log Screen

Accessed via the `Close Day` FAB in Insights (visible after 9 PM).

Captures your end-of-day reflection:
- Task summary (total / completed / skipped / rescheduled)
- Energy level (1–10 slider)
- Motivation note
- Budget adherence question (did you stick to your budget today?)
- Optional free-text note
- Calculates a **health score** and assigns a **grade** (A–F) based on task completion rate

Logs are stored permanently and feed into the Insights charts and consistency map.

---

## Profile & Settings

Accessed by tapping the avatar icon on the Dashboard.

### Identity
- Displays your avatar and name
- Tap name or edit icon to open the Edit Profile sheet:
  - Set your first name
  - Choose from 8 avatar icons

### Routine & Schedule
- `Edit Routine` — opens the Routine Builder

### App Settings
- `EOD Reminder Time` — opens a time picker to reschedule the daily EOD notification (default: 10:30 PM)

### Data Management
- `Wipe App Data` — permanently deletes all tasks, logs, wallet data, and settings. Requires confirmation. Returns to onboarding.

---

## Routine Builder

Accessed from Profile → Edit Routine.

A horizontal 7-column weekly planner (Mon–Sun).

- Each column shows tasks scheduled for that day, sorted by time
- Tap any task block to edit it
- Tap `+` at the bottom of a column to add a new task to that day
- Shows the currently active routine period label (e.g. `Spring Semester`)

### Task Editor (Bottom Sheet)
When adding or editing a task:
- Title
- Task type:
  - `Fixed` — exact scheduled time + duration
  - `Floating` — flex window (start → end) + duration
  - `Adhoc` — one-time task with optional time
- Days of week (multi-select)
- Duration in minutes
- Buffer time after task (adds a buffer block in the schedule)
- Enable DND toggle — auto-enables Do Not Disturb during the task window
- Color label (optional)

---

## Background Services

### Notifications
- Fixed tasks: reminder 10 minutes before start, and again at start time
- Floating tasks: notification when window opens, and 45-minute warning before window closes
- EOD prompt: daily notification at your configured time (default 10:30 PM)
- Monthly Focus items: daily 9 AM reminder for each saved goal or habit

### Do Not Disturb (DND)
Checks every 30 seconds. If a task with `enableDND: true` is currently in its scheduled window and not yet done, the app automatically enables system DND. Disables DND when the window ends.

### Android Home Widget
A home screen widget that shows:
- Current active task title and progress bar
- Next upcoming task and its time
- Overall daily progress (e.g. `3 / 8 done`)

Supports interactive buttons — mark done or skip a task directly from the widget without opening the app.

### Month Rollover
At the start of each new month, the wallet automatically carries the closing balance forward as the new opening balance and resets monthly income/expense tracking.

---

## Task Types

| Type | Scheduling | Use case |
|------|-----------|----------|
| Fixed | Exact time + duration | Classes, meetings, workouts |
| Floating | Flex window (start–end) | Tasks you can do anytime in a range |
| Adhoc | Optional time, one-off | Spontaneous tasks added during the day |

Buffer blocks are auto-inserted after tasks that have a buffer time configured. They appear as dimmed spacers in the task list and are excluded from scoring.

---

## Data & Storage

All data is stored locally on-device using Hive (no cloud sync).

| Store | Contents |
|-------|----------|
| `routineTasks` | Weekly routine task templates |
| `dailyTaskInstances` | Per-day task instances generated from templates |
| `eodLogs` | End-of-day performance logs |
| `transactions` | Wallet income and expense records |
| `monthSummaries` | Monthly financial rollup records |
| `walletSettings` | Monthly budget limit and semester savings goal |
| `userSettings` | Name, avatar, first-launch flag |
| `simple_goals` | Monthly focus goals and habits |
