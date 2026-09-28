class_name EncounterGenerator
extends RefCounted
## Owns one seeded RNG and generated room snapshots. Never spawns live nodes.
## Layouts, enemy definitions, difficulty and story milestones are separate data.
## A seed reproduces geometry/composition; low-cash relief changes only a pickup.
var rng := RandomNumberGenerator.new()
var run_seed: int = 0
var difficulty: String = "easy"
var cache: Dictionary = {}
var recent_layouts: Array[String] = []
var recent_types: Array[int] = []
var last_name: String = ""
const NAMES: Array[String] = ["ACCOUNTS PAYABLE","LEGAL AFFAIRS","HUMAN RESOURCES","COMPLIANCE","DEBT RECOVERY","MARKET OPERATIONS","RISK MANAGEMENT","CLAIMS DEPARTMENT"]

func begin(mode: String, seed_value: int = -1) -> void:
	difficulty = mode
	if seed_value<0: rng.randomize()
	else: rng.seed = seed_value
	run_seed = rng.seed
	cache.clear()
	recent_layouts.clear()
	recent_types.clear()
	last_name = ""

func budget_for(standard_room: int) -> int:
	return maxi(4,roundi((4+standard_room*2)*DifficultySettings.profile(difficulty).budget))

func generate(index: int, money: int = 100) -> Dictionary:
	if cache.has(index): return cache[index]
	var config: Dictionary = Rooms.DATA[index].duplicate(true)
	config.standard_room = maxi(0,index-2)
	config.enemies = [] if index>=3 else config.enemies
	config.waves = []
	config.spawn_plan = []
	config.encounter_budget = 0
	# Shop terminals have their own lane so their world labels cannot cover upgrades.
	if index in [6,10]: config.overtime_at = [790,535]
	elif index in [12,Rooms.EXIT_INDEX]: config.overtime_at = [260,390]
	if index<3 or config.get("shop",false) or config.get("exit",false) or config.get("boss",false):
		config.template_id = "orientation" if index<3 else "open"
		cache[index] = config
		return config
	var standard: int = config.standard_room
	var candidates: Array[Dictionary] = []
	for template in RoomTemplates.DATA:
		if template.id in recent_layouts: continue
		if standard<3 and template.id in ["hazard","toll"]: continue
		candidates.append(template)
	var layout: Dictionary = candidates[rng.randi_range(0,candidates.size()-1)]
	if index==5: layout = RoomTemplates.get_template("toll")
	if config.get("inflation",false): layout = RoomTemplates.get_template("hazard")
	config.template_id = layout.id
	for key in ["desks","hazards","tolls"]: config[key] = layout[key].duplicate(true)
	recent_layouts.append(layout.id)
	if recent_layouts.size()>2: recent_layouts.pop_front()
	var names: Array[String] = []
	for title in NAMES:
		if title!=last_name: names.append(title)
	last_name = names[rng.randi_range(0,names.size()-1)]
	if not config.get("inflation",false): config.name = last_name
	config.subtitle = "%s / %s" % [layout.name, "Your next mistake is billable."]
	config.chests = []
	if rng.randf()<0.65 or index==4:
		var chest_choices: Array[Vector2] = []
		for socket in RoomTemplates.CHESTS:
			var valid: bool = not (config.get("shortcut",false) and socket.distance_to(Vector2(300,260))<105)
			for key in ["atm","loan","overtime_at"]:
				if config.has(key) and socket.distance_to(Vector2(config[key][0],config[key][1]))<105: valid = false
			if valid: chest_choices.append(socket)
		if not chest_choices.is_empty():
			var socket: Vector2 = chest_choices[rng.randi_range(0,chest_choices.size()-1)]
			config.chests.append([socket.x,socket.y])
	# Relief is visible and finite. It never alters the enemy budget or hidden stats.
	if money<60 and standard>=3: config.refund = [280,540]
	var mode: Dictionary = DifficultySettings.profile(difficulty)
	var total: int = budget_for(standard)
	config.encounter_budget = total
	var remaining: int = total
	var sockets: Array[Vector2] = RoomTemplates.available(config)
	var used_types: Array[int] = []
	var occupied: Array[Vector2] = []
	while remaining>0:
		var choices: Array[int] = []
		for kind in EnemyData.DEFINITIONS:
			var unit: Dictionary = EnemyData.DEFINITIONS[kind]
			if unit.cost<=0 or unit.cost>remaining or unit.min_room>standard: continue
			# Repeated types still occur, but new compositions get more weight.
			var weight: int = 1 if kind in recent_types else 3
			for i in weight: choices.append(kind)
		if choices.is_empty(): break
		var kind: int = choices[rng.randi_range(0,choices.size()-1)]
		var cost: int = EnemyData.DEFINITIONS[kind].cost
		var elite: bool = standard>=5 and rng.randf()<mode.elite*minf(1.0,float(standard)/8.0) and remaining>=cost+2
		if elite: cost += 2
		var available: Array[Vector2] = []
		for socket in sockets:
			if not socket in occupied: available.append(socket)
		if available.is_empty():
			occupied.clear()
			available = sockets.duplicate()
		var at: Vector2 = available[rng.randi_range(0,available.size()-1)]
		occupied.append(at)
		var reward: int = EnemyData.reward_for(kind,difficulty,elite,2 if index>=8 else 1)
		config.spawn_plan.append({"kind":kind,"at":at,"elite":elite,"reward":reward,"cost":cost,"overtime":false})
		used_types.append(kind)
		remaining -= cost
	config.spent_budget = total-remaining
	config.memo = "GENERATED ENCOUNTER\n%s\n\n%s\n\n%s" % [layout.name,_enemy_tip(standard),_feature_tip(config)]
	recent_types = used_types
	cache[index] = config
	return config

func _enemy_tip(standard: int) -> String:
	if standard>=7: return "AUDITORS: +$1 services\nENFORCERS: dodge charge\nCLERKS: buff nearby foes"
	if standard>=5: return "TAX: 20%, max $20\nDRONES: orbit + shoot"
	if standard>=3: return "BANKERS: ranged $4 fee\nUse desks for cover."
	return "COLLECTOR: contact $5\nRUNNER: fast, contact $3"

func _feature_tip(config: Dictionary) -> String:
	if config.has("loan"): return "LOAN +$25 NOW\n-$5 per new room"
	if config.has("atm"): return "ATM: pay $4, get $15\nOne withdrawal only."
	if not config.tolls.is_empty(): return "TOLL FLOOR: $1 / TILE\nGo around for free."
	if not config.hazards.is_empty(): return "Gold warns, red charges\nFloor hit costs $5."
	return "Chests: $5 / find $2-$20\nKeep cash for the CEO."
