# Tilawa Product Context

This folder defines the product, UX, architecture, and implementation context for Tilawa.

Use this folder as the first reference before making code changes. The goal is to keep future implementation aligned with the intended app rather than drifting into generic Quran app patterns.

## Files

- `product_brief.md` - What the app is, who it is for, and what success looks like.
- `ux_principles.md` - The 2-click max interaction model and core user flows.
- `visual_direction.md` - Dark theme, typography, cards, path nodes, and component style.
- `architecture.md` - Clean architecture boundaries and preferred Flutter structure.
- `data_model.md` - Mock data expectations and future persistence model.
- `revision_flow.md` - Quran-safe revision tracking flow with no generated quiz content.
- `roadmap.md` - Suggested build phases.
- `ai_handoff.md` - Instructions for future AI/code agents working on this project.
- `MERGE_NOTES.md` - How this codebase was merged from its two predecessors.

## Current App Identity

Name: Tilawa

Concept: A gamified Quran revision app with offline, on-device recitation follow-along, focused on memorization retention, fast daily practice, and elegant dark-mode reading.

Primary inspiration:

- Duolingo: clear progress path, streaks, XP, immediate daily action, playful feedback.
- Tarteel: live recitation follow-along, elegant Quran-focused typography, calm dark UI, premium visual restraint.

Primary constraint:

The app must make the daily revision action as close to instant as possible while avoiding generated Quran quizzes. From dashboard to choosing a Surah, reciting, and recording self-estimation should stay fast and clear - and the recogniser must work with no network at all.
