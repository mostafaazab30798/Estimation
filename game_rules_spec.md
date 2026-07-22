# Kotshina — Bidding Trick-Taking Card Game
## Complete Rule Specification for LLM Implementation Agent

> **Audience**: This document is written in English for the AI/LLM coding agent that will build the Flutter app.
> **App UI language**: The actual game interface, all player-facing text, buttons, labels, and messages MUST be in **Arabic**. Only this specification document is in English.

---

## 0. Project Summary

A 4-player trick-taking bidding card game (similar family to Trix/Tarneeb/Whist) built in Flutter, played over a local WiFi network using a temporary local server for discovery and session sync. Cards are auto-sorted in each player's hand. The round has three phases: **Deal → Auction (bidding) → Trick-taking → Scoring**.

---

## 1. Technical & Architecture Requirements

### 1.1 Networking
- Exactly **4 players**, all connected on the **same WiFi network**.
- One device acts as **host** and runs a **temporary local server** (in-process, not cloud-hosted).
  - Suggested approach: host advertises the session via UDP broadcast or mDNS on the local network so other devices can auto-discover it ("find open games on this WiFi") without manually entering an IP.
  - Once discovered, clients connect to the host via WebSocket (or raw TCP socket) for real-time game state sync.
  - The **host is authoritative**: it owns the canonical game state (deck, hands, bids, trick history, scores) and broadcasts state updates/deltas to all 4 clients after every action.
  - Suggested Flutter/Dart packages to evaluate: `shelf` + `shelf_web_socket` (server), `web_socket_channel` (client), `network_info_plus` (get local WiFi IP), `nsd` or `multicast_dns` (service discovery), or a simple custom UDP broadcast handshake if those prove unreliable.
- This server is **temporary/local only** — no persistence beyond the app session, no external internet dependency required to play.

### 1.2 Card Visual Assets
- The agent should **search for and select a high-quality playing card asset set** (SVG preferred for crisp scaling) before implementing the UI.
- Requirements for the chosen asset pack:
  - Complete 52-card deck + card back design.
  - Clear, legible pip/face/suit rendering at small sizes (mobile hand view) and large sizes (played card on table).
  - **License must be verified** as free for the intended use (e.g., CC0, MIT, or explicit free-commercial-use license). Do not use assets with unclear or restrictive licensing.
- Suit color convention to preserve for readability: ♠/♣ black, ♥/♦ red (standard), unless the chosen asset pack has its own consistent scheme.

---

## 2. Deck & Dealing

- Standard 52-card deck (no jokers).
- 4 players, **13 cards each**.
- Dealing is **one card at a time**, round-robin across the 4 players, until the deck is exhausted (i.e., NOT dealt in batches).

---

## 3. Card Strength Reference (used for sorting and trick resolution)

### 3.1 Rank order (high → low)
```
A > K > Q > J > 10 > 9 > 8 > 7 > 6 > 5 > 4 > 3 > 2
```

### 3.2 Suit priority order (high → low)
```
Spade (♠) > Heart (♥) > Diamond (♦) > Club (♣)
```
This suit priority is used for: (a) hand sorting, (b) comparing bids of equal trick-count in the auction. It is **not** a fixed trump — trump suit is chosen per round during the auction (see Section 5).

---

## 4. Hand Auto-Sort Rule

Each player's hand must be automatically arranged as follows:

1. **Group by suit**, in this fixed order: Spade → Heart → Diamond → Club.
2. **Within each suit group**, order cards by rank descending: A, K, Q, J, 10, 9, 8, 7, 6, 5, 4, 3, 2.

Pseudo sort key (lower = displayed first):
```
suit_rank = { Spade: 0, Heart: 1, Diamond: 2, Club: 3 }
value_rank = { A: 0, K: 1, Q: 2, J: 3, 10: 4, 9: 5, 8: 6, 7: 7, 6: 8, 5: 9, 4: 10, 3: 11, 2: 12 }
sort_key(card) = (suit_rank[card.suit], value_rank[card.value])
```
Sort ascending by `sort_key`.

---

## 5. Auction / Bidding Phase (المزاد)

After dealing completes (and after any redeal check, Section 6), the auction begins.

### 5.1 Turn order
Bidding proceeds turn by turn among the 4 players (define a fixed starting player each round, e.g. rotate dealer/first-bidder each round).

### 5.2 A bid consists of
- `trick_count`: an integer from 1 to 13 — the number of tricks the bidder commits to winning.
- `trump_suit`: the suit chosen to be trump for this round if this bid wins the auction.

### 5.3 Actions available on a player's turn
- **Raise**: submit a new bid that is strictly higher than the current highest bid.
- **Pass**: withdraw from further bidding this round (cannot bid again once passed).

### 5.4 Bid comparison rule (how to "outbid")
A new bid `B` beats the current highest bid `H` if and only if:
```
B.trick_count > H.trick_count
   OR
(B.trick_count == H.trick_count AND suit_priority(B.trump_suit) > suit_priority(H.trump_suit))
```
using the suit priority from Section 3.2 (Spade > Heart > Diamond > Club).

Example: current highest bid is "4, Diamond". A valid raise can be "4, Heart", "4, Spade", or any bid with trick_count ≥ 5 regardless of suit.

### 5.5 End of auction
The auction ends when **all players except the current highest bidder have passed**. The remaining (un-passed) highest bidder becomes **"The Bidder"** (صاحب المزاد) for this round.

### 5.6 Result of auction
- `trump_suit` for the round = The Bidder's winning bid suit.
- The Bidder **leads the first trick** of the round.
- The Bidder's `trick_count` from their winning bid becomes their personal declared target for scoring (see Section 8) — they do not re-declare separately.

---

## 6. Redeal Rule — Void Suit (إعادة التوزيع)

- Immediately after dealing (before the auction begins), any player who has **zero cards of an entire suit** in their 13-card hand may declare this and **request a redeal**.
- If requested, the current deal is cancelled: all cards are collected, reshuffled, and redealt (one at a time, as in Section 2) to all 4 players, then the void-suit check and auction restart fresh.
- *(Assumption: the check/redeal request window is right after dealing and before bidding starts — flagged in Section 11 for confirmation.)*

---

## 7. Post-Auction Individual Declarations (تحديد اللمات)

- After the auction concludes, **each of the 3 non-Bidder players** individually declares how many tricks (0–13) they personally intend to win this round. This is their `declared` value used in scoring (Section 8).
- The Bidder's `declared` value is simply their winning auction `trick_count` (no separate declaration needed — already fixed in Section 5.6).

---

## 8. Trick-Taking Phase (اللمات)

- 13 tricks are played per round (one per card in hand).
- **Trick 1** is led by The Bidder. For each subsequent trick, the **winner of the previous trick leads next**.
- **Follow-suit rule** *(assumption — see Section 11)*: a player must play a card of the led suit if they hold one. If they have no card of the led suit, they may play any card, including a trump card.

### 8.1 Determining the trick winner
1. If **any trump-suit card** was played in this trick: the **highest-ranked trump card played** wins the trick — this overrides everything else, including an Ace of the led suit or any non-trump card.
2. If **no trump card** was played in this trick: the **highest-ranked card of the led suit** wins the trick.
3. Rank comparison uses the rank order from Section 3.1 (A high).

The winner of the trick collects it (adds to their trick count for the round) and leads the next trick.

---

## 9. Scoring (per round, after all 13 tricks are played)

For each of the 4 players, compare `declared` (their target from Section 5.6 or Section 7) vs `actual` (tricks actually won this round):

```
if actual == declared:
    score = actual + round_number
    if player == The Bidder (this round's auction winner):
        score += 10
else:
    score = -abs(declared - actual)
```

Where `round_number` is the 1-based index of the current round within the match (Round 1, Round 2, …).

**Examples**:
- Declared 4, won 4, is The Bidder, round 3 → `4 + 3 + 10 = 17`
- Declared 4, won 4, is NOT The Bidder, round 3 → `4 + 3 = 7`
- Declared 4, won 3 (any role) → `-|4-3| = -1`
- Declared 4, won 5 (any role) → `-|4-5| = -1`

Scores accumulate across rounds into a running total per player.

---

## 10. Round / Match Loop

1. Shuffle & deal (Section 2).
2. Check for void-suit redeal requests (Section 6); repeat step 1 if triggered.
3. Run auction (Section 5).
4. Collect individual declarations from non-Bidder players (Section 7).
5. Play 13 tricks (Section 8).
6. Compute and apply scores (Section 9).
7. Increment `round_number`, start next round.
8. Repeat until match end condition is reached *(NOT specified by the user — see Section 11)*.

---

## 11. Open Points Needing Confirmation

The following were not explicitly specified and were filled with a reasonable default. Please confirm or correct:

| # | Point | Default assumption used |
|---|-------|--------------------------|
| 1 | Match end condition (how many rounds, or first to X points, etc.) | Not implemented — needs a value, e.g. "play until deck/cards run out N times" or "first to 50 points" |
| 2 | Follow-suit obligation | Assumed mandatory: must follow led suit if able |
| 3 | Minimum opening bid in the auction | Assumed 1 trick, any suit |
| 4 | Timing of the void-suit redeal declaration | Assumed: must be declared immediately after dealing, before auction starts |
| 5 | Starting bidder / dealer rotation each round | Assumed: rotates by one seat each round |
| 6 | What happens if all 4 players pass without any bid | Needs a rule (e.g., forced redeal, or lowest-seat forced minimum bid) |

---

## 12. Glossary (Arabic ↔ term used in this doc)

| Arabic | English term used here |
|---|---|
| كوتشينة | Playing cards / the deck |
| المزاد | Auction / bidding phase |
| القطوع | Trump suit |
| اللمة / اللمات | Trick / tricks |
| صاحب المزاد | The Bidder (auction winner) |
| الراوند | Round |
