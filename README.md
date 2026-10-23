# 🎵 BeatStream (Music App)

A modern, high-performance music streaming and discovery application built with **Flutter** and **Dart**. Featuring a sleek dark-themed UI, personalized song recommendations, social listening with friends, and high-fidelity audio playback.

---

### 📲 Download APK

Get the latest release directly on your Android device:

[![Download APK](https://img.shields.io/badge/Download-Android%20APK-4CAF50?style=for-the-badge&logo=android&logoColor=white)](https://drive.google.com/file/d/14PVmM_b2DHtECphe0M0p7HBtEqiRevvX/view?usp=sharing)

> **Direct Link:** [Download APK via Google Drive](https://drive.google.com/file/d/14PVmM_b2DHtECphe0M0p7HBtEqiRevvX/view?usp=sharing)

---

## ✨ Features

- **🎧 Seamless Audio Player**:
  - Persistent mini player and immersive full-screen audio player.
  - Smooth progress scrubbing, play, pause, skip, shuffle, and repeat controls powered by `just_audio`.
- **✨ Smart Recommendations & Feed**:
  - Dynamic home screen with curated feeds and personal taste profile insights.
- **🔍 Fast Search & Discovery**:
  - Instantly search through songs, artists, and albums.
- **❤️ Favorites & Liked Songs**:
  - Save and organize favorite tracks with instant offline-synced access.
- **👥 Social & Listening Rooms**:
  - View real-time friend activity, see what friends are streaming, and join shared listening sessions.
- **🔐 Secure Authentication**:
  - User sign-up and login with token persistence using `flutter_secure_storage`.
- **🎨 Premium Dark UI**:
  - Custom dark theme with vibrant gradients, fluid micro-animations, and responsive layouts.

---

## 🛠️ Tech Stack & Packages

- **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.12.2)
- **Language**: [Dart](https://dart.dev/)
- **Audio Engine**: [`just_audio`](https://pub.dev/packages/just_audio)
- **Networking**: [`http`](https://pub.dev/packages/http)
- **Security / Storage**: [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
- **Icons**: `cupertino_icons` & Material Icons

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.12.0 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio / VS Code with Flutter & Dart extensions
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

3. **Run the app:**
   ```bash
   flutter run
   ```

4. **Build APK for Release:**
   ```bash
   flutter build apk --release
   ```
   The release APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📦 Installing the APK on Android

1. Download the `.apk` file using the [Google Drive Link](https://drive.google.com/file/d/14PVmM_b2DHtECphe0M0p7HBtEqiRevvX/view?usp=sharing).
2. Open the downloaded file on your Android device.
3. If prompted, enable **"Install Unknown Apps"** from your browser/file manager settings.
4. Tap **Install** and launch the app!

---

## 📁 Project Structure

```text
lib/
├── core/
│   ├── models/            # Shared data models (recommendations, etc.)
│   ├── services/          # Audio player, favorites, recommendation services
│   └── theme/             # Color palette, dark theme definitions
├── features/
│   ├── auth/              # Sign in, Sign up, Token handling & AuthGate
│   ├── favorites/         # Liked songs & playlist screens
│   ├── home/              # Main dashboard, mini player, social cards
│   └── search/            # Search bar & search results
└── main.dart              # Application entry point & theme initialization
```

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
