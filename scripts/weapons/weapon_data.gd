class_name WeaponData
extends RefCounted
## Owns weapon tuning and shop copy, never purchases or projectile nodes.
## cost is per trigger pull, not per pellet; interval is seconds between pulls.
## life * speed limits range. pierce counts additional enemies after the first.
## Shot cost receives Ledger's flat inflation/audit surcharges exactly once.
const DEFINITIONS: Dictionary = {
	"standard":{"name":"STANDARD ISSUE","buy":0,"cost":1,"damage":1,"interval":0.23,"speed":920.0,"count":1,"spread":0.0,"jitter":0.0,"life":1.5,"radius":2.0,"pierce":0,"knockback":1.0,"style":"Accurate / long range","tradeoff":"One target per shot","color":Palette.MINT},
	"spread":{"name":"SPREADSHEET","buy":18,"cost":3,"damage":1,"interval":0.65,"speed":700.0,"count":5,"spread":0.13,"jitter":0.0,"life":0.5,"radius":2.5,"pierce":0,"knockback":0.7,"style":"5 pellets / short range","tradeoff":"Short range; $3 per pull","color":Palette.GOLD},
	"rapid":{"name":"MICROTRANSACTION","buy":15,"cost":1,"damage":1,"interval":0.12,"speed":1050.0,"count":1,"spread":0.0,"jitter":0.09,"life":0.48,"radius":2.0,"pierce":0,"knockback":0.45,"style":"Rapid fire; loose aim","tradeoff":"Loose aim; spends cash quickly","color":Palette.BLUE},
	"heavy":{"name":"CAPITAL INVESTMENT","buy":24,"cost":4,"damage":5,"interval":1.0,"speed":650.0,"count":1,"spread":0.0,"jitter":0.0,"life":1.5,"radius":6.0,"pierce":1,"knockback":1.8,"style":"5 damage / 2 targets","tradeoff":"Slow; each miss costs $4","color":Palette.RED}
}
static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(id,DEFINITIONS.standard)
