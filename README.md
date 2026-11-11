# CampusBell

CampusBell is a college "call bell" app. A HOD or lecturer taps **Ring** and the other person's phone rings, even when it is locked, with a short message such as "Please come to my cabin". Students can't ring staff. Instead they send a quiet **request to meet**, which the staff member accepts or declines.

This repository has three parts:

| Folder | What it is | Tech |
|---|---|---|
| `lib/`, `android/`, `ios/` | Mobile app | Flutter, Firebase Auth, Cloud Firestore, FCM |
| `portal/` | Admin web portal | Next.js 16, React 19, Tailwind, Firebase JS SDK |
| `worker/` | Push server (sends the ring) | Cloudflare Worker (free plan), FCM HTTP v1 |

Firestore security rules and indexes are in `firestore.rules` and `firestore.indexes.json`.

---

## Features

**Bells**
- Ring a person, with a message, priority (Normal / High / Urgent) and "keep ringing".
- Ring a group (for example "Lab assistants"). Everyone rings, the first to accept goes, and the others are told who is going.
- Request to meet: a quiet notification that goes from a junior to a senior.
- Accept or decline with a reason. The sender sees the answer live and gets a notification.

**Home**
- Greeting with your name (titles kept, e.g. "Dr. Vipin Kumar").
- Offline banner.
- Carousel with department notices and feature shortcuts.
- Ring person, Ring group, Announce.
- Today's timetable and pending meet requests.

**Notices (Announce)**
- A HOD posts to their department. The administrator can post to any department or to everyone.
- Shows how many people have seen each notice ("42 of 60 seen").

**Timetable**
- Weekly classes with time and room, and "repeat on" several days.
- Warns when two classes clash.
- *Quiet during classes*: while you are in a class, bells arrive silently. Urgent bells still ring.

**People**
- Directory and Hierarchy, ordered HOD → Professor → Associate Professor → Assistant Professor → Lab Assistant → Student.
- Shows who is in class right now.
- Each department can have only one HOD. A HOD is a Professor or an Associate Professor by designation.
- Profile photos.
- History of every bell, with status.

**Admin**
- Manage users: search, filter, change role or department, disable or enable.
- The web portal adds dashboards, departments, bells and admin management.

### Who can ring whom

Bells go **down** the hierarchy. Requests go **up**.

```
Administrator  (can ring anyone)
HOD
Professor
Associate Professor
Assistant Professor
Lab Assistant
Student        (cannot ring; can send requests)
```

The same rules are in `lib/models/models.dart` (`Roles`), `worker/src/index.js` (`ORDER`) and `firestore.rules`. Keep all three in sync.

---

## Mobile app

Requirements: Flutter 3.35+ (Dart 3.12+) and Android SDK 36.

```bash
flutter pub get
flutter run
```

Release APK, about 10 MB, for 64-bit Android phones:

```bash
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols
```

To share the app, use **Profile → Share CampusBell**. It sends the app as `CampusBell.apk`, which WhatsApp accepts.

Signing: put `android/key.properties` and the `.jks` keystore on your machine. Both are git-ignored and must never be committed.

## Push server (`worker/`)

```bash
cd worker
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT   # paste the service-account JSON
npx wrangler deploy
```

Put the deployed URL in `lib/core/config.dart` (`pushServerUrl`).

## Firestore

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Admin portal (`portal/`)

```bash
cd portal
cp .env.local.example .env.local   # fill in the Firebase web app keys
npm install
npm run dev                        # http://localhost:3000
npm run build
```

### Deploy to Vercel

1. Import this repository in Vercel and set **Root Directory** to `portal`.
2. Add the `NEXT_PUBLIC_FIREBASE_*` variables from `.env.local.example` under Project → Settings → Environment Variables.
3. In Firebase Console → Authentication → Settings → Authorized domains, add the Vercel domain.

---

## Project layout

```
lib/
  core/        theme, config
  models/      AppUser, BellRequest, Roles, Period, Announcement
  services/    Firebase, bells, groups, notices, timetable, notifications, share
  screens/     home, call, history, directory, hierarchy, timetable, announce, admin, profile …
  widgets/     shared UI (cards, avatars/photos, department picker)
portal/        Next.js admin portal
worker/        Cloudflare push server
test/          unit tests (roles, names)
```
