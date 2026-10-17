extends RefCounted
## The bot. Every 0.2 s it re-decides where to stand and what to do, then each frame it
## turns that into the same intent a human produces. It keeps gun range while it has ammo,
## closes in for the knife when it is winning or the zone is small, dodges fireballs, uses
## its powers when they are ready, and never willingly stands outside the zone.

var think := 0.0
var strafe := 1.0
var strafe_timer := 0.0
var want_dist := 10.0
var plan := {}
var agent: NavigationAgent3D


func _init(nav_agent: NavigationAgent3D) -> void:
	agent = nav_agent


func get_intent(f, delta: float) -> Dictionary:
	var intent: Dictionary = f.EMPTY_INTENT.duplicate()
	var opp = f.opponent
	var game = f.game
	var to_opp: Vector3 = opp.global_position - f.global_position
	to_opp.y = 0.0
	var dist := to_opp.length()
	var fwd := to_opp / maxf(dist, 0.001)
	var right := fwd.cross(Vector3.UP)
	var sees: bool = game.line_of_sight(f.chest(), opp.chest())

	think -= delta
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe = -strafe if randf() < 0.7 else strafe
		strafe_timer = randf_range(1.2, 2.8)
	if think <= 0.0:
		think = 0.2
		plan = {}
		var winning: bool = f.hp > opp.hp + 15.0
		var zone_small: bool = game.zone_radius() < 11.0
		want_dist = 2.0 if (winning or zone_small or (f.ammo == 0 and f.reloading <= 0.0)) else 10.0
		if f.blind > 0.0:
			want_dist = 14.0  # back off while blind
		if sees and not opp.dead:
			if f.cd.fire <= 0.0 and dist > 5.0 and dist < 22.0 and randf() < 0.25:
				plan.fire = true
			elif f.cd.shadow <= 0.0 and dist < 15.0 and randf() < 0.18:
				plan.shadow = true
		if game.projectile_incoming(f, 6.0) and f.cd.roll <= 0.0 and randf() < 0.6:
			plan.roll = true
		elif dist < 2.3 and randf() < 0.3:
			plan.punch = true
		if f.ammo < 4 and dist > 7.0 and f.reloading <= 0.0 and randf() < 0.3:
			plan.reload = true

	# Where to stand: keep the wanted range, circle-strafe, and stay inside the zone.
	var goal: Vector3 = opp.global_position - fwd * want_dist + right * strafe * 3.0
	var r: float = game.zone_radius()
	var flat_goal := Vector3(goal.x, 0, goal.z)
	if flat_goal.length() > r - 2.5:
		goal = flat_goal.normalized() * maxf(r - 2.5, 0.0)
	agent.target_position = goal
	var next := agent.get_next_path_position()
	var dir: Vector3 = next - f.global_position
	dir.y = 0.0
	if dir.length() > 0.3:
		dir = dir.normalized()
		intent.move = Vector2(dir.dot(right), dir.dot(fwd))
	intent.sprint = absf(dist - want_dist) > 6.0

	if sees and not opp.dead:
		intent.attack = dist <= f.MELEE_RANGE or randf() < 0.55
	for k in plan:
		intent[k] = true
	plan.clear()
	return intent
