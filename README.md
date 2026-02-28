# MayaShield

**Real-Time Anti-Voice Scam Detector | KitaHack 2026 | SDG 16**

MayaShield is an Android-primary Flutter app that automatically screens incoming phone calls from unsaved numbers, transcribes audio in real-time using Google Chirp 3 (Speech-to-Text V2), and analyzes the conversation with Gemini 2.5 Flash to detect Malaysian voice scam patterns -- **during the call**, not after, and alerts the user to take appropriate action immediately. Confirmed scam numbers are shared across all MayaShield users via a community Firestore database.

---

## Table of Contents

1. [Architecture](#architecture)
2. [API Setup and Configuration](#api-setup-and-configuration)
3. [Firebase Setup](#firebase-setup)
4. [Google Cloud Speech-to-Text V2 Setup](#google-cloud-speech-to-text-v2-setup)
5. [Firebase AI Logic (Gemini) Setup](#firebase-ai-logic-gemini-setup)
6. [Android Permissions Setup](#android-permissions-setup)
7. [Testing & Running the App (Demo Guide)](#testing--running-the-app-demo-guide)
8. [Firestore Security Rules](#firestore-security-rules)
9. [Known Limitations](#known-limitations)

---

## Architecture

Three layers of protection:

```text
Incoming Call
     |
     v
[1] Is number saved in contacts?
     YES -> Allow normally (no action)
     NO  -> Check community scam_numbers cache (local, <1ms)
                KNOWN SCAM -> Auto-reject + Show overlay alert
                UNKNOWN    -> Allow call + Start recording
                                |
                         Every 15 seconds:
                         Audio chunk -> Chirp 3 STT -> Append to transcript
                                                    -> Gemini 2.5 Flash (full context)
                                                          SCAM -> Show mid-call overlay
                                                                 + Auto-report to Firestore
                                                                 + Add to community DB
                                                                 + Prompt: End Call / Call PDRM
                                                          SAFE -> Continue listening
                         Call ends:
                              SCAM -> Show result screen, keep data
                              SAFE -> Delete all data, store nothing
```                              

---

## API Setup and Configuration

### Step 1: Base Configuration
Open `mayashield/lib/config/constants.dart` and replace the placeholder value for your GCP project ID:

```dart
static const String googleCloudProjectId = 'YOUR_GCP_PROJECT_ID';
```

---

## Firebase Setup

### Step 1: Create a Firebase project
1. Go to [https://console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** and follow the steps.
3. Enable **Google Analytics** (optional).

### Step 2: Enable Core Services
1. **Authentication**: In Firebase Console -> **Build** -> **Authentication**, enable **Anonymous** sign-in.
2. **Firestore**: In **Build** -> **Firestore Database**, create a database in **production mode** (Recommended Region: `asia-southeast1`). Apply the rules from Section 8.

### Step 3: Run FlutterFire CLI (Auto-Setup)
The FlutterFire CLI automatically registers your Android app, downloads the required configuration file (`google-services.json`), and links it to your project.

Run these commands in your terminal at the root of the project:
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This generates `lib/firebase_options.dart`. The app imports this file in `main.dart`.

---

## Google Cloud Speech-to-Text V2 Setup

**⚠️ IMPORTANT: STT V2 (Chirp) requires a Service Account. Standard API keys will return a 403 Forbidden error.**

### Step 1: Create a Service Account
1. Go to Google Cloud Console -> **IAM & Admin** -> **Service Accounts**.
2. Click **Create Service Account** (e.g., `chirp-audio-bot`).
3. Grant it the **Cloud Speech Administrator** role.
4. Click on the new service account -> **Keys** -> **Add Key** -> **Create New Key** -> **JSON**.

### Step 2: Inject the JSON Key
1. Rename the downloaded file (e.g., `service-account.json`) and place it inside your Flutter project at `mayashield/assets/service-account.json`.
2. Declare it in your `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/service-account.json
  ```
  
---

## Firebase AI Logic (Gemini) Setup

### Step 1: Enable Firebase AI Logic

1. In Firebase Console -> **Build** -> **AI Logic** (or **Vertex AI**) -> **Get started**.
2. Follow the setup wizard. This provisions the Vertex AI / Google AI backend.

### Step 2: No additional API keys needed

The `firebase_ai` package authenticates through Firebase using your `google-services.json`.
It uses `FirebaseAI.googleAI()` with anonymous auth -- no separate Gemini API key is required.

> The app uses `gemini-2.5-flash` for low latency analysis (~1-3s per call).

---

## Android Permissions Setup

The following permissions are required for the app to function:

| Permission | When requested | Why |
|---|---|---|
| `RECORD_AUDIO` | First launch | Record call audio |
| `READ_CONTACTS` | First launch | Check if caller is saved |
| `READ_PHONE_STATE` | First launch | Detect call state changes |
| `POST_NOTIFICATIONS` | First launch (Android 13+) | Show active background listening notification |
| `SYSTEM_ALERT_WINDOW` | Manual UI toggle | Show scam overlay during calls |
| `CALL_PHONE` | On PDRM dial | Dial PDRM directly |
| `FOREGROUND_SERVICE` | Install time | Keep audio service alive in background |
| `FOREGROUND_SERVICE_MICROPHONE` | Install time | Access microphone while app is minimized |
| Call Screening Role | Manual UI toggle | Auto-screen incoming calls |

### Granting the Call Screening Role

Android requires the user to manually grant MayaShield the **call screening role** to intercept calls:
1. On the app's home screen, locate the Service Status card.
2. Tap the **Enable** button next to Call Screening.
3. Select **MayaShield** as the default Caller ID & Spam app when the Android system dialog appears.
4. *(Note: Only ONE app can hold this role at a time, so this replaces apps like Truecaller).*

### Granting Overlay Permission (`SYSTEM_ALERT_WINDOW`)

Because MayaShield draws warnings over the native phone dialer, it requires system-level overlay rights:
1. On the app's home screen, tap the **Enable** button next to Alert Overlay.
2. This will automatically route you to Android Settings.
3. Find MayaShield in the list and toggle **Allow display over other apps**.
4. Return to the app and tap the top-right refresh icon to verify the green checkmark.

---

## Testing & Running the App (Demo Guide)

**🚨 DO NOT USE AN EMULATOR.** Call screening and native microphone services will fail or behave unpredictably on virtual devices. 
**🚨 DO NOT BUILD AN APK FOR TESTING.** Use development mode for live debugging.

### Step 1: Connect a Physical Device
1. Enable **Developer Options** and **USB Debugging** on a physical Android 10+ phone.
2. Connect it to your laptop via USB.
3. Verify connection by running `flutter devices` in your terminal.

### Step 2: Run the App
```bash
cd mayashield
flutter pub get
flutter run
```

---

## Firestore Security Rules

Apply these rules in Firebase Console -> Firestore -> Rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /scam_reports/{reportId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && request.resource.data.keys().hasAll(['transcript', 'callerNumber',
            'aiVerdict', 'aiReason', 'reportedAt']);
    }

    match /scam_numbers/{numberId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && request.resource.data.keys().hasAll(['phoneNumber', 'reportCount',
            'firstReportedAt', 'latestAiReason']);
      allow update: if request.auth != null
        && request.resource.data.reportCount == resource.data.reportCount + 1;
    }

  }
}
```

---

## Known Limitations

| Limitation | Details |
|---|---|
| Call audio (Android 10+) | `AudioSource.MIC` captures the user's microphone only. Caller's audio is captured only on speakerphone. `AudioSource.VOICE_CALL` (both sides) requires `CAPTURE_AUDIO_OUTPUT`, a system-only permission unavailable to third-party apps since Android 10. |
| Scam DB sync latency | New scam numbers take up to 30 minutes to propagate to other users' local caches. |
| Auto-end call | `TelecomManager.endCall()` is deprecated since API 28 but functional on most devices. |
| Credential security | For the prototype, the GCP Service Account JSON is stored locally in the `assets/` folder. In a production environment, STT calls must be proxied through a secure backend (like Firebase Cloud Functions) to prevent credential extraction. |
| Chirp 3 ms-MY | Malay language support is in Preview. Fall back to `"auto"` if accuracy is poor. |
