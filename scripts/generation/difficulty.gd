class_name DifficultySettings
extends RefCounted
## Owns tuning data, not combat or UI. Spawners and Ledger read the same profile.
## Add a mode here to expose it automatically in the title selector.
## hp/speed/damage/rate multiply enemy base stats; budget sets encounter density.
## reward multiplies drops; score multiplies the final score exactly once.
## cap limits living enemies + arrival reservations, including boss summons.
const MODES: Dictionary = {
	"easy":{"name":"EASY","description":"Union-mandated working conditions.","hp":1.0,"speed":1.0,"damage":1.0,"rate":1.0,"projectiles":1.0,"budget":0.8,"elite":0.04,"reward":1.0,"score":1.0,"cap":6,"boss_hp":60,"boss_cash":30,"ot_cash":30,"ot_score":650,"ot_interval":3.0,"exit_fee":50,"clear_bonus":1.0,"boss_adds":2,"boss_recovery":1.8,"boss_warning":1.2,"boss_combo":0.0},
	"normal":{"name":"NORMAL","description":"Standard corporate policy.","hp":1.2,"speed":1.1,"damage":1.0,"rate":1.1,"projectiles":1.1,"budget":1.0,"elite":0.1,"reward":1.15,"score":1.5,"cap":8,"boss_hp":75,"boss_cash":45,"ot_cash":50,"ot_score":1000,"ot_interval":2.5,"exit_fee":90,"clear_bonus":1.2,"boss_adds":3,"boss_recovery":1.45,"boss_warning":1.05,"boss_combo":0.18},
	"hard":{"name":"HARD","description":"Management has noticed you.","hp":1.5,"speed":1.2,"damage":1.25,"rate":1.2,"projectiles":1.2,"budget":1.3,"elite":0.19,"reward":1.3,"score":2.0,"cap":10,"boss_hp":95,"boss_cash":70,"ot_cash":75,"ot_score":1500,"ot_interval":2.0,"exit_fee":140,"clear_bonus":1.4,"boss_adds":4,"boss_recovery":1.15,"boss_warning":0.9,"boss_combo":0.38},
	"brutal":{"name":"BRUTAL","description":"Shareholder expectations are high.","hp":2.0,"speed":1.35,"damage":1.5,"rate":1.35,"projectiles":1.3,"budget":1.7,"elite":0.3,"reward":1.5,"score":3.0,"cap":12,"boss_hp":120,"boss_cash":100,"ot_cash":110,"ot_score":2200,"ot_interval":1.55,"exit_fee":200,"clear_bonus":1.6,"boss_adds":5,"boss_recovery":0.85,"boss_warning":0.8,"boss_combo":0.65}
}
static func profile(id: String) -> Dictionary:
	return MODES.get(id,MODES.easy)

# Delayed observations of visible movement, with partial rather than perfect lead.
const AI: Dictionary = {
	"easy":{"reaction":0.65,"prediction":0.10,"lead":0.10,"flank":0.04,"coordination":0.10,"acceleration":430.0,"warning":0.90},
	"normal":{"reaction":0.40,"prediction":0.35,"lead":0.35,"flank":0.16,"coordination":0.35,"acceleration":570.0,"warning":0.80},
	"hard":{"reaction":0.25,"prediction":0.65,"lead":0.65,"flank":0.32,"coordination":0.65,"acceleration":740.0,"warning":0.70},
	"brutal":{"reaction":0.14,"prediction":0.90,"lead":0.88,"flank":0.50,"coordination":1.0,"acceleration":940.0,"warning":0.62}
}
# Applied only to actors created for an optional shift. Normal rooms stay unchanged.
const OVERTIME: Dictionary = {
	"easy":{"hp":2.0,"speed":1.65,"damage":1.10,"rate":1.55,"prediction":0.55,"reaction":0.24,"zone_interval":5.0,"zone_size":104.0,"zone_warning":1.25,"elite":0.05},
	"normal":{"hp":2.15,"speed":1.90,"damage":1.15,"rate":1.70,"prediction":0.70,"reaction":0.20,"zone_interval":4.5,"zone_size":112.0,"zone_warning":1.15,"elite":0.10},
	"hard":{"hp":2.30,"speed":2.15,"damage":1.20,"rate":1.90,"prediction":0.82,"reaction":0.16,"zone_interval":4.0,"zone_size":124.0,"zone_warning":1.0,"elite":0.18},
	"brutal":{"hp":2.50,"speed":2.40,"damage":1.25,"rate":2.10,"prediction":0.95,"reaction":0.12,"zone_interval":3.4,"zone_size":136.0,"zone_warning":0.90,"elite":0.27}
}
static func exit_fee(id: String) -> int:
	return profile(id).exit_fee

static func overtime_profile(id: String) -> Dictionary:
	return OVERTIME.get(id,OVERTIME.easy)

static func ai_profile(id: String, overtime: bool = false) -> Dictionary:
	var result: Dictionary = AI.get(id,AI.easy).duplicate()
	if overtime:
		var pressure: Dictionary = overtime_profile(id)
		result.reaction = minf(result.reaction,pressure.reaction)
		result.prediction = maxf(result.prediction,pressure.prediction)
		result.lead = maxf(result.lead,pressure.prediction)
		result.flank = maxf(result.flank,0.45)
		result.coordination = maxf(result.coordination,0.65)
		result.acceleration *= 1.5
	return result
