extends Node

# ── Señales de combate ──────────────────────────────────────────
signal card_played(card_data: CardData, user_id: int)
signal turn_changed(player_id: int)
signal timer_updated(player_id: int, seconds_remaining: float)
signal timer_expired(player_id: int)
signal battler_damaged(target_id: int, amount: int)
signal battler_healed(target_id: int, amount: int)
signal battler_defeated(target_id: int)
signal game_state_changed(new_state: int)

# ── Señales de navegación ───────────────────────────────────────
signal character_selected(player_id: int, character_data: CharacterData)
signal arena_selected(platform_data: PlatformData)
signal match_started()
signal match_ended(winner_id: int)
