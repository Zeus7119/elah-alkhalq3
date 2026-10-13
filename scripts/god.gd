class_name Deity
extends RefCounted

var god_name := ""
var power := 100.0
var strength := 1.0
var is_player := false
var alive := true
var level := 1
var xp := 0.0
var home_universe := 0
var worlds: Array = []

func _init(n: String, player := false) -> void:
	god_name = n
	is_player = player

func xp_needed() -> float:
	return 80.0 + level * 40.0

func add_xp(n: float) -> int:
	xp += n
	var ups := 0
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		strength += 0.3
		power += 25.0
		ups += 1
	return ups

func world_power() -> float:
	var p := 0.0
	for b in worlds:
		if not is_instance_valid(b):
			continue
		if b.is_life:
			p += 5.0 + b.population * 0.5
		elif b.body_type in ["star", "blackhole", "galaxy", "solarsystem"]:
			p += b.radius * 2.0
		else:
			p += b.radius
	return p

func living_worlds() -> int:
	var n := 0
	for b in worlds:
		if is_instance_valid(b):
			n += 1
	return n
