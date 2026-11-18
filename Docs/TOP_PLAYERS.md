# Rivet Rise — TOP PLAYERS (weekly building league)

Status: wired to the Rivet Rise Supabase weekly league. UI tests keep deterministic mock data.

## What the player sees
Hoist pendant → **Top** (floor 6) → `TopPlayersView`:
- **League plate** (native): current *building league* from this week's tallest tower.
  Scaffold 0+ · Girder 20+ · Gold Rivet 35+ · Skyline 50+ floors, plus "N floors to next league".
- **Top 5** tab: the weekly leaderboard, season details, player ranking and reward slots.
  It shows the season name, a week countdown (resets Monday 00:00 UTC), the top 5, the player's own row
  if they are outside the top 5, and **3 weekly reward slots** with exclusive cosmetics:
  `#1 Gold Leaf Jib` (`crane.jib.gold`), `#2–3 Neon Crown` (`roof.crown.neon`), `#4–5 Chrome Hook` (`hook.chrome`).
  Slot states: locked / pending (holding the rank) / claimable / claimed.
- **Site Orders** tab (native, works fully offline): 4 weekly tasks for precision and rivet streaks,
  each paid once per ISO week in bolts:
  Rivet Crew (40 rivets/week, 120) · Plumb Perfect (10 perfects in one shift, 150) ·
  Zoning Board (3 districts in one shift, 100) · High Rise Permit (30 floors, 200).

## Code map
| Piece | File |
|---|---|
| Week keys, leagues, orders (pure, tested) | `Models/WeeklyLeague.swift` |
| Backend contract, payload types, mock | `Services/LeaderboardService.swift` |
| Screen | `ViewModels/TopPlayersViewModel.swift`, `Views/Board/TopPlayersView.swift` |
| Weekly shifts and order claims | `ProfileStore.shifts(inWeekOf:)`, `claimOrder(_:on:)`, `PlayerProfile.claimedOrderKeys` |
| Shift submission hook | `GameViewModel.submitToLeague(_:)` (called after `recordRun`) |

## Backend contract

1. `SupabaseLeaderboardService` signs in anonymously and stores its refresh credential in Keychain.
2. `weekly-board` returns the server-ranked board, the player's row, and each reward state.
3. Every completed shift submits its UUID, week, floors, score, rivets, perfects, districts, duration and foreman.
   The server validates and deduplicates submissions.
4. Reward claims are checked and recorded by Supabase after the ISO week closes.
5. The weekly board renders server-provided leaderboard and reward data.


## Known limits

- Reward claim records are server-side; the awarded cosmetics are not yet rendered on the crane, roof or hook.
- Weekly Site Orders continue to work offline and are stored on the device; they are not part of the online leaderboard.
- Anonymous leaderboard profiles are device-bound unless the player account is later linked to a sign-in method.
- The board starts empty until players submit real shifts; the former rival rows were mock examples, not seeded players.

## Next hooks (proposed, not built)
- League stipend (`BuildingLeague.weeklyStipend`) paid at week close by the server.
- Cosmetic rendering in `TowerScene` (jib tint, penthouse crown glow, chrome hook texture).
- Season pass of 4 weeks with a themed skyline backdrop per season.
