extends Node

## Pendiente de 1.8: esta clase pasa a llamarse `AbilityDatabase` y `CardData` a
## `Ability` (A-04/A-14). No se renombra todavía porque el autoload vive en
## `project.godot` y el tipo que devuelve se reescribe entero con el recurso
## componible. Aquí solo se corrige la ruta, que el renombrado de `resources/`
## dejó apuntando a una carpeta inexistente.

var _loaded_cards: Dictionary = {}

func get_card(card_id: String) -> CardData:
	if _loaded_cards.has(card_id):
		return _loaded_cards[card_id]
	var path := "res://resources/abilities/%s.tres" % card_id
	if not ResourceLoader.exists(path):
		push_error("CardDatabase: habilidad no encontrada -> %s" % card_id)
		return null
	var card: CardData = load(path)
	_loaded_cards[card_id] = card
	return card

func preload_cards(card_ids: Array[String]) -> void:
	for id in card_ids:
		get_card(id)

func clear_cache() -> void:
	_loaded_cards.clear()
