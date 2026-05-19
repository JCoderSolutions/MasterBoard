extends Resource
class_name CardData

enum Tipo    { ATAQUE, DEFENSA, UTILIDAD }
enum Rareza  { COMUN, RARA, EPICA, LEGENDARIA }

@export_group("Información Básica")
@export var id: String                    = ""
@export var nombre: String                = ""
@export var costo_energia: int            = 0
@export_multiline var descripcion: String = ""

@export_group("Clasificación")
@export var tipo: Tipo                    = Tipo.ATAQUE
@export var rareza: Rareza                = Rareza.COMUN
@export var efecto_id: String             = ""

@export_group("Arte")
@export var sprite_card: Texture2D        # Arte del frente de la carta
@export var sprite_icon: Texture2D        # Ícono pequeño para la mano (opcional)

@export_group("Balance")
@export var dano_base: int                = 0
@export var curacion_base: int            = 0
@export var duracion_turnos: int          = 0  # 0 = efecto instantáneo
