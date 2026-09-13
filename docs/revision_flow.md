# Revision Flow

Tilawa is a revision tracker and planner with an on-device recitation follow-along. It must not generate Quran quizzes, Quran prompts, missing-word questions, or Quran answer validation.

## Core Flow

1. User opens the dashboard.
2. User sees a Duolingo-style progress path and a priority Surah card.
3. User chooses a Surah.
4. User recites from memory. The recogniser follows along on-device and shows
   which ayah they have reached; the text stays hidden unless they reveal it.
   They may also revise from the Mushaf, a teacher, or any trusted method.
5. User records a self-estimate of how well they recalled it, with the session's
   recognition summary shown alongside as context.
6. App updates progress and schedules future revision.

## Allowed Interactions

- Select Surah.
- Start and stop live follow-along.
- Reveal or hide the verse text during recitation.
- Add/remove Surah from revision plan.
- Set reminder time.
- Record recall estimate.
- Track streak, XP, completion, and confidence.

## Not Allowed

- Displaying ayah text from any source but the checked-in corpus.
- Generating word sorting exercises.
- Multiple-choice Quran questions.
- Missing-word prompts.
- Validating Quran answers.
- Any invented sample Quran text.

## Source Discipline

Quran text is source-controlled canonical data, not generated UI content. The
scanned Mushaf pages remain the Libyan Qaloon / Jamahiriya edition; the verse
text used for recognition and display comes from the corpus shipped with the
model. See `ai_handoff.md`.
