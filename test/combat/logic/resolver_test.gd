extends GdUnitTestSuite

## Tests del contrato Command/Event/Resolver (backlog 1.2).
##
## Todavía no existe ningún comando de verdad —el primero es `MoveCommand`, tarea
## 1.4—, así que aquí se usan dos comandos de mentira que solo sirven para verificar
## que el contrato se respeta.


## Golpea a una unidad y narra lo ocurrido. Emite `UnitDamaged` siempre y, si el
## golpe fue letal, además `UnitDied` — en ese orden.
class GolpeDePrueba extends Command:
	var target_id: int
	var amount: int

	func _init(p_target_id: int, p_amount: int) -> void:
		target_id = p_target_id
		amount = p_amount

	func validate(state: CombatState) -> bool:
		var target := state.unit_by_id(target_id)
		return target != null and target.is_alive()

	func apply(state: CombatState) -> Array[Event]:
		var target := state.unit_by_id(target_id)
		var hp_before := target.hp
		target.take_damage(amount)

		var events: Array[Event] = []
		events.append(UnitDamaged.new(target_id, hp_before - target.hp, target.hp))
		if not target.is_alive():
			events.append(UnitDied.new(target_id, UnitDied.Cause.DAMAGE))
		return events


## Consume el RNG del estado. Sirve para comprobar que dos combates con la misma
## semilla y los mismos comandos terminan idénticos (A-03).
class GolpeAleatorioDePrueba extends Command:
	var target_id: int

	func _init(p_target_id: int) -> void:
		target_id = p_target_id

	func validate(state: CombatState) -> bool:
		var target := state.unit_by_id(target_id)
		return target != null and target.is_alive()

	func apply(state: CombatState) -> Array[Event]:
		var target := state.unit_by_id(target_id)
		var roll := state.rng.randi_range(1, 6)
		var hp_before := target.hp
		target.take_damage(roll)

		var events: Array[Event] = []
		events.append(UnitDamaged.new(target_id, hp_before - target.hp, target.hp))
		return events


func test_comando_valido_muta_el_estado_y_devuelve_eventos() -> void:
	var state := CombatState.new()
	var orc := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 0), 5)
	var resolver := Resolver.new()

	var events := resolver.execute(state, GolpeDePrueba.new(orc.id, 3))

	assert_int(orc.hp).is_equal(2)
	assert_array(events).has_size(1)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_DAMAGED)


## Un comando ilegal no debe dejar el estado a medias.
func test_comando_invalido_no_toca_el_estado() -> void:
	var state := CombatState.new()
	var orc := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 0), 5)
	orc.kill()
	var resolver := Resolver.new()

	var events := resolver.execute(state, GolpeDePrueba.new(orc.id, 3))

	assert_array(events).is_empty()
	assert_int(orc.hp).is_equal(0)
	assert_array(resolver.history).is_empty()


## `history` es lo que hace posibles el undo y el replay: si registrara comandos
## rechazados, reproducirlo daría un combate distinto al original.
func test_history_solo_registra_lo_aplicado() -> void:
	var state := CombatState.new()
	var orc := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 0), 5)
	var resolver := Resolver.new()

	var aplicado := GolpeDePrueba.new(orc.id, 1)
	var inexistente := GolpeDePrueba.new(999, 1)

	resolver.execute(state, aplicado)
	resolver.execute(state, inexistente)

	assert_array(resolver.history).contains_exactly([aplicado])


func test_can_execute_no_muta_nada() -> void:
	var state := CombatState.new()
	var orc := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 0), 5)
	var resolver := Resolver.new()
	var command := GolpeDePrueba.new(orc.id, 3)

	assert_bool(resolver.can_execute(state, command)).is_true()
	assert_bool(resolver.can_execute(state, command)).is_true()

	assert_int(orc.hp).is_equal(5)
	assert_array(resolver.history).is_empty()


## La vista reproduce los eventos en secuencia (1.17): si la muerte llegara antes
## que el golpe, animaría al muerto recibiendo daño.
func test_los_eventos_salen_en_orden_cronologico() -> void:
	var state := CombatState.new()
	var orc := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 0), 5)
	var resolver := Resolver.new()

	var events := resolver.execute(state, GolpeDePrueba.new(orc.id, 99))

	assert_array(events).has_size(2)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_DAMAGED)
	assert_int(events[1].type).is_equal(Event.Type.UNIT_DIED)


## Si a una unidad con 2 de vida le pegas 99, el evento debe decir 2. La vista no
## puede mostrar un "-99" sobre una barra que solo bajó 2.
func test_unit_damaged_reporta_el_dano_efectivo() -> void:
	var state := CombatState.new()
	var orc := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 0), 2)
	var resolver := Resolver.new()

	var events := resolver.execute(state, GolpeDePrueba.new(orc.id, 99))
	var damaged: UnitDamaged = events[0]

	assert_int(damaged.amount).is_equal(2)
	assert_int(damaged.hp_after).is_equal(0)


func test_unit_died_distingue_caida_de_dano() -> void:
	var por_dano := UnitDied.new(1, UnitDied.Cause.DAMAGE)
	var por_caida := UnitDied.new(2, UnitDied.Cause.FALL)

	assert_int(por_dano.cause).is_equal(UnitDied.Cause.DAMAGE)
	assert_int(por_caida.cause).is_equal(UnitDied.Cause.FALL)
	assert_int(por_dano.type).is_equal(por_caida.type)


## La vista interpola de `from` a `to`, y cuando recibe el evento la unidad ya está
## en `to`. Sin el origen dentro del evento, no habría de dónde sacarlo.
func test_unit_moved_conserva_origen_y_destino() -> void:
	var moved := UnitMoved.new(7, Vector2i(1, 1), Vector2i(1, 2))

	assert_int(moved.unit_id).is_equal(7)
	assert_that(moved.from).is_equal(Vector2i(1, 1))
	assert_that(moved.to).is_equal(Vector2i(1, 2))


## El caso que sostiene A-02 entero: misma semilla + mismos comandos = mismo combate.
## Sin esto no hay replay, ni reproducir bugs por semilla, ni multijugador.
func test_mismos_comandos_y_semilla_producen_el_mismo_estado() -> void:
	var hp_a := _correr_combate_de_prueba(48211)
	var hp_b := _correr_combate_de_prueba(48211)
	var hp_otra_semilla := _correr_combate_de_prueba(1)

	assert_array(hp_a).contains_exactly(hp_b)
	assert_array(hp_a).is_not_equal(hp_otra_semilla)


func _correr_combate_de_prueba(seed_value: int) -> Array[int]:
	var state := CombatState.new(seed_value)
	var orc := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 0), 40)
	var resolver := Resolver.new()

	var hp_por_turno: Array[int] = []
	for i in 5:
		resolver.execute(state, GolpeAleatorioDePrueba.new(orc.id))
		hp_por_turno.append(orc.hp)
	return hp_por_turno
