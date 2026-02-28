# MayaShield

**Real-Time AI Voice Scam Guardian | KitaHack 2026 | SDG 16: Peace, Justice & Strong Institutions**

MayaShield is a Flutter-based Android app that automatically screens incoming phone calls from unsaved numbers, transcribes audio in real-time using **Google Chirp 3** (Cloud Speech-to-Text V2), and analyzes the conversation with **Gemini 2.5 Flash** to detect Malaysian voice scam patterns -- **during the call, not after** -- alerting the user to take action immediately. Confirmed scam numbers are shared across all MayaShield users via a community Cloud Firestore database and can be reported directly to PDRM.

---

## Table of Contents

1. [Project Description](#project-description)
2. [Google AI Integration & Innovation](#google-ai-integration--innovation)
3. [Technical Architecture](#technical-architecture)
4. [Technical Implementation Overview](#technical-implementation-overview)
5. [User Feedback & Iteration](#user-feedback--iteration)
6. [Challenges Faced & Technical Decisions](#challenges-faced--technical-decisions)
7. [Success Metrics & Scalability](#success-metrics--scalability)
8. [Future Roadmap](#future-roadmap)

---

## Project Description

### The Problem

Voice scam syndicates are devastating Malaysian communities at an unprecedented scale:

- **RM1.18 billion** lost to financial scams in 2023 alone (Bank Negara Malaysia)
- **39,672 commercial crime cases** recorded in the first half of 2024 (PDRM / NST)
- Malaysia ranks **3rd in Southeast Asia** for scam losses per capita (Global Anti-Scam Alliance, 2023)
- Macau scam syndicates and mule account networks operate cross-border with near impunity
- **Elderly, B40, and rural communities** are disproportionately targeted -- victims who can least afford the losses

The most common attack vector is the **voice impersonation call**: scammers pose as officers from LHDN (tax), PDRM (police), banks, or courts, pressuring victims into transferring money under threats of arrest or legal action. These calls exploit trust, urgency, and fear -- and they work because they happen in real-time, faster than the victim can think critically.

### Target Audience

Everyday Malaysians -- particularly **elderly, rural, and less digitally-literate populations** who are most vulnerable to voice impersonation scams. These users may not recognise sophisticated social engineering tactics and have no technical tools to help them in the moment of the call.

### What Malaysia Has Tried (and Why It Still Fails)

| Current Measure | What It Does | Why It Falls Short |
|---|---|---|
| **NSRC 997 Hotline** | National Scam Response Centre -- report scams | Reactive only. Called *after* money is sent. Cannot prevent the scam. |
| **Semak Mule (PDRM)** | Check if a bank account is linked to scam activity | Checks accounts, not phone calls. Useless during a live voice scam. |
| **Bank Cooling-Off Periods** (BNM 2023) | Delays first-time online transfers by 12 hours | Delays the transfer, but does not stop the social engineering itself. Scammers simply call back after the period. |
| **Truecaller / Spam Filters** | Block known spam numbers from a global database | Only blocks *known* numbers. Powerless against fresh, spoofed, or rotated numbers used by syndicates. |
| **SG ScamShield** | Singapore's government app for SMS/call blocking | Uses a database of known numbers. Does not analyze live call content. No Malaysian equivalent exists. |

**The critical gap: zero intervention happens DURING the call, at the exact moment when the victim is being manipulated.**

### Our Innovation

MayaShield is the first **real-time, on-device AI call guardian** that:

1. **Listens** to live phone conversations as they happen (via Android Call Screening Service)
2. **Transcribes** speech in real-time using Google Chirp 3 -- supporting both English and Bahasa Malaysia in the same call
3. **Analyzes** the accumulated conversation with Gemini 2.5 Flash, trained to detect Malaysian scam patterns (LHDN threats, PDRM warrant scams, bank TAC/OTP urgency, Macau syndicate scripts)
4. **Alerts** the user mid-call with an overlay warning and a one-tap button to call PDRM
5. **Shares** confirmed scam numbers across all MayaShield users via a community Firestore database, building a crowdsourced defense network

This intercepts scams **at the point of social engineering** -- the only moment intervention can actually prevent financial loss.

### SDG 16 Alignment

MayaShield directly advances **UN Sustainable Development Goal 16: Peace, Justice and Strong Institutions**:

| SDG Target | How MayaShield Contributes |
|---|---|
| **16.4** -- Reduce illicit financial flows | Directly combats phone-based financial fraud that costs Malaysians over RM1 billion annually |
| **16.5** -- Substantially reduce corruption and bribery | Exposes scammers who impersonate government officials (LHDN, PDRM) to extract money through false authority |
| **16.a** -- Strengthen relevant national institutions to prevent crime | Community scam database + one-tap PDRM CCID reporting empowers citizens and feeds intelligence to law enforcement |
| **16.b** -- Promote non-discriminatory laws and policies | Protects the most vulnerable populations (elderly, B40, rural) who are disproportionately targeted by scam syndicates |

---

## Google AI Integration & Innovation

### AI Is the Core -- Not a Feature

MayaShield cannot function without AI. The entire detection pipeline is a two-stage AI system:

```text
Stage 1: PERCEPTION                     Stage 2: REASONING
Google Chirp 3 (STT V2)       --->      Gemini 2.5 Flash
Converts live speech to text             Analyzes full transcript for
in en-US and ms-MY                       Malaysian scam patterns
simultaneously                           and returns a verdict
```

Without Chirp 3, there is no transcript. Without Gemini, there is no scam detection. AI is not bolted on -- it **is** the product.

### Why Google AI Specifically

| Requirement | Why Google AI Wins | Alternatives Considered |
|---|---|---|
| **Malay + English in one call** | Chirp 3 is the only production STT with native `ms-MY` + `en-US` dual-language support in a single model -- critical for Malaysian code-switching (Manglish) | OpenAI Whisper lacks native ms-MY; local models cannot match Chirp 3 accuracy |
| **Real-time latency (< 3s)** | Gemini 2.5 Flash delivers ~1-3s response times, fitting within the mid-call analysis window | GPT-4o averages 3-8s -- too slow for live call interception |
| **Zero-config authentication** | Firebase AI Logic authenticates via `google-services.json` with anonymous auth -- no API key management | Other LLM APIs require key management and expose credentials on-device |
| **Regional deployment** | Cloud STT V2 deployed in `asia-southeast1` (Singapore) -- lowest latency to Malaysian users | Other STT services lack SEA regional endpoints |
| **Malaysian scam pattern recognition** | Gemini's large context window allows full-transcript analysis with Malaysian-specific prompt engineering (LHDN, PDRM, bank TAC/OTP patterns, Macau syndicate scripts) | Smaller models lack the reasoning depth for nuanced social engineering detection |

### What Makes This Novel

No existing consumer app performs **real-time voice scam analysis during a live phone call**. MayaShield combines four capabilities that have never been unified in a single pipeline:

1. **Native Android call interception** (CallScreeningService) -- automatic, no user action needed
2. **Live multilingual speech-to-text** (Chirp 3) -- processes both BM and English mid-call
3. **LLM-powered scam reasoning** (Gemini 2.5 Flash) -- understands context, not just keywords
4. **Community defense network** (Cloud Firestore) -- every detected scam protects all users

Existing tools like Truecaller or Singapore's ScamShield rely on **static databases of known numbers**. MayaShield analyzes **what the caller is actually saying**, detecting scams from numbers that have never been reported before.

---

## Technical Architecture

### Protection Flow

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
                         Every 5 seconds:
                         Audio chunk (WAV) -> Chirp 3 STT -> Append to transcript
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

### Layered Architecture

| Layer | Technology | Responsibility |
|---|---|---|
| **1. Call Interception** | Android `CallScreeningService` (Kotlin) | Intercepts all incoming calls from unsaved numbers without user interaction |
| **2. Audio Pipeline** | Android Foreground Service + Flutter `EventChannel` | Records microphone via `AudioRecord`, accumulates 5s of PCM audio, wraps in WAV headers, streams to Flutter |
| **3. AI Analysis** | Google Cloud STT V2 (Chirp 3) + Firebase AI (Gemini 2.5 Flash) | Transcribes audio chunks in ms-MY and en-US, then analyzes accumulated transcript for scam indicators |
| **4. Community Defense** | Cloud Firestore + Firebase Auth | SHA-256 hashed scam number sharing, anonymous auth, local cache with <1ms lookup, PDRM CCID hotline integration |

### Google Technologies Used

| Technology | Role in MayaShield |
|---|---|
| **Flutter** | Cross-platform UI framework; primary development platform |
| **Firebase Authentication** | Anonymous sign-in for Firestore access without collecting user identity |
| **Cloud Firestore** | Real-time database for community scam numbers and scam reports |
| **Google Cloud Speech-to-Text V2 (Chirp 3)** | Multilingual live transcription (en-US + ms-MY) |
| **Firebase AI Logic (Gemini 2.5 Flash)** | Real-time scam pattern analysis with Malaysian-specific prompt engineering |

---

## Technical Implementation Overview

### API Setup and Configuration

Open `mayashield/lib/config/constants.dart` and replace the placeholder value for your GCP project ID:

```dart
static const String googleCloudProjectId = 'YOUR_GCP_PROJECT_ID';
```

### Firebase Setup

**Step 1: Create a Firebase project**
1. Go to [https://console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** and follow the steps.
3. Enable **Google Analytics** (optional).

**Step 2: Enable Core Services**
1. **Authentication**: In Firebase Console -> **Build** -> **Authentication**, enable **Anonymous** sign-in.
2. **Firestore**: In **Build** -> **Firestore Database**, create a database in **production mode** (Recommended Region: `asia-southeast1`). Apply the rules from the Firestore Security Rules section below.

**Step 3: Run FlutterFire CLI (Auto-Setup)**

The FlutterFire CLI automatically registers your Android app, downloads the required configuration file (`google-services.json`), and links it to your project.

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This generates `lib/firebase_options.dart`. The app imports this file in `main.dart`.

### Google Cloud Speech-to-Text V2 Setup

> **IMPORTANT:** STT V2 (Chirp) requires a Service Account. Standard API keys will return a 403 Forbidden error.

**Step 1: Create a Service Account**
1. Go to Google Cloud Console -> **IAM & Admin** -> **Service Accounts**.
2. Click **Create Service Account** (e.g., `chirp-audio-bot`).
3. Grant it the **Cloud Speech Administrator** role.
4. Click on the new service account -> **Keys** -> **Add Key** -> **Create New Key** -> **JSON**.

**Step 2: Inject the JSON Key**
1. Rename the downloaded file (e.g., `service-account.json`) and place it inside your Flutter project at `mayashield/assets/service-account.json`.
2. Declare it in your `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/service-account.json
   ```

### Firebase AI Logic (Gemini) Setup

**Step 1: Enable Firebase AI Logic**
1. In Firebase Console -> **Build** -> **AI Logic** (or **Vertex AI**) -> **Get started**.
2. Follow the setup wizard. This provisions the Vertex AI / Google AI backend.

**Step 2: No additional API keys needed**

The `firebase_ai` package authenticates through Firebase using your `google-services.json`. It uses `FirebaseAI.googleAI()` with anonymous auth -- no separate Gemini API key is required.

> The app uses `gemini-2.5-flash` for low latency analysis (~1-3s per call).

### Android Permissions Setup

| Permission | When Requested | Why |
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

**Granting the Call Screening Role**

Android requires the user to manually grant MayaShield the **call screening role** to intercept calls:
1. On the app's home screen, locate the Service Status card.
2. Tap the **Enable** button next to Call Screening.
3. Select **MayaShield** as the default Caller ID & Spam app when the Android system dialog appears.
4. *(Note: Only ONE app can hold this role at a time, so this replaces apps like Truecaller.)*

**Granting Overlay Permission (`SYSTEM_ALERT_WINDOW`)**

Because MayaShield draws warnings over the native phone dialer, it requires system-level overlay rights:
1. On the app's home screen, tap the **Enable** button next to Alert Overlay.
2. This will automatically route you to Android Settings.
3. Find MayaShield in the list and toggle **Allow display over other apps**.
4. Return to the app and tap the top-right refresh icon to verify the green checkmark.

### Testing & Running the App (Demo Guide)

> **DO NOT USE AN EMULATOR.** Call screening and native microphone services will fail or behave unpredictably on virtual devices.
> **DO NOT BUILD AN APK FOR TESTING.** Use development mode for live debugging.

**Step 1: Connect a Physical Device**
1. Enable **Developer Options** and **USB Debugging** on a physical Android 10+ phone.
2. Connect it to your laptop via USB.
3. Verify connection by running `flutter devices` in your terminal.

**Step 2: Run the App**
```bash
cd mayashield
flutter pub get
flutter run
```

### Firestore Security Rules

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

## User Feedback & Iteration

### Testing Methodology

MayaShield was tested with **5 users across 3 age groups** (20s, 40s, 60s) using **simulated scam call scenarios** on physical Android devices. Testers received live phone calls where a team member read from real Malaysian scam scripts (LHDN tax threat, bank TAC verification, PDRM warrant intimidation), and MayaShield monitored the call in real-time.

### Key Insights & Iterations

| # | Insight from Testing | What We Changed |
|---|---|---|
| 1 | **Scam alert overlay was not noticeable enough** -- users on the native dialer screen missed the initial warning | Redesigned the overlay to use high-contrast red (`#B71C1C`) with bold text. Added the caller number banner to provide immediate context. |
| 2 | **Elderly testers struggled to find the "report" action** -- they wanted a single button to contact authorities | Added a **one-tap "Call PDRM" button** on the result screen that directly dials the PDRM CCID hotline (03-2610 1559) via `url_launcher`. |
| 3 | **15-second chunk interval was too slow** -- fast-talking scam scripts completed key manipulation within 10 seconds | Reduced the audio chunk interval from **15 seconds to 5 seconds**, tripling the detection responsiveness. |
| 4 | **Users were unsure if MayaShield was actually working** during the call -- no visual feedback during "safe" calls | Added a **pulsing green indicator** and a **live transcript card** to the Active Call Monitor screen so users can see real-time processing. |

### Iteration Summary

```text
v1: 15s audio chunks, no live transcript, basic alert popup
         |
         v  (user testing)
v2: 5s audio chunks, live transcript view, pulsing status indicator,
    high-contrast overlay, one-tap PDRM dial, community reporting
```

---

## Challenges Faced & Technical Decisions

| Challenge | Context | Technical Decision |
|---|---|---|
| **Android 10+ call audio restriction** | `AudioSource.VOICE_CALL` (both sides of the call) requires `CAPTURE_AUDIO_OUTPUT`, a system-only permission unavailable to third-party apps since Android 10. | We use `AudioSource.MIC` which captures the user's microphone reliably. The caller's voice is captured when the user enables speakerphone. This is the only viable approach for non-system apps. |
| **Real-time latency budget** | The entire pipeline -- record, transcribe, analyze, alert -- must complete within seconds to be useful during a live call. | Selected **Chirp 3** for fast STT and **Gemini 2.5 Flash** for low-latency LLM inference (~1-3s). Audio is chunked at 5-second intervals. STT endpoint is deployed in `asia-southeast1` for regional proximity. |
| **Privacy vs. community safety** | Storing phone numbers in a shared database creates privacy risk. But community sharing is essential for collective defense. | All phone numbers are **SHA-256 hashed** before storage. Firebase Anonymous Auth means no user identity is collected. Safe calls have **all data deleted** -- nothing is stored unless a scam is detected. |
| **Credential security (prototype)** | The GCP Service Account JSON is stored in the `assets/` folder, which is insecure for production. | Acceptable for the hackathon prototype. Production path: proxy STT calls through **Firebase Cloud Functions** so credentials never exist on-device. |
| **Malay language STT accuracy** | Chirp 3's `ms-MY` support is in Preview and accuracy may vary, especially with Manglish code-switching. | Configured dual-language recognition (`en-US` + `ms-MY`) with automatic **fallback to `"auto"` detection** if the primary config returns low-quality results. |

---

## Success Metrics & Scalability

### Key Performance Indicators

| Metric | Target | How It's Measured |
|---|---|---|
| **Scam detection rate** | > 85% on Malaysian voice scam patterns (LHDN, PDRM, bank impersonation) | Tested against a corpus of real scam call scripts; measured by Gemini verdict accuracy |
| **End-to-end response time** | < 8 seconds from audio chunk to user alert on a 4G connection | Measured from the moment a 5s audio chunk is flushed to the moment the scam overlay appears |
| **False positive rate** | < 10% of safe calls incorrectly flagged as scam | Measured by user override/dismiss rate on the result screen |
| **Community DB growth** | 1,000 unique scam numbers within 3 months of deployment | Tracked via Firestore `scam_numbers` collection document count |
| **Community protection reach** | Each reported scam number protects ALL users within 30 minutes | Scam number cache syncs every 30 minutes to all devices |

### Scalability Path

| Component | Scaling Mechanism |
|---|---|
| **Cloud Firestore** | Auto-scales horizontally -- no infrastructure changes needed from 10K to 1M users |
| **Google Cloud STT V2** | Google-managed cloud service -- scales with demand, no provisioning required |
| **Gemini 2.5 Flash** | Firebase AI Logic -- serverless, auto-scaling, pay-per-use |
| **Local scam number cache** | Stored on-device via SharedPreferences -- zero added latency regardless of total user count |
| **Phone number privacy** | SHA-256 hashing is computationally trivial at any scale -- privacy compliance is built-in |

The architecture is designed so that **adding users makes the system stronger** (more scam reports = better community database) without degrading performance for any individual user.

---

## Future Roadmap

| Phase | Feature | Impact |
|---|---|---|
| **Short-term** | On-device STT (remove cloud dependency) | Lower latency, offline support, reduced API costs |
| **Short-term** | iOS CallKit integration | Extend automatic call screening to iPhone users |
| **Medium-term** | Voice biometric fingerprinting | Identify repeat scam callers even when they rotate phone numbers |
| **Medium-term** | NSRC 997 API integration | Direct case filing to National Scam Response Centre from within the app |
| **Medium-term** | Multilingual expansion (Tamil, Mandarin, Cantonese) | Cover all major Malaysian languages |
| **Long-term** | Federated scam pattern learning | Improve Gemini prompts based on aggregated community data without exposing individual transcripts |
| **Long-term** | WhatsApp / Telegram voice note analysis | Extend protection to messaging platforms where voice scams are increasingly common |
| **Long-term** | Partnership with BNM / PDRM / MCMC | Integrate into national anti-scam infrastructure for government-backed deployment |
