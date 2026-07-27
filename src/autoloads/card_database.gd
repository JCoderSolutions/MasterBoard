extends Node

var _loaded_cards: Dictionary = {}

func get_card(card_id: String) -> CardData:
	if _loaded_cards.has(card_id):
		return _loaded_cards[card_id]
	var path := "res://resources/cards/%s.tres" % card_id
	if not ResourceLoader.exists(path):
		push_error("CardDatabase: carta no encontrada -> %s" % card_id)
		return null
	var card: CardData = load(path)
	_loaded_cards[card_id] = card
	return card

func preload_cards(card_ids: Array[String]) -> void:
	for id in card_ids:
		get_card(id)

func clear_cache() -> void:
	_loaded_cards.clear()
