# 🎵 BeatStream (Music App)

A modern, responsive music streaming application built with **Flutter** and **Dart**. Designed with a sleek dark aesthetic, seamless audio playback controls, personalized recommendation feeds, and social listening features.

---

### 📲 Download Latest APK

Install and test the release build on your Android device:

[![Download APK](https://img.shields.io/badge/Download-Android%20APK-4CAF50?style=for-the-badge&logo=android&logoColor=white)](https://drive.google.com/file/d/14PVmM_b2DHtECphe0M0p7HBtEqiRevvX/view?usp=sharing)

> **Direct Link:** [Download APK via Google Drive](https://drive.google.com/file/d/14PVmM_b2DHtECphe0M0p7HBtEqiRevvX/view?usp=sharing)

---

## ⚡ Current Working Features

### 🎧 Audio Playback & Player
- **Core Player Engine**: High-fidelity online audio playback powered by `just_audio`.
- **Persistent Mini-Player**: Bottom-docked mini player with play/pause and track details while navigating other pages.
- **Full Player Screen**: Immersive player interface with track scrubber/slider, current/total duration timestamps, play, pause, next, and previous track controls.

### 🔐 Authentication & Session Management
- **User Registration & Login**: Email and password authentication.
- **Secure Token Storage**: Encrypted token persistence using `flutter_secure_storage`.
- **Auth Gate**: Auto-login on app launch when a valid session token exists.

### 🏠 Dynamic Home & Discovery
- **Personalized Feed**: Curated home sections with intelligent song recommendations.
- **Taste Profile**: Visual taste profile indicators reflecting listening preferences.
- **Pull-to-Refresh**: Refresh recommendations with smooth spin animations.

### 🔍 Search & Exploration
- **Real-Time Track Search**: Search music by song title or artist.
- **Instant Results**: Fast browsing with tap-to-play functionality.

### ❤️ Favorites & Library
- **Liked Songs**: Save favorite songs with a single heart tap.
- **Dedicated Favorites Page**: View and play your entire collection of liked tracks.

### 👥 Social & Activity UI
- **Friend Activity Feed**: Visual indicators displaying what friends are currently listening to and their online status.
- **Quick Action Bar**: Fast shortcuts for listening rooms and social features.

---

## 🔮 Upcoming Features (Roadmap)

- [ ] **📥 Offline Song Downloads**: Download tracks locally to enjoy uninterrupted music without internet connectivity.
- [ ] **📜 Synchronized Real-Time Lyrics**: Karaoke-style live scrolling lyrics synchronized with track playback.
- [ ] **🎚️ Built-in Audio Equalizer**: Customizable presets (Bass Boost, Pop, Rock, Classical) and frequency band controls.
- [ ] **👥 Real-Time Collaborative Listening**: Live synchronized group listening rooms using WebSockets.
- [ ] **📁 Custom Playlists & Folders**: Create, rename, reorder, and share custom user-generated playlists.
- [ ] **⏰ Sleep Timer**: Auto-pause audio playback after a set duration.
- [ ] **🎨 Dynamic Theming**: Real-time theme palette adapting to the current track's album artwork colors.
- [ ] **🔔 Lock Screen & Notification Controls**: Background notification controls with media art and seeking actions.

---

## 🛠️ Tech Stack & Packages

- **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.12.2)
- **Language**: [Dart](https://dart.dev/)
- **Audio Engine**: [`just_audio`](https://pub.dev/packages/just_audio)
- **Networking**: [`http`](https://pub.dev/packages/http)
- **Secure Storage**: [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
- **Icons**: `cupertino_icons` & Material Design Icons

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.12.0 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio or VS Code with Flutter extension
- Android device or emulator (Android 7.0+ recommended)

### Local Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/music-app.git
   cd "music app/client"
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run in development mode:**
   ```bash
   flutter run
   ```

4. **Build a release APK:**
   ```bash
   flutter build apk --release
   ```
   The generated APK will be located at:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 📦 How to Install APK on Android

1. Download the file from the [Google Drive Download Link](https://drive.google.com/file/d/14PVmM_b2DHtECphe0M0p7HBtEqiRevvX/view?usp=sharing).
2. Open the downloaded `.apk` file from your device notifications or Downloads folder.
3. If prompted by Android, grant **"Allow from this source"** in your browser/file manager settings.
4. Tap **Install** and open the app.

---

## 📁 Project Architecture

```text
lib/
├── core/
│   ├── models/            # Shared data contracts (recommendations, etc.)
│   ├── services/          # Audio playback, favorites, recommendation logic
│   └── theme/             # Color palette, dark theme styles
├── features/
│   ├── auth/              # Sign in, Sign up, Session tokens & AuthGate
│   ├── favorites/         # Liked songs & favorites UI
│   ├── home/              # Main dashboard, mini-player, social widgets
│   └── search/            # Search bar & song query results
└── main.dart              # App initialization & root widget
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
