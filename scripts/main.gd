extends Node2D

const AI_GOD_NAMES = ["إله الظلام", "إله العاصفة", "إله الجحيم"]
const TOOLS = ["star", "planet", "blackhole", "solarsystem", "galaxy",
	"human", "plant", "animal", "fish", "water", "earth", "mountain"]
const SAVE_PATH = "user://savegame.cfg"
const AUTOSAVE_PATH = "user://autosave.cfg"

signal strike_done

var player: Deity
var gods: Array = []
var bodies_root: Node2D
var camera: Camera2D
var selected_tool := "star"
var war_active := false
var sfx: Sfx

var universes: Array = []
var universe_names: Array = []
var universe_cams: Array = []
var current_universe := 0

var hud_power: Label
var hud_strength: Label
var hud_worlds: Label
var hud_level: Label
var hud_universe: Label
var tool_label: Label
var log_box: RichTextLabel
var battle_panel: Control
var battle_title: Label
var battle_log: RichTextLabel
var duel_box: VBoxContainer
var duel_track: ColorRect
var duel_zone: ColorRect
var duel_marker: ColorRect
var strike_btn: Button
var war_popup: PopupMenu
var war_targets: Array = []
var name_edit_player: LineEdit
var name_edits_ai: Array = []
var universe_selector: OptionButton
var new_universe_edit: LineEdit

var duel_active := false
var pending_strike := false
var marker_t := 0.0
var marker_dir := 1.0
var wb_player_bonus := 0.0

var bg_points: Array = []

func _ready() -> void:
	setup_theme()
	sfx = Sfx.new()
	add_child(sfx)
	bodies_root = Node2D.new()
	bodies_root.name = "Multiverse"
	add_child(bodies_root)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	camera.zoom = Vector2(0.8, 0.8)
	make_starfield()
	setup_gods()
	build_ui()
	start_timers()
	update_hud()
	if FileAccess.file_exists(AUTOSAVE_PATH):
		add_log("💾 يوجد حفظ تلقائي سابق — اضغط «تحميل» لاستعادة كونك.")
	add_log("مرحباً أيها الإله المطلق! مواردك غير محدودة ♾️ — اخلق ما تشاء بلا حدود.")
	add_log("🌌 هذا عالم متعدد الأكوان: كل إله له كونه، ويمكنك خلق أكوان جديدة من لوحة الخلق.")

func setup_theme() -> void:
	var font: Font
	if ResourceLoader.exists("res://assets/fonts/NotoSansArabic-Regular.ttf"):
		font = load("res://assets/fonts/NotoSansArabic-Regular.ttf")
	else:
		var sf := SystemFont.new()
		sf.font_names = ["Noto Sans Arabic", "Noto Naskh Arabic", "Noto Kufi Arabic", "Amiri", "sans-serif"]
		font = sf
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	get_tree().root.theme = theme

func make_starfield() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(400):
		bg_points.append(Vector2(rng.randf_range(-4000, 4000), rng.randf_range(-4000, 4000)))

func _draw() -> void:
	for p in bg_points:
		draw_circle(p, 1.4, Color(1, 1, 1, 0.55))

func create_universe(nm: String) -> int:
	var u := Node2D.new()
	u.name = "Universe%d" % universes.size()
	bodies_root.add_child(u)
	universes.append(u)
	universe_names.append(nm)
	universe_cams.append(Vector2.ZERO)
	_refresh_universe_selector()
	return universes.size() - 1

func switch_universe(i: int) -> void:
	if i < 0 or i >= universes.size() or i == current_universe:
		return
	universe_cams[current_universe] = camera.position
	current_universe = i
	for k in range(universes.size()):
		universes[k].visible = (k == i)
		universes[k].process_mode = Node.PROCESS_MODE_INHERIT if k == i else Node.PROCESS_MODE_DISABLED
	camera.position = universe_cams[i]
	universe_selector.select(i)
	hud_universe.text = "🌌 الكون الحالي: " + universe_names[i]
	sfx.play("click")

func _on_universe_selected(idx: int) -> void:
	switch_universe(idx)

func _on_create_universe() -> void:
	var nm := new_universe_edit.text.strip_edges()
	if nm == "":
		nm = "كون " + str(universes.size() + 1)
	var idx := create_universe(nm)
	new_universe_edit.text = ""
	add_log("🌌 خلقتَ كوناً جديداً بالكامل: «%s»! عدد الأكوان الآن: %d" % [nm, universes.size()])
	player.add_xp(20)
	switch_universe(idx)
	sfx.play("create")

func _refresh_universe_selector() -> void:
	if universe_selector == null:
		return
	universe_selector.clear()
	for nm in universe_names:
		universe_selector.add_item("🌌 " + nm)
	universe_selector.select(current_universe)

func setup_gods() -> void:
	player = Deity.new("إله الخلق (أنت)", true)
	player.power = 500.0
	player.strength = 1.5
	create_universe("كون الخلق (كونك)")
	gods.append(player)
	var positions = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for i in range(3):
		var g := Deity.new(AI_GOD_NAMES[i], false)
		g.power = randf_range(300, 500)
		g.strength = randf_range(1.0, 2.2)
		g.level = randi_range(1, 3)
		g.home_universe = create_universe("عوالم " + g.god_name)
		gods.append(g)
		build_ai_world(g, Vector2(randf_range(-500, 500), randf_range(-400, 400)), universes[g.home_universe])
	build_player_home()

func build_player_home() -> void:
	var home := universes[player.home_universe]
	var s := spawn_body_in("star", Vector2.ZERO, player, home)
	for i in range(2):
		var pl := spawn_body_in("planet", Vector2.ZERO, player, home)
		pl.orbit_parent = s
		pl.orbit_radius = 90 + i * 60
		pl.orbit_speed = 0.5 - i * 0.18
		pl.orbit_angle = randf() * TAU
		pl.color = Color.from_hsv(randf(), 0.55, 0.9)
	for i in range(3):
		spawn_body_in(["human", "plant", "animal"][i], Vector2(randf_range(-200, 200), randf_range(-200, 200)), player, home)

func build_ai_world(g: Deity, c: Vector2, u: Node2D) -> void:
	var s := spawn_body_in("star", c, g, u)
	for i in range(2):
		var pl := spawn_body_in("planet", Vector2.ZERO, g, u)
		pl.orbit_parent = s
		pl.orbit_radius = 85 + i * 55
		pl.orbit_speed = 0.45 - i * 0.15
		pl.orbit_angle = randf() * TAU
		pl.color = Color.from_hsv(randf(), 0.55, 0.85)
	var life_types = ["human", "plant", "animal", "fish"]
	for i in range(3):
		spawn_body_in(life_types[randi() % life_types.size()], c + Vector2(randf_range(-180, 180), randf_range(-180, 180)), g, u)
	spawn_body_in("water", c + Vector2(randf_range(-220, 220), randf_range(-220, 220)), g, u)
	spawn_body_in("earth", c + Vector2(randf_range(-220, 220), randf_range(-220, 220)), g, u)

func spawn_body(t: String, pos: Vector2, god: Deity) -> CosmicBody:
	return spawn_body_in(t, pos, god, universes[current_universe])

func spawn_body_in(t: String, pos: Vector2, god: Deity, u: Node2D) -> CosmicBody:
	var b := CosmicBody.new()
	u.add_child(b)
	b.setup(t, pos, god)
	god.worlds.append(b)
	return b

func save_game(path: String, announce := true) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "power", player.power)
	cfg.set_value("player", "strength", player.strength)
	cfg.set_value("player", "name", player.god_name)
	cfg.set_value("player", "level", player.level)
	cfg.set_value("player", "xp", player.xp)
	cfg.set_value("meta", "tool", selected_tool)
	cfg.set_value("gods", "count", gods.size())
	for i in range(gods.size()):
		var g: Deity = gods[i]
		cfg.set_value("god%d" % i, "name", g.god_name)
		cfg.set_value("god%d" % i, "power", g.power)
		cfg.set_value("god%d" % i, "strength", g.strength)
		cfg.set_value("god%d" % i, "alive", g.alive)
		cfg.set_value("god%d" % i, "level", g.level)
		cfg.set_value("god%d" % i, "xp", g.xp)
		cfg.set_value("god%d" % i, "home", g.home_universe)
	universe_cams[current_universe] = camera.position
	cfg.set_value("universes", "count", universes.size())
	cfg.set_value("universes", "current", current_universe)
	for i in range(universes.size()):
		cfg.set_value("universe%d" % i, "name", universe_names[i])
		cfg.set_value("universe%d" % i, "cam", universe_cams[i])
		var bodies := universes[i].get_children()
		cfg.set_value("universe%d" % i, "bcount", bodies.size())
		for j in range(bodies.size()):
			var b: CosmicBody = bodies[j]
			var key := "u%db%d" % [i, j]
			cfg.set_value(key, "type", b.body_type)
			cfg.set_value(key, "pos", b.position)
			cfg.set_value(key, "color", var_to_str([b.color.r, b.color.g, b.color.b, b.color.a]))
			cfg.set_value(key, "orbit_parent", bodies.find(b.orbit_parent))
			cfg.set_value(key, "orbit_radius", b.orbit_radius)
			cfg.set_value(key, "orbit_speed", b.orbit_speed)
			cfg.set_value(key, "orbit_angle", b.orbit_angle)
			cfg.set_value(key, "pop", b.population)
			cfg.set_value(key, "owner", gods.find(b.owner_god))
	var err := cfg.save(path)
	if announce:
		if err == OK:
			add_log("💾 تم حفظ تقدّمك بنجاح!")
			sfx.play("click")
		else:
			add_log("⚠️ تعذّر الحفظ! رمز الخطأ: %d" % err)

func load_game(path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	for u in universes:
		u.queue_free()
	universes.clear()
	universe_names.clear()
	universe_cams.clear()
	for g in gods:
		g.worlds.clear()
	player.power = float(cfg.get_value("player", "power", 500.0))
	player.strength = float(cfg.get_value("player", "strength", 1.5))
	player.god_name = str(cfg.get_value("player", "name", player.god_name))
	player.level = int(cfg.get_value("player", "level", 1))
	player.xp = float(cfg.get_value("player", "xp", 0.0))
	_on_tool_selected(str(cfg.get_value("meta", "tool", "star")))
	var gcount: int = int(cfg.get_value("gods", "count", 0))
	for i in range(min(gcount, gods.size())):
		var g: Deity = gods[i]
		g.god_name = str(cfg.get_value("god%d" % i, "name", g.god_name))
		g.power = float(cfg.get_value("god%d" % i, "power", g.power))
		g.strength = float(cfg.get_value("god%d" % i, "strength", g.strength))
		g.alive = bool(cfg.get_value("god%d" % i, "alive", true))
		g.level = int(cfg.get_value("god%d" % i, "level", 1))
		g.xp = float(cfg.get_value("god%d" % i, "xp", 0.0))
		g.home_universe = int(cfg.get_value("god%d" % i, "home", 0))
	var ucount: int = int(cfg.get_value("universes", "count", 1))
	for i in range(ucount):
		var u := Node2D.new()
		u.name = "Universe%d" % i
		bodies_root.add_child(u)
		universes.append(u)
		universe_names.append(str(cfg.get_value("universe%d" % i, "name", "كون %d" % (i + 1))))
		universe_cams.append(cfg.get_value("universe%d" % i, "cam", Vector2.ZERO))
		var bcount: int = int(cfg.get_value("universe%d" % i, "bcount", 0))
		var body_nodes: Array = []
		for j in range(bcount):
			var key := "u%db%d" % [i, j]
			var t := str(cfg.get_value(key, "type", "star"))
			var pos: Vector2 = cfg.get_value(key, "pos", Vector2.ZERO)
			var owner_idx: int = int(cfg.get_value(key, "owner", 0))
			var god: Deity = gods[clampi(owner_idx, 0, gods.size() - 1)]
			var b := spawn_body_in(t, pos, god, u)
			var col = str_to_var(cfg.get_value(key, "color", "[1,1,0,1]"))
			if col is Array and col.size() == 4:
				b.color = Color(col[0], col[1], col[2], col[3])
			b.orbit_radius = float(cfg.get_value(key, "orbit_radius", 0.0))
			b.orbit_speed = float(cfg.get_value(key, "orbit_speed", 0.0))
			b.orbit_angle = float(cfg.get_value(key, "orbit_angle", 0.0))
			b.population = int(cfg.get_value(key, "pop", 0))
			body_nodes.append(b)
		for j in range(bcount):
			var pi: int = int(cfg.get_value("u%db%d" % [i, j], "orbit_parent", -1))
			if pi >= 0 and pi < body_nodes.size():
				body_nodes[j].orbit_parent = body_nodes[pi]
	current_universe = clampi(int(cfg.get_value("universes", "current", 0)), 0, universes.size() - 1)
	for k in range(universes.size()):
		universes[k].visible = (k == current_universe)
		universes[k].process_mode = Node.PROCESS_MODE_INHERIT if k == current_universe else Node.PROCESS_MODE_DISABLED
	camera.position = universe_cams[current_universe]
	_refresh_universe_selector()
	refresh_name_edits()
	hud_universe.text = "🌌 الكون الحالي: " + universe_names[current_universe]
	update_hud()
	add_log("📂 تم تحميل عوالمك المحفوظة عبر الأكوان — عدتَ إلى عرشك أيها الإله!")
	return true

func _on_save_pressed() -> void:
	save_game(SAVE_PATH)

func _on_load_pressed() -> void:
	if not load_game(SAVE_PATH):
		add_log("⚠️ لا يوجد ملف حفظ يدوي بعد — جرّب «الحفظ» أولاً أو انتظر الحفظ التلقائي.")
	sfx.play("click")

func _on_apply_names() -> void:
	if name_edit_player.text.strip_edges() != "":
		player.god_name = name_edit_player.text.strip_edges()
	var ai_i := 0
	for g in gods:
		if g.is_player:
			continue
		if ai_i < name_edits_ai.size() and name_edits_ai[ai_i].text.strip_edges() != "":
			g.god_name = name_edits_ai[ai_i].text.strip_edges()
			if g.home_universe < universe_names.size() and g.home_universe > 0:
				universe_names[g.home_universe] = "عوالم " + g.god_name
		ai_i += 1
	_refresh_universe_selector()
	add_log("✏️ تم تحديث أسماء الآلهة وأكوانهم.")
	sfx.play("click")
	update_hud()

func refresh_name_edits() -> void:
	name_edit_player.text = player.god_name
	var ai_i := 0
	for g in gods:
		if g.is_player:
			continue
		if ai_i < name_edits_ai.size():
			name_edits_ai[ai_i].text = g.god_name
		ai_i += 1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom * 1.12).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom / 1.12).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not war_active:
			place_tool(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE or event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			camera.position -= event.relative / camera.zoom.x

func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1
	if move != Vector2.ZERO:
		camera.position += move.normalized() * 700.0 * delta / camera.zoom.x
	if duel_active:
		marker_t += marker_dir * delta * 1.35
		if marker_t >= 1.0:
			marker_t = 1.0
			marker_dir = -1.0
		elif marker_t <= 0.0:
			marker_t = 0.0
			marker_dir = 1.0
		duel_marker.position.x = 8 + marker_t * (duel_track.size.x - 10)

func place_tool(pos: Vector2) -> void:
	match selected_tool:
		"solarsystem":
			var s := spawn_body("star", pos, player)
			for i in range(3):
				var pl := spawn_body("planet", Vector2.ZERO, player)
				pl.orbit_parent = s
				pl.orbit_radius = 75 + i * 48
				pl.orbit_speed = 0.55 - i * 0.14
				pl.orbit_angle = randf() * TAU
				pl.color = Color.from_hsv(randf(), 0.6, 0.9)
		_:
			spawn_body(selected_tool, pos, player)
	add_log("✨ خلقتَ: " + CosmicBody.TYPE_INFO[selected_tool]["name"] + " في «%s»!" % universe_names[current_universe])
	sfx.play("create")
	_check_level_up(player, player.add_xp(2))
	update_hud()

func _check_level_up(g: Deity, ups: int) -> void:
	if ups > 0 and g.is_player:
		sfx.play("win")
		add_log("🏆 صعدتَ إلى المستوى %d! قوّتك وشدّتك ازدادتا تلقائياً." % g.level)

func _on_tool_selected(t: String) -> void:
	selected_tool = t
	tool_label.text = "أداة الخلق الحالية: " + CosmicBody.TYPE_INFO[t]["name"]
	sfx.play("click")

func start_timers() -> void:
	var t1 := Timer.new()
	t1.wait_time = 5.0
	t1.autostart = true
	t1.timeout.connect(_on_growth_tick)
	add_child(t1)
	var t2 := Timer.new()
	t2.wait_time = 35.0
	t2.autostart = true
	t2.timeout.connect(_on_ai_war_tick)
	add_child(t2)
	var t3 := Timer.new()
	t3.wait_time = 30.0
	t3.autostart = true
	t3.timeout.connect(_on_autosave)
	add_child(t3)

func _on_autosave() -> void:
	if not war_active:
		save_game(AUTOSAVE_PATH, false)

func _on_growth_tick() -> void:
	for g in gods:
		if not g.alive:
			continue
		for w in g.worlds:
			if is_instance_valid(w) and w.is_life:
				w.population += randi_range(1, 4)
		g.add_xp(randi_range(1, 3))
		if not g.is_player and randf() < 0.35 and g.worlds.size() < 45:
			var types = ["planet", "star", "water", "earth", "mountain", "human", "animal", "plant", "fish"]
			var c := Vector2.ZERO
			if g.worlds.size() > 0 and is_instance_valid(g.worlds[0]):
				c = g.worlds[0].position
			spawn_body_in(types[randi() % types.size()], c + Vector2(randf_range(-280, 280), randf_range(-280, 280)), g, universes[g.home_universe])
	update_hud()

func _on_ai_war_tick() -> void:
	if war_active or randf() < 0.45:
		return
	var alive_ai: Array = gods.filter(func(g): return g.alive and not g.is_player)
	if alive_ai.size() < 2:
		return
	var a: Deity = alive_ai[randi() % alive_ai.size()]
	var b: Deity = alive_ai[randi() % alive_ai.size()]
	if a == b:
		return
	var pa: float = a.world_power() * a.strength * randf_range(0.8, 1.25)
	var pb: float = b.world_power() * b.strength * randf_range(0.8, 1.25)
	var winner: Deity = a if pa > pb else b
	var loser: Deity = b if winner == a else a
	absorb(winner, loser)
	winner.add_xp(40)
	add_log("⚔️ حرب آلهة: %s (مستوى %d) هزم %s واحتاز عوالمه وأصبحت قوته طاقةً للفائز!" % [winner.god_name, winner.level, loser.god_name])
	if gods.filter(func(g): return g.alive and not g.is_player).is_empty():
		add_log("👑 أنت الآن الإله الأوحد في الوجود! كل العوالم لك.")

func absorb(winner: Deity, loser: Deity) -> void:
	winner.power += loser.power * 0.6
	winner.strength += 0.8
	for w in loser.worlds.duplicate():
		if is_instance_valid(w):
			w.owner_god = winner
			winner.worlds.append(w)
	loser.worlds.clear()
	if not loser.is_player:
		loser.alive = false

func _on_war_button() -> void:
	if war_active:
		return
	sfx.play("click")
	war_popup.clear()
	war_targets.clear()
	var idx := 0
	for g in gods:
		if not g.is_player and g.alive:
			war_targets.append(g)
			war_popup.add_item("⚔️ %s (مستوى %d)   قوة: %d — عوالم: %d" % [g.god_name, g.level, int(g.power), g.living_worlds()], idx)
			idx += 1
	if idx == 0:
		add_log("لا يوجد آلهة أحياء — أنتَ الإله الأوحد في هذا الوجود!")
		return
	war_popup.popup()

func _on_war_target_selected(id: int) -> void:
	if id >= 0 and id < war_targets.size():
		start_war(war_targets[id])

func start_war(defender: Deity) -> void:
	war_active = true
	battle_panel.visible = true
	battle_log.clear()
	duel_box.visible = false
	battle_title.text = "⚔️ حرب العوالم: أنتَ (مستوى %d) ضدّ %s (مستوى %d)" % [player.level, defender.god_name, defender.level]
	add_log("🔥 أعلنتَ حرب عوالم على " + defender.god_name + "!")
	sfx.play("hit")
	await run_world_battle(defender)
	duel_box.visible = true
	var player_won_duel: bool = await run_god_duel(defender)
	finish_war(defender, player_won_duel)

func run_world_battle(defender: Deity) -> void:
	var a_army: float = player.world_power() + player.power * 0.3
	var d_army: float = defender.world_power() + defender.power * 0.3
	var a_rounds := 0
	for i in range(4):
		await get_tree().create_timer(1.1).timeout
		var ar: float = a_army * randf_range(0.7, 1.3)
		var dr: float = d_army * randf_range(0.7, 1.3)
		if ar >= dr:
			a_rounds += 1
			sfx.play("hit")
			battle_log.append_text("🗡️ الجولة %d: مخلوقات عالمك تتقدّم وتسحق الجحافل!\n" % (i + 1))
		else:
			battle_log.append_text("🛡️ الجولة %d: قوات %s تصدّت لهجومك ببسالة!\n" % [i + 1, defender.god_name])
	await get_tree().create_timer(0.8).timeout
	if a_rounds >= 3:
		wb_player_bonus = 0.12
		battle_log.append_text("🏆 فزتَ بمعركة العوالم! جنودك يهتفون باسمك قبل نزال الآلهة!\n")
	else:
		wb_player_bonus = -0.10
		battle_log.append_text("💀 خسرتَ معركة العوالم... لكن النزال الحقيقي بين الآلهة يبدأ الآن!\n")

func run_god_duel(defender: Deity) -> bool:
	battle_title.text = "👑 نزال الآلهة: أنتَ ضدّ " + defender.god_name
	battle_log.append_text("\nاضغط «⚡ اضرب الآن» عندما يكون المؤشر في المنطقة الخضراء! (أفضل من 3 جولات)\n")
	duel_active = true
	var ps := 0
	var ds := 0
	for i in range(3):
		marker_t = 0.0
		marker_dir = 1.0
		pending_strike = true
		await strike_done
		var hit := abs(marker_t - 0.5) <= 0.14
		var chance: float = clamp(player.strength / (player.strength + defender.strength) + 0.2 + wb_player_bonus, 0.1, 0.95)
		if hit and randf() < chance:
			ps += 1
			sfx.play("hit")
			battle_log.append_text("⚡ ضربة موجعة! تفوّقتَ على %s في الجولة %d!\n" % [defender.god_name, i + 1])
		elif hit:
			ds += 1
			sfx.play("lose")
			battle_log.append_text("🌑 صدَّ %s ضربتك بقوته المظلمة! (الجولة %d)\n" % [defender.god_name, i + 1])
		else:
			ds += 1
			battle_log.append_text("❌ أخطأتَ التوقيت... استغلّ %s الفرصة! (الجولة %d)\n" % [defender.god_name, i + 1])
	duel_active = false
	return ps >= 2

func _on_strike() -> void:
	if duel_active and pending_strike:
		pending_strike = false
		strike_done.emit()

func finish_war(defender: Deity, player_won: bool) -> void:
	var msg := ""
	if player_won:
		var gained: int = int(defender.power * 0.6)
		absorb(player, defender)
		player.strength += 0.5
		sfx.play("win")
		msg = "🏆 انتصرتَ! احتزتَ عوالم %s، وأصبحت قوّته ومصيره طاقةً تغذي قوّتك (+%d)!" % [defender.god_name, gained]
		add_log("👑 هزمتَ " + defender.god_name + " — عوالمه لك الآن وقوته تغذيك!")
		_check_level_up(player, player.add_xp(60))
	else:
		var lost: float = player.power * 0.5
		defender.power += lost
		defender.strength += 0.6
		defender.add_xp(40)
		var half: int = int(ceil(player.worlds.size() / 2.0))
		var transferred := 0
		while transferred < half and player.worlds.size() > 1:
			var w: CosmicBody = player.worlds[randi() % player.worlds.size()]
			player.worlds.erase(w)
			defender.worlds.append(w)
			w.owner_god = defender
			transferred += 1
		player.power = max(50.0, player.power - lost)
		sfx.play("lose")
		msg = "💀 هُزمتَ أمام %s... احتاز نصف عوالمك وامتصّ جزءاً من قوّتك. لكن إرادة الخلق لا تنكسر — اخلق من جديد وتعالَ للانتقام!" % defender.god_name
		add_log("💀 هزمك " + defender.god_name + "... عُد أقوى وخذ بثأرك!")
		player.add_xp(15)
	update_hud()
	save_game(AUTOSAVE_PATH, false)
	await get_tree().create_timer(1.2).timeout
	battle_panel.visible = false
	war_active = false
	var dlg := AcceptDialog.new()
	dlg.title = "⚔️ نتيجة حرب العوالم"
	dlg.dialog_text = msg
	dlg.ok_button_text = "متابعة"
	add_child(dlg)
	dlg.popup_centered()

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := VBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.position = Vector2(16, 12)
	hud.add_theme_constant_override("separation", 4)
	layer.add_child(hud)
	var title := Label.new()
	title.text = "🌌 إله الخلق"
	title.add_theme_font_size_override("font_size", 30)
	hud.add_child(title)
	var sub := Label.new()
	sub.text = "مواردك: غير محدودة ♾️"
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(1, 1, 0.6)
	hud.add_child(sub)
	hud_universe = Label.new()
	hud_universe.add_theme_font_size_override("font_size", 17)
	hud_universe.modulate = Color(0.7, 0.9, 1.0)
	hud.add_child(hud_universe)
	hud_level = Label.new()
	hud.add_child(hud_level)
	hud_power = Label.new()
	hud.add_child(hud_power)
	hud_strength = Label.new()
	hud.add_child(hud_strength)
	hud_worlds = Label.new()
	hud.add_child(hud_worlds)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -290
	panel.offset_top = -350
	panel.offset_bottom = 350
	panel.offset_right = -10
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.05, 0.05, 0.13, 0.88)
	pstyle.corner_radius = 12
	panel.add_theme_stylebox_override("panel", pstyle)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var ptitle := Label.new()
	ptitle.text = "✨ لوحة الخلق المطلق"
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ptitle.add_theme_font_size_override("font_size", 24)
	box.add_child(ptitle)
	tool_label = Label.new()
	tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_label.add_theme_font_size_override("font_size", 15)
	box.add_child(tool_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	box.add_child(scroll)
	var tools_box := VBoxContainer.new()
	tools_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tools_box)
	for t in TOOLS:
		var btn := Button.new()
		btn.text = "✦ " + CosmicBody.TYPE_INFO[t]["name"]
		btn.pressed.connect(_on_tool_selected.bind(t))
		tools_box.add_child(btn)
	var uni_title := Label.new()
	uni_title.text = "🌌 الأكوان (Multiverse)"
	uni_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uni_title.add_theme_font_size_override("font_size", 18)
	box.add_child(uni_title)
	universe_selector = OptionButton.new()
	universe_selector.item_selected.connect(_on_universe_selected)
	box.add_child(universe_selector)
	var uni_row := HBoxContainer.new()
	uni_row.add_theme_constant_override("separation", 6)
	box.add_child(uni_row)
	new_universe_edit = LineEdit.new()
	new_universe_edit.placeholder_text = "اسم كون جديد..."
	new_universe_edit.text_direction = Control.TEXT_DIRECTION_RTL
	new_universe_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	new_universe_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uni_row.add_child(new_universe_edit)
	var uni_btn := Button.new()
	uni_btn.text = "➕ خلق"
	uni_btn.pressed.connect(_on_create_universe)
	uni_row.add_child(uni_btn)
	var war_btn := Button.new()
	war_btn.text = "⚔️ إعلان حرب عالمية"
	war_btn.add_theme_font_size_override("font_size", 22)
	war_btn.modulate = Color(1.0, 0.75, 0.75)
	war_btn.pressed.connect(_on_war_button)
	box.add_child(war_btn)
	war_popup = PopupMenu.new()
	layer.add_child(war_popup)
	war_popup.id_pressed.connect(_on_war_target_selected)
	var names_title := Label.new()
	names_title.text = "✏️ أسماء الآلهة"
	names_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names_title.add_theme_font_size_override("font_size", 18)
	box.add_child(names_title)
	name_edit_player = _make_name_edit("اسم إلهك أنت...")
	box.add_child(name_edit_player)
	for g in gods:
		if g.is_player:
			continue
		var le := _make_name_edit(g.god_name)
		name_edits_ai.append(le)
		box.add_child(le)
	refresh_name_edits()
	var apply_btn := Button.new()
	apply_btn.text = "تطبيق الأسماء"
	apply_btn.pressed.connect(_on_apply_names)
	box.add_child(apply_btn)
	var save_title := Label.new()
	save_title.text = "💾 الحفظ"
	save_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_title.add_theme_font_size_override("font_size", 18)
	box.add_child(save_title)
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	box.add_child(save_row)
	var save_btn := Button.new()
	save_btn.text = "💾 حفظ"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_on_save_pressed)
	save_row.add_child(save_btn)
	var load_btn := Button.new()
	load_btn.text = "📂 تحميل"
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_btn.pressed.connect(_on_load_pressed)
	save_row.add_child(load_btn)
	_on_tool_selected("star")
	var log_panel := PanelContainer.new()
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_panel.offset_left = 12
	log_panel.offset_top = -210
	log_panel.offset_bottom = -12
	log_panel.offset_right = 470
	var lstyle := StyleBoxFlat.new()
	lstyle.bg_color = Color(0.05, 0.05, 0.13, 0.8)
	lstyle.corner_radius = 10
	log_panel.add_theme_stylebox_override("panel", lstyle)
	layer.add_child(log_panel)
	log_box = RichTextLabel.new()
	log_box.custom_minimum_size = Vector2(450, 190)
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.fit_content = false
	log_box.add_theme_font_size_override("normal_font_size", 15)
	log_panel.add_child(log_box)
	battle_panel = Control.new()
	battle_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_panel.visible = false
	layer.add_child(battle_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	battle_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_panel.add_child(center)
	var bpanel := PanelContainer.new()
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.09, 0.07, 0.18, 0.98)
	bstyle.corner_radius = 16
	bpanel.add_theme_stylebox_override("panel", bstyle)
	center.add_child(bpanel)
	var bbox := VBoxContainer.new()
	bbox.custom_minimum_size = Vector2(560, 420)
	bbox.add_theme_constant_override("separation", 8)
	bpanel.add_child(bbox)
	battle_title = Label.new()
	battle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_title.add_theme_font_size_override("font_size", 26)
	bbox.add_child(battle_title)
	battle_log = RichTextLabel.new()
	battle_log.custom_minimum_size = Vector2(540, 200)
	battle_log.bbcode_enabled = true
	battle_log.scroll_following = true
	bbox.add_child(battle_log)
	duel_box = VBoxContainer.new()
	duel_box.visible = false
	duel_box.add_theme_constant_override("separation", 8)
	bbox.add_child(duel_box)
	var duel_area := Control.new()
	duel_area.custom_minimum_size = Vector2(540, 44)
	duel_box.add_child(duel_area)
	duel_track = ColorRect.new()
	duel_track.color = Color(0.2, 0.2, 0.3)
	duel_track.position = Vector2(8, 14)
	duel_track.size = Vector2(524, 16)
	duel_area.add_child(duel_track)
	duel_zone = ColorRect.new()
	duel_zone.color = Color(0.2, 0.9, 0.4, 0.55)
	duel_zone.position = Vector2(8 + 524 * 0.36, 14)
	duel_zone.size = Vector2(524 * 0.28, 16)
	duel_area.add_child(duel_zone)
	duel_marker = ColorRect.new()
	duel_marker.color = Color(1, 0.3, 0.3)
	duel_marker.position = Vector2(8, 8)
	duel_marker.size = Vector2(10, 28)
	duel_area.add_child(duel_marker)
	strike_btn = Button.new()
	strike_btn.text = "⚡ اضرب الآن!"
	strike_btn.add_theme_font_size_override("font_size", 26)
	strike_btn.pressed.connect(_on_strike)
	duel_box.add_child(strike_btn)

func _make_name_edit(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.text_direction = Control.TEXT_DIRECTION_RTL
	le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	le.custom_minimum_size = Vector2(0, 34)
	return le

func update_hud() -> void:
	hud_universe.text = "🌌 الكون الحالي: " + universe_names[current_universe]
	hud_level.text = "🏆 المستوى: %d   ⭐ الخبرة: %d / %d" % [player.level, int(player.xp), int(player.xp_needed())]
	hud_power.text = "⚡ قوّتك: %d" % int(player.power)
	hud_strength.text = "💪 شدّتك: %.1f" % player.strength
	hud_worlds.text = "🪐 عوالمك: %d   🌌 أكوان الوجود: %d" % [player.living_worlds(), universes.size()]

func add_log(text: String) -> void:
	log_box.append_text(text + "\n")

