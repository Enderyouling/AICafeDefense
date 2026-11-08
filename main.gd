extends Node2D
# AI 娘守店记 —— 界面、输入、特效与音频。战斗规则在 battle.gd，关卡数据在 campaign.gd。

const Battle = preload("res://battle.gd")
const Campaign = preload("res://campaign.gd")
const SAVE := "user://progress.dat"
const AUDIO_PREF := "user://audio-setting.txt"
const UI_FONT = preload("res://art/NotoSansSC.ttf")
const WEIGHT_AXIS := 2003265652
const SIZE := Vector2(1280, 720)

# 樱花咖啡厅配色：奶油纸、可可描边、樱花粉按钮、薄荷色算力
const COCOA := Color("#3d2422")
const COCOA_SOFT := Color("#7a5243")
const WOOD := Color("#4a2a26")
const CREAM := Color("#fff7ea")
const LATTE := Color("#ecd2ae")
const GOLD := Color("#ffd27a")
const GOLD_DEEP := Color("#d99a3e")
const SAKURA := Color("#ff8db3")
const SAKURA_DEEP := Color("#d94f7c")
const SAKURA_PALE := Color("#ffdbe7")
const MINT := Color("#7df0cd")
const MINT_DEEP := Color("#22a586")
const BERRY := Color("#ff5b7d")
const SKY := Color("#8edcff")
const PLUM := Color("#2a1528")
const TEXT := Color("#fff8ef")
const MUTED := Color("#ecd5c8")
const INK_SOFT := Color("#8b6757")
const ACCENTS := [Color("#b58bff"), Color("#ffb03f"), Color("#45b4ff"), Color("#ff8758"), Color("#9a86ff"), Color("#6d8cff"), Color("#2fd1a3"), Color("#ffc23d")]
const ARENAS := {"arena": ["门口", Color("#ff8db3")], "hall": ["主厅", Color("#e0965a")], "night": ["夜班", Color("#8a7bff")],
	"kitchen": ["后厨", Color("#ff7b5c")], "core": ["核心区", Color("#2fc4b2")]}
const ENEMY_TIPS := {"C": "普通来客", "R": "跑得很快", "B": "举着箱盾", "A": "让同伴加速", "S": "潜行，躲开锁定",
	"T": "召来职员", "D": "封住炮台", "I": "潜行又耐打", "X": "三阶段 Boss"}
const PAGE_SIZE := 6
const MAX_LOADOUT := 5
const PHASE_NAMES := ["", "金牌接管", "封条封场", "影子加班"]
const SHOT_ART := {0: "gpt_shot", 2: "deepseek_shot", 4: "gemini_shot", 5: "qwen_shot", 7: "grok_shot"}
const HIT_ART := {0: "gpt_hit", 2: "deepseek_hit", 4: "gpt_hit", 5: "qwen_shot", 7: "grok_hit", 9: "warning_fx", 10: "kimi_fx"}
const SHOT_SFX := {0: "shot_gpt", 2: "shot_water", 4: "shot_gemini", 5: "shot_qwen", 7: "shot_grok"}
# 每个音效的基础音量（dB），播放时还可以再加偏移。
const SFX_DB := {"click": -11.0, "select": -9.0, "deny": -10.0, "page": -8.0, "toggle": -9.0,
	"deploy": -5.0, "remove": -8.0, "collect": -6.0, "produce": -13.0, "supply": -6.0,
	"shot_gpt": -18.0, "shot_water": -17.0, "shot_gemini": -19.0, "shot_qwen": -16.0, "shot_grok": -11.0, "scan": -13.0,
	"hit": -19.0, "hit_water": -18.0, "hit_shield": -16.0, "shield_break": -7.0, "boom": -8.0, "block": -15.0, "bite": -19.0,
	"kill": -9.0, "lost": -6.0, "wave": -5.0, "last_wave": -4.0, "boss_phase": -3.0, "warning": -12.0, "seal": -7.0,
	"megaphone": -8.0, "hurry": -10.0, "reveal": -9.0, "sweep": -5.0, "win": -3.0, "lose": -4.0, "star": -6.0}
const MUSIC_DB := -9.0
const PETAL := [Vector2(0, -1), Vector2(0.55, -0.62), Vector2(0.62, 0.08), Vector2(0.32, 0.82), Vector2(0, 0.56),
	Vector2(-0.32, 0.82), Vector2(-0.62, 0.08), Vector2(-0.55, -0.62)]
const MID := 1
const END := 2
enum {TITLE, SELECT, BRIEF, PLAY, RESULT}

var state := TITLE
var stage := 0
var stars: Array = []
var loadout: Array = []
var page := 0
var selected := -1
var paused := false
var save_ok := true
var rating := 0
var carry := 0.0
var ui_time := 0.0
var toast := ""
var toast_until := 0.0
var toast_at := 0.0
var battle
var art := {}
var fonts: Array[FontVariation] = []
var buttons: Array = []
var styles := {}
var pointer := Vector2(-100, -100)
var mobile := false
var rng := RandomNumberGenerator.new()
# 音频
var music_on := true
var sfx_on := true
var tracks := {}
var cues := {}
var decks: Array[AudioStreamPlayer] = []
var deck_gain := [0.0, 0.0]
var deck_target := [0.0, 0.0]
var deck_now := 0
var music_key := ""
var voices: Array[AudioStreamPlayer] = []
var voice_next := 0
var last_cue := {}
# 演出
var cam := Vector2.ZERO
var trauma := 0.0
var flash := 0.0
var flash_color := Color.WHITE
var parts: Array[Dictionary] = []
var ui_parts: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var flyers: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var petals: Array[Dictionary] = []
var banner_text := ""
var banner_color := SAKURA
var banner_at := -10.0
var shown_power := 0.0
var power_pop := -10.0
var power_deny := -10.0
var result_at := 0.0
var stars_played := 0
var showcase := 0
var showcase_at := 0.0
var wave_marks: Array[float] = []

func _ready() -> void:
	rng.seed = 1107
	for weight in [450, 700, 900]:
		var face := FontVariation.new()
		face.base_font = UI_FONT
		face.variation_opentype = {WEIGHT_AXIS: weight}
		fonts.append(face)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mobile = OS.has_feature("mobile")
	var keys := ["cafe", "arena", "hall", "night", "kitchen", "core", "clerk", "runner", "guard", "advisor", "stealth", "robot", "trump", "dario", "tibo", "boss1", "boss2", "boss3",
		"gpt_shot", "gpt_hit", "deepseek_shot", "deepseek_hit", "kimi_fx", "claude_fx", "gemini_shot", "qwen_shot", "glm_fx", "grok_shot", "grok_hit", "warning_fx"]
	for card in Campaign.CARDS:
		keys.append(card.key)
		keys.append(card.key + "_act")
	for key in keys:
		art[key] = load("res://art/%s.png" % key)
	stars.resize(Campaign.levels.size())
	stars.fill(0)
	loadout.resize(Campaign.CARDS.size())
	loadout.fill(false)
	var loaded := read_progress(SAVE)
	if loaded.is_empty():
		loaded = read_progress(SAVE + ".bak")
	if loaded.is_empty():
		var previous := OS.get_environment("LOCALAPPDATA")
		if not previous.is_empty():
			loaded = read_progress(previous.path_join("AICafeDefenseTrial/progress.dat"))
	if not loaded.is_empty():
		stars = loaded
	setup_audio()
	get_window().min_size = Vector2i(865, 486)
	get_window().focus_exited.connect(func():
		if state == PLAY:
			paused = true
			buttons.clear()
	)

# ---------------------------------------------------------------- 音频

func setup_audio() -> void:
	read_audio_pref()
	if DisplayServer.get_name() == "headless":
		return
	for key in ["menu", "battle", "boss"]:
		var stream: AudioStreamOggVorbis = load("res://art/audio/music_%s.ogg" % key)
		stream.loop = true
		tracks[key] = stream
	for i in range(2):
		var deck := AudioStreamPlayer.new()
		deck.volume_db = -80.0
		add_child(deck)
		decks.append(deck)
	for key in SFX_DB:
		cues[key] = load("res://art/audio/sfx_%s.wav" % key)
	for i in range(14):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func read_audio_pref() -> void:
	if not FileAccess.file_exists(AUDIO_PREF):
		return
	var saved := FileAccess.get_file_as_string(AUDIO_PREF).strip_edges()
	if saved == "muted":
		music_on = false
		sfx_on = false
	elif saved != "on":
		music_on = not saved.contains("music=off")
		sfx_on = not saved.contains("sfx=off")

func save_audio_pref() -> void:
	var file := FileAccess.open(AUDIO_PREF, FileAccess.WRITE)
	if file != null:
		file.store_string("music=%s\nsfx=%s" % ["on" if music_on else "off", "on" if sfx_on else "off"])
		file.close()

func toggle_music() -> void:
	music_on = not music_on
	save_audio_pref()
	sfx("toggle")

func toggle_sfx() -> void:
	sfx_on = not sfx_on
	if not sfx_on:
		for voice in voices:
			voice.stop()
	save_audio_pref()
	sfx("toggle")

func wanted_music() -> String:
	if not music_on:
		return ""
	match state:
		PLAY:
			return "boss" if stage == Campaign.levels.size() - 1 else "battle"
		RESULT:
			return "menu" if ui_time - result_at > 3.6 else ""
	return "menu"

func update_music(delta: float) -> void:
	if decks.is_empty():
		return
	var key := wanted_music()
	if key != music_key:
		music_key = key
		deck_target = [0.0, 0.0]
		if key != "":
			deck_now = 1 - deck_now
			decks[deck_now].stream = tracks[key]
			decks[deck_now].play()
			deck_gain[deck_now] = 0.0
			deck_target[deck_now] = 1.0
	var duck := 0.4 if state == PLAY and paused else 1.0
	for i in range(2):
		var speed := 1.5 if deck_target[i] > deck_gain[i] else 1.1
		deck_gain[i] = move_toward(deck_gain[i], deck_target[i], delta * speed)
		var deck := decks[i]
		if deck_gain[i] <= 0.001:
			if deck.playing:
				deck.stop()
		else:
			deck.volume_db = MUSIC_DB + linear_to_db(deck_gain[i] * (duck if i == deck_now else 1.0))

func sfx(key: String, db: float = 0.0, pitch: float = 1.0, gap: float = 0.045) -> void:
	if not sfx_on or voices.is_empty() or not cues.has(key):
		return
	if ui_time - float(last_cue.get(key, -10.0)) < gap:
		return
	last_cue[key] = ui_time
	var voice: AudioStreamPlayer = voices[voice_next]
	for i in range(voices.size()):
		var candidate := voices[(voice_next + i) % voices.size()]
		if not candidate.playing:
			voice = candidate
			break
	voice_next = (voices.find(voice) + 1) % voices.size()
	voice.stream = cues[key]
	voice.volume_db = float(SFX_DB[key]) + db
	voice.pitch_scale = pitch * rng.randf_range(0.96, 1.04)
	voice.play()

# ---------------------------------------------------------------- 存档与流程

func read_progress(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	if lines.size() not in [5, Campaign.levels.size() + 1] or lines[0].strip_edges() != "AI-CAFE/1":
		return []
	var values := []
	var gap := false
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line not in ["0", "1", "2", "3"] or (gap and line != "0"):
			return []
		values.append(line.to_int())
		gap = gap or line == "0"
	while values.size() < Campaign.levels.size():
		values.append(0)
	return values

func record_win(score: int) -> bool:
	if score <= stars[stage]:
		return true
	var next := stars.duplicate()
	next[stage] = score
	var file := FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_line("AI-CAFE/1")
	for n in next:
		file.store_line(str(n))
	file.close()
	if not read_progress(SAVE).is_empty():
		if DirAccess.copy_absolute(SAVE, SAVE + ".bak") != OK:
			return false
	if DirAccess.rename_absolute(SAVE + ".tmp", SAVE) != OK:
		return false
	stars = next
	return true

func unlocked() -> int:
	var first := stars.find(0)
	return Campaign.levels.size() - 1 if first == -1 else first

func total_stars() -> int:
	var sum := 0
	for n in stars:
		sum += int(n)
	return sum

func open_title() -> void:
	state = TITLE
	paused = false

func open_map(use_latest: bool = false) -> void:
	if use_latest:
		page = floori(float(unlocked()) / PAGE_SIZE)
	state = SELECT
	paused = false

func equipped() -> Array:
	var result := []
	for i in range(loadout.size()):
		if loadout[i]:
			result.append(i)
	return result

func open_stage(id: int) -> void:
	stage = id
	page = floori(float(id) / PAGE_SIZE)
	var suggested := [0, 1, 2, 3, 4]
	if id == 7 or id == 8:
		suggested = [0, 1, 2, 4, 5]
	elif id >= 9:
		suggested = [0, 1, 4, 5, 6]
		if id == 11:
			suggested = [0, 1, 4, 6, 7]
		elif id in [9, 15, 18]:
			suggested = [0, 1, 3, 4, 6]
	for i in range(loadout.size()):
		loadout[i] = Campaign.available(i, id) and i in suggested
	state = BRIEF
	toast_until = 0.0

func start_battle() -> void:
	if not loadout.has(true):
		notice("至少选择一位店员。")
		return
	battle = Battle.new(stage, loadout)
	paused = false
	selected = -1
	carry = 0.0
	toast_until = 0.0
	shown_power = battle.power
	trauma = 0.0
	flash = 0.0
	banner_at = -10.0
	parts.clear()
	ui_parts.clear()
	floaters.clear()
	flyers.clear()
	ghosts.clear()
	wave_marks.clear()
	var spawns: Array = battle.level.spawns
	for k in range(1, spawns.size()):
		if spawns[k][2] != spawns[k - 1][2]:
			wave_marks.append(float(k) / spawns.size())
	state = PLAY

func pause_game() -> void:
	paused = true

func notice(message: String, bad: bool = true) -> void:
	toast = message
	toast_until = ui_time + 2.0
	toast_at = ui_time
	if bad:
		sfx("deny")

func finish() -> void:
	rating = maxi(1, 3 - battle.robots.count(false))
	save_ok = battle.result != 1 or record_win(rating)
	state = RESULT
	result_at = ui_time
	stars_played = 0
	selected = -1
	buttons.clear()
	if battle.result == 1:
		confetti()

func _process(delta: float) -> void:
	ui_time += delta
	pointer = get_global_mouse_position()
	var sim := 0.0
	if state == PLAY and not paused:
		carry += minf(0.1, delta)
		while carry >= 0.02 and battle.result == 0:
			battle.step(0.02)
			carry -= 0.02
			sim += 0.02
		drain()
		if battle.result != 0:
			finish()
	elif state == RESULT:
		sim = delta
		battle.events.clear()
	world_step(sim)
	ui_step(delta)
	update_music(delta)
	queue_redraw()

func choose_card(index: int) -> void:
	if battle.deck[index]:
		selected = -1 if selected == index else index
		sfx("select")

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and event.index == 0:
		click(make_canvas_position_local(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			click(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT and state == PLAY and not paused:
			selected = -1
	elif event is InputEventKey and event.pressed and not event.echo:
		if state == PLAY:
			if event.keycode in [KEY_ESCAPE, KEY_SPACE]:
				go_back()
			elif not paused and event.keycode >= KEY_1 and event.keycode <= KEY_5:
				var slot: int = event.keycode - KEY_1
				var active := equipped()
				if slot < active.size():
					choose_card(active[slot])
			elif not paused and event.keycode == KEY_R:
				toggle_remove()
		elif event.keycode == KEY_ESCAPE:
			go_back()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()

func go_back() -> void:
	if state == PLAY:
		paused = not paused
		sfx("click")
	elif state != TITLE:
		state = TITLE if state == SELECT else SELECT
		sfx("page")
	buttons.clear()

func toggle_remove() -> void:
	selected = -1 if selected == -2 else -2
	sfx("select")

func click(point: Vector2) -> void:
	for i in range(buttons.size() - 1, -1, -1):
		if buttons[i][0].has_point(point):
			var action: Callable = buttons[i][1]
			var cue: String = buttons[i][2]
			buttons.clear()
			if cue != "":
				sfx(cue)
			action.call()
			return
	if state != PLAY or paused:
		return
	for i in range(battle.tokens.size() - 1, -1, -1):
		if token_point(battle.tokens[i]).distance_to(point) <= 30:
			battle.collect(i)
			drain()
			return
	var cell := board_cell(point)
	if selected == -1 or cell.x < 0:
		return
	if cell in battle.level.blocked:
		notice("这格暂时封闭。")
		return
	if selected == -2:
		if battle.remove(cell.y, cell.x):
			selected = -1
			drain()
		else:
			notice("这个格子是空的。")
	elif battle.place(selected, cell.y, cell.x):
		selected = -1
		drain()
	elif battle.towers[cell.y][cell.x] != null:
		notice("这个格子已有店员。")
	elif battle.time < battle.ready_at[selected]:
		notice("这张卡正在冷却。")
	else:
		power_deny = ui_time
		notice("算力不足，点击场上的发光算力。")

func change_page(offset: int) -> void:
	page = clampi(page + offset, 0, floori(float(Campaign.levels.size() - 1) / PAGE_SIZE))

func set_page(value: int) -> void:
	page = value

func stage_art(id: int) -> String:
	var card := Campaign.UNLOCKS.find(id)
	if card >= 0:
		return Campaign.CARDS[card].key
	match id:
		21: return "boss3"
		10: return "trump"
		13, 18: return "dario"
		15, 20: return "tibo"
		6, 14, 16: return "guard"
		8, 17: return "advisor"
		_: return "runner"

func toggle_card(index: int) -> void:
	if loadout[index]:
		loadout[index] = false
	elif loadout.count(true) < MAX_LOADOUT:
		loadout[index] = true
	else:
		notice("最多上阵五位店员，先取消一张卡片。")

# ---------------------------------------------------------------- 战斗事件 → 音效与特效

func drain() -> void:
	if battle == null:
		return
	for e in battle.events:
		handle(e)
	battle.events.clear()

func handle(e: Dictionary) -> void:
	match e.type:
		"place":
			var p := cell_center(e.row, e.col)
			sfx("deploy")
			burst(p + Vector2(0, 22), CREAM, 7, 80.0, "puff", 0.45, 13.0)
			burst(p, ACCENTS[e.card], 9, 170.0, "star", 0.55, 6.5)
			ring(p, ACCENTS[e.card], 52.0, 0.4)
		"remove":
			sfx("remove")
			burst(cell_center(e.row, e.col), CREAM, 9, 100.0, "puff", 0.5, 14.0)
		"collect":
			var p := Vector2(board_x(e.x), lane_y(e.row) + row_height() * (0.24 if e.kimi else 0.48))
			sfx("collect", 0.0, 1.12 if e.kimi else 1.0)
			flyers.append({"from": p + cam, "age": 0.0, "color": GOLD if e.kimi else MINT})
			burst(p, GOLD if e.kimi else MINT, 7, 130.0, "star", 0.45, 5.5)
		"produce":
			sfx("produce", 0.0, 1.0, 0.25)
		"supply":
			sfx("supply")
			ui_floater("+%d 补给" % e.amount, Vector2(164, 150), MINT)
			power_pop = ui_time
		"wave":
			if e.last:
				sfx("last_wave")
				if stage > 0:
					banner("最后一波来客！", BERRY)
				shake(0.18)
			else:
				sfx("wave")
				if stage > 0:
					banner("第 %d 波来客" % e.wave, SAKURA)
		"spawn":
			if e.kind == "X":
				sfx("boss_phase")
				shake(0.6)
				flash_screen(BERRY, 0.35)
				banner("算力收购机甲 来袭！", BERRY)
		"fire":
			if SHOT_SFX.has(e.card):
				sfx(SHOT_SFX[e.card], 0.0, 1.0, 0.07)
			burst(cell_center(e.row, e.col) + Vector2(34, -8), ACCENTS[e.card], 3, 90.0, "dot", 0.25, 4.0)
		"scan":
			sfx("scan", 0.0, 1.0, 0.2)
		"reveal":
			var p := lane_point(e.row, e.x)
			sfx("reveal", 0.0, 1.0, 0.15)
			burst(p, SKY, 9, 130.0, "star", 0.5, 6.0)
			floater("显形！", p + Vector2(0, -44), SKY)
		"hit":
			var p := lane_point(e.row, e.x)
			if e.broke:
				sfx("shield_break")
				shake(0.16)
				burst(p, GOLD, 12, 240.0, "shard", 0.65, 7.0, 520.0)
				floater("破盾！", p + Vector2(0, -48), GOLD)
			elif e.shield:
				sfx("hit_shield", 0.0, 1.0, 0.06)
				burst(p, GOLD, 3, 150.0, "dot", 0.25, 3.5)
			elif e.card == 2:
				sfx("hit_water", 0.0, 1.0, 0.06)
				burst(p, SKY, 6, 120.0, "drop", 0.45, 4.5, 360.0)
			else:
				sfx("hit", 0.0, 1.0, 0.05)
				burst(p, ACCENTS[e.card], 4, 140.0, "dot", 0.25, 4.0)
		"boom":
			var p := lane_point(e.row, e.x)
			sfx("boom", 0.0, 1.0, 0.08)
			ring(p, GOLD, 120.0, 0.45)
			burst(p, GOLD, 10, 270.0, "star", 0.55, 7.0)
			burst(p, CREAM, 6, 90.0, "puff", 0.5, 16.0)
			shake(0.14)
		"kill":
			var p := lane_point(e.row, e.x)
			sfx("kill", 0.0, rng.randf_range(0.95, 1.1), 0.06)
			ghost(e.kind, e.row, e.x)
			burst(p + Vector2(0, 12), CREAM, 8, 120.0, "puff", 0.55, 15.0)
			burst(p, [SAKURA, GOLD, MINT][rng.randi() % 3], 7, 210.0, "star", 0.6, 6.0, 220.0)
			if e.kind == "X":
				shake(1.0)
				flash_screen(GOLD, 0.6)
				burst(p, GOLD, 30, 380.0, "star", 1.0, 9.0, 160.0)
				ring(p, GOLD, 240.0, 0.7)
		"bite":
			sfx("block" if e.card == 3 else "bite", 0.0, 1.0, 0.12)
		"lost":
			var p := cell_center(e.row, e.col)
			sfx("lost")
			shake(0.25)
			burst(p, CREAM, 10, 230.0, "shard", 0.7, 7.0, 620.0)
			burst(p, CREAM, 6, 70.0, "puff", 0.6, 16.0)
		"warning":
			sfx("warning", 0.0, 1.0, 0.2)
		"seal":
			var p := cell_center(e.row, e.col)
			sfx("seal", 0.0, 1.0, 0.1)
			burst(p, BERRY, 6, 150.0, "dot", 0.35, 4.0)
			floater("封印！", p + Vector2(0, -42), BERRY)
		"skill":
			var p := lane_point(e.row, e.x)
			match e.kind:
				"A":
					sfx("hurry", 0.0, 1.0, 0.3)
					floater("加班！", p + Vector2(0, -52), GOLD)
				"T":
					sfx("megaphone", 0.0, 1.0, 0.3)
					floater("叫人来！", p + Vector2(0, -56), GOLD)
				"X":
					sfx("hit_shield", 5.0)
					floater("装甲展开", p + Vector2(0, -96), GOLD)
		"phase":
			sfx("boss_phase")
			shake(0.7)
			flash_screen(GOLD, 0.4)
			banner("机甲阶段 %d · %s" % [e.phase, PHASE_NAMES[e.phase]], GOLD)
			burst(lane_point(e.row, e.x), GOLD, 18, 300.0, "star", 0.8, 8.0)
		"sweep":
			sfx("sweep")
			shake(0.22)
		"win":
			sfx("win")
		"lose":
			sfx("lose")
			shake(0.5)

func cell_center(row: int, col: int) -> Vector2:
	return Vector2(board_x(col + 0.5), lane_y(row) + row_height() * 0.5)

func lane_point(row: int, x: float) -> Vector2:
	return Vector2(board_x(x), lane_y(row) + row_height() * 0.46)

func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func flash_screen(color: Color, amount: float) -> void:
	flash_color = color
	flash = maxf(flash, amount)

func banner(value: String, color: Color) -> void:
	banner_text = value
	banner_color = color
	banner_at = ui_time

func part(list: Array, p: Vector2, v: Vector2, life: float, color: Color, size: float, kind: String, grav: float = 0.0, drag: float = 2.5) -> void:
	if list.size() > 420:
		return
	list.append({"p": p, "v": v, "age": 0.0, "life": life * rng.randf_range(0.8, 1.2), "color": color, "size": size * rng.randf_range(0.75, 1.25),
		"kind": kind, "grav": grav, "drag": drag, "rot": rng.randf() * TAU, "spin": rng.randf_range(-6.0, 6.0), "flip": rng.randf() * TAU})

func burst(p: Vector2, color: Color, count: int, speed: float, kind: String, life: float, size: float, grav: float = 0.0, ui: bool = false) -> void:
	var list: Array = ui_parts if ui else parts
	for i in range(count):
		var dir := Vector2.from_angle(rng.randf() * TAU)
		part(list, p + dir * rng.randf_range(0.0, 8.0), dir * speed * rng.randf_range(0.35, 1.0) + Vector2(0, -speed * 0.15), life, color, size, kind, grav)

func ring(p: Vector2, color: Color, size: float, life: float) -> void:
	parts.append({"p": p, "v": Vector2.ZERO, "age": 0.0, "life": life, "color": color, "size": size, "kind": "ring", "grav": 0.0, "drag": 0.0, "rot": 0.0, "spin": 0.0, "flip": 0.0})

func floater(value: String, p: Vector2, color: Color) -> void:
	floaters.append({"text": value, "p": p, "age": 0.0, "life": 0.9, "color": color, "ui": false})

func ui_floater(value: String, p: Vector2, color: Color) -> void:
	floaters.append({"text": value, "p": p, "age": 0.0, "life": 1.1, "color": color, "ui": true})

func ghost(kind: String, row: int, x: float) -> void:
	var px := board_x(x)
	var y := lane_y(row)
	var h := row_height()
	if kind == "X":
		ghosts.append({"key": "boss%d" % maxi(1, battle.boss_phase), "rect": Rect2(px - 81, y - 68, 162, h + 57), "age": 0.0})
	else:
		ghosts.append({"key": Campaign.ENEMIES[kind].key, "rect": Rect2(px - 45, y, 90, h - 10), "age": 0.0})

func confetti() -> void:
	var colors := [SAKURA, GOLD, MINT, SKY, CREAM, SAKURA_PALE]
	for i in range(80):
		var p := Vector2(rng.randf_range(0.0, SIZE.x), rng.randf_range(-260.0, -10.0))
		var kind := "petal" if i % 3 == 0 else "confetti"
		part(ui_parts, p, Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(60.0, 160.0)), 4.2, colors[i % colors.size()], 7.0, kind, 40.0, 0.4)

func step_parts(list: Array, dt: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var q: Dictionary = list[i]
		q.age += dt
		if q.age >= q.life:
			list.remove_at(i)
			continue
		q.v *= maxf(0.0, 1.0 - q.drag * dt)
		q.v.y += q.grav * dt
		q.p += q.v * dt
		q.rot += q.spin * dt
		q.flip += dt * 5.0

# 战场内的演出跟着模拟时间走，暂停时一起冻结。
func world_step(dt: float) -> void:
	if dt <= 0.0:
		return
	trauma = maxf(0.0, trauma - dt * 1.7)
	step_parts(parts, dt)
	for i in range(floaters.size() - 1, -1, -1):
		var f: Dictionary = floaters[i]
		f.age += dt
		if f.age >= f.life:
			floaters.remove_at(i)
	for i in range(ghosts.size() - 1, -1, -1):
		ghosts[i].age += dt
		if ghosts[i].age > 0.38:
			ghosts.remove_at(i)
	for i in range(flyers.size() - 1, -1, -1):
		var fly: Dictionary = flyers[i]
		fly.age += dt
		if fly.age >= 0.5:
			flyers.remove_at(i)
			power_pop = ui_time
			burst(Vector2(78, 66), fly.color, 6, 110.0, "star", 0.4, 5.0, 0.0, true)
	if battle != null and state == PLAY:
		for row in range(battle.level.rows):
			if battle.sweep_until[row] > battle.time and rng.randf() < 0.6:
				var x := lerpf(144.0, 1220.0, 1.0 - (float(battle.sweep_until[row]) - battle.time) / 0.85)
				part(parts, Vector2(x - 40, lane_y(row) + row_height() * 0.8), Vector2(rng.randf_range(-60, -20), rng.randf_range(-40, -10)), 0.5, CREAM, 11.0, "puff")

func ui_step(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 2.6)
	step_parts(ui_parts, delta)
	if state in [TITLE, SELECT, BRIEF]:
		update_petals(delta, 30 if state == TITLE else 18)
	if battle != null:
		if shown_power < battle.power:
			shown_power = minf(battle.power, shown_power + maxf(1.0, (battle.power - shown_power) * 9.0 * delta))
		else:
			shown_power = battle.power
	if state == RESULT and battle.result == 1:
		var age := ui_time - result_at
		while stars_played < rating and age > 0.5 + stars_played * 0.32:
			var p := Vector2(640 + (stars_played - 1) * 112, 268)
			sfx("star", 0.0, 1.0 + stars_played * 0.12, 0.0)
			burst(p, GOLD, 14, 260.0, "star", 0.7, 7.0, 120.0, true)
			stars_played += 1

func update_petals(delta: float, count: int) -> void:
	while petals.size() < count:
		petals.append(new_petal(petals.size() < count and ui_time < 0.5))
	for i in range(petals.size() - 1, -1, -1):
		var q: Dictionary = petals[i]
		q.p += (q.v + Vector2(sin(ui_time * q.sway + q.phase) * 22.0, 0)) * delta
		q.rot += q.spin * delta
		q.flip += delta * q.sway * 1.6
		if q.p.y > SIZE.y + 20 or q.p.x < -30:
			petals[i] = new_petal(false)
	while petals.size() > count:
		petals.pop_back()

func new_petal(anywhere: bool) -> Dictionary:
	var p := Vector2(rng.randf_range(0.0, SIZE.x + 200.0), rng.randf_range(-40.0, -10.0))
	if anywhere:
		p.y = rng.randf_range(0.0, SIZE.y)
	return {"p": p, "v": Vector2(rng.randf_range(-55.0, -20.0), rng.randf_range(28.0, 62.0)), "size": rng.randf_range(5.0, 9.5),
		"rot": rng.randf() * TAU, "spin": rng.randf_range(-1.6, 1.6), "sway": rng.randf_range(0.8, 2.2), "phase": rng.randf() * TAU,
		"flip": rng.randf() * TAU, "color": SAKURA_PALE.lerp(SAKURA, rng.randf() * 0.6)}

func ease_back(t: float) -> float:
	t = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * t * t * t + 1.70158 * t * t

func ease_out(t: float) -> float:
	t = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - t * t * t

func shake_offset() -> Vector2:
	var amount := trauma * trauma * 14.0
	return Vector2(sin(ui_time * 67.0) + sin(ui_time * 23.0) * 0.5, cos(ui_time * 53.0) + cos(ui_time * 31.0) * 0.5) * amount * 0.7

# ---------------------------------------------------------------- 绘图小工具

func box(rect: Rect2, fill: Color, edge: Color = Color.TRANSPARENT, radius: int = 12, width: int = 0, shadow: float = 0.0) -> void:
	var key := "%s%s%d.%d.%d" % [fill.to_html(), edge.to_html(), radius, width, int(shadow * 100.0)]
	var style: StyleBoxFlat = styles.get(key)
	if style == null:
		if styles.size() > 800:
			styles.clear()
		style = StyleBoxFlat.new()
		style.bg_color = fill
		style.border_color = edge
		style.set_border_width_all(width if edge.a > 0.0 else 0)
		style.set_corner_radius_all(radius)
		style.corner_detail = 6
		style.anti_aliasing = true
		if shadow > 0.0:
			style.shadow_color = Color(0.1, 0.03, 0.07, shadow)
			style.shadow_size = 10
			style.shadow_offset = Vector2(0, 5)
		styles[key] = style
	draw_style_box(style, rect)

func paper(rect: Rect2, radius: int = 18, fill: Color = CREAM, edge: Color = COCOA, stitch: bool = true, shadow: float = 0.35) -> void:
	box(rect, fill, edge, radius, 3, shadow)
	if stitch:
		stitches(rect.grow(-8), float(radius) * 0.7, Color(COCOA_SOFT, 0.32))

func stitches(r: Rect2, k: float, color: Color) -> void:
	draw_dashed_line(r.position + Vector2(k, 0), Vector2(r.end.x - k, r.position.y), color, 1.5, 6.0)
	draw_dashed_line(Vector2(r.position.x + k, r.end.y), r.end - Vector2(k, 0), color, 1.5, 6.0)
	draw_dashed_line(r.position + Vector2(0, k), Vector2(r.position.x, r.end.y - k), color, 1.5, 6.0)
	draw_dashed_line(Vector2(r.end.x, r.position.y + k), r.end - Vector2(0, k), color, 1.5, 6.0)

func label(value: String, rect: Rect2, size: int = 16, color: Color = COCOA, align: int = 0, weight: int = 1, outline: int = 0, outline_color: Color = COCOA) -> void:
	var face: Font = fonts[weight]
	var width := face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if rect.size.x > 0.0 and width > rect.size.x:
		size = maxi(9, floori(size * rect.size.x / width))
		width = face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := rect.position.x
	if align == MID:
		x += (rect.size.x - width) * 0.5
	elif align == END:
		x += rect.size.x - width
	var y := rect.get_center().y + (face.get_ascent(size) - face.get_descent(size)) * 0.5
	var p := Vector2(roundf(x), roundf(y))
	if outline > 0:
		draw_string_outline(face, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
	draw_string(face, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

# 糖果按钮：0 樱花主按钮、1 奶油次按钮、2 薄荷按钮。
func candy(value: String, rect: Rect2, action: Callable, kind: int = 0, size: int = 0) -> void:
	var live := action.is_valid()
	var hot := live and rect.has_point(pointer)
	var face: Color = [SAKURA, CREAM, MINT][kind]
	var depth: Color = [SAKURA_DEEP, Color("#d6ad85"), MINT_DEEP][kind]
	var ink: Color = [TEXT, COCOA, COCOA][kind]
	if not live:
		face = Color("#dcc9b9")
		depth = Color("#ab9283")
		ink = Color("#8d7466")
	elif hot:
		face = face.lightened(0.14)
	var radius := mini(18, int(rect.size.y * 0.42))
	box(rect, depth, COCOA, radius, 3, 0.25)
	var top := Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 9))
	box(top, face, Color.TRANSPARENT, radius - 3)
	box(Rect2(top.position + Vector2(7, 3), Vector2(top.size.x - 14, top.size.y * 0.4)), Color(1, 1, 1, 0.32 if hot else 0.22), Color.TRANSPARENT, maxi(3, radius - 8))
	var font_size := size if size > 0 else (21 if rect.size.y >= 56 else 17 if rect.size.y >= 44 else 15)
	label(value, top.grow_individual(-8, 0, -8, 0), font_size, ink, MID, 2, 5 if kind == 0 and live else 0, Color("#a8325b"))
	if live:
		buttons.append([rect, action, "click"])

func round_button(icon: String, c: Vector2, r: float, action: Callable, active: bool = false, caption: String = "", off: bool = false) -> void:
	var live := action.is_valid()
	var hot := live and c.distance_to(pointer) <= r
	var face := SAKURA if active else CREAM
	if not live:
		face = Color("#d9c6b6")
	elif hot:
		face = face.lightened(0.12)
	draw_circle(c + Vector2(0, 4), r, COCOA, true, -1.0, true)
	draw_circle(c, r, COCOA, true, -1.0, true)
	draw_circle(c, r - 3.0, face, true, -1.0, true)
	draw_circle(c + Vector2(0, -r * 0.42), r * 0.42, Color(1, 1, 1, 0.2), true, -1.0, true)
	glyph(icon, c, r * 0.5, TEXT if active else (COCOA if live else Color("#a08878")))
	if off:
		draw_line(c + Vector2(-r, -r) * 0.55, c + Vector2(r, r) * 0.55, BERRY, 4.0, true)
	if caption != "":
		label(caption, Rect2(c.x - 44, c.y + r + 3, 88, 20), 13, TEXT, MID, 2, 4, COCOA)
	if live:
		buttons.append([Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), action, "click"])

func glyph(icon: String, c: Vector2, s: float, color: Color) -> void:
	var w := maxf(2.0, s * 0.3)
	match icon:
		"back", "next":
			var d := -1.0 if icon == "back" else 1.0
			draw_polyline(PackedVector2Array([c + Vector2(-0.3 * d, -0.7) * s, c + Vector2(0.4 * d, 0) * s, c + Vector2(-0.3 * d, 0.7) * s]), color, w, true)
		"pause":
			box(Rect2(c + Vector2(-0.62, -0.7) * s, Vector2(0.42, 1.4) * s), color, Color.TRANSPARENT, 3)
			box(Rect2(c + Vector2(0.2, -0.7) * s, Vector2(0.42, 1.4) * s), color, Color.TRANSPARENT, 3)
		"broom":
			draw_line(c + Vector2(0.75, -0.9) * s, c + Vector2(-0.05, 0.05) * s, color, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.15, -0.12) * s, c + Vector2(0.2, 0.22) * s, c + Vector2(-0.35, 0.95) * s, c + Vector2(-0.95, 0.45) * s]), color)
		"music":
			draw_circle(c + Vector2(-0.35, 0.5) * s, s * 0.32, color, true, -1.0, true)
			draw_line(c + Vector2(-0.06, 0.5) * s, c + Vector2(-0.06, -0.8) * s, color, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-0.06, -0.8) * s, c + Vector2(0.55, -0.5) * s, c + Vector2(0.55, -0.15) * s]), color, w, true)
		"sound":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.85, -0.32) * s, c + Vector2(-0.4, -0.32) * s, c + Vector2(0.05, -0.78) * s,
				c + Vector2(0.05, 0.78) * s, c + Vector2(-0.4, 0.32) * s, c + Vector2(-0.85, 0.32) * s]), color)
			draw_arc(c + Vector2(0.05, 0) * s, s * 0.45, -0.9, 0.9, 10, color, w * 0.8, true)
			draw_arc(c + Vector2(0.05, 0) * s, s * 0.82, -0.9, 0.9, 12, color, w * 0.8, true)
		"lock":
			draw_arc(c + Vector2(0, -0.2) * s, s * 0.42, PI, TAU, 12, color, w, true)
			box(Rect2(c + Vector2(-0.62, -0.2) * s, Vector2(1.24, 1.0) * s), color, Color.TRANSPARENT, 4)
		"cup":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.75, -0.35) * s, c + Vector2(0.55, -0.35) * s, c + Vector2(0.4, 0.55) * s, c + Vector2(-0.6, 0.55) * s]), color)
			draw_arc(c + Vector2(0.62, 0.02) * s, s * 0.26, -1.6, 1.6, 10, color, w * 0.8, true)
			draw_line(c + Vector2(-0.95, 0.72) * s, c + Vector2(0.75, 0.72) * s, color, w, true)
		"door":
			box(Rect2(c + Vector2(-0.55, -0.85) * s, Vector2(1.1, 1.7) * s), color, Color.TRANSPARENT, 3)
			draw_circle(c + Vector2(0.28, 0.05) * s, s * 0.12, CREAM, true, -1.0, true)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-0.65, 0.0) * s, c + Vector2(-0.15, 0.5) * s, c + Vector2(0.7, -0.5) * s]), color, w, true)

func gem(p: Vector2, s: float, color: Color, edge: Color = COCOA) -> void:
	if s < 0.8:
		return
	var top := p + Vector2(0, -s)
	var right := p + Vector2(s * 0.78, 0)
	var bottom := p + Vector2(0, s)
	var left := p + Vector2(-s * 0.78, 0)
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), Color(color.darkened(0.22), color.a))
	draw_colored_polygon(PackedVector2Array([top, right, left]), color)
	draw_colored_polygon(PackedVector2Array([top, p + Vector2(-s * 0.1, -s * 0.15), left]), Color(1, 1, 1, 0.45 * color.a))
	if edge.a > 0.0:
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(edge, edge.a * color.a), maxf(1.5, s * 0.15), true)

func star(p: Vector2, r: float, fill: Color, edge: Color = COCOA, width: float = 2.5, rot: float = 0.0) -> void:
	if r < 0.8:
		return
	var pts := PackedVector2Array()
	for i in range(10):
		var a := rot - PI * 0.5 + i * PI / 5.0
		pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.48))
	draw_colored_polygon(pts, fill)
	if width > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, edge, width, true)

func petal(p: Vector2, s: float, rot: float, color: Color, flip: float = 0.0) -> void:
	var c := cos(rot)
	var sn := sin(rot)
	var fx := 0.35 + 0.65 * absf(cos(flip))
	var pts := PackedVector2Array()
	for v in PETAL:
		var q := Vector2(v.x * fx, v.y)
		pts.append(p + Vector2(q.x * c - q.y * sn, q.x * sn + q.y * c) * s)
	draw_colored_polygon(pts, color)

func ribbon(rect: Rect2, color: Color, value: String, size: int = 24) -> void:
	var dark := color.darkened(0.32)
	var h := rect.size.y
	for side in [-1.0, 1.0]:
		var x0: float = rect.position.x if side < 0 else rect.end.x
		var y0 := rect.position.y + h * 0.3
		var outer: float = x0 + side * h * 0.9
		var pts := PackedVector2Array([Vector2(x0 - side * 10.0, y0), Vector2(outer, y0), Vector2(outer - side * h * 0.3, y0 + h * 0.5),
			Vector2(outer, y0 + h), Vector2(x0 - side * 10.0, y0 + h)])
		draw_colored_polygon(pts, dark)
		pts.append(pts[0])
		draw_polyline(pts, COCOA, 3.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(x0, rect.end.y), Vector2(x0 + side * h * 0.32, y0 + h), Vector2(x0, y0 + h)]), dark.darkened(0.35))
	box(rect, color, COCOA, 8, 3)
	box(Rect2(rect.position + Vector2(6, 4), Vector2(rect.size.x - 12, h * 0.32)), Color(1, 1, 1, 0.2), Color.TRANSPARENT, 5)
	label(value, rect.grow_individual(-12, 0, -12, 0), size, TEXT, MID, 2, 6, dark.darkened(0.35))

func ellipse(c: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(cam + c, 0.0, Vector2(1.0, radii.y / radii.x))
	draw_circle(Vector2.ZERO, radii.x, color, true, -1.0, true)
	draw_set_transform(cam)

func sprite(key: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var image: Texture2D = art[key]
	var ratio := minf(rect.size.x / image.get_width(), rect.size.y / image.get_height())
	var size := image.get_size() * ratio
	draw_texture_rect(image, Rect2(Vector2(rect.get_center().x - size.x / 2.0, rect.end.y - size.y), size), false, tint)

func sprite_at(key: String, rect: Rect2, tint: Color, scale: Vector2, pivot: Vector2) -> void:
	if scale.is_equal_approx(Vector2.ONE):
		sprite(key, rect, tint)
		return
	draw_set_transform(cam + pivot, 0.0, scale)
	sprite(key, Rect2(rect.position - pivot, rect.size), tint)
	draw_set_transform(cam)

func effect(key: String, center: Vector2, bounds: Vector2, alpha: float = 1.0) -> void:
	if alpha <= 0.0:
		return
	var texture: Texture2D = art[key]
	var size := texture.get_size() * minf(bounds.x / texture.get_width(), bounds.y / texture.get_height())
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, Color(1, 1, 1, clampf(alpha, 0, 1)))

func backdrop(key: String, shade: float = 0.0) -> void:
	draw_texture_rect(art[key], Rect2(Vector2.ZERO, SIZE), false)
	if shade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(PLUM, shade))

func gradient_rect(rect: Rect2, left: Color, right: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([left, right, right, left]))

func draw_petals() -> void:
	for q in petals:
		petal(q.p, q.size, q.rot, Color(q.color, 0.88), q.flip)

func draw_parts(list: Array) -> void:
	for q in list:
		var t: float = q.age / q.life
		var c: Color = q.color
		match q.kind:
			"dot":
				draw_circle(q.p, q.size * (1.0 - t * 0.7), Color(c, 1.0 - t * 0.6), true, -1.0, true)
			"star":
				star(q.p, q.size * (1.0 - t * 0.5), Color(c, 1.0 - t), COCOA, 0.0, q.rot)
			"puff":
				draw_circle(q.p, q.size * (0.5 + t * 0.9), Color(c, 0.6 * (1.0 - t)), true, -1.0, true)
			"ring":
				draw_arc(q.p, q.size * (0.2 + 0.8 * ease_out(t)), 0.0, TAU, 48, Color(c, 1.0 - t), 6.0 * (1.0 - t) + 1.0, true)
			"drop":
				draw_circle(q.p, q.size * (1.0 - t * 0.5), Color(c, 1.0 - t), true, -1.0, true)
			"shard":
				var d: Vector2 = Vector2.from_angle(q.rot) * q.size
				var e: Vector2 = Vector2.from_angle(q.rot + 2.3) * q.size * 0.7
				draw_colored_polygon(PackedVector2Array([q.p + d, q.p + e, q.p - d * 0.6]), Color(c, 1.0 - t))
			"petal":
				petal(q.p, q.size, q.rot, Color(c, minf(1.0, (1.0 - t) * 3.0)), q.flip)
			"confetti":
				var a: Vector2 = Vector2.from_angle(q.rot) * q.size * 0.8
				var b: Vector2 = Vector2.from_angle(q.rot + PI * 0.5) * q.size * 0.45 * maxf(0.2, absf(cos(q.flip)))
				draw_colored_polygon(PackedVector2Array([q.p - a - b, q.p + a - b, q.p + a + b, q.p - a + b]), Color(c, minf(1.0, (1.0 - t) * 3.0)))

func draw_floaters(ui: bool) -> void:
	for f in floaters:
		if f.ui != ui:
			continue
		var t: float = f.age / f.life
		var p: Vector2 = f.p - Vector2(0, 46.0 * ease_out(t))
		var alpha := clampf((1.0 - t) * 3.0, 0.0, 1.0)
		label(f.text, Rect2(p - Vector2(80, 14), Vector2(160, 28)), 19, Color(f.color, alpha), MID, 2, 6, Color(COCOA, alpha))

# ---------------------------------------------------------------- 各界面

func _draw() -> void:
	if art.is_empty():
		return
	buttons.clear()
	cam = Vector2.ZERO
	match state:
		TITLE: draw_title()
		SELECT: draw_stages()
		BRIEF: draw_brief()
		PLAY:
			draw_battle()
			if paused:
				draw_pause()
		RESULT:
			draw_battle()
			draw_result()
	draw_parts(ui_parts)
	if ui_time < toast_until and not (state == PLAY and paused):
		var slide := (1.0 - ease_out((ui_time - toast_at) / 0.2)) * 24.0
		var r := Rect2(390, 566 + slide, 500, 46)
		paper(r, 23, CREAM, COCOA, false, 0.4)
		draw_circle(Vector2(r.position.x + 26, r.get_center().y), 9, BERRY, true, -1.0, true)
		label(toast, Rect2(r.position.x + 44, r.position.y, r.size.x - 60, r.size.y), 17, COCOA, MID, 2)

func draw_title() -> void:
	backdrop("cafe")
	gradient_rect(Rect2(0, 0, 820, 720), Color(PLUM, 0.86), Color(PLUM, 0.0))
	draw_polygon(PackedVector2Array([Vector2(0, 560), Vector2(1280, 560), Vector2(1280, 720), Vector2(0, 720)]),
		PackedColorArray([Color(PLUM, 0.0), Color(PLUM, 0.0), Color(PLUM, 0.55), Color(PLUM, 0.55)]))
	draw_showcase()
	draw_petals()
	# 挂在门口的店招，轻轻摇晃
	var pivot := Vector2(330, -4)
	draw_set_transform(pivot, sin(ui_time * 1.15) * 0.014)
	for x in [-176.0, 176.0]:
		draw_line(Vector2(x, 0), Vector2(x * 0.92, 78), COCOA, 6.0, true)
		draw_line(Vector2(x, 0), Vector2(x * 0.92, 78), GOLD_DEEP, 2.5, true)
		draw_circle(Vector2(x * 0.92, 80), 8, GOLD_DEEP, true, -1.0, true)
		draw_circle(Vector2(x * 0.92, 80), 4, COCOA, true, -1.0, true)
	var board := Rect2(-268, 74, 536, 300)
	box(board, WOOD, GOLD_DEEP, 28, 4, 0.5)
	stitches(board.grow(-12), 22.0, Color(GOLD, 0.45))
	box(Rect2(-134, 100, 268, 34), SAKURA, COCOA, 17, 3)
	label("AI  CAFÉ  DEFENSE", Rect2(-134, 100, 268, 34), 15, TEXT, MID, 2, 4, SAKURA_DEEP)
	label("AI 娘守店记", Rect2(-268, 152, 536, 110).grow_individual(-16, 0, -16, 0), 84, COCOA, MID, 2, 16, COCOA)
	var logo := Rect2(-268, 146, 536, 110).grow_individual(-16, 0, -16, 0)
	label("AI 娘守店记", logo, 84, CREAM, MID, 2, 12, SAKURA_DEEP)
	ribbon(Rect2(-196, 276, 392, 52), SAKURA, "算力咖啡厅 · 开门营业", 22)
	glyph("cup", Vector2(214, 116), 15, GOLD)
	for k in range(3):
		var y := 92.0 - fmod(ui_time * 14.0 + k * 9.0, 26.0)
		draw_arc(Vector2(208 + k * 6, y), 4, -1.2, 1.2, 6, Color(CREAM, 0.6 * (1.0 - (92.0 - y) / 26.0)), 2.0, true)
	star(Vector2(-226, 118), 9 + 3 * sin(ui_time * 3.0), GOLD, COCOA, 0.0)
	star(Vector2(-200, 340), 6 + 2 * sin(ui_time * 2.4 + 1.0), SAKURA_PALE, COCOA, 0.0)
	draw_set_transform(Vector2.ZERO)
	label("收集算力，叫店员上阵。", Rect2(94, 404, 620, 36), 23, TEXT, 0, 2, 7, PLUM)
	label("别让资本怪客摸到吧台。", Rect2(94, 442, 620, 36), 23, TEXT, 0, 2, 7, PLUM)
	candy("开始营业  ›", Rect2(92, 500, 254, 70), open_map.bind(true), 0, 25)
	candy("退出游戏", Rect2(362, 500, 168, 70), get_tree().quit, 1)
	label("第 01 章 · 1-0 至 1-20EX   ·   已通关 %d / %d" % [stars.size() - stars.count(0), stars.size()], Rect2(96, 648, 640, 30), 15, MUTED, 0, 1, 5, PLUM)
	round_button("music", Vector2(1150, 60), 28, toggle_music, false, "音乐", not music_on)
	round_button("sound", Vector2(1218, 60), 28, toggle_sfx, false, "音效", not sfx_on)

# 标题右侧轮流介绍八位店员，也可以点下面的小圆点切换。
func draw_showcase() -> void:
	if ui_time - showcase_at > 4.2:
		showcase = (showcase + 1) % Campaign.CARDS.size()
		showcase_at = ui_time
	var card: Dictionary = Campaign.CARDS[showcase]
	var accent: Color = ACCENTS[showcase]
	var t := clampf((ui_time - showcase_at) / 0.5, 0.0, 1.0)
	var center := Vector2(990, 410)
	for i in range(7):
		draw_circle(center, 250.0 - i * 32.0, Color(accent.lerp(SAKURA_PALE, 0.4), 0.05 + i * 0.012), true, -1.0, true)
	for k in range(8):
		var a := ui_time * 0.25 + k * TAU / 8.0
		star(center + Vector2(cos(a), sin(a) * 0.8) * 236.0, 5.0 + 2.5 * sin(ui_time * 3.0 + k), Color(GOLD, 0.85), COCOA, 0.0)
	ellipse(Vector2(990, 628), Vector2(150, 22), Color(PLUM, 0.45))
	var bob := sin(ui_time * 2.2) * 6.0
	var slide := (1.0 - ease_out(t)) * 70.0
	sprite(card.key, Rect2(785 + slide, 178 + bob, 410, 456), Color(1, 1, 1, t))
	var badge := Rect2(842, 596, 296, 72)
	paper(badge, 20)
	box(Rect2(badge.position + Vector2(14, 14), Vector2(10, 44)), accent, Color.TRANSPARENT, 5)
	label("今日值班", Rect2(badge.position + Vector2(34, 8), Vector2(120, 22)), 13, INK_SOFT, 0, 1)
	label(card.name, Rect2(badge.position + Vector2(34, 28), Vector2(130, 38)), 26, COCOA, 0, 2)
	box(Rect2(badge.position + Vector2(170, 22), Vector2(112, 30)), Color(accent, 0.25), accent.darkened(0.2), 15, 2)
	label(card.role, Rect2(badge.position + Vector2(170, 22), Vector2(112, 30)), 14, COCOA, MID, 2)
	for i in range(Campaign.CARDS.size()):
		var dot := Vector2(990 - (Campaign.CARDS.size() - 1) * 9.0 + i * 18.0, 690)
		draw_circle(dot, 6.5 if i == showcase else 5.0, COCOA, true, -1.0, true)
		draw_circle(dot, 4.5 if i == showcase else 3.0, SAKURA if i == showcase else CREAM, true, -1.0, true)
		buttons.append([Rect2(dot - Vector2(9, 9), Vector2(18, 18)), pick_showcase.bind(i), "click"])

func pick_showcase(index: int) -> void:
	showcase = index
	showcase_at = ui_time

func header(kicker: String, title: String, sub: String, back: Callable) -> void:
	round_button("back", Vector2(84, 70), 30, back)
	label(kicker, Rect2(134, 30, 400, 26), 15, SAKURA_PALE, 0, 2, 4, PLUM)
	label(title, Rect2(132, 52, 760, 54), 38, TEXT, 0, 2, 9, COCOA)
	if sub != "":
		label(sub, Rect2(134, 104, 760, 28), 16, MUTED, 0, 1, 5, PLUM)

func draw_stages() -> void:
	backdrop("cafe", 0.62)
	draw_petals()
	header("今日菜单", "第 01 章 · 算力咖啡厅", "完成当前关卡即可开启下一场值班。", open_title)
	var badge := Rect2(950, 38, 276, 84)
	paper(badge, 20)
	star(Vector2(992, 80), 20, GOLD, COCOA, 2.5)
	label("%d / %d" % [total_stars(), stars.size() * 3], Rect2(1022, 46, 190, 40), 28, COCOA, 0, 2)
	label("已通关 %d / %d 关" % [stars.size() - stars.count(0), stars.size()], Rect2(1023, 84, 190, 26), 14, INK_SOFT, 0, 1)
	for slot in range(PAGE_SIZE):
		var i := page * PAGE_SIZE + slot
		if i >= Campaign.levels.size():
			break
		draw_stage_card(i, Rect2(56.0 + (slot % 3) * 392.0, 150.0 + floorf(slot / 3.0) * 218.0, 372, 200))
	var last := floori(float(Campaign.levels.size() - 1) / PAGE_SIZE)
	round_button("back", Vector2(530, 648), 28, change_page.bind(-1) if page > 0 else Callable())
	round_button("next", Vector2(750, 648), 28, change_page.bind(1) if page < last else Callable())
	for p in range(last + 1):
		var dot := Vector2(640 - last * 15.0 + p * 30.0, 648)
		draw_circle(dot, 9 if p == page else 7, COCOA, true, -1.0, true)
		draw_circle(dot, 6 if p == page else 4, SAKURA if p == page else CREAM, true, -1.0, true)
		buttons.append([Rect2(dot - Vector2(13, 13), Vector2(26, 26)), set_page.bind(p), "page"])
	for b in buttons:
		if b[1].get_method() == "change_page":
			b[2] = "page"

func draw_stage_card(i: int, rect: Rect2) -> void:
	var level: Dictionary = Campaign.levels[i]
	var locked := i > unlocked()
	var arena: Array = ARENAS[level.arena]
	var boss := i == Campaign.levels.size() - 1
	var tone: Color = GOLD_DEEP if boss else arena[1]
	var fresh: bool = not locked and stars[i] == 0
	var hot := not locked and rect.has_point(pointer)
	var r := rect
	if hot:
		r.position.y -= 4
	if fresh:
		box(r.grow(5.0 + 2.0 * sin(ui_time * 4.0)), Color(SAKURA, 0.45), Color.TRANSPARENT, 26)
	paper(r, 20, LATTE if locked else CREAM, SAKURA_DEEP if hot else COCOA, not locked)
	var pc := r.position + Vector2(84, 118)
	draw_circle(pc, 60, COCOA, true, -1.0, true)
	draw_circle(pc, 57, Color("#d8c3ad") if locked else tone.lightened(0.55), true, -1.0, true)
	sprite(stage_art(i), Rect2(pc.x - 64, pc.y - 82, 128, 138), Color(0.55, 0.5, 0.5, 0.55) if locked else Color.WHITE)
	if locked:
		draw_circle(pc + Vector2(0, 8), 24, Color(COCOA, 0.8), true, -1.0, true)
		glyph("lock", pc + Vector2(0, 8), 13, CREAM)
	var chip := Rect2(r.position + Vector2(14, 14), Vector2(86, 30))
	box(chip, Color("#b49a85") if locked else tone, COCOA, 15, 2)
	label(Campaign.code(i), chip, 16, TEXT, MID, 2, 3, COCOA)
	label("挑战" if boss else arena[0], Rect2(r.end.x - 124, r.position.y + 15, 106, 26), 14, INK_SOFT if locked else tone.darkened(0.35), END, 2)
	label(level.title, Rect2(r.position.x + 158, r.position.y + 48, r.size.x - 172, 34), 24, INK_SOFT if locked else COCOA, 0, 2)
	label("%d 路 · %s" % [level.rows, "三阶段 Boss" if boss else "%d 波" % level.waves], Rect2(r.position.x + 158, r.position.y + 82, 200, 22), 15, INK_SOFT, 0, 1)
	for s in range(3):
		star(Vector2(r.position.x + 172 + s * 32, r.position.y + 124), 12, GOLD if s < stars[i] else Color("#e6d2ba"), COCOA, 2.0)
	if locked:
		label("完成前一关后解锁", Rect2(r.position.x + 158, r.end.y - 52, r.size.x - 172, 36), 15, INK_SOFT, 0, 2)
	else:
		buttons.append([rect, open_stage.bind(i), "click"])
		candy("开始值班  ›" if stars[i] == 0 else "再来一局", Rect2(r.position.x + 156, r.end.y - 60, r.size.x - 172, 46), open_stage.bind(i), 0 if stars[i] == 0 else 1)
	if fresh:
		draw_set_transform(Vector2(r.end.x - 26, r.position.y + 4), 0.25)
		box(Rect2(-30, -14, 60, 28), SAKURA, COCOA, 14, 2)
		label("NEW", Rect2(-30, -14, 60, 28), 14, TEXT, MID, 2, 3, SAKURA_DEEP)
		draw_set_transform(Vector2.ZERO)

func draw_brief() -> void:
	backdrop("cafe", 0.7)
	draw_petals()
	var level: Dictionary = Campaign.levels[stage]
	var arena: Array = ARENAS[level.arena]
	round_button("back", Vector2(84, 66), 30, open_map)
	var chip := Rect2(132, 44, 96, 40)
	box(chip, arena[1], COCOA, 20, 3)
	label(Campaign.code(stage), chip, 18, TEXT, MID, 2, 4, COCOA)
	label(level.title, Rect2(242, 36, 760, 56), 38, TEXT, 0, 2, 9, COCOA)
	var bubble := Rect2(56, 104, 1168, 54)
	paper(bubble, 22, CREAM, COCOA, false, 0.3)
	draw_circle(Vector2(84, 131), 17, SAKURA, true, -1.0, true)
	glyph("cup", Vector2(84, 132), 9, TEXT)
	label("店长叮嘱：" + level.brief, Rect2(112, 104, 1096, 54), 17, COCOA, 0, 1)
	var panel := Rect2(56, 174, 860, 444)
	paper(panel, 22)
	label("教学值班 · 固定阵容" if stage == 0 else "选择值班店员", Rect2(80, 186, 400, 34), 21, COCOA, 0, 2)
	if stage > 0:
		var count := Rect2(800, 188, 96, 30)
		box(count, SAKURA, COCOA, 15, 2)
		label("%d / %d" % [loadout.count(true), MAX_LOADOUT], count, 16, TEXT, MID, 2, 3, SAKURA_DEEP)
	for i in range(Campaign.CARDS.size()):
		draw_badge(i, Rect2(78.0 + (i % 4) * 208.0, 230.0 + floorf(i / 4.0) * 190.0, 194, 176))
	draw_receipt(level, arena, Rect2(936, 174, 288, 444))
	candy("开始值班  ›", Rect2(970, 634, 254, 66), start_battle, 0, 24)
	var tips := "点卡片再点格子部署 · 点发光算力收集 · 再点卡片取消"
	if not mobile:
		tips += " · 1-5 选卡  R 移除  空格 暂停"
	label(tips, Rect2(60, 648, 890, 36), 15, MUTED, 0, 1, 5, PLUM)

func draw_badge(i: int, rect: Rect2) -> void:
	var card: Dictionary = Campaign.CARDS[i]
	var accent: Color = ACCENTS[i]
	var available := Campaign.available(i, stage)
	var on: bool = loadout[i]
	var hot := available and stage > 0 and rect.has_point(pointer)
	var r := rect
	if on:
		r.position.y -= 5
	elif hot:
		r.position.y -= 2
	if on:
		box(r.grow(5), Color(accent, 0.45), Color.TRANSPARENT, 20)
	box(r, CREAM if available else LATTE, accent.darkened(0.25) if on else COCOA, 16, 4 if on else 3, 0.25)
	box(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 30)), accent if available else Color("#c8ad93"), Color.TRANSPARENT, 12)
	box(Rect2(r.get_center().x - 18, r.position.y + 13, 36, 8), Color(COCOA, 0.45), Color.TRANSPARENT, 4)
	label("No.%d" % (i + 1), Rect2(r.position + Vector2(12, 6), Vector2(60, 26)), 12, TEXT, 0, 2, 3, Color(COCOA, 0.6))
	sprite(card.key, Rect2(r.position + Vector2(12, 36), Vector2(r.size.x - 24, 82)), Color.WHITE if available else Color(0.6, 0.55, 0.55, 0.45))
	label(card.name, Rect2(r.position.x + 8, r.position.y + 118, r.size.x - 16, 26), 19, COCOA if available else INK_SOFT, MID, 2)
	label(card.role, Rect2(r.position.x + 12, r.position.y + 146, 100, 22), 13, INK_SOFT, 0, 1)
	var cost := Rect2(r.end.x - 74, r.position.y + 145, 62, 24)
	box(cost, Color(MINT, 0.55) if available else Color("#dcc6ae"), COCOA, 12, 2)
	gem(cost.position + Vector2(13, 12), 7, MINT_DEEP if available else INK_SOFT, Color.TRANSPARENT)
	label(str(card.cost), Rect2(cost.position + Vector2(22, 0), Vector2(38, 24)), 14, COCOA, MID, 2)
	if not available:
		draw_circle(r.position + Vector2(r.size.x * 0.5, 78), 22, Color(COCOA, 0.8), true, -1.0, true)
		glyph("lock", r.position + Vector2(r.size.x * 0.5, 78), 12, CREAM)
		label(Campaign.code(Campaign.UNLOCKS[i]) + " 解锁", Rect2(r.position.x + 70, r.position.y + 6, r.size.x - 82, 26), 12, TEXT, END, 2, 3, Color(COCOA, 0.6))
	elif on:
		var tag := Rect2(r.end.x - 70, r.position.y - 10, 76, 28)
		box(tag, SAKURA, COCOA, 14, 2)
		glyph("check", tag.position + Vector2(16, 14), 7, TEXT)
		label("上阵", Rect2(tag.position + Vector2(26, 0), Vector2(46, 28)), 14, TEXT, MID, 2, 3, SAKURA_DEEP)
	if available and stage > 0:
		buttons.append([rect, toggle_card.bind(i), "select"])

# 「今日来客」小票：锯齿边的白纸，列出本关会来的敌人。
func draw_receipt(level: Dictionary, arena: Array, r: Rect2) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - 10)])
	var x := r.end.x
	var up := true
	while x > r.position.x:
		x = maxf(r.position.x, x - 9.0)
		pts.append(Vector2(x, r.end.y if up else r.end.y - 10))
		up = not up
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, 6))
	draw_colored_polygon(shadow, Color(PLUM, 0.35))
	draw_colored_polygon(pts, Color("#fffdf6"))
	pts.append(pts[0])
	draw_polyline(pts, COCOA, 3.0, true)
	label("今 日 来 客", Rect2(r.position.x, r.position.y + 14, r.size.x, 30), 21, COCOA, MID, 2)
	label("No.%s · %s" % [Campaign.code(stage), arena[0]], Rect2(r.position.x, r.position.y + 44, r.size.x, 20), 13, INK_SOFT, MID, 1)
	draw_dashed_line(Vector2(r.position.x + 16, r.position.y + 74), Vector2(r.end.x - 16, r.position.y + 74), Color(COCOA, 0.45), 2.0, 6.0)
	var counts := {}
	for spawn in level.spawns:
		counts[spawn[3]] = int(counts.get(spawn[3], 0)) + 1
	var row := 0
	for id in ["X", "T", "D", "I", "B", "A", "S", "R", "C"]:
		if not counts.has(id) or row >= 6:
			continue
		var enemy: Dictionary = Campaign.ENEMIES[id]
		var y := r.position.y + 84 + row * 50
		sprite(enemy.key, Rect2(r.position.x + 14, y, 52, 46))
		label(enemy.name, Rect2(r.position.x + 74, y + 2, 140, 24), 16, COCOA, 0, 2)
		label(ENEMY_TIPS[id], Rect2(r.position.x + 74, y + 25, 140, 20), 12, INK_SOFT, 0, 1)
		label("×%d" % counts[id], Rect2(r.end.x - 72, y, 56, 46), 19, SAKURA_DEEP, END, 2)
		row += 1
	var foot := r.position.y + 392
	draw_dashed_line(Vector2(r.position.x + 16, foot), Vector2(r.end.x - 16, foot), Color(COCOA, 0.45), 2.0, 6.0)
	label("%d 路 · %d 波" % [level.rows, level.waves], Rect2(r.position.x + 18, foot + 6, 140, 30), 16, COCOA, 0, 2)
	gem(Vector2(r.end.x - 112, foot + 21), 9, MINT, COCOA)
	label("开局 %d" % level.power, Rect2(r.end.x - 100, foot + 6, 84, 30), 16, COCOA, END, 2)

func draw_pause() -> void:
	buttons.clear()
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(PLUM, 0.62))
	var r := Rect2(420, 160, 440, 400)
	paper(r, 26)
	draw_circle(Vector2(640, 214), 34, SAKURA, true, -1.0, true)
	draw_circle(Vector2(640, 214), 34, COCOA, false, 3.0, true)
	glyph("cup", Vector2(640, 218), 17, TEXT)
	label("营业暂停", Rect2(r.position.x, 254, r.size.x, 50), 36, COCOA, MID, 2)
	label("咖啡还热着，休息一下吧。", Rect2(r.position.x, 302, r.size.x, 26), 16, INK_SOFT, MID, 1)
	candy("继续营业", Rect2(470, 340, 340, 62), func(): paused = false, 0, 22)
	candy("重开本关", Rect2(470, 414, 164, 52), start_battle, 1)
	candy("返回选关", Rect2(646, 414, 164, 52), open_map, 1)
	round_button("music", Vector2(600, 500), 22, toggle_music, false, "", not music_on)
	round_button("sound", Vector2(680, 500), 22, toggle_sfx, false, "", not sfx_on)
	label("音乐", Rect2(560, 524, 80, 22), 13, INK_SOFT, MID, 2)
	label("音效", Rect2(640, 524, 80, 22), 13, INK_SOFT, MID, 2)

func draw_result() -> void:
	buttons.clear()
	var won: bool = battle.result == 1
	var age := ui_time - result_at
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(PLUM, minf(0.62, age * 2.2)))
	var r := Rect2(380, 112, 520, 500)
	var k := ease_back(age / 0.36)
	var c := r.get_center()
	draw_set_transform(c * (1.0 - k), 0.0, Vector2(k, k))
	paper(r, 28)
	ribbon(Rect2(r.position.x + 74, r.position.y - 28, r.size.x - 148, 60), SAKURA if won else Color("#9a7488"), "值班成功！" if won else "吧台失守…", 30)
	label("%s · %s" % [Campaign.code(stage), battle.level.title], Rect2(r.position.x, r.position.y + 44, r.size.x, 30), 17, INK_SOFT, MID, 2)
	if won:
		for s in range(3):
			var p := Vector2(640 + (s - 1) * 112, 268)
			star(p, 42, Color("#eadbc6"), COCOA, 3.0)
			if s < stars_played:
				var pop := ease_back((age - 0.5 - s * 0.32) / 0.3)
				star(p, 42 * pop, GOLD, COCOA, 3.0)
				star(p + Vector2(-10, -12) * pop, 9 * pop, Color(1, 1, 1, 0.7), COCOA, 0.0)
	else:
		draw_circle(Vector2(640, 262), 46, Color("#eadbc6"), true, -1.0, true)
		draw_circle(Vector2(640, 262), 46, COCOA, false, 3.0, true)
		glyph("cup", Vector2(640, 268), 24, Color("#9a7488"))
		draw_line(Vector2(626, 238), Vector2(650, 290), Color("#fffaf2"), 4.0, true)
	var stats := [["击退", str(battle.defeated)], ["部署", str(battle.placed)], ["收集", str(battle.collected)], ["用时", "%d:%02d" % [floori(battle.time / 60.0), int(battle.time) % 60]]]
	for s in range(4):
		var cell := Rect2(r.position.x + 30 + s * 117, r.position.y + 216, 108, 62)
		box(cell, Color("#f6e6cf"), Color(COCOA, 0.0), 14)
		label(stats[s][1], Rect2(cell.position + Vector2(0, 4), Vector2(cell.size.x, 32)), 24, COCOA, MID, 2)
		label(stats[s][0], Rect2(cell.position + Vector2(0, 36), Vector2(cell.size.x, 20)), 13, INK_SOFT, MID, 1)
	var copy := "清洁机器人每路只能救场一次，换一套布阵再试试。"
	if won:
		copy = ("EX 挑战已完成，感谢守店！" if stage == 21 else "第 01 章通关，EX 挑战已解锁。" if stage == 20 else "进度已保存，下一关已解锁。") if save_ok else "进度写入失败，可以重试。"
	label(copy, Rect2(r.position.x + 20, r.position.y + 290, r.size.x - 40, 30), 16, COCOA if won else SAKURA_DEEP, MID, 1)
	if won and save_ok and stage < Campaign.levels.size() - 1:
		candy("下一关  ›", Rect2(430, r.position.y + 334, 420, 64), open_stage.bind(stage + 1), 0, 23)
	else:
		var retry: Callable = start_battle
		if won and save_ok:
			retry = open_map
		candy("返回关卡列表" if won and save_ok else "再试一局", Rect2(430, r.position.y + 334, 420, 64), retry, 0, 23)
	candy("重玩本关" if won else "调整阵容", Rect2(430, r.position.y + 412, 204, 52), start_battle if won else open_stage.bind(stage), 1)
	candy("返回选关", Rect2(646, r.position.y + 412, 204, 52), open_map, 1)
	draw_set_transform(Vector2.ZERO)

# ---------------------------------------------------------------- 战斗画面

const BOARD_X := 206.0
const CELL := 101.0

func row_pitch() -> float:
	return 79.0 if battle.level.rows == 5 else 97.0 if battle.level.rows == 4 else 113.0

func row_height() -> float:
	return row_pitch() - 8.0

func lane_y(row: int) -> float:
	return 228.0 + (395.0 - battle.level.rows * row_pitch()) * 0.5 + row * row_pitch()

func board_x(col: float) -> float:
	return BOARD_X + col * CELL

func board_cell(p: Vector2) -> Vector2i:
	var row := floori((p.y - lane_y(0)) / row_pitch())
	var col := floori((p.x - BOARD_X) / CELL)
	if not battle.valid(row, col) or p.y >= lane_y(row) + row_height():
		return Vector2i(-1, -1)
	return Vector2i(col, row)

func token_point(token: Dictionary) -> Vector2:
	var age: float = battle.time - token.born
	var lift := maxf(0.0, 1.0 - age * 3.0) * 28.0
	return Vector2(board_x(token.x), lane_y(token.row) + row_height() * (0.24 if token.kimi else 0.48) - lift + sin(age * 4.5) * 3.0)

func draw_battle() -> void:
	var live: bool = (state == PLAY and not paused) or state == RESULT
	cam = shake_offset() if live else Vector2.ZERO
	draw_set_transform(cam)
	draw_texture_rect(art[battle.level.arena], Rect2(Vector2(-16, -16), SIZE + Vector2(32, 32)), false)
	draw_rect(Rect2(-16, -16, 1312, 752), Color(PLUM, 0.1))
	draw_signs()
	var hover := board_cell(pointer)
	for row in range(battle.level.rows):
		var y := lane_y(row)
		var height := row_height()
		box(Rect2(BOARD_X - 8, y - 3, 9 * CELL + 16, height + 6), Color(PLUM, 0.34), Color(CREAM, 0.5), 14, 2)
		draw_robot(row, y)
		for col in range(9):
			draw_tile(row, col, hover)
		for col in range(9):
			if battle.towers[row][col] != null:
				draw_tower(row, col, battle.towers[row][col])
		for enemy in battle.enemies:
			if enemy.row == row:
				draw_enemy(enemy)
		for shot in battle.shots:
			if shot.row == row:
				draw_shot(shot)
		if battle.sweep_until[row] > battle.time:
			var x := lerpf(144.0, 1220.0, 1.0 - (float(battle.sweep_until[row]) - battle.time) / 0.85)
			for k in range(3):
				draw_line(Vector2(x - 40 - k * 30, y + height * (0.45 + k * 0.12)), Vector2(x - 100 - k * 40, y + height * (0.45 + k * 0.12)), Color(MINT, 0.55 - k * 0.15), 5.0, true)
			sprite_at("robot", Rect2(x - 43, y, 86, height), Color.WHITE, Vector2(1.08, 0.94), Vector2(x, y + height))
	for token in battle.tokens:
		draw_token(token)
	for hit in battle.impacts:
		draw_impact(hit)
	for alert in battle.warnings:
		draw_warning(alert)
	for g in ghosts:
		var t: float = g.age / 0.38
		var rect: Rect2 = g.rect
		sprite_at(g.key, rect, Color(1.6, 1.6, 1.6, 1.0 - t), Vector2(1.0 + t * 0.35, 1.0 - t * 0.25), Vector2(rect.get_center().x, rect.end.y))
	draw_parts(parts)
	draw_floaters(false)
	draw_set_transform(Vector2.ZERO)
	cam = Vector2.ZERO
	draw_hud()
	if battle.boss_phase > 0:
		draw_boss_meter()
	draw_banner()
	draw_bottom()
	draw_flyers()
	draw_floaters(true)
	if stage == 0 and state == PLAY and not paused:
		draw_tutorial()
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(flash_color, flash * 0.45))

func draw_signs() -> void:
	var left := Rect2(30, 180, 108, 36)
	box(left, WOOD, GOLD_DEEP, 12, 2, 0.3)
	glyph("cup", left.position + Vector2(22, 18), 9, GOLD)
	label("吧台", Rect2(left.position + Vector2(36, 0), Vector2(66, 36)), 16, CREAM, MID, 2)
	var right := Rect2(1146, 180, 104, 36)
	box(right, WOOD, GOLD_DEEP, 12, 2, 0.3)
	glyph("door", right.position + Vector2(22, 18), 9, GOLD)
	label("入口 ‹", Rect2(right.position + Vector2(34, 0), Vector2(66, 36)), 16, CREAM, MID, 2)

func draw_tile(row: int, col: int, hover: Vector2i) -> void:
	var y := lane_y(row)
	var h := row_height()
	var tile := Rect2(board_x(col) + 3, y + 2, CELL - 6, h - 4)
	var cell := Vector2i(col, row)
	if cell in battle.level.blocked:
		box(tile, Color("#f2b84b", 0.3), Color("#f2b84b"), 9, 2)
		var c := tile.get_center() + Vector2(0, -6)
		var tri := PackedVector2Array([c + Vector2(0, -20), c + Vector2(20, 14), c + Vector2(-20, 14)])
		draw_colored_polygon(tri, GOLD)
		tri.append(tri[0])
		draw_polyline(tri, COCOA, 3.0, true)
		label("!", Rect2(c.x - 10, c.y - 12, 20, 26), 18, COCOA, MID, 2)
		label("封闭", Rect2(tile.position.x, tile.end.y - 22, tile.size.x, 20), 13, TEXT, MID, 2, 4, COCOA)
		return
	var tower = battle.towers[row][col]
	box(tile, Color(1, 0.95, 0.88, 0.13 if (col + row) % 2 == 0 else 0.06), Color.TRANSPARENT, 9)
	if cell != hover or state != PLAY or paused:
		return
	if selected >= 0:
		var card: Dictionary = Campaign.CARDS[selected]
		var ok: bool = tower == null and battle.time >= battle.ready_at[selected] and battle.power >= card.cost
		var tint := MINT if ok else BERRY
		box(tile, Color(tint, 0.24), tint, 9, 3)
		if ok:
			var accent: Color = ACCENTS[selected]
			if selected in [0, 2, 4, 5, 7]:
				var lanes := [row]
				if selected == 4:
					lanes = range(maxi(0, row - 1), mini(battle.level.rows - 1, row + 1) + 1)
				for lane in lanes:
					var ly := lane_y(lane) + row_height() * 0.45
					draw_dashed_line(Vector2(tile.end.x + 4, ly), Vector2(board_x(9) - 6, ly), Color(accent, 0.75), 3.0, 12.0)
			elif selected == 6:
				box(Rect2(BOARD_X, y, 9 * CELL, h), Color(MINT, 0.12), Color.TRANSPARENT, 10)
			sprite(card.key, tile.grow(-4), Color(1, 1, 1, 0.6))
	elif selected == -2:
		var tint := BERRY if tower != null else CREAM
		box(tile, Color(tint, 0.24), tint, 9, 3)
	else:
		box(tile, Color(CREAM, 0.1), Color(CREAM, 0.7), 9, 2)

func draw_robot(row: int, y: float) -> void:
	var ready: bool = battle.robots[row]
	sprite("robot", Rect2(140, y + 18, 64, row_height() - 21), Color(1, 1, 1, 1.0 if ready else 0.25))
	var c := Vector2(150, y + 12)
	draw_circle(c, 11, COCOA, true, -1.0, true)
	draw_circle(c, 9, MINT if ready else Color("#b8a0a8"), true, -1.0, true)
	label(str(row + 1), Rect2(c - Vector2(10, 10), Vector2(20, 20)), 12, COCOA, MID, 2)

func draw_hud() -> void:
	var bar := Rect2(22, 12, 1236, 128)
	box(bar, Color(WOOD, 0.96), GOLD_DEEP, 20, 3, 0.4)
	stitches(bar.grow(-9), 14.0, Color(GOLD, 0.35))
	# 算力
	var pc := Vector2(78, 72)
	var pop := 1.0 + 0.2 * maxf(0.0, 1.0 - (ui_time - power_pop) / 0.25)
	var deny := ui_time - power_deny < 0.4
	var pill := Rect2(104, 48, 118, 50)
	if deny:
		pill.position.x += sin(ui_time * 70.0) * 4.0
	box(pill, CREAM, BERRY if deny else COCOA, 25, 3)
	label(str(int(shown_power)), pill.grow_individual(-24, 0, -8, 0), 30, BERRY if deny else COCOA, MID, 2)
	draw_circle(pc, 46, COCOA, true, -1.0, true)
	draw_circle(pc, 42, Color("#26403b"), true, -1.0, true)
	draw_arc(pc, 38, 0.0, TAU, 40, MINT, 4.0, true)
	gem(pc + Vector2(0, -7), 17.0 * pop, MINT)
	label("算力", Rect2(pc.x - 30, pc.y + 14, 60, 20), 13, MINT, MID, 2)
	var active := equipped()
	for slot in range(active.size()):
		draw_card(active[slot], slot, Rect2(246 + slot * 114, 24, 104, 108))
	round_button("broom", Vector2(866, 64), 30, toggle_remove, selected == -2, "移除")
	round_button("pause", Vector2(944, 64), 30, pause_game, false, "暂停")
	for b in buttons:
		if b[1] == Callable(self, "toggle_remove"):
			b[2] = ""
	var arena: Array = ARENAS[battle.level.arena]
	var chip := Rect2(1004, 32, 78, 30)
	box(chip, GOLD_DEEP if stage == Campaign.levels.size() - 1 else arena[1], COCOA, 15, 2)
	label(Campaign.code(stage), chip, 15, TEXT, MID, 2, 3, COCOA)
	label(arena[0], Rect2(1090, 32, 150, 30), 14, GOLD, 0, 2)
	label(battle.level.title, Rect2(1004, 70, 236, 40), 22, CREAM, 0, 2, 5, COCOA)

func draw_card(i: int, slot: int, rect: Rect2) -> void:
	var card: Dictionary = Campaign.CARDS[i]
	var accent: Color = ACCENTS[i]
	var available: bool = battle.deck[i]
	var left := maxf(0.0, float(battle.ready_at[i]) - battle.time)
	var afford: bool = battle.power >= card.cost
	var chosen := selected == i
	var r := rect
	if chosen:
		r.position.y -= 9
	elif available and rect.has_point(pointer) and state == PLAY and not paused:
		r.position.y -= 3
	if chosen:
		box(r.grow(5), Color(SAKURA, 0.5), Color.TRANSPARENT, 18)
	box(r, CREAM, SAKURA_DEEP if chosen else COCOA, 14, 4 if chosen else 3, 0.3)
	box(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 34)), Color(accent, 0.3), Color.TRANSPARENT, 10)
	var dim := Color.WHITE if available and afford else Color(0.62, 0.56, 0.56, 0.9 if available else 0.35)
	sprite(card.key, Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 70)), dim)
	label(card.name, Rect2(r.position.x + 6, r.end.y - 28, r.size.x - 12, 24), 15, COCOA, MID, 2)
	var chip := Rect2(r.position + Vector2(-6, -9), Vector2(60, 26))
	box(chip, MINT if afford else Color("#ffc4d1"), COCOA, 13, 2)
	gem(chip.position + Vector2(14, 13), 7, MINT_DEEP if afford else BERRY, Color.TRANSPARENT)
	label(str(card.cost), Rect2(chip.position + Vector2(22, 0), Vector2(36, 26)), 15, COCOA if afford else Color("#b0284e"), MID, 2)
	if not mobile:
		var key := r.position + Vector2(r.size.x - 13, 13)
		draw_circle(key, 10, COCOA, true, -1.0, true)
		label(str(slot + 1), Rect2(key - Vector2(10, 10), Vector2(20, 20)), 12, CREAM, MID, 2)
	if left > 0.0 and available:
		var ratio := clampf(left / float(card.cooldown), 0.0, 1.0)
		box(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, (r.size.y - 6) * ratio)), Color(PLUM, 0.66), Color.TRANSPARENT, 11)
		label("%.1f" % left, Rect2(r.position.x, r.position.y + 30, r.size.x, 36), 24, TEXT, MID, 2, 6, PLUM)
	else:
		var since: float = battle.time - float(battle.ready_at[i])
		if battle.ready_at[i] > 0.0 and since < 0.4:
			draw_rect(r.grow(2.0 + since * 24.0), Color(accent, 1.0 - since / 0.4), false, 3.0)
	if available:
		buttons.append([rect, choose_card.bind(i), ""])

func draw_bottom() -> void:
	var r := Rect2(28, 630, 1224, 72)
	paper(r, 20, CREAM, COCOA, false, 0.35)
	draw_circle(Vector2(66, 666), 19, SAKURA, true, -1.0, true)
	draw_circle(Vector2(66, 666), 19, COCOA, false, 2.5, true)
	glyph("cup", Vector2(66, 668), 10, TEXT)
	var help: String = battle.level.brief
	if selected == -2:
		help = "点击一位店员所在的格子将其移除。"
	elif selected >= 0:
		help = Campaign.CARDS[selected].desc + "  点击空格部署。"
	elif stage == 0:
		help = ("教学 ① 点击场上的发光算力。" if battle.collected == 0 else
			"教学 ② 点击 GPT 卡，再点击路上的空格。" if battle.placed == 0 else
			"教学 ③ GPT 会自动开火，守住这一行。")
	label(help, Rect2(96, 636, 770, 60), 17, COCOA, 0, 1)
	label("第 %d / %d 波" % [maxi(1, battle.wave), battle.level.waves], Rect2(892, 638, 160, 24), 15, COCOA, 0, 2)
	label("已击退 %d" % battle.defeated, Rect2(1050, 638, 180, 24), 14, INK_SOFT, END, 1)
	var track := Rect2(892, 670, 338, 16)
	box(track, LATTE, COCOA, 8, 2)
	var ratio: float = float(battle.spawned) / maxf(1.0, battle.level.spawns.size())
	if ratio > 0.0:
		box(Rect2(track.position + Vector2(3, 3), Vector2((track.size.x - 6) * ratio, 10)), SAKURA, Color.TRANSPARENT, 5)
	for mark in wave_marks:
		var x := track.position.x + track.size.x * mark
		draw_line(Vector2(x, track.position.y - 7), Vector2(x, track.end.y), COCOA, 2.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(x, track.position.y - 8), Vector2(x + 10, track.position.y - 4), Vector2(x, track.position.y)]), BERRY if mark <= ratio else GOLD)

func draw_banner() -> void:
	var age := ui_time - banner_at
	if age > 2.2 or banner_text == "":
		return
	var sx := ease_back(age / 0.3)
	var sy := sx * clampf((2.2 - age) / 0.25, 0.0, 1.0)
	var c := Vector2(640, 222 if battle.boss_phase > 0 else 186)
	draw_set_transform(c * (1.0 - sx) * Vector2(1, 0) + Vector2(0, c.y * (1.0 - sy)), 0.0, Vector2(sx, sy))
	ribbon(Rect2(c.x - 190, c.y - 25, 380, 50), banner_color, banner_text, 24)
	draw_set_transform(Vector2.ZERO)

func draw_boss_meter() -> void:
	var r := Rect2(390, 148, 500, 46)
	box(r, Color(WOOD, 0.96), GOLD_DEEP, 14, 3, 0.35)
	sprite("boss%d" % battle.boss_phase, Rect2(392, 136, 58, 58))
	var ratio: float = battle.boss_hp / maxf(1.0, battle.boss_max)
	label("算力收购机甲 · " + PHASE_NAMES[battle.boss_phase], Rect2(456, 150, 300, 22), 14, GOLD, 0, 2)
	label("%d%%" % ceili(ratio * 100.0), Rect2(770, 150, 106, 22), 14, CREAM, END, 2)
	var track := Rect2(456, 174, 422, 12)
	box(track, Color("#2a1a1a"), COCOA, 6, 2)
	if ratio > 0.0:
		box(Rect2(track.position + Vector2(2, 2), Vector2((track.size.x - 4) * ratio, 8)), BERRY, Color.TRANSPARENT, 4)
	for mark in [0.7, 0.35]:
		var x: float = track.position.x + track.size.x * mark
		draw_line(Vector2(x, track.position.y), Vector2(x, track.end.y), CREAM, 2.0)

func draw_warning(alert: Dictionary) -> void:
	var pulse: float = 0.6 + 0.4 * sin(battle.time * 17.0)
	var y := lane_y(alert.row)
	var r := Rect2(BOARD_X, y, 9 * CELL, row_height()) if alert.col == -1 else Rect2(board_x(alert.col), y, CELL, row_height())
	draw_rect(r, Color(BERRY, 0.18 * pulse))
	box(r, Color.TRANSPARENT, BERRY, 9, 3)
	effect("warning_fx", Vector2(r.get_center().x, y + row_height() * 0.5), Vector2(75, 66), pulse)
	var left := clampf((float(alert.at) - battle.time) / (2.0 if alert.col == -1 else 1.55), 0.0, 1.0)
	draw_arc(Vector2(r.get_center().x, y + row_height() * 0.5), 34, -PI * 0.5, -PI * 0.5 + TAU * left, 32, BERRY, 4.0, true)
	if alert.col == -1:
		label("封锁预警", Rect2(r.end.x - 112, y + 2, 106, 24), 14, TEXT, MID, 2, 4, SAKURA_DEEP)

func draw_tower(row: int, col: int, tower: Dictionary) -> void:
	var card: Dictionary = Campaign.CARDS[tower.card]
	var x := board_x(col + 0.5)
	var y := lane_y(row)
	var height := row_height()
	var age: float = battle.time - tower.cast
	var pose: float = card.pose
	var acting := age < pose
	var t := clampf(age / pose, 0, 1)
	var recoil := 0.0
	var lift := sin(battle.time * 3.0 + col + row) * 1.3
	if acting:
		match tower.card:
			0: recoil = -9.0 * sin(t * PI)
			1: lift -= 8.0 * sin(t * PI)
			2: recoil = -5.0 * sin(t * PI)
			3: recoil = 4.0 * sin(t * PI)
			4, 6: lift -= 5.0 * sin(t * PI)
			5: recoil = 5.0 * sin(t * PI)
			7: recoil = -10.0 * sin(t * PI)
	ellipse(Vector2(x, y + height - 14), Vector2(34, 8), Color(PLUM, 0.55))
	if acting and tower.card == 1:
		cast_fx(tower.card, Vector2(x, y + height * 0.5), t)
	var born: float = battle.time - float(tower.get("born", -9.0))
	var scale := Vector2.ONE
	if born < 0.35:
		var k := ease_back(born / 0.35)
		scale = Vector2(k, k)
	var hit_age: float = battle.time - tower.hit
	var tint := Color.WHITE
	if tower.sealed > battle.time:
		tint = Color("#c9a3c0")
	elif hit_age < 0.12:
		tint = Color(1.0, 0.6, 0.6)
		scale *= Vector2(1.05, 0.95)
	sprite_at(card.key + ("_act" if acting else ""), Rect2(x - 50 + recoil, y - 2 + lift, 100, height - 8), tint, scale, Vector2(x, y + height - 10))
	if acting and tower.card != 1:
		cast_fx(tower.card, Vector2(x + 31, y + height * 0.43), t)
	if tower.hp < card.hp:
		hp_bar(Vector2(x - 24, y + height - 8), 48, float(tower.hp) / float(card.hp), ACCENTS[tower.card])
	if tower.sealed > battle.time:
		effect("warning_fx", Vector2(x, y + height * 0.4), Vector2(52, 45), 0.7)
		draw_set_transform(cam + Vector2(x + 26, y + 18), -0.2)
		box(Rect2(-15, -15, 30, 30), Color("#e0405f"), Color("#ffe8ec"), 7, 2)
		label("封", Rect2(-15, -15, 30, 30), 17, TEXT, MID, 2)
		draw_set_transform(cam)

func hp_bar(p: Vector2, width: float, ratio: float, color: Color) -> void:
	box(Rect2(p - Vector2(2, 2), Vector2(width + 4, 9)), COCOA, Color.TRANSPARENT, 4)
	var w := width * clampf(ratio, 0.0, 1.0)
	if w > 1.0:
		box(Rect2(p, Vector2(w, 5)), color, Color.TRANSPARENT, 3)

func draw_enemy(enemy: Dictionary) -> void:
	var x := board_x(enemy.x)
	var y := lane_y(enemy.row)
	var height := row_height()
	var boss: bool = enemy.kind == "X"
	var appear := clampf((battle.time - float(enemy.get("born", -9.0))) / 0.4, 0.0, 1.0)
	var bob := absf(sin(battle.time * (13.0 if enemy.kind == "R" else 8.0) + enemy.x)) * 4.0
	if enemy.wait > battle.time:
		bob = 0.0
	ellipse(Vector2(x, y + height - 13), Vector2(52 if boss else 27, 12 if boss else 6), Color(PLUM, 0.6 * appear))
	if enemy.slow > 0:
		draw_set_transform(cam + Vector2(x, y + height - 13), 0.0, Vector2(1.0, 0.25))
		draw_arc(Vector2.ZERO, 32.0, battle.time * 2.0, battle.time * 2.0 + 4.8, 24, SKY, 4.0, true)
		draw_set_transform(cam)
		for k in range(3):
			var a: float = battle.time * 3.0 + k * TAU / 3.0
			draw_circle(Vector2(x + cos(a) * 26.0, y + height * 0.35 + sin(a) * 8.0), 3.5, Color(SKY, 0.85), true, -1.0, true)
	var hit_age: float = battle.time - enemy.hit
	var tint := Color.WHITE
	var scale := Vector2.ONE
	if hit_age < 0.07:
		tint = Color(1.7, 1.7, 1.7)
		scale = Vector2(1.08, 0.92)
	elif hit_age < 0.16:
		tint = Color(1.0, 0.78, 0.78)
	elif enemy.slow > 0:
		tint = Color("#c4eaff")
	if enemy.hidden:
		tint.a = 0.42 + 0.15 * sin(battle.time * 5.0)
	tint.a *= appear
	var dx := (1.0 - appear) * 22.0
	if enemy.boost > battle.time:
		for k in range(3):
			var ly := y + height * (0.3 + k * 0.18)
			var lx := x + 30 + fmod(battle.time * 260.0 + k * 37.0, 40.0)
			draw_line(Vector2(lx, ly), Vector2(lx + 26, ly), Color(GOLD, 0.7), 3.0, true)
	if boss:
		sprite_at("boss%d" % battle.boss_phase, Rect2(x - 81 + dx, y - 68 - bob, 162, height + 57), tint, scale, Vector2(x, y + height - 10))
		if enemy.armor > battle.time:
			effect("claude_fx", Vector2(x - 55, y + height * 0.18), Vector2(64, 90), 0.8)
	else:
		sprite_at(Campaign.ENEMIES[enemy.kind].key, Rect2(x - 45 + dx, y - bob, 90, height - 10), tint, scale, Vector2(x, y + height - 12))
	if enemy.boost > battle.time:
		effect("kimi_fx", Vector2(x, y + height * 0.47), Vector2(63, 49), 0.7)
	if enemy.hidden:
		var q := Vector2(x + 20, y + 4 - bob)
		draw_circle(q, 11, Color(CREAM, 0.85), true, -1.0, true)
		label("?", Rect2(q - Vector2(10, 11), Vector2(20, 22)), 15, COCOA, MID, 2)
	if boss:
		return
	if enemy.hp < enemy.max_hp or enemy.shield > 0.0:
		hp_bar(Vector2(x - 25, y + height - 6), 50, float(enemy.hp) / float(enemy.max_hp), BERRY)
	if enemy.shield > 0.0:
		hp_bar(Vector2(x - 25, y + height - 14), 50, float(enemy.shield) / float(enemy.max_shield), GOLD)

func draw_token(token: Dictionary) -> void:
	var p := token_point(token)
	var color := GOLD if token.kimi else MINT
	var age: float = battle.time - token.born
	var alpha := 1.0 if age < 8.0 else 0.65 + 0.35 * sin(age * 17.0)
	var hot := p.distance_to(pointer) < 30.0
	draw_circle(p, 30, Color(color, 0.12 * alpha), true, -1.0, true)
	draw_circle(p, 22, Color(color, 0.22 * alpha), true, -1.0, true)
	draw_arc(p, 19, age * 2.8, age * 2.8 + 4.6, 24, Color(color, 0.9 * alpha), 2.5, true)
	gem(p, 15.0 if hot else 12.0, Color(color, alpha))
	star(p + Vector2(11, -12), 4.5 * absf(sin(age * 4.0)) + 1.0, Color(1, 1, 1, alpha), COCOA, 0.0)
	if hot or (stage == 0 and battle.collected == 0):
		var tag := Rect2(p + Vector2(-25, 22), Vector2(50, 22))
		box(tag, COCOA, Color.TRANSPARENT, 11)
		label("+25", tag, 13, color, MID, 2)

func cast_fx(kind: int, p: Vector2, t: float) -> void:
	var fade := 1.0 - t
	match kind:
		0: effect("gpt_hit", p + Vector2(9 * t, 0), Vector2(55, 55) * (0.5 + t), fade * 0.87)
		1: effect("kimi_fx", p + Vector2(7, -22 * t), Vector2(96, 82) * (0.76 + t * 0.44), fade)
		2: effect("deepseek_hit", p + Vector2(14 * t, 0), Vector2(47, 47) * (0.57 + t * 0.47), fade * 0.72)
		3: effect("claude_fx", p, Vector2(64, 79) * (0.67 + t * 0.48), fade)
		4: effect("gemini_shot", p + Vector2(14 * t, -8), Vector2(76, 45) * (0.62 + t * 0.4), fade)
		5: effect("qwen_shot", p + Vector2(16 * t, 0), Vector2(76, 54) * (0.66 + t * 0.48), fade)
		6: effect("glm_fx", p + Vector2(17 * t, 0), Vector2(86, 57) * (0.68 + t * 0.43), fade)
		7: effect("grok_hit", p + Vector2(7, 0), Vector2(56, 56) * (0.63 + t * 0.42), fade)

func draw_shot(shot: Dictionary) -> void:
	var age: float = battle.time - shot.born
	var p := Vector2(board_x(shot.x) - 14, lane_y(shot.row) + row_height() * 0.43)
	if shot.card == 7:
		p.y -= 12.0 * absf(sin(age * 8.0))
	var size := Vector2(74, 35) * (1.0 + 0.09 * sin(age * 24.0))
	for k in range(1, 4):
		effect(SHOT_ART[shot.card], p - Vector2(k * 12.0, 0), size * (1.0 - k * 0.16), 0.32 - k * 0.08)
	effect(SHOT_ART[shot.card], p, size)

func draw_impact(hit: Dictionary) -> void:
	var age: float = battle.time - hit.born
	var t := clampf(age / 0.7, 0, 1)
	var p := Vector2(board_x(hit.x), lane_y(hit.row) + row_height() * 0.46)
	if hit.kind == 8:
		label("+25", Rect2(p + Vector2(-30, -20 - t * 40), Vector2(60, 28)), 19, Color(MINT, 1.0 - t), MID, 2, 6, Color(COCOA, 1.0 - t))
	elif hit.kind == 6:
		draw_rect(Rect2(BOARD_X, lane_y(hit.row), 9 * CELL, row_height()), Color(MINT, 0.22 * (1.0 - t)))
		effect("glm_fx", p + Vector2((t - 0.5) * 850, 0), Vector2(181, 68), 1.0 - t)
	elif hit.kind in HIT_ART:
		var size := Vector2(132, 116) if hit.kind == 7 else Vector2(75, 65)
		effect(HIT_ART[hit.kind], p, size * (0.46 + t * 0.9), 1.0 - t)

func draw_flyers() -> void:
	var target := Vector2(78, 66)
	for fly in flyers:
		var t := ease_out(fly.age / 0.5)
		var a: Vector2 = fly.from
		var ctrl := Vector2(lerpf(a.x, target.x, 0.35), minf(a.y, target.y) - 90.0)
		var p := a.lerp(ctrl, t).lerp(ctrl.lerp(target, t), t)
		for k in range(1, 4):
			var tt := maxf(0.0, t - k * 0.06)
			var q := a.lerp(ctrl, tt).lerp(ctrl.lerp(target, tt), tt)
			draw_circle(q, 6.0 - k * 1.4, Color(fly.color, 0.5 - k * 0.12), true, -1.0, true)
		gem(p, 12.0 - 4.0 * t, fly.color)

func draw_tutorial() -> void:
	var target := Vector2.ZERO
	var up := false
	if battle.collected == 0 and not battle.tokens.is_empty():
		target = token_point(battle.tokens[0]) + Vector2(0, -32)
	elif battle.placed == 0 and battle.collected > 0:
		if selected != 0:
			target = Vector2(298, 146)
			up = true
		else:
			target = cell_center(0, 2) + Vector2(0, -36)
	else:
		return
	var d := -1.0 if up else 1.0
	var tip := target + Vector2(0, (sin(ui_time * 6.0) * 7.0 - 4.0) * d)
	var pts := PackedVector2Array([tip, tip + Vector2(-16, -22 * d), tip + Vector2(-6, -22 * d), tip + Vector2(-6, -42 * d),
		tip + Vector2(6, -42 * d), tip + Vector2(6, -22 * d), tip + Vector2(16, -22 * d)])
	draw_colored_polygon(pts, SAKURA)
	pts.append(pts[0])
	draw_polyline(pts, COCOA, 3.0, true)
	var bubble := Rect2(tip + Vector2(22, -40 * d - 14), Vector2(78, 28))
	box(bubble, COCOA, Color.TRANSPARENT, 14)
	label("点这里", bubble, 14, CREAM, MID, 2)
