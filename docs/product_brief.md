# Product Brief

## Product Name

Tilawa

## One-Sentence Pitch

Tilawa listens to your recitation on-device, follows along ayah by ayah, and turns each session into tracked, self-assessed revision progress.

## Target User

- Quran students revising memorized Surahs.
- Hifdh learners who need reminders and progress motivation.
- Libyan users who require Qaloon/Jamahiriya alignment.

## Core Product Rule

The app is not a Quran quiz generator, and it never judges whether a recitation
was correct.

Quran text is displayed only from the checked-in, checksummed corpus. The app
must never invent or modify ayah text. Recognition reports *where* the reciter
is, not *how well* they did; the recall estimate remains theirs.

## Scope

- Dashboard with streak, XP, priority Surah, and progress path.
- Surah navigator.
- Live recitation follow-along, fully offline, text hidden by default.
- Mushaf reader with highlights, notes and bookmarks.
- Revision plans and reminder times.
- Per-Surah self-assessment after each session.
- Local storage first, synced to the account when online.

## Data Scope

The build stores:

- Surah metadata from the generated catalogue.
- User progress, confidence and activity.
- Reminder and plan settings.
- Recitation session outcomes (matched ayat, duration, confidence).

It must never store Quran verse text produced by anything other than the
checked-in corpus, and it never stores audio.

## Success Criteria

- The follow-along keeps up with a live reciter and lands on the right ayah.
- Recognition works with no network connection.
- Quran content is treated with strict source discipline.
- User can choose Surahs, recite, self-rate, and plan future revision.
