# Basra Game Mode — Implementation Specification

## 1. Objective

Implement a complete **Basra (بصرة)** game mode in the existing game.

This document is the source of truth for the game rules. The implementation must preserve the existing game's architecture, UI conventions, player/session model, localization, sound system, animations, and persistence patterns wherever possible.

**Important:** Do not invent alternative rules. If an existing implementation conflicts with this document, this specification wins for the Basra mode unless the existing project already has a clearly shared rule abstraction that can safely support both modes.

---

## 2. Game Configuration

### 2.1 Players

The mode is designed for the existing game's supported player count. The rule text assumes multiple players and turn rotation.

Do not hard-code a specific player count if the current game already supports a configurable count.

### 2.2 Deck

Use a standard 52-card deck:

- Suits: Hearts, Diamonds, Clubs, Spades.
- Ranks: A, 2, 3, 4, 5, 6, 7, 8, 9, 10, J, Q, K.

The following cards have special Basra behavior:

- **7 of Diamonds (7♦)** — special sweeping card.
- **Any Jack (J)** — special sweeping card.
- J, Q and K are face cards for the purposes of numeric capture rules.
- Q and K have **no numeric value**.

---

# 3. Initial Deal

At the start of a round:

1. Shuffle the full 52-card deck.
2. Deal **4 cards to each player**.
3. Place **4 cards face-up on the table**.

### 3.1 Initial Table Replacement Rule

If any of the four initially opened table cards is:

- **7♦**, OR
- **any Jack (J)**,

do NOT leave that special card on the initial table.

Instead:

1. Return that card to the remaining deck / draw pile according to the game's deck-management model.
2. Draw another card to replace it.
3. Continue until the four initial table cards contain no 7♦ and no Jack.

This restriction applies specifically to the initial four face-up cards.

---

# 4. Turn Order

The first player is **not the dealer**.

After the first player is selected:

- Turns proceed in player order.
- Every player must play a card on their turn.
- There is **no Pass / Bass / Skip action**.

A turn consists of:

1. Player selects exactly one card from their hand.
2. The card is played to the table.
3. The engine determines whether that played card captures cards from the table.
4. Captured cards are moved to that player's captured pile.
5. Basra detection is evaluated.
6. If nothing was captured, the played card remains on the table.
7. Turn advances to the next player.

---

# 5. Dealing Additional Cards

Players start with 4 cards.

Whenever all players have exhausted their current hands:

1. If cards remain in the deck, deal **4 new cards to each player**.
2. Continue the game.
3. Do not deal additional cards until all players have exhausted their current hand.

The round ends when:

- every player has no cards in hand, AND
- the deck/draw pile is empty.

The cards remaining on the table are then awarded according to the final-table rule described below.

---

# 6. Card Values

For capture calculations:

| Card |    Numeric Value |
| ---- | ---------------: |
| A    |                1 |
| 2    |                2 |
| 3    |                3 |
| 4    |                4 |
| 5    |                5 |
| 6    |                6 |
| 7    |                7 |
| 8    |                8 |
| 9    |                9 |
| 10   |               10 |
| J    | No numeric value |
| Q    | No numeric value |
| K    | No numeric value |

### Important

Do not assign Q or K a numeric value.

J is also not treated as a numeric card for sum combinations. Its special power is described separately.

---

# 7. Capture Rules

When a player plays a card, evaluate the table according to these rules.

## 7.1 Same-Rank Capture

If the table contains a card with the **same rank/value** as the played card, the player captures that matching card.

Suit does not matter.

Examples:

- Played 5♥ + table contains 5♣ → capture the 5♣.
- Played A♠ + table contains A♦ → capture the A♦.
- Played 10♣ + table contains 10♥ → capture the 10♥.

For Q and K:

- Q can only match another Q.
- K can only match another K.
- They do not participate in numeric sums.

---

## 7.2 Sum Capture

If the played card has a numeric value and a subset of numeric cards on the table has a total equal to the played card's numeric value, capture that subset.

Examples:

- Play 7 and table has 3 + 4 → capture 3 + 4.
- Play 10 and table has 2 + 3 + 5 → capture 2 + 3 + 5.
- Play 8 and table has 1 + 7 → capture A + 7.

### Subset rule

The combination can contain any valid subset of numeric table cards.

The implementation must find a valid combination rather than requiring adjacent cards.

---

## 7.3 Same-Rank + Sum Capture

If both conditions are satisfied by the played card:

1. There is a same-rank card on the table, AND
2. There is a numeric subset whose sum equals the played card,

the player captures **all cards involved in both conditions**, not just one group.

If multiple valid sum combinations exist, the implementation must capture the complete set according to the game's intended deterministic capture resolution.

### Recommended deterministic resolution

To avoid client/server disagreement:

1. Include the same-rank match.
2. Find a deterministic valid sum combination.
3. Prefer the combination that captures the greatest number of cards.
4. If multiple combinations capture the same number of cards, use a deterministic stable ordering based on table-card IDs.

This rule should be encapsulated in the game engine, not the UI.

---

# 8. Q and K Capture Rules

Q and K have no numeric value.

Therefore:

- Q can capture only a Q.
- K can capture only a K.
- Q cannot participate in sums.
- K cannot participate in sums.
- Q cannot capture numeric combinations.
- K cannot capture numeric combinations.

Examples:

- Play Q + table Q → capture Q.
- Play Q + table 2 + 3 → do not capture 2 + 3.
- Play K + table K → capture K.
- Play K + table 4 + 3 → do not capture 4 + 3.

---

# 9. Special Capture Cards

## 9.1 Any Jack (J)

Every Jack is a powerful sweeping card.

When a player plays **any J**:

- Capture **all cards currently on the table**.
- The Jack itself is also placed in the player's captured pile.
- No numeric-sum calculation is needed.
- No same-rank calculation is needed.
- The J always performs the sweep.

### Important

A Jack played during normal gameplay can capture the entire table regardless of its size or contents.

---

## 9.2 7 of Diamonds (7♦)

7♦ is a special sweeping card.

When 7♦ is played:

- Capture all cards currently on the table **if the Basra condition is satisfied**.
- For normal capture behavior, treat 7♦ as a powerful capture card that can clear the table according to the rules.

The Basra-specific restriction is:

A 7♦ earns a Basra only if:

1. Total numeric value of the table cards is **10 or less**, AND
2. There are **no Q cards**, AND
3. There are **no K cards**.

Because J has no numeric value, its presence must still be explicitly handled by the engine. The Basra condition should follow the written rule literally: Q/K invalidate the 7♦ Basra condition.

---

# 10. Basra Detection

A Basra is a scoring event.

The engine must detect Basra immediately after a capture is resolved.

## 10.1 Normal Basra

If a player captures **all cards from the table using one played card**, the player receives:

- **1 Basra**
- Worth **10 bonus points**

The played card must NOT be:

- 7♦
- any J

So:

- 5 clears the table → Basra.
- 10 clears the table → Basra.
- A clears the table → Basra.
- Q clears the table by matching Q and no other table cards remain → Basra.
- K clears the table by matching K and no other table cards remain → Basra.
- J clears the table → NOT this Basra type.
- 7♦ clears the table → NOT this Basra type.

### Implementation condition

A normal Basra exists when:

```text
tableBeforePlay is not empty
AND
playedCard is not J
AND
playedCard is not 7♦
AND
capturedCards == all cards that were on tableBeforePlay
```

---

## 10.2 7♦ Basra

A 7♦ can earn a Basra if:

- it clears all table cards,
- the numeric total of table cards is <= 10,
- there are no Q cards,
- there are no K cards.

Then:

- add 1 Basra
- add 10 Basra bonus points

### Important

Do not award a 7♦ Basra merely because it clears the table. The conditions above must be checked.

---

## 10.3 Final Table Sweep

If cards remain on the table when the round ends:

- The **last player who successfully captured cards from the table** receives all remaining table cards.

This final transfer is **not automatically a Basra**.

Do not add a Basra bonus solely because the final player receives the remaining cards.

---

# 11. Scoring

At the end of the round, calculate each player's score.

## 11.1 Card Majority

The player who captured **27 cards or more** receives:

- **30 points**

In a 52-card deck, only one player can normally reach 27+.

If the game architecture supports unusual player configurations, still keep this calculation centralized and deterministic.

---

## 11.2 Jacks

Each captured Jack gives:

- **+1 point**

Example:

- 2 captured Jacks = +2 points.

---

## 11.3 Aces

Each captured Ace gives:

- **+1 point**

Example:

- 3 captured Aces = +3 points.

---

## 11.4 2 of Spades

The player who captured **2♠** receives:

- **+2 points**

This is a special card bonus.

---

## 11.5 10 of Diamonds

The player who captured **10♦** receives:

- **+3 points**

This is a special card bonus.

---

## 11.6 Basra Bonus

Each Basra gives:

- **+10 points**

Example:

- 2 Basras = +20 points.

---

# 12. Tie / 26-26 Rule

If the round ends with an exact card-count tie where:

- Player A has 26 cards
- Player B has 26 cards

then:

- Do NOT award the 30-card-majority points.
- All other applicable bonuses should be handled according to the normal scoring rules.
- The **30 points associated with the majority are carried forward to the next round**.

### Carry-over behavior

Maintain a `carriedMajorityPoints` value.

Initial value:

```text
carriedMajorityPoints = 0
```

On a 26-26 tie:

```text
carriedMajorityPoints += 30
```

The next round's winner receives the carried majority points in addition to that round's normal scoring.

If another 26-26 tie occurs before those points are awarded:

```text
carriedMajorityPoints += 30
```

Therefore:

- First consecutive tie → next round carries 30.
- Second consecutive tie → next round carries 60.
- Third consecutive tie → next round carries 90.
- etc.

### Important interpretation

The carry-over is attached to the next round's majority winner.

It should not be lost.

---

# 13. Match End

The match ends when a player reaches:

**121 total points**

That player is the winner.

### Recommended implementation

After each round:

1. Calculate round scores.
2. Apply carried majority points.
3. Add round score to cumulative match score.
4. Check all players.
5. If any player has `totalScore >= 121`, end the match.
6. Otherwise start the next round.

Do not wait for exactly 121.

If a player reaches 121 or exceeds it, the match ends immediately after scoring that round.

---

# 14. Suggested Domain Model

Keep Basra logic independent from widgets/screens.

Recommended entities:

```text
BasraGameState
BasraRoundState
BasraPlayerState
BasraCard
BasraCaptureResult
BasraScoreResult
BasraTurnResult
```

### BasraCard

Recommended properties:

```text
id
rank
suit
numericValue
isJack
isQueen
isKing
isSevenOfDiamonds
```

### BasraPlayerState

Recommended properties:

```text
playerId
hand
capturedCards
totalScore
roundScore
basraCount
```

### BasraRoundState

Recommended properties:

```text
deck
tableCards
players
currentPlayerIndex
dealerPlayerIndex
lastCapturePlayerId
carriedMajorityPoints
roundStatus
```

---

# 15. Core Engine APIs

The exact naming should follow the existing project's architecture, but the Basra engine should provide functionality equivalent to:

```text
initializeRound()
dealInitialCards()
replaceInitialSpecialTableCards()

getPlayableCards(playerId)

playCard(playerId, cardId)

resolveCapture(playedCard, tableCards)

detectBasra(
    playedCard,
    tableBeforePlay,
    capturedCards
)

dealNextHands()

finishRound()

calculateRoundScore()

applyCarryOver()

checkMatchWinner()
```

The UI must not implement any game rules itself.

---

# 16. Capture Algorithm

Implement capture resolution in one pure/testable service.

Suggested flow:

```text
resolvePlay(player, playedCard):

    tableBeforePlay = copy(table)

    remove playedCard from player.hand

    if playedCard.isJack:
        captured = all table cards
        clear table
        return capture result

    if playedCard.isSevenOfDiamonds:
        captured = all table cards
        clear table
        return capture result

    sameRankCards = findSameRankCards(playedCard, table)

    sumCombinations = []

    if playedCard has numeric value:
        sumCombinations = findTableSubsetsWithSum(
            table,
            playedCard.numericValue
        )

    selectedCombination = resolveDeterministically(
        sameRankCards,
        sumCombinations
    )

    captured = union(
        sameRankCards,
        selectedCombination
    )

    if captured is empty:
        add playedCard to table
    else:
        remove captured cards from table
        add captured cards + playedCard to player.capturedCards

    basra = detectBasra(...)

    update lastCapturePlayerId if capture occurred

    return result
```

### Important clarification for 7♦

Because 7♦ is a special sweep card, it must not be processed as a normal 7 numeric card during the same turn.

Do not allow the engine to accidentally resolve 7♦ as a normal `7` first.

---

# 17. Sum-Combination Algorithm

Use a subset-sum/backtracking algorithm over numeric table cards.

Requirements:

- Ignore J/Q/K.
- Find subsets whose sum equals the played card value.
- Do not mutate the table while searching.
- Return card IDs, not object references where possible.
- Ensure deterministic ordering.
- Avoid exponential work becoming a performance issue.

The table normally contains relatively few cards, but still implement the algorithm cleanly.

Recommended optimization:

- Ignore combinations whose running sum already exceeds the target.
- Sort candidate numeric cards deterministically.
- Memoization is optional but acceptable.

---

# 18. Multiple Capture Combinations

There can be more than one valid subset.

Example:

```text
Table:
A, 2, 3, 4

Played:
5
```

Possible captures:

```text
A + 4 = 5
2 + 3 = 5
```

The engine must not let the client choose differently on different devices.

Use a deterministic selection policy.

Recommended:

1. Maximize number of captured cards.
2. Then maximize total number of captured non-face numeric cards.
3. Then choose stable card-ID ordering.

The same algorithm must run identically on server and client if both perform validation.

---

# 19. Turn Validation

Reject a play if:

- It is not the current player's turn.
- The player does not own the selected card.
- The round is not active.
- The card ID is invalid.
- The player has no cards.
- The match has already ended.

There is no Pass action.

---

# 20. State Synchronization / Multiplayer

If the game is multiplayer:

- The authoritative game state should live on the server or authoritative game-session layer.
- The client sends:
  - player ID
  - selected card ID
  - action type = `play_card`
- The server validates and resolves the entire turn.
- The server returns the resulting state/event.

Never trust the client to calculate:

- captured cards
- Basra
- scores
- winner
- carried points

### Recommended event

```text
BasraCardPlayed
```

Payload should contain enough information to animate the result:

```text
playerId
playedCard
capturedCards
tableBefore
tableAfter
wasCapture
wasBasra
basraType
lastCapturePlayerId
```

For round completion:

```text
BasraRoundFinished
```

Include:

```text
roundScores
capturedCardCounts
basraCounts
carriedPoints
totalScores
winnerId
isMatchFinished
```

---

# 21. UI Requirements

Implement the Basra mode using the existing game's visual language.

Do not redesign the whole game.

The Basra table must clearly show:

- Current player's turn.
- Player hands.
- Face-up table cards.
- Captured-card count.
- Current total score.
- Round score.
- Basra count.
- Remaining deck/cards.
- Match target: 121.

### Capture animation

When a capture happens:

1. Played card moves toward the player's capture area.
2. Captured table cards animate toward the same area.
3. Table updates.
4. If Basra occurs, show a strong but short Basra feedback animation.
5. Add +10 to the player's round score.
6. Continue to next turn.

Avoid heavy animations that can cause frame drops on mobile devices.

---

# 22. Basra Feedback

Use a dedicated event/result rather than relying on UI-side inference.

Possible labels:

- `بصرة!`
- `Basra!`

The displayed language must follow the existing localization system.

For 7♦:

- Show a distinct label such as `بصرة 7 ديناري` only if the current product language/UI already supports detailed feedback.
- Otherwise standard `بصرة!` is sufficient.

Do not show Basra when the conditions are not satisfied.

---

# 23. Scoring Service

Create a dedicated scoring function:

```text
calculateBasraRoundScore(player)
```

It should calculate:

```text
score = 0

if capturedCards >= 27:
    score += 30

score += numberOfCapturedJacks
score += numberOfCapturedAces

if captured(2♠):
    score += 2

if captured(10♦):
    score += 3

score += basraCount * 10
```

Then apply carry-over majority points to the appropriate next-round winner according to Section 12.

Do not duplicate this calculation in multiple UI or state classes.

---

# 24. Round Lifecycle

Use this lifecycle:

```text
CREATE MATCH
    ↓
CREATE ROUND
    ↓
SHUFFLE DECK
    ↓
SELECT DEALER
    ↓
DEAL 4 TO EACH PLAYER
    ↓
DEAL 4 TO TABLE
    ↓
REPLACE INITIAL 7♦ / J
    ↓
SELECT FIRST PLAYER = NOT DEALER
    ↓
PLAY TURNS
    ↓
ALL HANDS EMPTY?
    ├── NO → continue
    └── YES
          ↓
       DECK EMPTY?
          ├── NO → deal 4 cards to each player
          └── YES
                 ↓
             FINAL TABLE CARDS
                 ↓
             AWARD TO LAST CAPTURER
                 ↓
             CALCULATE SCORE
                 ↓
             APPLY CARRY OVER
                 ↓
             UPDATE TOTAL SCORES
                 ↓
             SOMEONE >= 121?
                ├── YES → MATCH FINISHED
                └── NO → NEXT ROUND
```

---

# 25. Edge Cases

The implementation must explicitly handle:

### Empty table

If a player plays a card while the table is empty:

- No capture.
- The played card becomes the first table card.
- No Basra.

### J on empty table

A Jack played when the table is empty:

- It cannot capture cards.
- It should remain on the table.
- It does not produce Basra.

### 7♦ on empty table

Same principle:

- No cards to capture.
- No Basra.
- The 7♦ remains on the table.

### Same rank plus multiple sum combinations

Use the deterministic resolution defined above.

### Q/K mixed with numeric cards

Q/K are simply non-numeric cards on the table.

They:

- cannot be included in sums,
- can only be captured by the matching Q/K,
- are captured by J/7♦ sweeps.

### Final table contains Q/K

The last capture player gets them at round end.

They contribute to card count, but do not contribute numeric sum points.

### 26-26 tie

Do not award the 30-card-majority points.

Carry them forward.

---

# 26. Testing Requirements

Before considering the mode complete, add unit tests for the rule engine.

Minimum required tests:

## Initial Deal

- [ ] 4 cards per player.
- [ ] 4 cards on table.
- [ ] Initial J is replaced.
- [ ] Initial 7♦ is replaced.
- [ ] Replacement continues until no initial J/7♦ remains.
- [ ] Dealer does not start.

## Capture

- [ ] Same-rank capture.
- [ ] Same-rank capture ignores suit.
- [ ] Numeric sum capture.
- [ ] Sum ignores J.
- [ ] Sum ignores Q.
- [ ] Sum ignores K.
- [ ] Q captures Q only.
- [ ] K captures K only.
- [ ] Combined same-rank + sum capture.
- [ ] Multiple valid sums resolve deterministically.

## Special cards

- [ ] J sweeps table.
- [ ] Every suit of J works.
- [ ] 7♦ sweeps table.
- [ ] Other 7s do not behave as 7♦.
- [ ] J is not treated as numeric 11.
- [ ] Q is not numeric.
- [ ] K is not numeric.

## Basra

- [ ] Normal full-table clear awards Basra.
- [ ] J full-table clear does not award normal Basra.
- [ ] 7♦ full-table clear does not award normal Basra.
- [ ] Valid 7♦ condition awards Basra.
- [ ] 7♦ with total > 10 does not award Basra.
- [ ] 7♦ with Q does not award Basra.
- [ ] 7♦ with K does not award Basra.
- [ ] Empty-table play does not award Basra.
- [ ] Multiple Basras are counted.

## Scoring

- [ ] 27+ cards = +30.
- [ ] 26-26 = no majority +30.
- [ ] J = +1 each.
- [ ] A = +1 each.
- [ ] 2♠ = +2.
- [ ] 10♦ = +3.
- [ ] Basra = +10 each.
- [ ] Multiple scoring bonuses stack correctly.
- [ ] Carry-over 30 after first tie.
- [ ] Carry-over 60 after second consecutive tie.
- [ ] Carry-over is awarded to next round's majority winner.
- [ ] Match ends at >=121.

## Round lifecycle

- [ ] New 4-card deal happens only after all hands are empty.
- [ ] Round ends when deck and hands are exhausted.
- [ ] Remaining table cards go to last successful capturer.
- [ ] Final transfer does not create Basra automatically.
- [ ] Next round resets round-specific state but preserves cumulative score and carry-over.

---

# 27. Important Architecture Rules

### Do

- Keep rules in pure domain/game-engine code.
- Make capture resolution deterministic.
- Keep scoring separate from UI.
- Use existing card/player/session models where compatible.
- Reuse existing animations/components.
- Reuse localization.
- Reuse existing networking/state synchronization.
- Add automated tests.
- Keep the implementation performant on mobile.
- Make the rule engine easy to unit test.

### Do not

- Put capture logic inside widgets.
- Put scoring logic inside widgets.
- Trust client-calculated scores in multiplayer.
- Add a Pass button.
- Assign numeric values to Q/K.
- Treat J as 11.
- Treat all 7s as 7♦.
- Award Basra for J simply because it cleared the table.
- Award Basra for 7♦ without checking its special conditions.
- Create a separate duplicated card/deck system if the existing game already has a reusable one.
- Break other existing game modes while implementing Basra.

---

# 28. Implementation Strategy for the LLM Agent

The agent must work incrementally.

## Phase 1 — Inspect

Before changing code:

1. Inspect the project structure.
2. Identify the existing:
   - card model
   - deck/shuffle implementation
   - player model
   - game state
   - turn manager
   - scoring system
   - networking/session system
   - UI table
   - hand UI
   - captured-card UI
   - localization
   - animations
   - sound system
   - existing game modes
3. Determine which components can be reused.

Do not start by creating duplicate infrastructure.

## Phase 2 — Domain Logic

Implement:

1. Basra card helpers.
2. Initial deal.
3. Special initial-card replacement.
4. Turn validation.
5. Capture engine.
6. J sweep.
7. 7♦ sweep.
8. Basra detection.
9. Round lifecycle.
10. Scoring.
11. Tie carry-over.
12. Match winner detection.

## Phase 3 — Tests

Run all new unit tests.

Then run the existing test suite.

Fix regressions before UI work.

## Phase 4 — Integration

Connect the engine to the existing game/session architecture.

For multiplayer:

- server/authoritative layer validates actions,
- clients render resulting events/state.

## Phase 5 — UI

Add only the Basra-specific UI elements required by the existing design.

## Phase 6 — QA

Test:

- Local game.
- Multiplayer if supported.
- Reconnect/resume if supported.
- Different player counts supported by the project.
- Small-screen mobile devices.
- RTL Arabic UI.
- English UI if the game supports it.
- Round transitions.
- Match ending.
- Tie carry-over.

---

# 29. Acceptance Criteria

The implementation is complete only when:

1. The game can start a Basra round.
2. Initial J/7♦ cards on the table are replaced.
3. First player is not the dealer.
4. Players can only play cards from their own hand.
5. There is no Pass action.
6. Same-rank captures work regardless of suit.
7. Numeric sums work.
8. Q/K are non-numeric.
9. J sweeps the table.
10. 7♦ performs its special sweep.
11. Basra detection follows the exact rules.
12. Final table cards go to the last successful capturer.
13. Round scoring is correct.
14. 26-26 tie carry-over is correct.
15. Match ends at >=121.
16. All rule-engine tests pass.
17. Existing game modes remain functional.
18. No game logic is duplicated in UI.
19. Multiplayer state cannot be manipulated by the client.
20. Performance remains suitable for mobile.

---

# 30. Final Agent Instruction

Implement this mode as a production-quality Basra game mode inside the existing project.

**Do not rewrite unrelated parts of the application.**

**Do not invent rules that are not specified here.**

When an implementation detail is not specified, follow the existing project's architecture and conventions rather than introducing a new framework or pattern.

At the end of the implementation, provide a concise report containing:

- Files created.
- Files modified.
- Main game-engine changes.
- UI changes.
- Tests added.
- Tests executed and their results.
- Any rule ambiguity discovered.
- Any assumptions made.
