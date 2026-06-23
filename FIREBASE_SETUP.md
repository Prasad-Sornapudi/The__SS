# Firebase Configuration Setup Guide

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select existing project
3. Enter project name: `SkillSync` (or your preferred name)
4. Enable Google Analytics (optional)
5. Click "Create project"

## Step 2: Add Android App

1. In Firebase console, click "Add app" → Android icon
2. **Android package name**: `com.techwing.skill_sync` (check `android/app/build.gradle.kts` for exact package)
3. **App nickname**: Skill Sync Android
4. Click "Register app"
5. **Download `google-services.json`**
6. Place it in: `android/app/google-services.json`

## Step 3: Add iOS App (if needed)

1. In Firebase console, click "Add app" → iOS icon
2. **iOS bundle ID**: Check `ios/Runner.xcodeproj` for bundle ID
3. **App nickname**: Skill Sync iOS
4. Click "Register app"
5. **Download `GoogleService-Info.plist`**
6. Place it in: `ios/Runner/GoogleService-Info.plist`

## Step 4: Enable Realtime Database

1. In Firebase console, go to "Realtime Database"
2. Click "Create Database"
3. **Location**: Select closest region (e.g., asia-southeast1)
4. **Security rules**: Start in **locked mode** (we'll update rules next)
5. Click "Enable"

## Step 5: Configure Database Rules

Go to "Realtime Database" → "Rules" tab and paste:

```json
{
  "rules": {
    "attendance": {
      "$classId": {
        "$date": {
          "$session": {
            ".read": true,
            ".write": true
          }
        }
      }
    },
    "classes": {
      "$classId": {
        ".read": true,
        ".write": true
      }
    }
  }
}
```

Click "Publish" to save.

> **Note**: These rules allow public read/write. For production, implement authentication.

## Step 6: Get Database URL

1. In "Realtime Database" tab, copy the database URL
2. It looks like: `https://skillsync-xxxxx-default-rtdb.firebaseio.com/`
3. You'll need this for Flutter configuration

## Step 7: Configure Flutter App

The `firebase_options.dart` file will be auto-generated using FlutterFire CLI:

### Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### Generate Firebase Options

```bash
flutterfire configure
```

Follow the prompts:
- Select your Firebase project
- Select platforms (Android, iOS, Web)
- This will create `lib/firebase_options.dart`

## Step 8: Verify Setup

After placing the config files and running `flutterfire configure`:

1. ✅ `android/app/google-services.json` exists
2. ✅ `ios/Runner/GoogleService-Info.plist` exists (if iOS)
3. ✅ `lib/firebase_options.dart` created
4. ✅ Firebase Realtime Database enabled
5. ✅ Database rules configured

## Next Steps

Once setup is complete, the app will:
- ✅ Initialize Firebase on startup
- ✅ Write attendance to Firebase immediately when QR scanned (online)
- ✅ Save to Hive for offline scenarios
- ✅ Real-time sync across all devices
- ✅ Session-end backup to Google Sheets

---

**Questions or issues?** Let me know and I'll help troubleshoot!
