class_name EnemyData
extends RefCounted
## Defines enemy economics, identity and behaviour names. Does not instantiate nodes.
## kind is stable for existing scenes. New entries need a behaviour in enemy.gd.
## cost = generator budget; hp/speed/fee = unscaled combat; reward/score = payout.
## min_room counts standard departments AFTER orientation. Dummy 4 is never rolled.
const DEFINITIONS: Dictionary = {
	0:{"name":"COLLECTOR","cost":1,"hp":3,"speed":95.0,"fee":5,"reward":6,"score":10,"min_room":1,"behavior":"melee","color":Color("ff7d80")},
	1:{"name":"TAX MAN","cost":3,"hp":4,"speed":80.0,"fee":5,"reward":10,"score":30,"min_room":5,"behavior":"tax","color":Color("f1c979")},
	2:{"name":"RUNNER","cost":1,"hp":2,"speed":148.0,"fee":3,"reward":4,"score":10,"min_room":1,"behavior":"runner","color":Color("d99bea")},
	3:{"name":"BANKER","cost":2,"hp":4,"speed":70.0,"fee":4,"reward":8,"score":20,"min_room":3,"behavior":"ranged","color":Color("83ccec")},
	4:{"name":"TRAINING TARGET","cost":0,"hp":1,"speed":0.0,"fee":0,"reward":0,"score":0,"min_room":999,"behavior":"dummy","color":Color("f1c979")},
	5:{"name":"AUDITOR","cost":3,"hp":5,"speed":65.0,"fee":4,"reward":11,"score":35,"min_room":7,"behavior":"audit","color":Color("94e2a8")},
	6:{"name":"ENFORCER","cost":4,"hp":8,"speed":61.0,"fee":12,"reward":17,"score":50,"min_room":7,"behavior":"charge","color":Color("edaa70")},
	7:{"name":"DEBT DRONE","cost":2,"hp":2,"speed":116.0,"fee":2,"reward":6,"score":20,"min_room":5,"behavior":"orbit","color":Color("a2b5ff")},
	8:{"name":"COLLECTION CLERK","cost":3,"hp":4,"speed":52.0,"fee":3,"reward":10,"score":30,"min_room":7,"behavior":"support","color":Color("f5b0d1")}
}

static func scaled(kind: int, difficulty: String, elite: bool = false, overtime: bool = false) -> Dictionary:
	var unit: Dictionary = DEFINITIONS.get(kind,DEFINITIONS[0]).duplicate(true)
	if kind==4: return unit
	var mode: Dictionary = DifficultySettings.profile(difficulty)
	var pressure: Dictionary = DifficultySettings.overtime_profile(difficulty)
	unit.hp = ceili(unit.hp*mode.hp*(1.5 if elite else 1.0)*(pressure.hp if overtime else 1.0))
	unit.speed *= mode.speed*(1.15 if elite else 1.0)*(pressure.speed if overtime else 1.0)
	unit.fee = ceili(unit.fee*mode.damage*(pressure.damage if overtime else 1.0))
	unit.rate = mode.rate*(pressure.rate if overtime else 1.0)
	unit.projectiles = mode.projectiles
	unit.reward = ceili(unit.reward*mode.reward*(1.5 if elite else 1.0))
	unit.score = int(unit.score*(2 if elite else 1))
	return unit

static func reward_for(kind: int, difficulty: String, elite: bool, shot_price: int) -> int:
	var unit: Dictionary = scaled(kind,difficulty,elite)
	# Perfect aim must not create a mandatory deficit. Extra rewards on harder modes
	# leave room for mistakes, while missed bullets and financial damage still matter.
	var sustainable: int = unit.hp*shot_price+2
	return maxi(unit.reward,ceili(sustainable*DifficultySettings.profile(difficulty).reward))

# Briefings describe the actual mode's hit fees. Longer lore stays out of combat UI.
static func briefing(kind: int, difficulty: String) -> Dictionary:
	if kind==-1:
		return {"name":"THE CEO","color":Palette.GOLD,"ability":"Invoices, summons and three phases.","tip":"Dodge blue charges and red fee zones."}
	var unit: Dictionary = scaled(kind,difficulty)
	var descriptions: Dictionary = {
		0:["Contact costs $%d."%unit.fee,"Keep moving; shoot from a distance."],
		1:["Takes 20% cash ($4-$20 per hit).","Keep your distance; use cover."],
		2:["Warned burst. Contact costs $%d."%unit.fee,"Juke after its gold line locks."],
		3:["Fires invoices. Hit costs $%d."%unit.fee,"Move sideways; desks block shots."],
		5:["Marks you: shots and dashes +$1.","Break sight during its gold warning."],
		6:["Warned charge. Hit costs $%d."%unit.fee,"Step aside, then shoot as it recovers."],
		7:["Circles you; fires $%d invoices."%unit.fee,"Keep moving; it has low health."],
		8:["Gives nearby enemies +20% speed.","Defeat the clerk to remove its buff."]}
	var lines: Array = descriptions.get(kind,["Harmless training target.","Aim with the mouse. Click to shoot."])
	return {"name":unit.name,"color":unit.color,"ability":lines[0],"tip":lines[1]}
