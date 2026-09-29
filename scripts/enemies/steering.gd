class_name EnemySteering
extends RefCounted
## Samples visible motion at the mode's reaction interval. Predictions are bounded
## and attacks copy them once at telegraph start; nothing homes after release.
var observed_position := Vector2.ZERO
var observed_velocity := Vector2.ZERO
var sample_left: float = 0
var initialized: bool = false
var circle_time: float = 0
var circle_sign: float = 0
var circle_start := Vector2.ZERO
var circling: bool = false

func observe(delta: float, at: Vector2, motion: Vector2, ai: Dictionary, visible: bool = true) -> void:
	sample_left -= delta
	if not visible or (initialized and sample_left>0): return
	var next_velocity: Vector2 = motion.limit_length(360)
	if initialized and observed_velocity.length()>90 and next_velocity.length()>90:
		var turn: float = observed_velocity.angle_to(next_velocity)
		if absf(turn)>0.025 and absf(turn)<1.2 and (circle_sign==0 or signf(turn)==circle_sign):
			if circle_time==0: circle_start = at
			circle_time += ai.reaction
			circle_sign = signf(turn)
		else:
			circle_time = maxf(0,circle_time-ai.reaction*2)
			if circle_time==0: circle_sign = 0
	else:
		circle_time = 0
	circling = circle_time>=2.2 and at.distance_to(circle_start)<560
	observed_position = at
	observed_velocity = next_velocity
	initialized = true
	sample_left = ai.reaction

func predict(seconds: float, strength: float) -> Vector2:
	var offset: Vector2 = (observed_velocity*minf(seconds,1.2)*strength).limit_length(215)
	return (observed_position+offset).clamp(Vector2(84,185),Vector2(910,590))

func aim(from: Vector2, projectile_speed: float, lead: float) -> Vector2:
	var travel: float = minf(from.distance_to(observed_position)/projectile_speed,0.85)
	return (predict(travel,lead)-from).normalized()
