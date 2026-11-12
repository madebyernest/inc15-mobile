# CSC 4360 Inclass 15

A Flutter app that fetches five easy multiple choice questions from the Open Trivia Database and lets players complete a scored round

## Setup and Run

```bash
flutter pub get
flutter run
```

All app code is in `lib/main.dart`. The `http` package is already included in `pubspec.yaml`.

## Features

- Fetches five questions using a GET request with a 10-second timeout.
- Checks HTTP status, API response code, and question data.
- Shows loading and error screens with a Retry button.
- Decodes HTML entities and shuffles answer choices.
- Provides answer feedback using green and red highlights.
- Tracks score, question number, and progress.
- Includes Next, Finish, and Play Again buttons.
- Displays the final score out of five.

## Score Sync

The **Sync Score to Leaderboard** button simulates a submission. It waits one second, creates a JSON payload with the score, prints it to the debug console, and displays a confirmation.

No actual HTTP request is sent or data stored online because no backend endpoint was provided. A real version would use POST and check the server response.

## Evidence

| # | Description | Screenshot |
|---|---|---|
| 1 | Loading spinner | [Loading](screenshots/1.png) |
| 2 | First question and answer choices | [Question](screenshots/2.png) |
| 3 | Correct/incorrect answer feedback | [Feedback](screenshots/3.png) |
| 4 | Final score and available actions | [Final Score](screenshots/4.png) |
| 5 | Network error and Retry button | [Error](screenshots/5.png) |
| 6 | Score sync simulation | [Sync Simulation](screenshots/6.png) |

**Limitations:** Entity decoding was implemented but not visibly demonstrated in the screenshots. Score syncing was only simulated

## Critical Thinking

**1. What happens if the internet disconnects after the questions load?**

The player can finish the round because all five questions are already stored in `_questions`. Answering and scoring do not require internet access. However, replaying requires a new API request, and syncing would require a connection. Both should display an error if the connection is unavailable.

**2. What information would be useful to save locally?**

I would save the player's highest score so it remains available after closing the app. However, local scores would only be visible on that device. A shared leaderboard would require a backend to store and retrieve scores from multiple players.

I did not implement local storage.