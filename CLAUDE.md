

Cadence — AI-Enhanced Reading & Study Platform
> Complete project context for any AI assistant continuing this build.

---

## What This App Is

Cadence is a Flutter mobile app that helps users actually finish their books. It has two signature features:

- **The Pacer** — user sets a finish date for a book, app calculates exact daily page goal
- **The AI Tutor** — highlight any passage → Summarise / Explain / Generate image (via Gemini API)

It is a freemium app: core features free, AI Tutor behind a $2.99/month subscription.

---

## Critical Rules — Read Before Writing Any Code

1. **Never hardcode colours** — always use `AppColors.midnight`, `AppColors.amber` etc from `lib/core/theme/app_colors.dart`
2. **Never use Firebase** — this project uses **Supabase** for everything (auth, database, storage)
3. **Playfair Display** for all headings and display text — `fontFamily: 'PlayfairDisplay'`
4. **DM Sans** for all body/UI text — available via `google_fonts` package
5. **Dark theme only** — `AppColors.midnight` (#0D1B2A) background on every screen
6. **Amber is accent only** — use sparingly for CTAs, active states, progress bars, key numbers
7. **Always follow MVVM** — screens never call Supabase directly in production code (use services/providers). During active sprint development, direct calls are acceptable as placeholders with a `// TODO: move to service` comment
8. **Empty states are required** — every list screen must have a friendly empty state widget
9. **Run `flutter analyze`** before considering any task done — zero warnings policy

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x + Dart 3.x |
| State management | flutter_riverpod ^2.5.1 |
| Navigation | go_router ^13.2.0 |
| Backend/Auth | supabase_flutter ^2.8.4 |
| PDF rendering | flutter_pdfview ^1.3.2 |
| File picking | file_picker ^8.0.3 |
| AI features | google_generative_ai ^0.4.3 |
| HTTP | http ^1.2.1 |
| Local storage | shared_preferences ^2.2.3 |
| Temp files | path_provider ^2.1.3 |
| Environment | flutter_dotenv ^5.2.1 |
| Fonts | google_fonts ^6.2.1 + local PlayfairDisplay |
| Unique IDs | uuid ^4.3.3 |

---

## Brand Colours

```dart
// lib/core/theme/app_colors.dart
midnight:   #0D1B2A  // Primary background
midnight2:  #142234  // Secondary background, sheets
midnight3:  #1C2E42  // Cards, containers
slate:      #2C3E52  // Deep slate
amber:      #C47D0E  // Primary accent, CTAs
amberLight: #F0A830  // Highlights, active states
cream:      #F7F2EA  // Primary text, light surfaces
muted:      #8A9BB0  // Secondary text, borders, placeholders
success:    #1D9E75  // Completed states
```

---

## Folder Structure

```
lib/
├── core/
│   ├── theme/
│   │   ├── app_colors.dart      ✅ DONE
│   │   └── app_theme.dart       ✅ DONE
│   ├── constants/
│   │   └── app_strings.dart     ❌ TODO
│   └── utils/
│       └── pacer_calculator.dart ❌ TODO Sprint 4
│
├── models/
│   ├── user_model.dart          ❌ TODO
│   ├── book_model.dart          ❌ TODO
│   └── library_entry_model.dart ❌ TODO
│
├── services/
│   ├── auth_service.dart        ❌ TODO (auth currently inline)
│   ├── library_service.dart     ❌ TODO (library calls currently inline)
│   ├── storage_service.dart     ❌ TODO (storage calls currently inline)
│   └── ai_service.dart          ❌ TODO Sprint 6
│
├── providers/
│   ├── auth_provider.dart       ❌ TODO
│   ├── library_provider.dart    ❌ TODO
│   └── pacer_provider.dart      ❌ TODO Sprint 4
│
├── screens/
│   ├── splash/
│   │   └── splash_screen.dart   ✅ DONE
│   ├── onboarding/
│   │   └── onboarding_screen.dart ✅ DONE (5 pages)
│   ├── auth/
│   │   ├── login_screen.dart    ✅ DONE
│   │   └── signup_screen.dart   ✅ DONE
│   ├── home/
│   │   └── home_screen.dart     ✅ DONE
│   ├── library/
│   │   └── library_screen.dart  ✅ DONE (upload flow, filter pills, book cards)
│   ├── reader/
│   │   └── reader_screen.dart   ✅ DONE (PDF render, progress save, tap to hide bars)
│   ├── dashboard/
│   │   └── dashboard_screen.dart ❌ TODO Sprint 5
│   └── discover/
│       └── discover_screen.dart  ❌ TODO Sprint 9
│
├── widgets/
│   ├── book_card.dart           ❌ TODO (extract from library_screen)
│   ├── pacer_card.dart          ❌ TODO (extract from home_screen)
│   ├── progress_bar.dart        ❌ TODO
│   └── ai_tutor_sheet.dart      ❌ TODO Sprint 6
│
└── main.dart                    ✅ DONE
```

---

## Supabase Configuration

**Project:** cadence-app
**Region:** eu-west-1

### Tables

#### `profiles`
```
id              uuid  PK  references auth.users(id)
full_name       text
is_premium      bool  default false
streak          int   default 0
created_at      timestamptz  default now()
```
> ⚠️ A profile row must be created for every new user on signup. Currently this is done manually. Fix: add automatic profile creation in signup_screen.dart after auth.signUp() succeeds.

#### `books`
```
id              uuid  PK  default gen_random_uuid()
title           text  not null
author          text  default 'Unknown'
uploaded_by     uuid  FK → profiles(id)
file_url        text
cover_url       text  nullable
total_pages     int   default 0
is_public       bool  default false
created_at      timestamptz  default now()
```

#### `user_library`
```
id                  uuid  PK  default gen_random_uuid()
user_id             uuid  FK → profiles(id)
book_id             uuid  FK → books(id)
reading_progress    int   default 0
pacer_target_date   date  nullable
daily_page_goal     int   default 0
status              text  default 'reading'  -- 'reading' | 'completed' | 'wishlist'
started_at          timestamptz  default now()
completed_at        timestamptz  nullable
created_at          timestamptz  default now()
```

### Storage
- **Bucket:** `books` (private)
- **Path pattern:** `users/{userId}/books/{fileId}.pdf`
- Policies: users can upload/read files in their own path

### Auth
- Email/Password enabled
- Google sign-in enabled
- Email confirmation: **OFF** (turn ON before launch)

---

## Current Sprint Status

### ✅ Sprint 0 — Foundation (DONE)
Splash screen with animated waveform bars, home screen shell, full brand theme.

### ✅ Sprint 1 — Authentication (DONE)
- Onboarding: 5 pages (Welcome, Problem, Pacer, AI Tutor, Sign Up)
- Signup with Supabase Auth — stores full_name in user metadata
- Login with friendly error messages
- Forgot password via Supabase reset email
- Logout from profile menu sheet
- SharedPreferences routing — splash routes correctly after first login

**Known issue to fix in Sprint 3:** Profile row in `profiles` table is not auto-created on signup. Fix by adding this to `signup_screen.dart` after successful `auth.signUp()`:
```dart
await _supabase.from('profiles').insert({
  'id': response.user!.id,
  'full_name': _nameController.text.trim(),
  'is_premium': false,
  'streak': 0,
});
```

### ✅ Sprint 2 — Library & PDF Reader (DONE)
- Library screen with filter pills (All/Reading/Completed/Uploads/Wishlist)
- PDF upload to Supabase Storage → saves to `books` + `user_library` tables
- Book cards with progress bars, status chips, options menu
- Reader screen: downloads PDF to temp storage, renders with flutter_pdfview
- Progress saved to Supabase every 5 pages
- Tap anywhere in reader to toggle top/bottom bars
- Empty states on library

**Known issue:** Upload fails with foreign key error if no profile row exists for user. Fix with Sprint 1 known issue solution above.

### 🔄 Sprint 3 — Full Library Polish (CURRENT — START HERE)

**Goal:** All data flows correctly. HomeScreen shows real data. Library is fully connected.

#### Task 1 — Fix profile auto-creation (URGENT — do this first)
File: `lib/screens/auth/signup_screen.dart`
After `response.user != null` check, before `_markOnboardingSeen()`, add:
```dart
// Create profile row in profiles table
await _supabase.from('profiles').insert({
  'id': response.user!.id,
  'full_name': _nameController.text.trim(),
  'is_premium': false,
  'streak': 0,
});
```

#### Task 2 — Wire HomeScreen Continue Reading to real data
File: `lib/screens/home/home_screen.dart`
Replace `_ContinueReadingCard` static widget with one that queries:
```dart
final response = await _supabase
    .from('user_library')
    .select('*, books(*)')
    .eq('user_id', userId)
    .eq('status', 'reading')
    .order('started_at', ascending: false)
    .limit(1)
    .maybeSingle();
```
If null → show empty state. If found → show book title, author, progress bar, Read button that navigates to ReaderScreen.

#### Task 3 — Wire HomeScreen Up Next shelf to real wishlist
File: `lib/screens/home/home_screen.dart`
Replace `_UpNextShelf` placeholder with real query:
```dart
final response = await _supabase
    .from('user_library')
    .select('*, books(*)')
    .eq('user_id', userId)
    .eq('status', 'wishlist')
    .order('created_at', ascending: false)
    .limit(5);
```

#### Task 4 — Update total_pages when PDF renders
File: `lib/screens/reader/reader_screen.dart`
Add `bookId` as a required parameter to `ReaderScreen`.
In the `onRender` callback:
```dart
onRender: (pages) {
  setState(() { _totalPages = pages ?? 0; _isReady = true; });
  if (pages != null && pages > 0) {
    _supabase.from('books')
        .update({'total_pages': pages})
        .eq('id', widget.bookId);
  }
},
```

#### Task 5 — Add search bar to Library
File: `lib/screens/library/library_screen.dart`
Add a `TextEditingController _searchController` and filter `_filteredBooks` getter to also check if title or author contains the search text.

#### Task 6 — Extract BookCard widget
Create `lib/widgets/book_card.dart` — move `_BookCard` class from `library_screen.dart` into it. Update imports.

### ❌ Sprint 4 — The Pacer (NOT STARTED)
Create `lib/core/utils/pacer_calculator.dart`, add SetPacerSheet, wire PacerCard to real data.

### ❌ Sprint 5 — Dashboard (NOT STARTED)
Implement `dashboard_screen.dart`, streak tracking, weekly bar chart (add `fl_chart` package).

### ❌ Sprint 6 — AI Tutor Text (NOT STARTED)
Create `lib/services/ai_service.dart` using `google_generative_ai`, add text selection to reader, build `ai_tutor_sheet.dart`.

### ❌ Sprint 7 — AI Tutor Images (NOT STARTED)
Gemini image generation in AI Tutor sheet.

### ❌ Sprint 8 — Premium & Paywall (NOT STARTED)
Google Play in-app purchases, $2.99/month subscription.

### ❌ Sprint 9 — Community & Discover (NOT STARTED)
Discover screen, community publishing flow.

### ❌ Sprint 10 — Polish & Testing (NOT STARTED)
Security rules, error states, flutter analyze clean, beta testing.

### ❌ Sprint 11 — Launch (NOT STARTED)
Play Store submission, signed APK, store listing.

---

## Key Code Patterns

### Supabase join query
```dart
final response = await _supabase
    .from('user_library')
    .select('*, books(*)')
    .eq('user_id', userId)
    .order('created_at', ascending: false);
```

### Navigation — push (can go back)
```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const TargetScreen()),
);
```

### Navigation — replace with fade (after auth)
```dart
Navigator.of(context).pushReplacement(
  PageRouteBuilder(
    pageBuilder: (_, __, ___) => const TargetScreen(),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 400),
  ),
);
```

### Bottom sheet
```dart
showModalBottomSheet(
  context: context,
  backgroundColor: AppColors.midnight2,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  isScrollControlled: true,
  builder: (ctx) => YourSheetWidget(),
);
```

### Error snackbar
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(message, style: const TextStyle(color: AppColors.cream)),
    backgroundColor: AppColors.midnight3,
  ),
);
```

### Supabase current user
```dart
final userId = Supabase.instance.client.auth.currentUser!.id;
final user = Supabase.instance.client.auth.currentUser;
final name = user?.userMetadata?['full_name'] as String?;
```

---

## Environment Variables

File: `.env` (in project root — never commit to git)
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GEMINI_API_KEY=your-gemini-key
```

---

## Run Commands

```bash
flutter pub get       # Install dependencies
flutter run           # Run on device/emulator
flutter analyze       # Check for errors (run before every commit)
flutter build apk --release  # Build release APK
```

---

## About the Project

**Founder:** Favour Abignue Tamfu — solo developer, bootstrapped, building in public.
**Location:** Cameroon (UTC+1)
**Target:** Android first (Google Play), iOS later (App Store)
**Budget:** $0 — all free tiers

When suggesting code: keep it achievable solo, explain the why, prefer simple solutions over complex ones, flag potential issues early.

---

*Last updated: April 2026 — Sprint 2 complete, Sprint 3 starting*
