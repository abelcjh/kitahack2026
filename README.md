# MayaShield

**Real-Time Anti-Voice Scam Detector | KitaHack 2026 | SDG 16**

MayaShield is an Android-primary Flutter app that automatically screens incoming phone calls from unsaved numbers, transcribes audio in real-time using Google Chirp 3 (Speech-to-Text V2), and analyzes the conversation with Gemini 2.5 Flash to detect Malaysian voice scam patterns -- **during the call**, not after. Confirmed scam numbers are shared across all MayaShield users via a community Firestore database.

---

## Table of Contents

1. [Architecture](#architecture)
2. [API Setup and Configuration](#api-setup-and-configuration)
3. [Firebase Setup](#firebase-setup)
4. [Google Cloud Speech-to-Text V2 Setup](#google-cloud-speech-to-text-v2-setup)
5. [Firebase AI Logic (Gemini) Setup](#firebase-ai-logic-gemini-setup)
6. [Android Permissions Setup](#android-permissions-setup)
7. [Running the App](#running-the-app)
8. [Firestore Security Rules](#firestore-security-rules)
9. [Known Limitations](#known-limitations)

---

## Architecture

Three layers of protection:

```
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

### Step 1: Copy and fill in your credentials

Open `mayashield/lib/config/constants.dart` and replace all placeholder values:

```dart
static const String googleCloudApiKey = 'YOUR_GOOGLE_CLOUD_API_KEY';
static const String googleCloudProjectId = 'YOUR_GCP_PROJECT_ID';
```

---

## Firebase Setup

### Step 1: Create a Firebase project

1. Go to [https://console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** and follow the steps.
3. Enable **Google Analytics** (optional).

### Step 2: Register your Android app

1. In Firebase Console, click **Add app** -> **Android**.
2. Set package name: `com.mayashield.app`
3. Download `google-services.json` and place it at:
   ```
   mayashield/android/app/google-services.json
   ```

### Step 3: Register your iOS app (for iOS fallback)

1. Click **Add app** -> **iOS**.
2. Set bundle ID: `com.mayashield.app`
3. Download `GoogleService-Info.plist` and place it at:
   ```
   mayashield/ios/Runner/GoogleService-Info.plist
   ```

### Step 4: Enable Firebase Authentication

1. In Firebase Console -> **Build** -> **Authentication** -> **Get started**.
2. Click **Sign-in method** tab.
3. Enable **Anonymous** sign-in.

### Step 5: Enable Cloud Firestore

1. In Firebase Console -> **Build** -> **Firestore Database** -> **Create database**.
2. Start in **production mode**.
3. Choose a region (recommended: `asia-southeast1` for Malaysia).
4. Apply the security rules from the [Firestore Security Rules](#firestore-security-rules) section below.

### Step 6: Run FlutterFire CLI in terminal to generate firebase_options.dart

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This generates `lib/firebase_options.dart`. The app imports this file in `main.dart`.

---

## Google Cloud Speech-to-Text V2 Setup

### Step 1: Enable the API

1. Go to [https://console.cloud.google.com](https://console.cloud.google.com).
2. Select your Firebase project (they share the same GCP project).
3. Navigate to **APIs & Services** -> **Library**.
4. Search for **Cloud Speech-to-Text API** and click **Enable**.

### Step 2: Create an API key

1. Go to **APIs & Services** -> **Credentials** -> **Create credentials** -> **API key**.
2. Click **Restrict key**:
   - Under **API restrictions**, select **Restrict key**.
   - Choose **Cloud Speech-to-Text API** only.
   - Under **Application restrictions**, optionally restrict to Android (package: `com.mayashield.app`).
3. Copy the key into `constants.dart` as `googleCloudApiKey`.

### Step 3: Understand the Chirp 3 endpoint

The app sends `POST` requests to:
```
https://asia-southeast1-speech.googleapis.com/v2/projects/{PROJECT_ID}/locations/asia-southeast-1/recognizers/_:recognize?key={API_KEY}
```

> **Note**: Chirp 3 is GA in `us` and `eu` multi-regions. `asia-southeast1` is in Preview.
> To use the closer region, update `sttRegion` in `constants.dart` to `asia-southeast1`
> and the endpoint host to `asia-southeast1-speech.googleapis.com`.

> **Malay language**: `ms-MY` is supported in Preview for Chirp 3. If transcription quality
> is poor, set `languageCodes` to `["auto"]` for language-agnostic detection.

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

The following permissions require user grant flows:

| Permission | When requested | Why |
|---|---|---|
| `RECORD_AUDIO` | First launch | Record call audio |
| `READ_CONTACTS` | First launch | Check if caller is saved |
| `READ_PHONE_STATE` | First launch | Detect call state changes |
| `POST_NOTIFICATIONS` | First launch (Android 13+) | Show recording notification |
| `SYSTEM_ALERT_WINDOW` | First launch | Show scam overlay during calls |
| `CALL_PHONE` | On PDRM dial | Dial PDRM directly |
| Call Screening Role | First launch | Auto-screen incoming calls |

### Granting the Call Screening Role

Android requires the user to manually grant MayaShield the **call screening role**:
1. The app shows a prompt on first launch.
2. Tap **Set as call screener** -> follow the system dialog.
3. Only ONE app can hold this role at a time (replaces other call screeners).

### Granting Overlay Permission

1. The app shows a prompt on first launch.
2. Tap **Open Settings** -> toggle **Allow display over other apps** for MayaShield.

---

## Running the App

```bash
cd mayashield
flutter pub get
flutter run --debug
```

For release build:
```bash
flutter build apk --release
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
| iOS | Apple blocks all call interception. iOS users get manual Record/Upload fallback. |
| Scam DB sync latency | New scam numbers take up to 30 minutes to propagate to other users' local caches. |
| Auto-end call | `TelecomManager.endCall()` is deprecated since API 28 but functional on most devices. |
| API key security | For the prototype, the GCP API key is stored in `constants.dart`. In production, proxy through a Firebase Cloud Function. |
| Chirp 3 ms-MY | Malay language support is in Preview. Fall back to `"auto"` if accuracy is poor. |
