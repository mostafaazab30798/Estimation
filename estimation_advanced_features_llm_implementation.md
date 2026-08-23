# Estimation Advanced Features — LLM Agent Implementation Specification

## Purpose

Implement these six connected Estimation features:

1. Estimation Academy
2. Puzzle Mode
3. Personal Playstyle
4. Player Personality Profile
5. Player Card / Identity Card
6. Shareable "My Estimation"

Estimation is the main game mode. These features must strengthen its strategic identity without changing the existing rules.

---

# 1. Critical Rules

Before coding:

- Inspect the existing Estimation engine, models, scoring, bidding, declaration, profile, persistence, routing, and theme systems.
- Reuse existing card, player, bid, trick, scoring, authentication, and profile models.
- Do not duplicate game rules.
- Do not rewrite the existing game engine unless absolutely necessary.
- Keep all six features data-driven and extensible.
- Preserve the existing 99 mode.

The core principle is:

**One source of truth for gameplay data.**

---

# 2. Architecture

Use this conceptual flow:

```text
                 ESTIMATION GAME
                       │
                       ▼
                Gameplay Events
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
     Statistics     Academy        Puzzles
        │              │              │
        └──────────────┼──────────────┘
                       ▼
                Player Analytics
                       │
              ┌────────┴────────┐
              ▼                 ▼
       Playstyle Engine    Personality
              │                 │
              └────────┬────────┘
                       ▼
                 Player Identity
                       │
                ┌──────┴──────┐
                ▼             ▼
           Identity Card   Share Card
```

---

# 3. Estimation Academy

## Goal

Create an interactive learning center, not a static tutorial.

Teach:

- Reading a hand
- Bidding
- Declaration
- Trump strategy
- Sans / No Trump
- Dash Call
- Risk
- Forbidden 13
- Trick-taking
- Score management
- Reading opponents
- Advanced strategy

## Structure

```text
Academy
├── Getting Started
├── Reading Your Hand
├── Bidding
├── Declaration
├── Trump Strategy
├── Sans Strategy
├── Dash Call
├── Risk
├── Forbidden 13
├── Trick Taking
├── Score Management
├── Advanced Strategy
└── Master Challenges
```

Each lesson should contain:

```text
id
title
description
difficulty
duration
explanation
example
interactiveScenario
correctAnswer
answerExplanation
reward
```

## Interactive Hand Simulator

Example:

```text
Your Hand

♠ A K Q 8
♥ A 7
♦ K 9
♣ 6 4

What would you bid?

5 ♠
6 ♠
7 ♠
8 ♠
PASS
```

Evaluate the answer using real game rules.

Then explain:

```text
Your Answer: 7 ♠

Result: Reasonable but aggressive.

Expected reliable tricks: 6–7
Risk: Medium/High
```

Never expose hidden information.

## Progress

Track:

- Lessons completed
- Attempts
- Correct answers
- Mastery percentage
- Topic mastery

Mastery:

```text
Not Started
Learning
Practicing
Proficient
Mastered
```

Do not award mastery simply for opening a lesson.

## Agent Requirements

- Make lesson content configuration/data driven.
- Reuse real game-rule validation.
- Persist progress.
- Add tests.
- Support Arabic/English and RTL.
- Make scenarios deterministic when required.

---

# 4. Puzzle Mode

## Goal

Create strategic standalone Estimation situations, similar to chess puzzles.

## Puzzle Categories

### Bid Puzzle

“What should you bid?”

### Declaration Puzzle

“What declaration is legal/strongest?”

### Trick Puzzle

“What card should you play?”

### Risk Puzzle

“Should you take Risk?”

### Dash Puzzle

“Should you make a Dash Call?”

### Score Puzzle

“You are behind. What decision gives you the best chance?”

## Data Model

Conceptually:

```text
Puzzle
├── id
├── title
├── category
├── difficulty
├── scenario
├── playerHand
├── visibleGameState
├── legalActions
├── optimalActions
├── acceptableActions
├── explanation
└── scoring
```

Do not assume every puzzle has exactly one correct strategic answer.

Results:

```text
OPTIMAL
STRONG
WEAK
INVALID
```

Example:

```text
Your answer: 7 ♠

Result: STRONG

Expected best: 6 ♠

Why:
7 is playable but introduces significantly more
risk because of weak side suits.
```

## Difficulty

```text
⭐ Beginner
⭐⭐ Intermediate
⭐⭐⭐ Advanced
⭐⭐⭐⭐ Expert
⭐⭐⭐⭐⭐ Master
```

Difficulty should reflect decision complexity, not merely obscure rules.

## Daily Puzzle

Add:

```text
🧩 PUZZLE OF THE DAY
```

Same puzzle for all players.

Track:

- Attempts
- Score
- Success rate
- Streak
- Rank

## Agent Requirements

- Validate actions through existing rules.
- Never create impossible card states.
- Support multiple acceptable solutions.
- Keep puzzle evaluation separate from production match scoring.
- Persist results.
- Make puzzle content data-driven.

---

# 5. Personal Playstyle

## Goal

Answer:

**“How do I play?”**

This is different from simply measuring skill.

## Dimensions

Use 0–100 metrics for:

```text
Aggression
Conservatism
Risk Taking
Precision
Adaptability
Trump Confidence
Comeback Ability
Bid Discipline
Declaration Accuracy
Score Awareness
```

Example:

```text
YOUR PLAYSTYLE

🔥 Aggression        78
🛡️ Conservatism      34
🎲 Risk Taking       72
🎯 Precision         81
🧠 Adaptability      66
♠ Trump Confidence   74
🔥 Comeback Ability  83
```

## Data Requirements

Do not classify from one match.

Suggested confidence:

```text
<20 rounds   → Early estimate
20–49        → Developing
50–99        → Reliable
100+         → High confidence
```

Display:

```text
Profile Confidence: 82%
```

## Example Signals

### Aggression

Increase when the player frequently makes ambitious bids or accepts high-risk contracts.

### Precision

Increase when declarations frequently match actual tricks.

### Risk Taking

Increase when risky opportunities are intentionally accepted.

### Comeback Ability

Increase when the player performs strongly while behind or takes the lead late.

These must be measurable behavioral signals.

## Archetypes

Possible primary/secondary styles:

```text
🧠 The Calculator
🔥 The Aggressor
🛡️ The Survivor
🎲 The Gambler
👑 The Closer
🔄 The Adapter
```

The profile must evolve over time.

---

# 6. Player Personality Profile

## Goal

Turn numerical playstyle data into a human-readable identity.

Example:

```text
MOSTAFA

🧠 THE CALCULATOR

“You rarely make unnecessary bids.
You prefer reliable contracts and consistently
perform close to your declarations.”
```

Include:

- Primary archetype
- Secondary archetype
- Strengths
- Weaknesses
- Signature behavior
- Improvement recommendation

## Explain the Result

Always show measurable reasons:

```text
WHY YOU ARE “THE CALCULATOR”

• 72% declaration accuracy
• Low overbid frequency
• High score preservation
• Low unnecessary Risk usage
```

Never make personality feel random.

## Dynamic Personality

Do not permanently hard-code the personality.

If behavior changes:

```text
Old: The Calculator
New: The Closer
```

Show:

```text
Your playstyle evolved.
```

## Privacy

Allow players to control which profile information is public.

Never expose hidden opponent information or internal analytics that should remain private.

---

# 7. Player Card / Identity Card

## Goal

Create a premium visual identity for every player.

## Content

```text
Avatar
Player Name
Title
Level
Primary Personality
Estimation Accuracy
Wins
Perfect Estimates
Best Streak
Selected Style
```

Example:

```text
╔══════════════════════════╗

          MOSTAFA

      🧠 THE CALCULATOR

         LEVEL 27

      ESTIMATION
        MASTER

   🎯 Accuracy      71%
   🏆 Wins          143
   🎯 Perfect       89
   🔥 Streak         11

       CARD SHARK

╚══════════════════════════╝
```

## Visual Rules

Use:

- Strong typography
- Player avatar
- Subtle card texture
- Estimation symbols
- Personality badge
- Level
- Selected theme

Avoid clutter.

Support:

- Long names
- Arabic names
- RTL
- Missing avatars
- Different levels
- Different themes

## Public vs Private

Public:

- Name
- Avatar
- Title
- Level
- Selected personality
- Selected statistics

Private:

- Detailed behavioral analytics
- Internal confidence scores
- Sensitive history

---

# 8. Shareable “My Estimation”

## Goal

Turn achievements into organic marketing.

Generate a polished share image.

Example:

```text
╔══════════════════════════╗

       MY ESTIMATION

          MOSTAFA

      🧠 THE CALCULATOR

        LEVEL 27

   🎯 71% Accuracy
   🏆 143 Wins
   🎯 89 Perfect Estimates
   🔥 11 Win Streak

       CARD SHARK

       ESTIMATION

╚══════════════════════════╝
```

Also support match-specific sharing:

```text
🏆 VICTORY

MOSTAFA

Final Score
148

🎯 Perfect Estimates: 4
🔥 Comebacks: 1
🏆 Best Round: +28

BOULA CHAMPION
```

## Actions

```text
[ Share ]
[ Save Image ]
[ Copy ]
[ Cancel ]
```

Prefer the platform's native share mechanism.

## Image Requirements

- Match app theme
- Use selected avatar
- Include only approved public data
- Stable aspect ratio
- High-DPI output
- Arabic and English support
- Correct RTL
- Handle long names without clipping
- Subtle game branding

---

# 9. Integration

These features must reinforce each other.

Example:

```text
Play Match
    ↓
Gameplay Statistics
    ↓
Playstyle Analytics
    ↓
Personality Evolves
    ↓
Identity Card Updates
    ↓
Share New Profile
```

Academy:

```text
Academy Progress
    ↓
Skill Development
    ↓
Player Profile
```

Puzzle:

```text
Puzzle Result
    ↓
Puzzle Statistics
    ↓
XP / Achievements
    ↓
Profile Progress
```

---

# 10. Navigation

Recommended:

```text
ESTIMATION

├── 🎮 Play
├── 🧠 Academy
├── 🧩 Puzzles
├── 👤 My Profile
│   ├── Identity Card
│   ├── Playstyle
│   ├── Personality
│   ├── Statistics
│   └── Achievements
└── 📤 Share My Estimation
```

Do not overcrowd the active match UI.

---

# 11. Data Architecture

Conceptual structures:

```text
EstimationAnalytics
├── roundStats
├── matchStats
├── biddingStats
├── declarationStats
├── riskStats
├── dashStats
├── comebackStats
└── accuracyStats

PlaystyleProfile
├── aggression
├── conservatism
├── riskTaking
├── precision
├── adaptability
├── trumpConfidence
├── comebackAbility
└── bidDiscipline

PersonalityProfile
├── primaryArchetype
├── secondaryArchetype
├── strengths
├── weaknesses
├── signatureBehavior
└── recommendation

AcademyProgress
├── completedLessons
├── attempts
├── correctAnswers
├── mastery
└── topicProgress

PuzzleProgress
├── solved
├── attempts
├── streak
├── score
└── difficultyProgress
```

Adapt these names to existing project conventions.

Do not create duplicate models if equivalent models already exist.

---

# 12. Persistence

Persist:

- Academy progress
- Puzzle results
- Aggregated statistics
- Playstyle profile
- Personality profile
- Identity-card configuration
- Share-card preferences

Avoid permanently storing unnecessary raw gameplay events.

Use existing synchronization/authentication infrastructure.

---

# 13. Performance

Never allow these features to slow active gameplay.

- Heavy analytics should update after rounds/matches.
- Share-image generation must never block gameplay.
- Cache derived analytics where useful.
- Do not recalculate the entire profile on every UI rebuild.
- Do not perform expensive work synchronously during trick play.

---

# 14. Localization and Accessibility

All features must support:

- Arabic
- English
- RTL
- Large text
- Screen readers where applicable
- Reduced animation
- Haptic toggle
- Strong contrast
- Non-color-only indicators

Do not hard-code strings.

Example localization keys:

```text
academy.perfect_estimate.title
academy.perfect_estimate.description
profile.playstyle.calculator
profile.playstyle.aggressor
puzzle.result.optimal
share.victory.title
```

---

# 15. Testing

## Academy

Test:

- Lesson loading
- Progress persistence
- Correct/incorrect answers
- Mastery
- Interactive scenarios
- RTL/localization

## Puzzles

Test:

- Legal action validation
- Correct solutions
- Multiple accepted solutions
- Scoring
- Daily puzzle
- Persistence

## Playstyle

Test:

- Metric calculations
- Low-data behavior
- Confidence
- Archetype selection
- Profile evolution

## Personality

Test:

- Archetype mapping
- Explanations
- Dynamic changes
- Localization

## Identity Card

Test:

- Long names
- Arabic names
- Missing avatar
- Different themes
- RTL
- Privacy

## Share

Test:

- Image generation
- High DPI
- Arabic text
- Long names
- Missing optional data
- Native sharing

---

# 16. Data Integrity

Never allow the client to freely modify:

- Wins
- Accuracy
- XP
- Achievements
- Perfect estimates
- Puzzle scores
- Leaderboard statistics

Where multiplayer data is server-authoritative, derive these values from trusted match results.

---

# 17. Recommended Implementation Order

## Phase 1 — Analytics Foundation

1. Inspect existing Estimation events.
2. Normalize round/match statistics.
3. Build the analytics layer.
4. Add tests.
5. Persist aggregated statistics.

## Phase 2 — Player Intelligence

6. Personal Playstyle
7. Player Personality Profile

These depend on reliable analytics.

## Phase 3 — Identity

8. Player Card / Identity Card
9. Shareable My Estimation

These consume the profile and analytics layers.

## Phase 4 — Learning

10. Estimation Academy

Make lesson content data-driven and reusable.

## Phase 5 — Challenges

11. Puzzle Mode
12. Daily Puzzle
13. Puzzle statistics

Reuse Academy scenario infrastructure where possible.

---

# 18. Definition of Done

The implementation is complete only when:

- All six features are accessible.
- Existing Estimation rules remain unchanged.
- No duplicate game-rule implementations exist.
- Statistics come from real gameplay.
- Playstyle is based on actual player behavior.
- Personality is based on measurable data.
- Identity Card reflects current profile data.
- Share cards expose only approved public data.
- Academy scenarios use real rules.
- Puzzle actions are rule-valid.
- Arabic/English and RTL work correctly.
- Existing synchronization/authentication architecture is reused.
- Critical calculations have tests.
- Existing 99 mode remains unaffected.

---

# Final Product Philosophy

The six features should create this loop:

```text
PLAY
  ↓
LEARN
  ↓
PRACTICE
  ↓
IMPROVE
  ↓
ANALYZE
  ↓
DISCOVER YOUR STYLE
  ↓
BUILD YOUR IDENTITY
  ↓
SHARE IT
  ↓
PLAY AGAIN
```

The player should eventually feel:

> “This isn't just a card game. It knows how I play.”

The match remains the product.

These features exist to make the player:

**understand it, master it, identify with it, and share it.**
