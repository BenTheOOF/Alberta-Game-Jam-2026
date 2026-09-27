class_name RoomTemplates
extends RefCounted
## Owns safe geometry and sockets, never enemy composition or run progression.
## All obstacles are authored rectangles [x,y,w,h] with wide, connected routes.
## Spawn sockets are filtered against solids, hazards, props and player distance.
const SPAWN := Vector2(140,390)
const EXIT := Vector2(888,390)
const DATA: Array[Dictionary] = [
	{"id":"open","name":"OPEN OFFICE","desks":[],"hazards":[],"tolls":[]},
	{"id":"cubicles","name":"CUBICLE FLOOR","desks":[[395,265,96,44],[600,445,96,44],[595,250,96,44],[385,480,96,44]],"hazards":[],"tolls":[]},
	{"id":"hall","name":"RECORDS HALL","desks":[[360,220,390,48],[360,520,390,48]],"hazards":[],"tolls":[]},
	{"id":"island","name":"CENTRAL OFFICE","desks":[[465,323,124,134]],"hazards":[],"tolls":[]},
	{"id":"split","name":"SPLIT ACCOUNTS","desks":[[465,210,74,115],[465,470,74,115]],"hazards":[],"tolls":[]},
	{"id":"hazard","name":"RISK GRID","desks":[[445,355,92,44]],"hazards":[[580,265,86,52],[580,485,86,52],[730,370,80,50]],"tolls":[]},
	{"id":"toll","name":"TOLL ROUTE","desks":[[495,268,90,48],[495,470,90,48]],"hazards":[],"tolls":[[480,345,40,84],[520,345,40,84],[560,345,40,84],[600,345,40,84]]},
	{"id":"executive","name":"EXECUTIVE FLOOR","desks":[[385,235,86,42],[635,525,86,42]],"hazards":[],"tolls":[]}
]
const SOCKETS: Array[Vector2] = [Vector2(350,220),Vector2(350,560),Vector2(480,220),Vector2(480,560),Vector2(620,220),Vector2(620,390),Vector2(620,560),Vector2(760,220),Vector2(760,310),Vector2(760,480),Vector2(760,560),Vector2(845,230),Vector2(845,550),Vector2(350,310),Vector2(350,480),Vector2(480,390)]
const CHESTS: Array[Vector2] = [Vector2(270,260),Vector2(280,515),Vector2(820,280)]

static func get_template(id: String) -> Dictionary:
	for template in DATA:
		if template.id==id: return template.duplicate(true)
	return DATA[0].duplicate(true)

static func safe(at: Vector2, config: Dictionary, player_at: Vector2, minimum: float = 250.0) -> bool:
	if at.distance_to(player_at)<minimum or at.distance_to(EXIT)<76: return false
	if not Rect2(78,188,832,418).has_point(at): return false
	for key in ["desks","hazards","tolls"]:
		for rect in config.get(key,[]):
			if Rect2(rect[0],rect[1],rect[2],rect[3]).grow(28).has_point(at): return false
	if config.get("shortcut",false) and at.distance_to(Vector2(300,260))<78: return false
	for chest in config.get("chests",[]):
		if at.distance_to(Vector2(chest[0],chest[1]))<70: return false
	for key in ["atm","loan","overtime_at"]:
		if config.has(key) and at.distance_to(Vector2(config[key][0],config[key][1]))<78: return false
	if config.get("shop",false):
		for item in [Vector2(330,300),Vector2(615,300),Vector2(330,495),Vector2(615,495)]:
			if at.distance_to(item)<75: return false
	return true

static func available(config: Dictionary, player_at: Vector2 = SPAWN, minimum: float = 250.0) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for at in SOCKETS:
		if safe(at,config,player_at,minimum): result.append(at)
	return result
