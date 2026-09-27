class_name DifficultySettings
extends RefCounted
## Owns tuning data, not combat or UI. Spawners and Ledger read the same profile.
## Add a mode here to expose it automatically in the title selector.
## hp/speed/damage/rate multiply enemy base stats; budget sets encounter density.
## reward multiplies drops; score multiplies the final score exactly once.
## cap limits living enemies + arrival reservations, including boss summons.
const MODES: Dictionary = {
	"easy":{"name":"EASY","description":"Union-mandated working conditions.","hp":1.0,"speed":1.0,"damage":1.0,"rate":1.0,"projectiles":1.0,"budget":0.8,"elite":0.04,"reward":1.0,"score":1.0,"cap":6,"boss_hp":60,"boss_cash":30,"ot_cash":25,"ot_score":500,"ot_interval":3.6},
	"normal":{"name":"NORMAL","description":"Standard corporate policy.","hp":1.2,"speed":1.1,"damage":1.0,"rate":1.1,"projectiles":1.1,"budget":1.0,"elite":0.10,"reward":1.15,"score":1.5,"cap":8,"boss_hp":75,"boss_cash":35,"ot_cash":30,"ot_score":750,"ot_interval":3.0},
	"hard":{"name":"HARD","description":"Management has noticed you.","hp":1.5,"speed":1.2,"damage":1.25,"rate":1.2,"projectiles":1.2,"budget":1.3,"elite":0.19,"reward":1.3,"score":2.0,"cap":10,"boss_hp":95,"boss_cash":40,"ot_cash":40,"ot_score":1100,"ot_interval":2.5},
	"brutal":{"name":"BRUTAL","description":"Shareholder expectations are high.","hp":2.0,"speed":1.35,"damage":1.5,"rate":1.35,"projectiles":1.3,"budget":1.7,"elite":0.30,"reward":1.5,"score":3.0,"cap":12,"boss_hp":120,"boss_cash":45,"ot_cash":50,"ot_score":1600,"ot_interval":2.0}
}
static func profile(id: String) -> Dictionary:
	return MODES.get(id,MODES.easy)
