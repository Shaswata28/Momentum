# Momentum — Feature Overview

## Today (Dashboard)
- Personalized greeting with your name and avatar
- Progress pill showing tasks completed vs total for the day
- Wallet summary card with quick income/expense logging
- Monthly Focus section — horizontally scrollable goal and habit chips
- Task list grouped by time blocks (morning, afternoon, etc.)
- Completed tasks collapsible toggle
- Quick Add button for ad-hoc tasks

## Monthly Focus & Habit Tracker
- Add goals or habits via a clean, distraction-free entry screen
- Toggle between Goal and Habit type
- Daily 9 AM reminder notification for each item
- Long-press a chip on the dashboard to delete it
- Data persists locally via Hive

## Wallet
- Running monthly balance with opening balance carry-forward
- Log income (with source: tuition / freelance / other)
- Log expenses (with type: fixed / variable / borrowed / lent)
- Monthly budget bar showing spend vs limit
- Semester savings goal tracker with progress bar
- Full transaction history for the current month

## Insights
- Segmented toggle between Routine and Wallet views

**Routine view**
- Health score ring showing your weekly average score and letter grade
- Energy bar chart (Mon–Sun) based on EOD logs
- 35-day consistency heatmap with score-based color intensity

**Wallet view**
- Income vs Spend bar chart for the current month
- Semester savings goal progress
- Budget discipline indicator showing how many days you stuck to your budget

## EOD Log
- Triggered via Close Day button (visible after 9 PM if no log exists today)
- Logs: task summary, energy level (1–10), motivation level, budget adherence, optional notes
- Calculates a health score and letter grade (A–F)
- Read-only summary shown if today is already logged

## Routine Builder
- 7-column weekly planner (Mon–Sun)
- Add, edit, and delete routine tasks per day
- Task types: Fixed (exact time), Floating (flex window), Adhoc (one-off)
- Per-task options: duration, buffer time, DND toggle, color label

## Profile & Settings
- Set your name and choose an avatar
- Edit your weekly routine
- Configure EOD reminder time
- Wipe all app data (with confirmation)

## Background & System
- Local notifications: task reminders, EOD prompt, monthly focus reminders
- Auto Do Not Disturb during tasks with DND enabled
- Android home screen widget showing live task progress with mark-done/skip actions
- Automatic month rollover carrying wallet balance forward
