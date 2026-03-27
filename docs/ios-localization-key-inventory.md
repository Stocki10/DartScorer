# iOS Localization Key Inventory

This inventory is for the iOS app only and is intended as the concrete source list for `Localizable.xcstrings`.

Recommended locales:

- `en`
- `de`
- `nl`

Recommended conventions:

- Use `screen.section.label` style keys for static UI
- Use `message.*` keys for dynamic status strings
- Use parameterized values for player names, counts, and rule summaries
- Use plural rules for `game`, `games`, `leg`, `legs`, `device`, `devices`

## 1. DartsGameView.swift

### Static UI

- `game.winner.title.leg_won`
  - `Leg Won`
- `game.winner.title.winner`
  - `Winner`
- `game.winner.subtitle.practice`
  - `Practice session.`
- `game.winner.subtitle.cricket`
  - `Closed all targets and finished ahead.`
- `game.winner.subtitle.match_complete`
  - `Match complete.`
- `game.alert.player_disconnected.title`
  - `Player Disconnected`
- `game.alert.player_disconnected.ok`
  - `OK`
- `game.alert.restart_leg.title`
  - `Restart Leg?`
- `game.alert.restart_leg.cancel`
  - `Cancel`
- `game.alert.restart_leg.confirm`
  - `Restart Leg`
- `game.alert.restart_leg.message`
  - `You already started this leg. This will discard current progress.`
- `game.alert.leave_session.title`
  - `Leave Local Multiplayer Session?`
- `game.alert.leave_session.cancel`
  - `Cancel`
- `game.alert.leave_session.confirm`
  - `Leave Session`
- `game.alert.leave_session.message.host`
  - `This will end the session for all connected devices.`
- `game.alert.leave_session.message.joiner`
  - `You will be disconnected from the host's game.`

### Dynamic / parameterized

- `game.winner.subtitle.rules`
  - `Played %@, %@.`
  - args: `in rule label`, `out rule label`
- `game.alert.player_disconnected.message.active`
  - `%@ has left the session.`
- `game.alert.player_disconnected.message.ended`
  - `%@ left — multiplayer session ended.`
- `game.rule.in.default`
  - `default-in`
- `game.rule.in.double`
  - `double-in`
- `game.rule.out.single`
  - `single-out`
- `game.rule.out.double`
  - `double-out`

## 2. GameScreenComponents.swift

### Input mode / score entry

- `input.mode.throws`
  - `Throws`
- `input.mode.quick`
  - `Quick`
- `input.quick.no_score`
  - `No Score`
- `input.quick.enter_score`
  - `Enter score`
- `input.quick.finish_current_visit`
  - `Finish the current visit in Throws mode.`
- `input.quick.more`
  - `•••`

### Multiplier / throw entry

- `input.multiplier.title`
  - `Multiplier`
- `input.multiplier.single`
  - `Single`
- `input.multiplier.double`
  - `Double`
- `input.multiplier.triple`
  - `Triple`
- `input.segment.bull`
  - `Bull`

### Checkout / status

- `checkout.bogey`
  - `Bogey — no finish possible`
- `checkout.none`
  - `No finish available`

### Cricket board / visit history

- `cricket.visit.none`
  - `No throw`
- `game.reconnect.status`
  - `Reconnecting…`
- `game.reconnect.abort`
  - `Abort Connection`

### Scoreboard / stats

- `game.average.short`
  - `⌀ %@`

## 3. WinnerOverlayView.swift

- `winner.action.new_leg_random`
  - `New Leg (Random)`
- `winner.action.new_game`
  - `New Game`
- `winner.action.start_new_game`
  - `Start New Game`

## 4. NewGameSetupView.swift

### Navigation / actions

- `setup.title`
  - `New Game`
- `setup.action.cancel`
  - `Cancel`
- `setup.action.start`
  - `Start`

### Section headers

- `setup.section.game_settings`
  - `Game Settings`
- `setup.section.player_order`
  - `Player Order`
- `setup.section.local_multiplayer`
  - `Local Multiplayer`

### Labels

- `setup.mode.label`
  - `Mode`
- `setup.players.label`
  - `Players: %@`
- `setup.start_score.label`
  - `Game`
- `setup.finish_mode.label`
  - `Finish Mode`
- `setup.in_mode.label`
  - `In Mode`
- `setup.set_mode.label`
  - `Set Mode`
- `setup.legs_to_win.label`
  - `Legs to Win: %@`
- `setup.input_mode.label`
  - `Input Mode`
- `setup.undo.label`
  - `Undo`

### Descriptions

- `setup.description.x01`
  - `Start on %@ and check out with %@, %@ rules.`
- `setup.description.practice`
  - `Score keeps going up. Turns rotate after three darts and there is no bust or checkout.`
- `setup.description.cricket`
  - `Hit 20 through 15 and Bull to close them. Extra marks score only if opponents are still open.`
- `setup.player_order.help`
  - `Drag rows to set the throw sequence.`

### Multiplayer labels

- `setup.multiplayer.host_game`
  - `Host a Game`
- `setup.multiplayer.join_game`
  - `Join a Game`
- `setup.multiplayer.hosting`
  - `Hosting: %@`
- `setup.multiplayer.waiting`
  - `Waiting for devices to join…`
- `setup.multiplayer.connected_devices`
  - `%@ device(s) connected`
- `setup.multiplayer.manage_players`
  - `Manage Players`
- `setup.multiplayer.stop`
  - `Stop Local Multiplayer`
- `setup.multiplayer.connecting`
  - `Connecting…`
- `setup.multiplayer.game_starting`
  - `Game Starting`
- `setup.multiplayer.joined_waiting`
  - `Joined — Waiting for host to start`
- `setup.multiplayer.leave`
  - `Leave Session`

### Game mode display labels

- `game_mode.x01`
  - `X01`
- `game_mode.practice`
  - `Practice`
- `game_mode.cricket`
  - `Cricket`

## 5. MultiplayerSetupView.swift

- `multiplayer.host.title`
  - `Hosting`
- `multiplayer.join.title`
  - `Join Game`
- `multiplayer.share_qr`
  - `Share this QR code with other players`
- `multiplayer.section.connected_devices`
  - `Connected Devices (%@/4)`
- `multiplayer.device.host`
  - `This device (Host)`
- `multiplayer.section.player_assignments`
  - `Player Assignments`
- `multiplayer.assignment.unassigned`
  - `Unassigned`
- `multiplayer.action.cancel`
  - `Cancel`
- `multiplayer.action.done`
  - `Done`
- `multiplayer.join.scan_prompt`
  - `Point the camera at the host's QR code`
- `multiplayer.join.connecting`
  - `Connecting…`
- `multiplayer.join.secure_connection`
  - `Establishing a secure connection with the host`
- `multiplayer.join.joined`
  - `Joined Game`
- `multiplayer.join.waiting`
  - `Waiting for host to start…`
- `multiplayer.join.connected_to`
  - `Connected to %@`
- `multiplayer.join.starting`
  - `Game Starting`

## 6. GameHistoryView.swift

### Empty / navigation

- `history.empty.title`
  - `No Games Yet`
- `history.empty.description`
  - `Completed games will appear here.`
- `history.title`
  - `History`
- `history.action.back`
  - `Back`
- `history.action.clear`
  - `Clear`
- `history.alert.clear.title`
  - `Clear History?`
- `history.alert.clear.cancel`
  - `Cancel`
- `history.alert.clear.confirm`
  - `Clear All`
- `history.alert.clear.message`
  - `This will permanently delete all saved game history.`

### Match summary

- `history.match_summary.title`
  - `Match Summary`
- `history.match_summary.date`
  - `Date`
- `history.match_summary.format`
  - `Format`
- `history.match_summary.winner`
  - `Winner`
- `history.match_summary.total_legs`
  - `Total Legs`
- `history.legs.title`
  - `Legs`
- `history.player_summary.title`
  - `Player Summary`

### Player summary stats

- `history.legs_won`
  - `Legs won: %@`
- `history.stat.score`
  - `Score`
- `history.stat.average`
  - `Average`
- `history.stat.darts`
  - `Darts`
- `history.stat.best_turn`
  - `Best Turn`
- `history.stat.scoring_average`
  - `Scoring Avg`
- `history.stat.best_finish`
  - `Best Finish`

### Leg detail

- `history.leg.single`
  - `Leg`
- `history.leg.numbered`
  - `Leg %@`
- `history.finish`
  - `Finish: %@`
- `history.darts_short`
  - `Darts %@`
- `history.first_nine_short`
  - `First 9 %@`
- `history.detail.winner`
  - `Winner`
- `history.detail.checkout`
  - `Checkout`
- `history.detail.finish`
  - `Finish`
- `history.detail.per_player_breakdown`
  - `Per-Player Breakdown`
- `history.detail.started`
  - `Started`
- `history.stat.first_nine`
  - `First 9`
- `history.stat.busts`
  - `Busts`
- `history.value.em_dash`
  - `—`

### Format labels

- `history.format.score_and_finish`
  - `%@ • %@`

## 7. PlayerProfileView.swift

### Empty / navigation

- `profiles.empty.title`
  - `No Profiles`
- `profiles.empty.description`
  - `Add a profile to track your stats across games.`
- `profiles.title`
  - `Profiles`
- `profiles.action.back`
  - `Back`
- `profiles.action.add`
  - `Add`
- `profiles.action.cancel`
  - `Cancel`
- `profiles.action.save`
  - `Save`
- `profiles.edit.title`
  - `Edit Profile`
- `profiles.new.title`
  - `New Profile`
- `profiles.select.title`
  - `Select Profile`

### Labels / sections

- `profiles.section.profile`
  - `Profile`
- `profiles.section.stats`
  - `Stats`
- `profiles.section.overview`
  - `Overview`
- `profiles.section.scoring`
  - `Scoring`
- `profiles.section.finishing`
  - `Finishing`
- `profiles.field.name`
  - `Name`
- `profiles.field.color`
  - `Color`
- `profiles.avg_and_games`
  - `Avg %@  ·  %@ games`
- `profiles.games_short`
  - `%@ games`
- `profiles.no_profile`
  - `No Profile`
- `profiles.in_use`
  - `In use`

### Stat labels

- `profiles.stat.games`
  - `Games`
- `profiles.stat.wins`
  - `Wins`
- `profiles.stat.win_rate`
  - `Win Rate`
- `profiles.stat.average`
  - `Average`
- `profiles.stat.first_nine_average`
  - `First 9 Avg`
- `profiles.stat.best_turn`
  - `Best Turn`
- `profiles.stat.highest_score`
  - `Highest Score`
- `profiles.stat.count_180`
  - `180 Count`
- `profiles.stat.count_140_plus`
  - `140+ Count`
- `profiles.stat.checkout_percentage`
  - `Checkout %`
- `profiles.stat.best_checkout`
  - `Best Checkout`

## 8. SettingsPopupView.swift

- `settings.title`
  - `Settings`
- `settings.close.accessibility`
  - `Close settings`
- `settings.theme`
  - `Theme`
- `settings.color`
  - `Color`
- `settings.accent_color`
  - `Accent Color`
- `settings.buy_me_a_coffee`
  - `Buy Me a Coffee`
- `settings.buy_me_a_coffee.hint`
  - `Opens the Buy Me a Coffee page in your browser`
- `settings.action.cancel`
  - `Cancel`
- `settings.action.save`
  - `Save`

## 9. DartsGame.swift

These are model-layer strings and should move to localized lookup instead of being stored as raw English.

### Status / validation messages

- `message.invalid_throw`
  - `Invalid throw.`
- `message.win.set`
  - `%@ wins the set.`
- `message.win.leg`
  - `%@ wins the leg.`
- `message.quick_score.unavailable_in_cricket`
  - `Quick score is unavailable in Cricket.`
- `message.quick_score.finish_current_visit`
  - `Finish the current visit in Throws mode.`
- `message.quick_score.range`
  - `Quick scores must be between 1 and 180.`
- `message.quick_score.finish_opening_double`
  - `Finish the opening double in Throws mode.`
- `message.practice_mode`
  - `Practice mode`
- `message.cricket.instructions`
  - `Close all numbers and finish level or ahead.`
- `message.win.cricket`
  - `%@ wins Cricket.`

### Rule / enum display labels

- `finish_rule.double_out`
  - `Double Out`
- `finish_rule.single_out`
  - `Single Out`
- `in_rule.default`
  - `Default`
- `in_rule.double_in`
  - `Double In`

### Throw notation

These may stay untranslated if the dart notation should remain sport-standard:

- `notation.double`
  - `D%@`
- `notation.triple`
  - `T%@`

## 10. DartThrow.swift

If surfaced directly in UI, localize:

- `dart.multiplier.single`
  - `Single`
- `dart.multiplier.double`
  - `Double`
- `dart.multiplier.triple`
  - `Triple`
- `dart.segment.bull`
  - `Bull`
- `dart.display_text`
  - `%@ %@ (%@)`

## 11. NetworkGameState.swift

### Input mode labels

- `multiplayer.input_mode.own_only`
  - `Own Only`
- `multiplayer.input_mode.others_only`
  - `Others Only (Referee)`
- `multiplayer.input_mode.free`
  - `Free`

### Input mode explanations

- `multiplayer.input_mode.own_only.explanation`
  - `You can only enter your own scores`
- `multiplayer.input_mode.others_only.explanation`
  - `You enter scores for your opponent`
- `multiplayer.input_mode.free.explanation`
  - `Any player can enter any score`

### Undo permission labels

- `multiplayer.undo.any_player`
  - `Any Player`
- `multiplayer.undo.host_only`
  - `Host Only`

## 12. Remaining fallback/default labels

These should be reviewed because they are user-visible defaults:

- `player.default.numbered`
  - `Player %@`
- `player.default.one`
  - `Player 1`
- `player.default.two`
  - `Player 2`

## 13. Formatting And Plurals

Use localized formatting for:

- dates in history
- averages and decimals
- percentages

Use plural entries for:

- `history.total_legs`
- `profiles.games_short`
- `setup.players.label`
- `setup.multiplayer.connected_devices`

## 14. Likely Not Needed For Translation

These are probably safe to keep as-is unless product wants full terminology translation:

- dart shorthand like `D20`, `T19`
- numeric checkout routes
- QR/session token values
- player IDs and assignment identifiers

## 15. Suggested Next Implementation Order

1. Localize all SwiftUI screen text in:
   - `DartsGameView.swift`
   - `GameScreenComponents.swift`
   - `NewGameSetupView.swift`
   - `GameHistoryView.swift`
   - `PlayerProfileView.swift`
   - `SettingsPopupView.swift`
   - `MultiplayerSetupView.swift`
2. Move dynamic game messages in `DartsGame.swift` to localized lookups.
3. Localize enum display labels in:
   - `DartsGame.swift`
   - `DartThrow.swift`
   - `NetworkGameState.swift`
4. Add `de` translations.
5. Add `nl` translations.
6. Run layout QA for long strings.
