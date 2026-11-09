extends Node2D
# AI 娘守店记 —— 界面、输入、特效与音频。战斗规则在 battle.gd，关卡数据在 campaign.gd。

const Battle = preload("res://battle.gd")
const Campaign = preload("res://campaign.gd")
const SAVE := "user://progress.dat"
const AUDIO_PREF := "user://audio-setting.txt"
const WALLET := "user://wallet.dat"
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
const ACCENTS := [Color("#b58bff"), Color("#ffb03f"), Color("#45b4ff"), Color("#ff8758"), Color("#9a86ff"), Color("#6d8cff"), Color("#2fd1a3"), Color("#ffc23d"),
	Color("#ff9f43"), Color("#c98b5a"), Color("#3fcfc0"), Color("#ff6b3d"), Color("#6c7cff"), Color("#f5b82e"), Color("#d4a373"), Color("#b48cff"),
	Color("#2f6bff"), Color("#c7a6ff"), Color("#ff9a6a"), Color("#a99cff"), Color("#7d8dff"),
	Color("#4f9dff"), Color("#22b8b0"), Color("#ff6fb1"), Color("#9fd4ff"), Color("#a46bff"), Color("#ffbf3d"), Color("#3ad1ff"),
	Color("#5a7dff"), Color("#e0884f"), Color("#8c7bff"), Color("#6fdc9f"), Color("#ffa94d"), Color("#ff9fb8"), Color("#5cc8ff"),
	Color("#f2b13c"), Color("#4f7bff"), Color("#ff7a3d"), Color("#c46bff")]
const ARENAS := {"arena": ["门口", Color("#ff8db3")], "hall": ["主厅", Color("#e0965a")], "night": ["夜班", Color("#8a7bff")],
	"kitchen": ["后厨", Color("#ff7b5c")], "core": ["核心区", Color("#2fc4b2")], "terrace": ["露台", Color("#f0a13a")],
	"cloud": ["云端", Color("#5b8cff")]}
const ENEMY_TIPS := {"C": "普通来客", "R": "跑得很快", "B": "举着箱盾", "A": "让同伴加速", "S": "潜行，躲开锁定",
	"T": "召来职员", "D": "封住炮台", "I": "潜行又耐打", "X": "三阶段 Boss", "Y": "飞行，不会被挡", "P": "闪光致盲店员",
	"W": "重甲，吃残渣回血", "H": "倒下时瘫痪店员", "V": "三阶段 Boss", "Q": "成群结队", "K": "偷走路上的算力", "M": "飞行母舰，空投无人机",
	"J": "跳过第一个挡路店员", "L": "咬到的店员被加密锁住", "N": "在场时持续吸走算力", "F": "丢下假算力，点了会扣钱",
	"G": "蓝屏冲击瘫痪一片店员", "Z": "三阶段 Boss"}
const ENEMY_ORDER := ["Z", "G", "V", "M", "X", "T", "D", "I", "W", "N", "K", "L", "P", "H", "F", "B", "A", "S", "Y", "J", "R", "Q", "C"]
const BOSS_PHASES := {"X": ["", "金牌接管", "封条封场", "影子加班"], "V": ["", "合规突击检查", "恶意商业收购", "狂暴清算强拆"], "M": ["", "空投外卖"],
	"G": ["", "蓝屏冲击"], "Z": ["", "恶意并购", "断网清算", "全面收购"]}
# 这些图片可以以后再补；文件不存在时游戏会画占位图。
const OPTIONAL_ART := ["terrace", "drone", "influencer", "sweeper", "hacker", "victor", "victor2", "victor3", "troll", "scalper", "carrier", "mistral_shot", "doubao_fx",
	"hailuo_shot", "spark_shot", "ernie_shot", "llama_shot", "paint_wall", "r1_beam",
	"cloud", "crawler", "ransomware", "miner", "phishing", "behemoth", "cyrus", "cyrus2", "cyrus3",
	"suno_wave", "sora_rewind", "sd_shot", "kling_shot", "skywork_strike", "firewall"]
const PAGE_SIZE := 6
const PHASE_NAMES := ["", "金牌接管", "封条封场", "影子加班"]
const SHOT_ART := {0: "gpt_shot", 2: "deepseek_shot", 4: "gemini_shot", 5: "qwen_shot", 7: "grok_shot", 8: "mistral_shot", 10: "hailuo_shot",
	11: "spark_shot", 12: "ernie_shot", 14: "llama_shot", 17: "gpt_shot", 19: "gemini_shot", 20: "qwen_shot",
	21: "gemini_shot", 25: "sd_shot", 27: "kling_shot", 32: "mistral_shot", 35: "gpt_shot", 36: "gemini_shot", 37: "grok_shot", 38: "qwen_shot"}
const SMALL_SHOTS := [17, 19, 20, 21, 32]
# impacts 的 kind 就是卡牌编号；9、10 被第 01 章的封印和光环占用，所以新卡的命中特效从这里查。
const HIT_ART := {0: "gpt_hit", 2: "deepseek_hit", 4: "gpt_hit", 5: "qwen_shot", 7: "grok_hit", 8: "mistral_shot", 9: "warning_fx", 10: "kimi_fx",
	11: "spark_shot", 12: "ernie_shot", 14: "llama_shot", 17: "gpt_hit", 20: "qwen_shot", 110: "hailuo_shot",
	21: "gpt_hit", 25: "sd_shot", 27: "kling_shot", 32: "mistral_shot", 35: "gpt_hit", 36: "gpt_hit", 37: "grok_hit", 138: "qwen_shot"}
const SHOT_SFX := {0: "shot_gpt", 2: "shot_water", 4: "shot_gemini", 5: "shot_qwen", 7: "shot_grok", 8: "shot_ice", 9: "whisk", 10: "conch",
	11: "fireball", 12: "brush", 14: "wool", 15: "paint", 17: "shot_gpt", 19: "zap", 20: "shot_qwen",
	21: "zap", 25: "brush", 27: "burst", 32: "shot_ice", 35: "shot_gpt", 36: "shot_gemini", 37: "shot_grok", 38: "shot_qwen"}
# 每个音效的基础音量（dB），播放时还可以再加偏移。
const SFX_DB := {"click": -11.0, "select": -9.0, "deny": -10.0, "page": -8.0, "toggle": -9.0,
	"deploy": -5.0, "remove": -8.0, "collect": -6.0, "produce": -13.0, "supply": -6.0,
	"shot_gpt": -18.0, "shot_water": -17.0, "shot_gemini": -19.0, "shot_qwen": -16.0, "shot_grok": -11.0, "scan": -13.0,
	"hit": -19.0, "hit_water": -18.0, "hit_shield": -16.0, "shield_break": -7.0, "boom": -8.0, "block": -15.0, "bite": -19.0,
	"kill": -9.0, "lost": -6.0, "wave": -5.0, "last_wave": -4.0, "boss_phase": -3.0, "warning": -12.0, "seal": -7.0,
	"megaphone": -8.0, "hurry": -10.0, "reveal": -9.0, "sweep": -5.0, "win": -3.0, "lose": -4.0, "star": -6.0,
	"shot_ice": -15.0, "freeze": -8.0, "whisk": -15.0, "aim": -11.0, "flash": -6.0, "drone": -14.0, "stamp": -5.0,
	"emp": -7.0, "overclock": -6.0, "reverse": -6.0, "umbrella_break": -6.0, "repair": -7.0, "blackout": -4.0,
	"charge": -5.0, "interrupt": -4.0, "blast": -3.0, "leak": -6.0, "tear": -7.0, "coins": -8.0, "income_freeze": -6.0, "absorb": -9.0,
	"conch": -15.0, "fireball": -15.0, "brush": -14.0, "wool": -14.0, "zap": -20.0, "paint": -9.0, "think": -10.0, "beam": -5.0, "steal": -8.0,
	"search": -11.0, "pulse": -9.0, "rewind": -7.0, "diffuse": -12.0, "hug": -8.0, "burst": -16.0, "orbital": -5.0, "reflect": -14.0,
	"agent": -9.0, "gate": -5.0, "backup": -7.0, "restore": -6.0, "hop": -12.0, "lock": -8.0, "drain": -13.0, "phished": -6.0,
	"bluescreen": -4.0, "acquire": -5.0, "storm": -5.0, "outage": -4.0, "bait": -13.0, "buy": -5.0, "coin": -7.0}
const MUSIC_DB := -9.0
const PETAL := [Vector2(0, -1), Vector2(0.55, -0.62), Vector2(0.62, 0.08), Vector2(0.32, 0.82), Vector2(0, 0.56),
	Vector2(-0.32, 0.82), Vector2(-0.62, 0.08), Vector2(-0.55, -0.62)]
const MID := 1
# 第 02 章每关的推荐阵容（6 位，和 tools/balance_sim.gd 里验证过的一致）。
const CHAPTER_TWO_LINEUPS := [[0, 1, 2, 8, 4, 17], [0, 1, 8, 9, 4, 17], [0, 1, 8, 10, 9, 17], [0, 1, 8, 9, 5, 19],
	[0, 1, 8, 9, 11, 18], [0, 1, 8, 10, 11, 12], [0, 1, 8, 9, 16, 17], [0, 13, 8, 10, 9, 17],
	[0, 1, 8, 14, 5, 9], [0, 1, 8, 15, 9, 12], [0, 13, 8, 9, 15, 11], [0, 1, 8, 9, 16, 12]]
# 第 03 章每关的推荐阵容（同样由 tools/balance_sim.gd 验证）。
const CHAPTER_THREE_LINEUPS := [[0, 1, 8, 9, 21, 31], [0, 1, 8, 9, 22, 33], [0, 1, 8, 22, 23, 32], [0, 1, 8, 22, 26, 34],
	[0, 1, 8, 9, 22, 24], [0, 1, 8, 22, 25, 26], [0, 1, 8, 22, 25, 29], [0, 1, 8, 22, 27, 29],
	[0, 1, 22, 28, 29, 34], [0, 30, 8, 22, 27, 29], [0, 1, 8, 27, 29, 34], [0, 1, 22, 27, 28, 29]]
const END := 2
enum {TITLE, SELECT, BRIEF, PLAY, RESULT, SHOP}
const SHOP_TABS := ["店员", "SP 限定", "mini", "卡槽"]

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
var chapter_view := 1
var core_hit_at := -10.0
var brief_focus := -1
var beams: Array[Dictionary] = []
var zaps: Array[Dictionary] = []
var fx_sprites: Array[Dictionary] = []
var brief_page := 0
# 金币与商店
var gold := 0
var owned: Array = []
var slots := Campaign.START_SLOTS
var last_gold := 0
var wallet_ok := true
var shop_tab := 0
var shop_focus := 0
var shop_from := TITLE
var shop_at := -10.0
var coin_played := false

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
	for key in keys + OPTIONAL_ART:
		var path := "res://art/%s.png" % key
		if ResourceLoader.exists(path):
			art[key] = load(path)
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
	load_wallet()
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
	for key in ["menu", "battle", "boss", "terrace", "boss2", "cloud", "boss3"]:
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
			if Campaign.chapter(stage) == 3:
				return "boss3" if battle != null and battle.boss_kind == "Z" else "cloud"
			if Campaign.chapter(stage) == 2:
				return "boss2" if battle != null and battle.boss_kind == "V" else "terrace"
			return "boss" if stage == 21 else "battle"
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
	if lines.size() < 2 or lines.size() > Campaign.levels.size() + 1 or lines[0].strip_edges() != "AI-CAFE/1":
		return []
	var values := []
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line not in ["0", "1", "2", "3"]:
			return []
		values.append(line.to_int())
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

# ---------------------------------------------------------------- 金币、店员与卡槽

# wallet.dat：金币、已拥有的店员、卡槽数。没有这个文件时（新玩家或老存档第一次打开新版）按关卡进度迁移。
func load_wallet() -> void:
	var data = read_wallet(WALLET)
	if data == null:
		data = read_wallet(WALLET + ".bak")
	if data == null:
		data = Campaign.migrate(stars)
		gold = data.gold
		owned = data.owned
		slots = data.slots
		save_wallet()
		return
	gold = data.gold
	owned = data.owned
	slots = data.slots

func read_wallet(path: String):
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("format", "") != "AI-CAFE-WALLET/1":
		return null
	var list := []
	list.resize(Campaign.CARDS.size())
	list.fill(false)
	for c in Campaign.START_CARDS:
		list[c] = true
	for value in parsed.get("owned", []):
		var c := int(value)
		if c >= 0 and c < list.size():
			list[c] = true
	return {"gold": maxi(0, int(parsed.get("gold", 0))), "owned": list,
		"slots": clampi(int(parsed.get("slots", Campaign.START_SLOTS)), Campaign.START_SLOTS, Campaign.MAX_SLOTS)}

func save_wallet() -> bool:
	var ids := []
	for c in range(owned.size()):
		if owned[c]:
			ids.append(c)
	var text := JSON.stringify({"format": "AI-CAFE-WALLET/1", "gold": gold, "slots": slots, "owned": ids})
	var file := FileAccess.open(WALLET + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	if read_wallet(WALLET) != null and DirAccess.copy_absolute(WALLET, WALLET + ".bak") != OK:
		return false
	return DirAccess.rename_absolute(WALLET + ".tmp", WALLET) == OK

func owns(card: int) -> bool:
	return card >= 0 and card < owned.size() and owned[card]

func open_shop(focus: int = -1) -> void:
	if state != SHOP:
		shop_from = state
	if focus >= 0:
		shop_tab = 1 if Campaign.CARDS[focus].get("tag", "") == "SP" else 2 if Campaign.is_mini(focus) else 0
		shop_focus = focus
	elif shop_focus < 0 or shop_focus >= Campaign.CARDS.size():
		shop_focus = shop_items(shop_tab)[0]
	state = SHOP
	shop_at = ui_time
	toast_until = 0.0

func close_shop() -> void:
	state = shop_from
	sfx("page")

func set_shop_tab(tab: int) -> void:
	shop_tab = tab
	var items := shop_items(tab)
	shop_focus = items[0] if not items.is_empty() else -1
	for c in items:
		if not owns(c):
			shop_focus = c
			break

func shop_items(tab: int) -> Array:
	var list := []
	if tab == 3:
		return list
	for c in range(Campaign.CARDS.size()):
		var tag: String = Campaign.CARDS[c].get("tag", "")
		if (tab == 0 and tag == "") or (tab == 1 and tag == "SP") or (tab == 2 and tag == "mini"):
			list.append(c)
	return list

func focus_item(card: int) -> void:
	shop_focus = card

func buy_card(card: int) -> void:
	if owns(card):
		return
	var price: int = Campaign.PRICES[card]
	if gold < price:
		power_deny = ui_time
		notice("金币不足，还差 %d。" % (price - gold))
		return
	gold -= price
	owned[card] = true
	wallet_ok = save_wallet()
	sfx("buy")
	confetti()
	notice("%s 加入了店员！" % Campaign.CARDS[card].name, false)

func buy_slot() -> void:
	var price := Campaign.slot_price(slots)
	if price < 0:
		return
	if gold < price:
		notice("金币不足，还差 %d。" % (price - gold))
		return
	gold -= price
	slots += 1
	wallet_ok = save_wallet()
	sfx("buy")
	confetti()
	notice("卡槽 +1，现在可以带 %d 位店员。" % slots, false)

# 第 01 章逐关解锁（1-20EX 在 1-20 之后）；第 02 章在通关 1-20 后开放。
func is_unlocked(i: int) -> bool:
	if i <= 0:
		return true
	if i == Campaign.CHAPTER_STARTS[1]:
		return stars[20] > 0
	return stars[i - 1] > 0

# 最靠后的一关「已解锁但还没通关」的关卡；全部通关时返回最后一关。
func latest() -> int:
	var best := -1
	for i in range(stars.size()):
		if is_unlocked(i) and stars[i] == 0:
			best = i
	return stars.size() - 1 if best == -1 else best

func chapter_pages(number: int) -> int:
	return ceili(float(Campaign.chapter_range(number).size()) / PAGE_SIZE)

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
		focus_stage(latest())
	state = SELECT
	paused = false

func focus_stage(id: int) -> void:
	chapter_view = Campaign.chapter(id)
	page = floori(float(id - Campaign.CHAPTER_STARTS[chapter_view - 1]) / PAGE_SIZE)

func open_chapter(number: int) -> void:
	if number == 2 and not is_unlocked(Campaign.CHAPTER_STARTS[1]):
		notice("通关 1-20 后开放第 02 章。")
		return
	if number == 3 and not is_unlocked(Campaign.CHAPTER_STARTS[2]):
		notice("通关 2-12 后开放第 03 章。")
		return
	chapter_view = number
	page = 0

func equipped() -> Array:
	var result := []
	for i in range(loadout.size()):
		if loadout[i]:
			result.append(i)
	return result

func open_stage(id: int) -> void:
	stage = id
	focus_stage(id)
	var suggested := [0, 1, 2, 3, 4]
	brief_page = 1 if id >= Campaign.CHAPTER_STARTS[2] else 0
	if id >= Campaign.CHAPTER_STARTS[2]:
		suggested = CHAPTER_THREE_LINEUPS[id - Campaign.CHAPTER_STARTS[2]]
	elif id >= Campaign.CHAPTER_STARTS[1]:
		suggested = CHAPTER_TWO_LINEUPS[id - Campaign.CHAPTER_STARTS[1]]
	elif id == 7 or id == 8:
		suggested = [0, 1, 2, 4, 5]
	elif id >= 9:
		suggested = [0, 1, 4, 5, 6]
		if id == 11:
			suggested = [0, 1, 4, 6, 7]
		elif id in [9, 15, 18]:
			suggested = [0, 1, 3, 4, 6]
	if id == 0:
		suggested = [0]
	loadout.fill(false)
	var picked := 0
	for c in suggested:
		if owns(c) and picked < max_loadout():
			loadout[c] = true
			picked += 1
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
	beams.clear()
	zaps.clear()
	fx_sprites.clear()
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
	if battle.chapter >= 2:
		rating = 3 if battle.core >= Battle.CORE_MAX and battle.facility_uses > 0 else 2 if battle.core >= 80 else 1
	var old_stars: int = stars[stage]
	last_gold = Campaign.gold_reward(stage, old_stars, rating if battle.result == 1 else 0, battle.result == 1, battle.defeated)
	save_ok = battle.result != 1 or record_win(rating)
	if last_gold > 0:
		gold += last_gold
		wallet_ok = save_wallet()
	state = RESULT
	result_at = ui_time
	stars_played = 0
	coin_played = false
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
			elif not paused and event.keycode >= KEY_1 and event.keycode <= KEY_7:
				var slot: int = event.keycode - KEY_1
				var active := equipped()
				if slot < active.size():
					choose_card(active[slot])
			elif not paused and event.keycode == KEY_R:
				toggle_remove()
			elif not paused and event.keycode == KEY_Q and battle.charger:
				toggle_overclock()
			elif not paused and event.keycode == KEY_E and not battle.conveyor_rows.is_empty():
				use_reverse()
			elif not paused and event.keycode == KEY_F and battle.has_gates:
				toggle_gate()
			elif not paused and event.keycode == KEY_B and battle.has_backup:
				toggle_backup()
		elif event.keycode == KEY_ESCAPE:
			go_back()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()

func go_back() -> void:
	if state == PLAY:
		paused = not paused
		sfx("click")
	elif state == SHOP:
		state = shop_from
		sfx("page")
	elif state != TITLE:
		state = TITLE if state == SELECT else SELECT
		sfx("page")
	buttons.clear()

func toggle_remove() -> void:
	selected = -1 if selected == -2 else -2
	sfx("select")

func toggle_overclock() -> void:
	selected = -1 if selected == -3 else -3
	sfx("select")

func toggle_gate() -> void:
	selected = -1 if selected == -4 else -4
	sfx("select")

func toggle_backup() -> void:
	selected = -1 if selected == -5 else -5
	sfx("select")

func use_reverse() -> void:
	if battle.reverse_conveyor():
		drain()
	elif battle.conveyor_wait() > 0.0:
		notice("传送带还在冷却。")
	else:
		power_deny = ui_time
		notice("逆流需要 %d 算力。" % Battle.CONVEYOR_COST)

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
	if cell.x < 0:
		return
	if cell in battle.level.blocked:
		notice("这格暂时封闭。")
		return
	if battle.chapter >= 2 and selected > -3:
		if battle.tear_seal(cell.y, cell.x):
			drain()
			return
		if battle.props.has(cell) and selected <= -1:
			if battle.wreck_at(cell.y, cell.x):
				if battle.repair(cell.y, cell.x):
					drain()
				else:
					power_deny = ui_time
					notice("修复遮阳伞需要 %d 算力。" % Battle.REPAIR_COST)
			return
	if selected == -1 or cell.x < 0:
		return
	if battle.props.has(cell) and selected >= 0:
		notice("这里摆着遮阳伞。")
		return
	if selected == -4:
		if battle.raise_gate(cell.y):
			selected = -1
			drain()
		elif battle.facilities_locked():
			notice("断网中，设施暂时用不了。")
		elif battle.gate_wait() > 0.0:
			notice("防火墙还在冷却。")
		else:
			power_deny = ui_time
			notice("防火墙需要 %d 算力。" % Battle.GATE_COST)
		return
	if selected == -5:
		if battle.towers[cell.y][cell.x] == null:
			notice("点一位店员做云备份。")
		elif battle.backup_tower(cell.y, cell.x):
			selected = -1
			drain()
		elif battle.facilities_locked():
			notice("断网中，设施暂时用不了。")
		elif battle.backup_wait() > 0.0:
			notice("云备份还在冷却。")
		else:
			power_deny = ui_time
			notice("云备份需要 %d 算力。" % Battle.BACKUP_COST)
		return
	if selected == -3:
		if battle.towers[cell.y][cell.x] == null:
			notice("点一位店员进行超频。")
		elif battle.overclock(cell.y, cell.x):
			selected = -1
			drain()
		elif battle.charger_wait() > 0.0:
			notice("充电桩还在冷却。")
		else:
			power_deny = ui_time
			notice("超频需要 %d 算力。" % Battle.CHARGER_COST)
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
	elif Campaign.is_mini(selected) and battle.minis[cell.y][cell.x] != null:
		notice("这一格已经有 mini 了。")
	elif not Campaign.is_mini(selected) and battle.towers[cell.y][cell.x] != null:
		notice("这个格子已有店员。mini 可以放在店员身上。")
	elif battle.time < battle.ready_at[selected]:
		notice("这张卡正在冷却。")
	else:
		power_deny = ui_time
		notice("算力不足，点击场上的发光算力。")

func set_brief_page(value: int) -> void:
	brief_page = value
	brief_focus = -1

func change_page(offset: int) -> void:
	page = clampi(page + offset, 0, chapter_pages(chapter_view) - 1)

func set_page(value: int) -> void:
	page = value

func stage_art(id: int) -> String:
	match id:
		27: return "carrier"
		32: return "sweeper"
		33: return "victor"
		39: return "behemoth"
		44: return "miner"
		45: return "cyrus"
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
	if not owns(index):
		open_shop(index)
		return
	if loadout[index]:
		loadout[index] = false
	elif loadout.count(true) < max_loadout():
		loadout[index] = true
	else:
		notice("最多上阵 %d 位店员，先取消一张卡片。" % max_loadout())
	brief_focus = index

# 能带几位店员由已购买的卡槽决定（教学关固定 1 位）。
func max_loadout() -> int:
	return 1 if stage == 0 else slots

# 配卡页显示全部店员（没买的显示价格，点了去商店）；教学关只显示自带的 4 位。
func visible_cards() -> Array:
	if stage == 0:
		return Campaign.START_CARDS.duplicate()
	return range(Campaign.CARDS.size())

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
			sfx("produce", 0.0, 0.8 if e.get("gold", false) else 1.0, 0.25)
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
			if e.kind in ["X", "V", "G", "Z"]:
				sfx("boss_phase")
				shake(0.6)
				flash_screen(BERRY, 0.35)
				banner(Campaign.ENEMIES[e.kind].name + " 来袭！", BERRY)
		"fire":
			if SHOT_SFX.has(e.card) and not e.get("burst", false):
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
			sfx("boom", 3.0 if e.get("heavy", false) else 0.0, 0.85 if e.get("heavy", false) else 1.0, 0.08)
			if e.get("heavy", false):
				ring(p, Color("#ff7a3d"), 260.0, 0.55)
				burst(p, Color("#ff9a5a"), 16, 340.0, "star", 0.7, 8.0)
				shake(0.3)
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
			if e.kind in ["X", "G", "Z"]:
				shake(1.0)
				flash_screen(GOLD, 0.6)
				burst(p, GOLD, 30, 380.0, "star", 1.0, 9.0, 160.0)
				ring(p, GOLD, 240.0, 0.7)
		"bite":
			sfx("block" if e.card in [3, 9, -1] else "bite", 0.0, 1.0, 0.12)
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
				"Z":
					sfx("hit_shield", 5.0)
					burst(p, GOLD, 12, 200.0, "star", 0.6, 6.0)
					floater("并购护盾 +200", p + Vector2(0, -100), GOLD)
		"phase":
			sfx("boss_phase")
			shake(0.7)
			flash_screen(GOLD, 0.4)
			banner("阶段 %d · %s" % [e.phase, BOSS_PHASES[battle.boss_kind][e.phase]], GOLD)
			burst(lane_point(e.row, e.x), GOLD, 18, 300.0, "star", 0.8, 8.0)
		"sweep":
			sfx("sweep")
			shake(0.22)
		"freeze":
			var p := lane_point(e.row, e.x)
			sfx("freeze", 0.0, 1.0, 0.1)
			burst(p, SKY, 10, 170.0, "star", 0.55, 6.0)
			floater("冻结！", p + Vector2(0, -46), SKY)
		"aim":
			sfx("aim", 0.0, 1.0, 0.2)
		"flash":
			var p := lane_point(e.row, e.x)
			sfx("flash", 0.0, 1.0, 0.15)
			ring(p + Vector2(-26, -10), Color(1, 1, 0.9), 150.0, 0.35)
			flash_screen(Color(1, 1, 0.95), 0.18)
			for col in e.cols:
				var c := cell_center(e.row, col)
				burst(c + Vector2(0, -20), GOLD, 5, 90.0, "star", 0.6, 5.0)
				floater("致盲", c + Vector2(0, -40), GOLD)
		"emp":
			var c := cell_center(e.row, e.col)
			sfx("emp")
			burst(c, SKY, 12, 220.0, "dot", 0.4, 4.0)
			ring(c, SKY, 70.0, 0.35)
			floater("瘫痪", c + Vector2(0, -42), SKY)
		"absorb":
			var p := lane_point(e.row, e.x)
			sfx("absorb", 0.0, 1.0, 0.2)
			burst(p + Vector2(-30, 20), Color("#8a5a3c"), 6, 80.0, "puff", 0.45, 10.0)
			floater("+60", p + Vector2(0, -50), MINT)
		"leak":
			core_hit_at = ui_time
			sfx("leak", 0.0, 1.0, 0.1)
			shake(0.15)
			ui_floater("满意度 -%d" % e.amount, Vector2(112, 236), BERRY)
		"reverse":
			sfx("reverse")
			for row in battle.conveyor_rows:
				for k in range(4):
					burst(Vector2(board_x(battle.conveyor_from + k + 0.5), lane_y(row) + row_height() * 0.6), SKY, 2, 120.0, "dot", 0.4, 4.0)
			floater("逆流！", Vector2(board_x(5.0), lane_y(0) - 6), SKY)
		"overclock":
			var c := cell_center(e.row, e.col)
			sfx("overclock")
			ring(c, GOLD, 80.0, 0.45)
			burst(c, GOLD, 10, 200.0, "star", 0.6, 6.0)
			floater("超频！", c + Vector2(0, -44), GOLD)
		"umbrella_break":
			var c := cell_center(e.row, e.col)
			sfx("umbrella_break")
			burst(c, SAKURA_PALE, 10, 200.0, "shard", 0.6, 7.0, 500.0)
			floater("遮阳伞坏了", c + Vector2(0, -44), CREAM)
		"repair":
			var c := cell_center(e.row, e.col)
			sfx("repair")
			burst(c, MINT, 10, 160.0, "star", 0.6, 6.0)
			floater("修好了", c + Vector2(0, -44), MINT)
		"blackout":
			sfx("blackout")
			banner("午间高峰跳闸！", BERRY)
			flash_screen(PLUM, 0.5)
		"audit":
			var c := cell_center(e.row, e.col)
			sfx("stamp")
			shake(0.15)
			floater("停业整顿", c + Vector2(0, -46), BERRY)
		"tap":
			sfx("click", 2.0, 1.0 + e.taps * 0.15, 0.0)
			burst(cell_center(e.row, e.col), CREAM, 4, 120.0, "shard", 0.35, 5.0, 300.0)
		"tear":
			var c := cell_center(e.row, e.col)
			sfx("tear")
			burst(c, BERRY, 10, 220.0, "shard", 0.55, 7.0, 400.0)
			floater("撕掉了！", c + Vector2(0, -44), MINT)
		"summon":
			sfx("drone", 3.0)
		"income_freeze":
			sfx("income_freeze")
			banner("资金流冻结 8 秒", SKY)
		"trap":
			var c := cell_center(e.row, e.col)
			sfx("coins")
			burst(c, GOLD, 12, 160.0, "dot", 0.6, 4.5, 200.0)
			floater("高薪挖角", c + Vector2(0, -44), GOLD)
		"charge":
			sfx("charge")
			banner("终极差评蓄力中！快打断！", BERRY)
		"interrupt":
			var p := lane_point(e.row, e.x)
			sfx("interrupt")
			shake(0.5)
			flash_screen(MINT, 0.3)
			burst(p, MINT, 20, 300.0, "star", 0.8, 8.0)
			floater("打断！", p + Vector2(0, -100), MINT)
		"blast":
			var p := lane_point(e.row, e.x)
			sfx("blast")
			shake(0.9)
			flash_screen(BERRY, 0.5)
			ring(p, BERRY, 600.0, 0.7)
			floater("终极差评！", p + Vector2(0, -100), BERRY)
		"think":
			sfx("think", 0.0, 1.0, 0.2)
		"beam":
			beams.append({"row": e.row, "col": e.col, "at": ui_time})
			sfx("beam")
			shake(0.2)
			flash_screen(SKY, 0.18)
		"paint":
			var c := cell_center(e.row, e.col)
			sfx("paint", 0.0, 1.0, 0.2)
			burst(c, Color("#b48cff"), 8, 140.0, "dot", 0.5, 5.0)
			burst(c, SAKURA_PALE, 6, 120.0, "star", 0.5, 5.0)
		"wall_break", "wall_gone":
			burst(cell_center(e.row, e.col), Color("#c7b3ff"), 8, 120.0, "puff", 0.45, 12.0)
		"mark":
			sfx("brush", -4.0, 1.2, 0.2)
		"ignite":
			burst(lane_point(e.row, e.x), Color("#ff7a2e"), 5, 90.0, "dot", 0.4, 4.0)
		"knock":
			burst(lane_point(e.row, e.x) + Vector2(-20, 10), CREAM, 4, 80.0, "puff", 0.35, 9.0)
		"steal":
			var p := lane_point(e.row, e.x)
			sfx("steal", 0.0, 1.0, 0.15)
			floater("偷走算力！", p + Vector2(0, -50), GOLD)
		"refund":
			var p := lane_point(e.row, e.x)
			sfx("supply", -3.0)
			floater("+%d 吐出来了" % e.value, p + Vector2(0, -50), GOLD)
		"gate":
			var p := Vector2(board_x(6.6), lane_y(e.row) + row_height() * 0.5)
			sfx("gate")
			shake(0.15)
			burst(p, Color("#ff7a3d"), 14, 220.0, "star", 0.55, 6.0)
			ring(p, Color("#ff9a3d"), 90.0, 0.4)
			floater("防火墙升起！", p + Vector2(0, -48), GOLD)
		"backup":
			var c := cell_center(e.row, e.col)
			sfx("backup")
			ring(c, SKY, 70.0, 0.45)
			burst(c + Vector2(0, -30), SKY, 10, 120.0, "puff", 0.6, 10.0, -60.0)
			floater("已云备份", c + Vector2(0, -46), SKY)
		"restore":
			var c := cell_center(e.row, e.col)
			sfx("restore")
			flash_screen(SKY, 0.12)
			ring(c, MINT, 90.0, 0.5)
			burst(c, MINT, 14, 200.0, "star", 0.7, 7.0)
			floater("云端恢复！", c + Vector2(0, -48), MINT)
		"phished":
			var p := Vector2(board_x(e.x), lane_y(e.row) + row_height() * 0.48)
			sfx("phished")
			power_deny = ui_time
			shake(0.12)
			burst(p, BERRY, 10, 160.0, "shard", 0.5, 6.0, 300.0)
			floater("钓鱼！-%d" % e.amount, p + Vector2(0, -36), BERRY)
		"bait":
			sfx("bait", 0.0, 1.0, 0.3)
		"bluescreen":
			var p := lane_point(e.row, e.x)
			sfx("bluescreen")
			shake(0.6)
			flash_screen(Color("#2f6bff"), 0.45)
			ring(p, Color("#5b8cff"), 300.0, 0.6)
			banner("蓝屏冲击！", SKY)
		"storm":
			sfx("storm")
			flash_screen(SKY, 0.3)
			banner("数据风暴：来客都套上了护盾", SKY)
		"search":
			var from := cell_center(e.row, e.col) + Vector2(30, -10)
			var to := lane_point(e.trow, e.x)
			sfx("search", 0.0, 1.25 if e.crit else 1.0, 0.08)
			zaps.append({"from": from, "to": to, "at": ui_time, "color": GOLD if e.crit else Color("#5fe0d6")})
			burst(to, GOLD if e.crit else Color("#5fe0d6"), 6, 140.0, "star", 0.4, 5.0)
			if e.crit:
				floater("精准检索！", to + Vector2(0, -48), GOLD)
		"pulse":
			var c := cell_center(e.row, e.col)
			sfx("pulse", 0.0, 1.0, 0.15)
			ring(c, Color("#ff6fb1"), 150.0, 0.5)
			fx_sprites.append({"key": "suno_wave", "p": c + Vector2(60, 0), "size": Vector2(120, 80), "at": ui_time, "life": 0.5, "drift": Vector2(160, 0)})
		"rewind":
			var c := cell_center(e.row, e.col)
			sfx("rewind")
			fx_sprites.append({"key": "sora_rewind", "p": Vector2(board_x(e.col + 3.0), c.y), "size": Vector2(180, 110), "at": ui_time, "life": 0.7, "drift": Vector2(-60, 0)})
			floater("时间回溯", Vector2(board_x(e.col + 2.5), c.y - 40), SKY)
		"hug":
			var p := lane_point(e.row, e.x)
			sfx("hug", 0.0, 1.0, 0.2)
			for k in range(5):
				burst(p + Vector2(rng.randf_range(-20, 20), -20), SAKURA, 1, 80.0, "heart", 0.7, 8.0, -40.0)
			floater("抱住了！", p + Vector2(0, -50), SAKURA)
		"target":
			sfx("aim", 2.0, 0.8, 0.2)
		"strike":
			var p := lane_point(e.row, e.x)
			sfx("orbital")
			shake(0.35)
			flash_screen(Color("#bcd0ff"), 0.15)
			fx_sprites.append({"key": "skywork_strike", "p": p + Vector2(0, -40), "size": Vector2(140, 220), "at": ui_time, "life": 0.45, "drift": Vector2.ZERO})
			ring(p, Color("#8aa6ff"), 130.0, 0.45)
			burst(p, Color("#cfe0ff"), 14, 260.0, "star", 0.6, 7.0)
		"agent":
			var c := cell_center(e.row, e.col)
			sfx("agent")
			ring(c, Color("#8c7bff"), 80.0, 0.4)
			if e.gained > 0:
				floater("代收 +%d" % e.gained, c + Vector2(0, -46), GOLD)
				flyers.append({"from": c + cam, "age": 0.0, "color": GOLD})
		"light":
			var c := cell_center(e.row, e.col)
			sfx("reveal", -3.0, 1.2, 0.3)
			burst(c + Vector2(40, -10), Color(1, 1, 0.75), 6, 120.0, "star", 0.4, 5.0)
		"diffuse":
			var p := lane_point(e.row, e.x)
			sfx("diffuse", 0.0, 1.0, 0.1)
			burst(p, Color("#b07cff"), 8, 150.0, "dot", 0.45, 5.0)
			ring(p, Color("#c7a6ff"), 80.0, 0.35)
		"lock":
			var c := cell_center(e.row, e.col)
			sfx("lock", 0.0, 1.0, 0.2)
			burst(c, BERRY, 6, 120.0, "shard", 0.4, 5.0, 300.0)
			floater("被加密了！", c + Vector2(0, -46), BERRY)
		"unlock":
			var c := cell_center(e.row, e.col)
			sfx("repair", -4.0, 1.2, 0.2)
			floater("解锁", c + Vector2(0, -46), MINT)
		"hop":
			var p := lane_point(e.row, e.x)
			sfx("hop", 0.0, 1.0, 0.15)
			burst(p + Vector2(0, 20), CREAM, 5, 90.0, "puff", 0.4, 9.0)
		"drain":
			sfx("drain", 0.0, 1.0, 0.6)
			ui_floater("-%d 挖矿" % e.amount, Vector2(232, 112), BERRY)
		"outage":
			sfx("outage")
			shake(0.4)
			flash_screen(PLUM, 0.55)
			banner("断网清算：设施锁定、全场熄灯 8 秒", BERRY)
		"layoff":
			var p := lane_point(e.row, e.x)
			sfx("stamp")
			shake(0.3)
			for col in range(9):
				if battle.towers[e.row][col] != null:
					burst(cell_center(e.row, col), BERRY, 5, 120.0, "shard", 0.4, 5.0, 300.0)
			floater("裁员优化！", p + Vector2(0, -100), BERRY)
		"acquire":
			var c := cell_center(e.row, e.col)
			sfx("acquire")
			shake(0.2)
			burst(c, GOLD, 12, 180.0, "dot", 0.6, 4.5, 200.0)
			banner("恶意收购！4 秒内点她 3 下撕掉合同", GOLD)
		"acquired":
			var c := cell_center(e.row, e.col)
			sfx("lost")
			shake(0.3)
			burst(c, GOLD, 16, 220.0, "shard", 0.7, 6.0, 400.0)
			floater("被收购了……", c + Vector2(0, -46), GOLD)
		"win":
			sfx("win")
		"lose":
			sfx("lose")
			shake(0.5)

# Boss 当前阶段的立绘：算力收购机甲 boss1~3，维克多 victor / victor2 / victor3。
func boss_art() -> String:
	var phase := maxi(1, battle.boss_phase)
	match battle.boss_kind:
		"X":
			return "boss%d" % phase
		"V":
			var key := "victor" if phase == 1 else "victor%d" % phase
			return key if art.has(key) else "victor"
		"Z":
			var key := "cyrus" if phase == 1 else "cyrus%d" % phase
			return key if art.has(key) else "cyrus"
	return Campaign.ENEMIES[battle.boss_kind].key if battle.boss_kind != "" else "victor"

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
	if kind in ["X", "V", "G", "Z"]:
		ghosts.append({"key": boss_art(), "rect": Rect2(px - 81, y - 68, 162, h + 57), "age": 0.0})
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
	for i in range(beams.size() - 1, -1, -1):
		if ui_time - float(beams[i].at) > 0.5:
			beams.remove_at(i)
	for i in range(zaps.size() - 1, -1, -1):
		if ui_time - float(zaps[i].at) > 0.3:
			zaps.remove_at(i)
	for i in range(fx_sprites.size() - 1, -1, -1):
		if ui_time - float(fx_sprites[i].at) > float(fx_sprites[i].life):
			fx_sprites.remove_at(i)
	step_parts(ui_parts, delta)
	if state in [TITLE, SELECT, BRIEF, SHOP]:
		update_petals(delta, 30 if state == TITLE else 18)
	if battle != null:
		if shown_power < battle.power:
			shown_power = minf(battle.power, shown_power + maxf(1.0, (battle.power - shown_power) * 9.0 * delta))
		else:
			shown_power = battle.power
	if state == RESULT and last_gold > 0 and not coin_played and ui_time - result_at > 0.6 + rating * 0.32:
		coin_played = true
		sfx("coin")
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
		"bolt":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.15, -0.95) * s, c + Vector2(-0.55, 0.12) * s, c + Vector2(-0.05, 0.12) * s,
				c + Vector2(-0.2, 0.95) * s, c + Vector2(0.55, -0.15) * s, c + Vector2(0.05, -0.15) * s]), color)
		"reverse":
			for k in [-0.45, 0.2]:
				draw_polyline(PackedVector2Array([c + Vector2(k, -0.6) * s, c + Vector2(k + 0.5, 0) * s, c + Vector2(k, 0.6) * s]), color, w, true)
		"heart":
			heart(c, s, color)
		"gate":
			for k in range(3):
				var yy := -0.75 + k * 0.52
				var off := 0.0 if k % 2 == 0 else 0.3
				for j in range(3):
					var xx := -0.9 + off + j * 0.62
					if xx + 0.5 <= 1.0:
						box(Rect2(c + Vector2(xx, yy) * s, Vector2(0.52, 0.42) * s), color, Color.TRANSPARENT, 2)
		"cloud":
			draw_circle(c + Vector2(-0.4, 0.15) * s, s * 0.42, color, true, -1.0, true)
			draw_circle(c + Vector2(0.1, -0.2) * s, s * 0.55, color, true, -1.0, true)
			draw_circle(c + Vector2(0.55, 0.2) * s, s * 0.38, color, true, -1.0, true)
			box(Rect2(c + Vector2(-0.8, 0.15) * s, Vector2(1.7, 0.42) * s), color, Color.TRANSPARENT, 4)
		"note":
			draw_circle(c + Vector2(-0.3, 0.55) * s, s * 0.3, color, true, -1.0, true)
			draw_line(c + Vector2(-0.03, 0.55) * s, c + Vector2(-0.03, -0.75) * s, color, w, true)
			draw_line(c + Vector2(-0.03, -0.75) * s, c + Vector2(0.5, -0.45) * s, color, w, true)

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
	if not art.has(key):
		figure(key, rect, tint)
		return
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

func effect(key: String, center: Vector2, bounds: Vector2, alpha: float = 1.0, tint: Color = Color.WHITE) -> void:
	if alpha <= 0.0:
		return
	if not art.has(key):
		figure(key, Rect2(center - bounds * 0.5, bounds), Color(tint, clampf(alpha, 0, 1)))
		return
	var texture: Texture2D = art[key]
	var size := texture.get_size() * minf(bounds.x / texture.get_width(), bounds.y / texture.get_height())
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, Color(tint, clampf(alpha, 0, 1)))

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
			"heart":
				heart(q.p, q.size * (1.0 - t * 0.3), Color(c, 1.0 - t))
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
		SHOP: draw_shop()
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
	candy("商店", Rect2(362, 500, 150, 70), open_shop.bind(-1), 2)
	candy("退出游戏", Rect2(528, 500, 150, 70), get_tree().quit, 1)
	gold_pill(Rect2(920, 38, 180, 46))
	label("第 01 ~ 03 章 · 共 %d 关   ·   已通关 %d / %d" % [stars.size(), stars.size() - stars.count(0), stars.size()], Rect2(96, 648, 640, 30), 15, MUTED, 0, 1, 5, PLUM)
	round_button("music", Vector2(1150, 60), 28, toggle_music, false, "音乐", not music_on)
	round_button("sound", Vector2(1218, 60), 28, toggle_sfx, false, "音效", not sfx_on)

# 标题右侧轮流介绍八位店员，也可以点下面的小圆点切换。
func draw_showcase() -> void:
	if ui_time - showcase_at > 4.2:
		showcase = (showcase + 1) % 17
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
	for i in range(17):
		var dot := Vector2(990 - 16 * 9.0 + i * 18.0, 690)
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
	header("今日菜单", "第 %02d 章 · %s" % [chapter_view, Campaign.CHAPTER_NAMES[chapter_view - 1]], "", open_title)
	for n in range(1, Campaign.CHAPTER_STARTS.size() + 1):
		var tab := Rect2(134 + (n - 1) * 132, 106, 122, 34)
		var open := is_unlocked(Campaign.CHAPTER_STARTS[n - 1])
		var on := n == chapter_view
		box(tab, SAKURA if on else (CREAM if open else Color("#d9c6b6")), COCOA, 17, 3)
		label("第 %02d 章" % n, tab.grow_individual(-10 if open else -26, 0, -10, 0), 15, TEXT if on else (COCOA if open else INK_SOFT), MID, 2, 4 if on else 0, SAKURA_DEEP)
		if not open:
			glyph("lock", tab.position + Vector2(20, 17), 7, INK_SOFT)
		if not on:
			buttons.append([tab, open_chapter.bind(n), "page"])
	gold_pill(Rect2(590, 44, 180, 46))
	candy("商店", Rect2(786, 40, 140, 54), open_shop.bind(-1), 2)
	var badge := Rect2(950, 38, 276, 84)
	paper(badge, 20)
	star(Vector2(992, 80), 20, GOLD, COCOA, 2.5)
	label("%d / %d" % [total_stars(), stars.size() * 3], Rect2(1022, 46, 190, 40), 28, COCOA, 0, 2)
	label("已通关 %d / %d 关" % [stars.size() - stars.count(0), stars.size()], Rect2(1023, 84, 190, 26), 14, INK_SOFT, 0, 1)
	var ids := Campaign.chapter_range(chapter_view)
	for slot in range(PAGE_SIZE):
		var k := page * PAGE_SIZE + slot
		if k >= ids.size():
			break
		draw_stage_card(ids[k], Rect2(56.0 + (slot % 3) * 392.0, 156.0 + floorf(slot / 3.0) * 218.0, 372, 200))
	var last := chapter_pages(chapter_view) - 1
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
	var locked := not is_unlocked(i)
	var arena: Array = ARENAS[level.arena]
	var boss: bool = i == 21 or level.get("boss", false)
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
	var info := "%d 波" % level.waves
	if i == 21 or i == Campaign.levels.size() - 1:
		info = "三阶段 Boss"
	elif boss:
		info = "%d 波 · 中 Boss" % level.waves
	label("%d 路 · %s" % [level.rows, info], Rect2(r.position.x + 158, r.position.y + 82, 200, 22), 15, INK_SOFT, 0, 1)
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
		label("%d / %d" % [loadout.count(true), max_loadout()], count, 16, TEXT, MID, 2, 3, SAKURA_DEEP)
	var cards := visible_cards()
	if cards.size() <= 10:
		var columns := ceili(cards.size() / 2.0)
		var width := (820.0 - (columns - 1) * 12.0) / columns
		for k in range(cards.size()):
			draw_badge(cards[k], Rect2(78.0 + (k % columns) * (width + 12.0), 230.0 + floorf(float(k) / columns) * 190.0, width, 176))
	else:
		if cards.size() > 21:
			# 店员太多，每页 21 张；没买的店员显示价格，点了去商店。
			for p in range(2):
				var tab := Rect2(300 + p * 124, 188, 116, 30)
				var on := p == brief_page
				box(tab, SAKURA if on else CREAM, COCOA, 15, 2)
				label(["No.1 – 21", "No.22 – %d" % cards.size()][p], tab, 14, TEXT if on else COCOA, MID, 2, 3 if on else 0, SAKURA_DEEP)
				if not on:
					buttons.append([tab, set_brief_page.bind(p), "page"])
			candy("商店", Rect2(572, 184, 112, 38), open_shop.bind(-1), 2, 15)
			gold_pill(Rect2(694, 186, 96, 34), true)
			cards = cards.slice(21) if brief_page == 1 else cards.slice(0, 21)
		var columns := 7
		var width := (820.0 - (columns - 1) * 8.0) / columns
		for k in range(cards.size()):
			draw_badge_small(cards[k], Rect2(78.0 + (k % columns) * (width + 8.0), 228.0 + floorf(float(k) / columns) * 121.0, width, 115))
		var focus: int = brief_focus if brief_focus in cards else cards[0]
		var info: Dictionary = Campaign.CARDS[focus]
		label("%s · %s：%s" % [info.name, info.role, info.desc], Rect2(80, 590, 820, 24), 14, COCOA, 0, 1)
	draw_receipt(level, arena, Rect2(936, 174, 288, 444))
	candy("开始值班  ›", Rect2(970, 634, 254, 66), start_battle, 0, 24)
	var tips := "点卡片再点格子部署 · 点发光算力收集 · 再点卡片取消"
	if not mobile:
		tips += " · 1-%d 选卡  R 移除  空格 暂停" % max_loadout()
		if Campaign.chapter(stage) == 3:
			tips = "点卡片再点格子部署 · 1-%d 选卡  R 移除  F 防火墙  B 云备份  空格 暂停" % max_loadout()
	label(tips, Rect2(60, 648, 890, 36), 15, MUTED, 0, 1, 5, PLUM)

func draw_badge(i: int, rect: Rect2) -> void:
	var card: Dictionary = Campaign.CARDS[i]
	var accent: Color = ACCENTS[i]
	var available := owns(i)
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
	label(card.role, Rect2(r.position.x + 10, r.position.y + 146, r.size.x - 84, 22), 13, INK_SOFT, 0, 1)
	var cost := Rect2(r.end.x - 70, r.position.y + 145, 60, 24)
	box(cost, Color(MINT, 0.55) if available else Color("#dcc6ae"), COCOA, 12, 2)
	gem(cost.position + Vector2(13, 12), 7, MINT_DEEP if available else INK_SOFT, Color.TRANSPARENT)
	label(str(card.cost), Rect2(cost.position + Vector2(22, 0), Vector2(38, 24)), 14, COCOA, MID, 2)
	if not available:
		draw_circle(r.position + Vector2(r.size.x * 0.5, 78), 22, Color(COCOA, 0.8), true, -1.0, true)
		glyph("lock", r.position + Vector2(r.size.x * 0.5, 78), 12, CREAM)
		label("商店购买", Rect2(r.position.x + 70, r.position.y + 6, r.size.x - 82, 26), 12, TEXT, END, 2, 3, Color(COCOA, 0.6))
	elif on:
		var tag := Rect2(r.end.x - 70, r.position.y - 10, 76, 28)
		box(tag, SAKURA, COCOA, 14, 2)
		glyph("check", tag.position + Vector2(16, 14), 7, TEXT)
		label("上阵", Rect2(tag.position + Vector2(26, 0), Vector2(46, 28)), 14, TEXT, MID, 2, 3, SAKURA_DEEP)
	if available and stage > 0:
		buttons.append([rect, toggle_card.bind(i), "select"])

# 第 02 章卡多，用小号工牌排成 7 × 3。
func draw_badge_small(i: int, rect: Rect2) -> void:
	var card: Dictionary = Campaign.CARDS[i]
	var accent: Color = ACCENTS[i]
	var available := owns(i)
	var on: bool = loadout[i]
	var hot := rect.has_point(pointer)
	if hot:
		brief_focus = i
	var r := rect
	if on:
		r.position.y -= 4
	elif hot:
		r.position.y -= 2
	if on:
		box(r.grow(4), Color(accent, 0.45), Color.TRANSPARENT, 16)
	box(r, CREAM if available else LATTE, accent.darkened(0.25) if on else COCOA, 13, 3 if on else 2, 0.2)
	box(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 18)), accent if available else Color("#c8ad93"), Color.TRANSPARENT, 9)
	label("No.%d" % (i + 1), Rect2(r.position + Vector2(8, 3), Vector2(50, 18)), 10, TEXT, 0, 2, 2, Color(COCOA, 0.6))
	var tag: String = card.get("tag", "")
	if tag != "":
		var pill := Rect2(r.end.x - 40, r.position.y + 3, 37, 18)
		box(pill, COCOA if tag == "SP" else Color("#5a3d8a"), Color.TRANSPARENT, 9)
		label(tag, pill, 10, GOLD if tag == "SP" else TEXT, MID, 2)
	sprite(card.key, Rect2(r.position + Vector2(6, 22), Vector2(r.size.x - 12, 58)), Color.WHITE if available else Color(0.6, 0.55, 0.55, 0.45))
	label(card.name, Rect2(r.position.x + 4, r.position.y + 80, r.size.x - 8, 18), 13, COCOA if available else INK_SOFT, MID, 2)
	var cost := Rect2(r.get_center().x - 26, r.position.y + 97, 52, 16)
	box(cost, Color(MINT, 0.55) if available else Color("#dcc6ae"), COCOA, 8, 1)
	gem(cost.position + Vector2(10, 8), 5, MINT_DEEP if available else INK_SOFT, Color.TRANSPARENT)
	label(str(card.cost), Rect2(cost.position + Vector2(16, 0), Vector2(34, 16)), 11, COCOA, MID, 2)
	if not available:
		draw_circle(r.position + Vector2(r.size.x * 0.5, 50), 16, Color(COCOA, 0.8), true, -1.0, true)
		glyph("lock", r.position + Vector2(r.size.x * 0.5, 50), 9, CREAM)
		var tag_rect := Rect2(r.position.x + 6, r.position.y + 62, r.size.x - 12, 17)
		box(tag_rect, Color(COCOA, 0.82), Color.TRANSPARENT, 8)
		coin(tag_rect.position + Vector2(12, 8.5), 5.5)
		label(str(Campaign.PRICES[i]), Rect2(tag_rect.position + Vector2(20, 0), Vector2(tag_rect.size.x - 22, 17)), 11, GOLD, MID, 2)
		if stage > 0:
			buttons.append([rect, open_shop.bind(i), "click"])
	elif on:
		draw_circle(r.position + Vector2(r.size.x - 6, 4), 11, SAKURA, true, -1.0, true)
		draw_circle(r.position + Vector2(r.size.x - 6, 4), 11, COCOA, false, 2.0, true)
		glyph("check", r.position + Vector2(r.size.x - 6, 4), 6, TEXT)
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
	var tag := "No.%s · %s" % [Campaign.code(stage), arena[0]]
	match level.get("event", ""):
		"rain": tag += " · 全程下雨"
		"blackout": tag += " · 第 3 波停电"
	label(tag, Rect2(r.position.x, r.position.y + 44, r.size.x, 20), 13, INK_SOFT, MID, 1)
	draw_dashed_line(Vector2(r.position.x + 16, r.position.y + 74), Vector2(r.end.x - 16, r.position.y + 74), Color(COCOA, 0.45), 2.0, 6.0)
	var counts := {}
	for spawn in level.spawns:
		counts[spawn[3]] = int(counts.get(spawn[3], 0)) + 1
	var row := 0
	var kinds := ENEMY_ORDER.filter(func(id): return counts.has(id))
	var pitch := minf(50.0, 300.0 / maxf(1.0, kinds.size()))
	for id in kinds:
		var enemy: Dictionary = Campaign.ENEMIES[id]
		var y := r.position.y + 84 + row * pitch
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
	var clock := "%d:%02d" % [floori(battle.time / 60.0), int(battle.time) % 60]
	var stats := [["击退", str(battle.defeated)], ["部署", str(battle.placed)], ["收集", str(battle.collected)], ["用时", clock]]
	if battle.chapter >= 2:
		stats = [["击退", str(battle.defeated)], ["满意度", str(battle.core)], ["设施", "%d 次" % battle.facility_uses], ["用时", clock]]
	for s in range(4):
		var cell := Rect2(r.position.x + 30 + s * 117, r.position.y + 216, 108, 62)
		box(cell, Color("#f6e6cf"), Color(COCOA, 0.0), 14)
		label(stats[s][1], Rect2(cell.position + Vector2(0, 4), Vector2(cell.size.x, 32)), 24, COCOA, MID, 2)
		label(stats[s][0], Rect2(cell.position + Vector2(0, 36), Vector2(cell.size.x, 20)), 13, INK_SOFT, MID, 1)
	var copy := "清洁机器人每路只能救场一次，换一套布阵再试试。"
	if battle.chapter >= 2:
		copy = "Boss 走到了吧台，再调整一下阵容吧。" if battle.boss_kind != "" and battle.core > 0 else "满意度归零了，别让来客漏过去。"
	if won:
		copy = "进度已保存，下一关已解锁。"
		if stage == 21:
			copy = "EX 挑战已完成，感谢守店！"
		elif stage == 20:
			copy = "第 01 章通关，EX 挑战与第 02 章已开放。"
		elif stage == Campaign.CHAPTER_STARTS[2] - 1:
			copy = "第 02 章通关，第 03 章「云端分店」已开放！"
		elif stage == Campaign.levels.size() - 1:
			copy = "第 03 章通关，感谢守店！"
		elif battle.chapter >= 2 and rating < 3:
			copy = "满意度 100 且用过场景设施，就能拿到三星。"
		if not save_ok:
			copy = "进度写入失败，可以重试。"
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
	if last_gold > 0:
		var pill := Rect2(520, r.end.y - 22, 240, 44)
		box(pill, COCOA, GOLD, 22, 3, 0.3)
		coin(pill.position + Vector2(28, 22), 13)
		label("+%d 金币  ·  共 %d" % [last_gold, gold], Rect2(pill.position + Vector2(46, 0), Vector2(pill.size.x - 56, pill.size.y)), 17, GOLD, MID, 2)
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
	var terrace: bool = battle.chapter >= 2
	if battle.chapter == 3:
		draw_cloud()
	elif terrace:
		draw_terrace()
	else:
		draw_texture_rect(art[battle.level.arena], Rect2(Vector2(-16, -16), SIZE + Vector2(32, 32)), false)
		draw_rect(Rect2(-16, -16, 1312, 752), Color(PLUM, 0.1))
	draw_signs()
	var hover := board_cell(pointer)
	for row in range(battle.level.rows):
		var y := lane_y(row)
		var height := row_height()
		var lane_fill := Color(PLUM, 0.34)
		if battle.chapter == 3:
			lane_fill = Color("#1b2347", 0.48)
		elif terrace:
			lane_fill = Color("#2c3350", 0.42) if row in battle.conveyor_rows else Color("#2d4430", 0.36)
		box(Rect2(BOARD_X - 8, y - 3, 9 * CELL + 16, height + 6), lane_fill, Color(CREAM, 0.5), 14, 2)
		draw_robot(row, y)
		for col in range(9):
			draw_tile(row, col, hover)
		if terrace:
			draw_conveyor(row)
			draw_residues(row)
			draw_umbrellas(row)
		for col in range(9):
			if battle.towers[row][col] != null:
				draw_tower(row, col, battle.towers[row][col])
			if battle.minis[row][col] != null:
				draw_mini(row, col, battle.minis[row][col], battle.towers[row][col] != null)
		if battle.chapter == 3:
			draw_fog(row)
		for enemy in battle.enemies:
			if enemy.row == row:
				draw_enemy(enemy)
		if battle.chapter == 3:
			draw_gate(row)
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
	for beam in beams:
		var bt: float = (ui_time - beam.at) / 0.35
		if bt > 1.0:
			continue
		var by := lane_y(beam.row) + row_height() * 0.45
		var bx := board_x(beam.col + 0.6)
		var seg := 90.0
		var n := int((board_x(9.3) - bx) / seg) + 1
		for k in range(n):
			effect("r1_beam", Vector2(bx + seg * (k + 0.5), by), Vector2(seg + 6, 40 * (1.0 - bt * 0.6)), 1.0 - bt)
		draw_line(Vector2(bx, by), Vector2(board_x(9.3), by), Color(1, 1, 1, 0.8 * (1.0 - bt)), 4.0 * (1.0 - bt) + 1.0, true)
	for g in ghosts:
		var t: float = g.age / 0.38
		var rect: Rect2 = g.rect
		sprite_at(g.key, rect, Color(1.6, 1.6, 1.6, 1.0 - t), Vector2(1.0 + t * 0.35, 1.0 - t * 0.25), Vector2(rect.get_center().x, rect.end.y))
	for z in zaps:
		var zt: float = (ui_time - z.at) / 0.25
		if zt <= 1.0:
			draw_line(z.from, z.to, Color(z.color, 0.9 * (1.0 - zt)), 5.0 * (1.0 - zt) + 1.0, true)
			draw_line(z.from, z.to, Color(1, 1, 1, 0.7 * (1.0 - zt)), 1.5, true)
	for f in fx_sprites:
		var ft: float = (ui_time - f.at) / f.life
		if ft <= 1.0:
			effect(f.key, f.p + f.drift * ft, f.size * (0.8 + ft * 0.3), 1.0 - ft * ft)
	draw_parts(parts)
	draw_floaters(false)
	if terrace:
		draw_weather()
	draw_unit_overlay()
	if battle.chapter == 3:
		draw_cloud_overlay()
	draw_set_transform(Vector2.ZERO)
	cam = Vector2.ZERO
	draw_hud()
	if battle.boss_phase > 0 and battle.boss_hp > 0.0:
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
	if battle.chapter >= 2:
		draw_core_gauge()
	else:
		draw_bar_sign()
	var right := Rect2(1146, 180, 104, 36)
	box(right, WOOD, GOLD_DEEP, 12, 2, 0.3)
	glyph("door", right.position + Vector2(22, 18), 9, GOLD)
	label("入口 ‹", Rect2(right.position + Vector2(34, 0), Vector2(66, 36)), 16, CREAM, MID, 2)

func draw_bar_sign() -> void:
	var left := Rect2(30, 180, 108, 36)
	box(left, WOOD, GOLD_DEEP, 12, 2, 0.3)
	glyph("cup", left.position + Vector2(22, 18), 9, GOLD)
	label("吧台", Rect2(left.position + Vector2(36, 0), Vector2(66, 36)), 16, CREAM, MID, 2)

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
	if battle.props.has(cell):
		box(tile, Color(GOLD, 0.2), GOLD if battle.wreck_at(row, col) and selected == -1 else Color(CREAM, 0.6), 9, 3 if battle.wreck_at(row, col) else 2)
		return
	if selected == -3:
		var tint := SKY if tower != null else CREAM
		box(tile, Color(tint, 0.24), tint, 9, 3)
	elif selected >= 0:
		var card: Dictionary = Campaign.CARDS[selected]
		var mini := Campaign.is_mini(selected)
		var free: bool = battle.minis[row][col] == null if mini else tower == null
		var ok: bool = free and battle.time >= battle.ready_at[selected] and battle.power >= card.cost
		var tint := MINT if ok else BERRY
		box(tile, Color(tint, 0.24), tint, 9, 3)
		if ok:
			var accent: Color = ACCENTS[selected]
			if selected in [0, 2, 4, 5, 7, 8, 10, 11, 12, 14, 16, 17, 20]:
				var lanes := [row]
				if selected == 4:
					lanes = range(maxi(0, row - 1), mini(battle.level.rows - 1, row + 1) + 1)
				for lane in lanes:
					var ly := lane_y(lane) + row_height() * 0.45
					draw_dashed_line(Vector2(tile.end.x + 4, ly), Vector2(board_x(9) - 6, ly), Color(accent, 0.75), 3.0, 12.0)
			elif selected == 6:
				box(Rect2(BOARD_X, y, 9 * CELL, h), Color(MINT, 0.12), Color.TRANSPARENT, 10)
			if mini and tower != null:
				sprite(card.key, Rect2(tile.end - Vector2(tile.size.x * 0.5, tile.size.y * 0.62), tile.size * Vector2(0.5, 0.6)), Color(1, 1, 1, 0.7))
			else:
				sprite(card.key, tile.grow(-4), Color(1, 1, 1, 0.6))
	elif selected == -2:
		var tint := BERRY if tower != null else CREAM
		box(tile, Color(tint, 0.24), tint, 9, 3)
	else:
		box(tile, Color(CREAM, 0.1), Color(CREAM, 0.7), 9, 2)

func draw_robot(row: int, y: float) -> void:
	var ready: bool = battle.robots[row]
	if battle.chapter >= 2:
		ready = true
	else:
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
	if battle.chapter >= 2 and battle.income_frozen_until > battle.time:
		draw_circle(pc, 44, Color("#bfe9ff", 0.88), true, -1.0, true)
		label("冻结 %d" % ceili(battle.income_frozen_until - battle.time), Rect2(pc.x - 40, pc.y - 12, 80, 24), 15, TEXT, MID, 2, 5, Color("#2b5a7a"))
	var active := equipped()
	var wide := active.size() <= 5
	var narrow := active.size() >= 7
	var card_w := 104.0 if wide else 80.0 if narrow else 94.0
	var card_step := 114.0 if wide else 86.0 if narrow else 100.0
	var first_x := 246.0 if wide else 236.0 if narrow else 238.0
	for slot in range(active.size()):
		draw_card(active[slot], slot, Rect2(first_x + slot * card_step, 24, card_w, 108))
	var x := maxf(866.0, first_x + active.size() * card_step + 30.0)
	round_button("broom", Vector2(x, 64), 30, toggle_remove, selected == -2, "移除")
	var step := 74.0 if wide else 64.0 if narrow else 70.0
	if battle.charger:
		x += step
		tool_button("bolt", Vector2(x, 64), toggle_overclock, selected == -3, "超频 %d" % Battle.CHARGER_COST, battle.charger_wait(), Battle.CHARGER_CD, battle.power >= Battle.CHARGER_COST)
	if not battle.conveyor_rows.is_empty():
		x += step
		tool_button("reverse", Vector2(x, 64), use_reverse, battle.reverse_until > battle.time, "逆流 %d" % Battle.CONVEYOR_COST, battle.conveyor_wait(), Battle.CONVEYOR_CD, battle.power >= Battle.CONVEYOR_COST)
	var locked: bool = battle.chapter == 3 and battle.facilities_locked()
	if battle.has_gates:
		x += step
		tool_button("gate", Vector2(x, 64), toggle_gate, selected == -4, "防火墙 %d" % Battle.GATE_COST, battle.gate_wait(), Battle.GATE_CD, battle.power >= Battle.GATE_COST)
		if locked:
			lock_cover(Vector2(x, 64))
	if battle.has_backup:
		x += step
		tool_button("cloud", Vector2(x, 64), toggle_backup, selected == -5, "备份 %d" % Battle.BACKUP_COST, battle.backup_wait(), Battle.BACKUP_CD, battle.power >= Battle.BACKUP_COST)
		if locked:
			lock_cover(Vector2(x, 64))
	x += step + 4.0
	round_button("pause", Vector2(x, 64), 30, pause_game, false, "暂停")
	for b in buttons:
		if b[1] in [Callable(self, "toggle_remove"), Callable(self, "toggle_overclock"), Callable(self, "toggle_gate"), Callable(self, "toggle_backup")]:
			b[2] = ""
	var arena: Array = ARENAS[battle.level.arena]
	var left := x + 46.0
	var chip := Rect2(left, 32, 78, 30)
	box(chip, GOLD_DEEP if battle.level.get("boss", false) or stage == 21 else arena[1], COCOA, 15, 2)
	label(Campaign.code(stage), chip, 15, TEXT, MID, 2, 3, COCOA)
	label(arena[0], Rect2(left + 86, 32, 1244 - left - 86, 30), 14, GOLD, 0, 2)
	label(battle.level.title, Rect2(left, 70, 1244 - left, 40), 22, CREAM, 0, 2, 5, COCOA)

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
	elif selected == -3:
		help = "点一位店员超频：8 秒攻速 +50%，结束后过热 1.5 秒。"
	elif selected >= 0:
		help = Campaign.CARDS[selected].desc + ("  点店员或空格部署。" if Campaign.is_mini(selected) else "  点击空格部署。")
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
	sprite(boss_art(), Rect2(392, 136, 58, 58))
	var ratio: float = battle.boss_hp / maxf(1.0, battle.boss_max)
	var title: String = Campaign.ENEMIES[battle.boss_kind].name + " · " + BOSS_PHASES[battle.boss_kind][battle.boss_phase]
	label(title, Rect2(456, 150, 300, 22), 14, GOLD, 0, 2)
	label("%d%%" % ceili(ratio * 100.0), Rect2(770, 150, 106, 22), 14, CREAM, END, 2)
	var track := Rect2(456, 174, 422, 12)
	box(track, Color("#2a1a1a"), COCOA, 6, 2)
	if ratio > 0.0:
		box(Rect2(track.position + Vector2(2, 2), Vector2((track.size.x - 4) * ratio, 8)), BERRY, Color.TRANSPARENT, 4)
	var marks: Array = [] if battle.boss_kind in ["M", "G"] else [0.7, 0.35] if battle.boss_kind in ["X", "Z"] else [0.66, 0.33]
	for mark in marks:
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
	var idle: String = battle.idle_reason(tower)
	if tower.sealed > battle.time:
		tint = Color("#c9a3c0")
	elif hit_age < 0.12:
		tint = Color(1.0, 0.6, 0.6)
		scale *= Vector2(1.05, 0.95)
	elif idle != "":
		tint = Color(0.72, 0.7, 0.78)
	if tower.get("boost", 0.0) > battle.time:
		draw_circle(Vector2(x, y + height * 0.5), 40 + 3 * sin(ui_time * 10.0), Color(GOLD, 0.22), true, -1.0, true)
	var key: String = card.key + "_act" if acting and art.has(card.key + "_act") else card.key
	sprite_at(key, Rect2(x - 50 + recoil, y - 2 + lift, 100, height - 8), tint, scale, Vector2(x, y + height - 10))
	if tower.card == 16 and tower.get("charge", 0.0) > battle.time:
		var k: float = 1.0 - (tower.charge - battle.time) / 2.0
		draw_arc(Vector2(x, y + height * 0.45), 34, -PI * 0.5, -PI * 0.5 + TAU * k, 32, SKY, 4.0, true)
		for b in range(3):
			draw_circle(Vector2(x + 18 + b * 7, y + 2 - b * 8 - sin(ui_time * 6.0 + b) * 2), 3 + b, Color(CREAM, 0.85), true, -1.0, true)
	draw_status(tower, x, y, height)
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
	var boss: bool = enemy.kind in ["X", "V", "G", "Z"]
	var flying: bool = enemy.get("fly", false)
	var appear := clampf((battle.time - float(enemy.get("born", -9.0))) / 0.4, 0.0, 1.0)
	var bob := absf(sin(battle.time * (13.0 if enemy.kind == "R" else 8.0) + enemy.x)) * 4.0
	if enemy.wait > battle.time or enemy.get("freeze", 0.0) > battle.time:
		bob = 0.0
	if flying:
		bob = 10.0 + sin(battle.time * 7.0 + enemy.x) * 4.0
	var shadow := Vector2(52, 12) if boss else Vector2(18, 4) if flying else Vector2(40, 9) if enemy.kind in ["W", "N"] else Vector2(20, 5) if enemy.kind in ["Q", "J"] else Vector2(27, 6)
	ellipse(Vector2(x, y + height - 13), shadow, Color(PLUM, (0.35 if flying else 0.6) * appear))
	if enemy.kind == "V" and enemy.charge > battle.time:
		var k: float = 1.0 - (enemy.charge - battle.time) / 4.0
		draw_circle(Vector2(x, y + height * 0.2), 70 + 12 * sin(ui_time * 14.0), Color(BERRY, 0.16 + 0.2 * k), true, -1.0, true)
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
	var unseen: bool = battle.chapter == 3 and not enemy.hidden and not battle.can_target(enemy)
	if unseen:
		tint = Color(0.22, 0.24, 0.42, 0.55)
	tint.a *= appear
	var dx := (1.0 - appear) * 22.0
	if enemy.boost > battle.time:
		for k in range(3):
			var ly := y + height * (0.3 + k * 0.18)
			var lx := x + 30 + fmod(battle.time * 260.0 + k * 37.0, 40.0)
			draw_line(Vector2(lx, ly), Vector2(lx + 26, ly), Color(GOLD, 0.7), 3.0, true)
	var key: String = Campaign.ENEMIES[enemy.kind].key
	var rect := Rect2(x - 45 + dx, y - bob, 90, height - 10)
	if boss:
		rect = Rect2(x - 81 + dx, y - 68 - bob, 162, height + 57)
		if enemy.kind == "X":
			key = "boss%d" % battle.boss_phase
		elif enemy.kind in ["V", "Z"]:
			key = boss_art()
		if enemy.kind == "G":
			rect = Rect2(x - 100 + dx, y - 80 - bob * 0.5, 200, height + 70)
	elif enemy.kind == "W":
		rect = Rect2(x - 60 + dx, y - 14, 120, height + 4)
	elif enemy.kind == "M":
		rect = Rect2(x - 95 + dx, y - 48 - bob, 190, height + 22)
	elif enemy.kind == "Q":
		rect = Rect2(x - 32 + dx, y + 8 - bob, 64, height - 18)
	elif enemy.kind == "N":
		rect = Rect2(x - 56 + dx, y - 10, 112, height)
	elif enemy.kind == "J":
		var hop: float = absf(sin(battle.time * 9.0 + enemy.x)) * 8.0
		rect = Rect2(x - 38 + dx, y + 6 - hop, 76, height - 16)
	elif flying:
		rect = Rect2(x - 42 + dx, y - 12 - bob, 84, height * 0.78)
	if enemy.kind == "H" and fmod(ui_time * 3.0 + enemy.x, 1.0) < 0.35:
		sprite(key, Rect2(rect.position + Vector2(-5, 0), rect.size), Color(0.3, 1.0, 1.0, 0.35 * appear))
		sprite(key, Rect2(rect.position + Vector2(5, 1), rect.size), Color(1.0, 0.3, 0.9, 0.35 * appear))
	sprite_at(key, rect, tint, scale, Vector2(x, rect.end.y - 2))
	if enemy.kind == "X" and enemy.armor > battle.time:
		effect("claude_fx", Vector2(x - 55, y + height * 0.18), Vector2(64, 90), 0.8)
	if enemy.get("lit", 0.0) > battle.time:
		ellipse(Vector2(x, y + height - 13), Vector2(44, 11), Color(1, 1, 0.7, 0.35))
		star(Vector2(x + 26, rect.position.y + 10), 6, Color(1, 1, 0.75), COCOA, 1.5, ui_time * 3.0)
	if enemy.get("root", 0.0) > battle.time:
		for k in range(3):
			var a := ui_time * 3.0 + k * TAU / 3.0
			heart(Vector2(x + cos(a) * 30.0, y + height * 0.55 + sin(a) * 8.0), 6, Color(SAKURA, 0.9))
	if enemy.get("beat", 0.0) > battle.time:
		for k in range(2):
			var age := fposmod(ui_time * 1.5 + k * 0.5, 1.0)
			glyph("note", Vector2(x - 12 + k * 22, rect.position.y + 4 - age * 18), 7, Color(Color("#ff6fb1"), 1.0 - age))
	if enemy.kind == "N":
		var pull := fposmod(ui_time * 1.6, 1.0)
		gem(Vector2(x - 40 + pull * 34, y + 10 + pull * 10), 6.0 * (1.0 - pull * 0.5), Color(MINT, 1.0 - pull))
	if enemy.get("freeze", 0.0) > battle.time:
		var ice := Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.25), Vector2(rect.size.x * 0.64, rect.size.y * 0.75))
		box(ice, Color(SKY, 0.38), Color(1, 1, 1, 0.85), 8, 2)
		draw_line(ice.position + Vector2(6, 6), ice.position + Vector2(18, 20), Color(1, 1, 1, 0.8), 2.0, true)
		star(ice.position + Vector2(ice.size.x - 8, 8), 6, Color(1, 1, 1, 0.9), COCOA, 0.0, ui_time * 2.0)
	if enemy.kind == "P" and enemy.get("aim", 0.0) > battle.time:
		var k: float = 1.0 - (enemy.aim - battle.time) / 0.7
		star(Vector2(x - 26, y + height * 0.3), 6 + 14 * k, Color(1, 1, 0.85, 0.5 + 0.5 * k), COCOA, 0.0, ui_time * 4.0)
	if enemy.get("burn", 0.0) > battle.time:
		for k in range(4):
			var fx := x - 18 + k * 12 + sin(ui_time * 9.0 + k) * 3
			var fy := rect.end.y - 18 - fmod(ui_time * 40.0 + k * 9.0, 22.0)
			draw_colored_polygon(PackedVector2Array([Vector2(fx, fy - 9), Vector2(fx + 5, fy + 3), Vector2(fx - 5, fy + 3)]), Color(1.0, 0.45 + 0.3 * (k % 2), 0.1, 0.85))
	if enemy.get("mark", 0.0) > battle.time:
		var mc := Vector2(x, rect.position.y - 4)
		draw_circle(mc, 12, Color("#6c7cff", 0.9), true, -1.0, true)
		draw_arc(mc, 12, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 2.0, true)
		label("标", Rect2(mc - Vector2(12, 12), Vector2(24, 24)), 13, TEXT, MID, 2)
	if enemy.get("stolen", 0) > 0:
		var bag := Rect2(x + 14, rect.position.y + 4, 44, 20)
		box(bag, COCOA, GOLD, 10, 2)
		label("+%d" % enemy.stolen, bag, 12, GOLD, MID, 2)
	if enemy.get("weak", 0.0) > battle.time:
		draw_colored_polygon(PackedVector2Array([Vector2(x + 22, y + 6), Vector2(x + 34, y + 6), Vector2(x + 28, y + 16)]), Color("#b07cff"))
	if enemy.kind == "V" and enemy.charge > battle.time:
		var left: float = enemy.charge - battle.time
		var c := Vector2(x, y - 74)
		draw_circle(c, 24, Color(COCOA, 0.85), true, -1.0, true)
		draw_arc(c, 21, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - left / 4.0), 36, BERRY, 5.0, true)
		label("%.1f" % left, Rect2(c - Vector2(20, 12), Vector2(40, 24)), 14, TEXT, MID, 2)
		var tag := Rect2(c + Vector2(30, -14), Vector2(118, 28))
		box(tag, COCOA, BERRY, 14, 2)
		label("打断 %d/%d" % [int(enemy.charge_dmg), int(Battle.INTERRUPT)], tag, 13, GOLD, MID, 2)
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
	var value: int = token.get("value", 25)
	var gold: bool = token.get("gold", false)
	var fake: bool = token.get("fake", false)
	var age: float = battle.time - token.born
	var alpha := 1.0 if age < 8.0 else 0.65 + 0.35 * sin(age * 17.0)
	var hot := p.distance_to(pointer) < 30.0
	draw_circle(p, 30, Color(color, 0.12 * alpha), true, -1.0, true)
	draw_circle(p, 22, Color(color, 0.22 * alpha), true, -1.0, true)
	draw_arc(p, 19, -age * 2.8 if fake else age * 2.8, (-age * 2.8 if fake else age * 2.8) + 4.6, 24, Color(color, 0.9 * alpha), 2.5, true)
	if fake:
		# 钓鱼邮件丢下的假算力：反着转，底下挂着一个小鱼钩。
		draw_arc(p + Vector2(0, 24), 5, 0.0, PI, 8, Color(BERRY, alpha), 2.0, true)
		draw_line(p + Vector2(5, 24), p + Vector2(5, 15), Color(BERRY, alpha), 2.0, true)
	if gold:
		draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -2), p + Vector2(-9, -11), p + Vector2(9, -11), p + Vector2(16, -2), p + Vector2(11, 8), p + Vector2(-11, 8)]), Color("#ffcf3d", alpha))
		draw_polyline(PackedVector2Array([p + Vector2(-16, -2), p + Vector2(-9, -11), p + Vector2(9, -11), p + Vector2(16, -2), p + Vector2(11, 8), p + Vector2(-11, 8), p + Vector2(-16, -2)]), Color(COCOA, alpha), 2.0, true)
		draw_circle(p + Vector2(0, -4), 5, Color("#fff1a8", alpha), true, -1.0, true)
	else:
		gem(p, 15.0 if hot else 12.0, Color(color, alpha))
	star(p + Vector2(11, -12), 4.5 * absf(sin(age * 4.0)) + 1.0, Color(1, 1, 1, alpha), COCOA, 0.0)
	if hot or gold or (stage == 0 and battle.collected == 0):
		var tag := Rect2(p + Vector2(-25, 22), Vector2(50, 22))
		box(tag, COCOA, Color.TRANSPARENT, 11)
		label("+%d" % value, tag, 13, color, MID, 2)

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
		8: effect("mistral_shot", p + Vector2(10 * t, 0), Vector2(60, 40) * (0.6 + t * 0.5), fade)
		9: effect("doubao_fx", p + Vector2(12 * t, 0), Vector2(90, 80) * (0.6 + t * 0.6), fade)
		10: effect("hailuo_shot", p + Vector2(12 * t, 0), Vector2(70, 60) * (0.6 + t * 0.5), fade)
		11: effect("spark_shot", p + Vector2(10 * t, 0), Vector2(60, 40) * (0.6 + t * 0.5), fade)
		12: effect("ernie_shot", p + Vector2(10 * t, 0), Vector2(70, 40) * (0.6 + t * 0.5), fade)
		13: effect("kimi_fx", p + Vector2(4, -20 * t), Vector2(90, 76) * (0.7 + t * 0.4), fade)
		14: effect("llama_shot", p + Vector2(10 * t, 0), Vector2(50, 40) * (0.6 + t * 0.5), fade)
		15: effect("paint_wall", p + Vector2(18 * t, 0), Vector2(60, 60) * (0.5 + t * 0.5), fade * 0.8)
		16: effect("r1_beam", p + Vector2(20 * t, 0), Vector2(90, 40) * (0.6 + t * 0.5), fade)
		35: effect("gpt_hit", p + Vector2(9 * t, 0), Vector2(60, 60) * (0.5 + t), fade * 0.9, Color(1.0, 0.85, 0.6))
		36: effect("gemini_shot", p + Vector2(14 * t, -8), Vector2(90, 54) * (0.62 + t * 0.4), fade)
		37: effect("grok_hit", p + Vector2(7, 0), Vector2(70, 70) * (0.63 + t * 0.42), fade)
		38: effect("qwen_shot", p + Vector2(16 * t, 0), Vector2(96, 64) * (0.66 + t * 0.48), fade)

func draw_shot(shot: Dictionary) -> void:
	var age: float = battle.time - shot.born
	var p := Vector2(board_x(shot.x) - 14, lane_y(shot.row) + row_height() * 0.43)
	if shot.card == 7:
		p.y -= 12.0 * absf(sin(age * 8.0))
	var size := Vector2(74, 35) * (1.0 + 0.09 * sin(age * 24.0))
	var tint := Color.WHITE
	if shot.card in SMALL_SHOTS:
		size *= 0.55
	elif shot.card == 10:
		size = Vector2(60, 64)
	elif shot.card == 37:
		size *= 1.45
		p.y -= 14.0 * absf(sin(age * 7.0))
	elif shot.card == 38:
		size = Vector2(96, 60)
	elif shot.card == 35:
		# GPT-4o：光 / 冰 / 火三色轮换
		tint = [Color(1.0, 0.95, 0.75), Color(0.6, 0.9, 1.0), Color(1.0, 0.55, 0.3)][shot.get("elem", 0)]
	for k in range(1, 4):
		effect(SHOT_ART[shot.card], p - Vector2(k * 12.0, 0), size * (1.0 - k * 0.16), 0.32 - k * 0.08, tint)
	effect(SHOT_ART[shot.card], p, size, 1.0, tint)

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
		var size := Vector2(132, 116) if hit.kind == 7 else Vector2(45, 40) if hit.kind in SMALL_SHOTS else Vector2(75, 65)
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

# ---------------------------------------------------------------- 第 02 章：场景、设施与状态

func draw_terrace() -> void:
	var key := "terrace" if art.has("terrace") else "arena"
	draw_texture_rect(art[key], Rect2(Vector2(-16, -16), SIZE + Vector2(32, 32)), false)
	if not art.has("terrace"):
		draw_rect(Rect2(-16, -16, 1312, 752), Color("#ffcf7a", 0.12))
		for k in range(27):
			var x := -16.0 + k * 50.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 140), Vector2(x + 50, 140), Vector2(x + 50, 156), Vector2(x, 156)]), SAKURA if k % 2 == 0 else CREAM)
			draw_circle(Vector2(x + 25, 156), 25, SAKURA if k % 2 == 0 else CREAM, true, -1.0, true)
	if battle.level.get("boss", false):
		draw_rect(Rect2(-16, -16, 1312, 752), Color("#3a0f2c", 0.3))
	elif battle.rain:
		draw_rect(Rect2(-16, -16, 1312, 752), Color("#1d2b45", 0.3))
	else:
		draw_rect(Rect2(-16, -16, 1312, 752), Color(PLUM, 0.06))

func draw_core_gauge() -> void:
	var r := Rect2(24, 176, 178, 46)
	if ui_time - core_hit_at < 0.35:
		r.position.x += sin(ui_time * 70.0) * 4.0
	var ratio := float(battle.core) / Battle.CORE_MAX
	var color := MINT if ratio >= 0.8 else GOLD if ratio >= 0.4 else BERRY
	box(r, WOOD, BERRY if ui_time - core_hit_at < 0.35 else GOLD_DEEP, 14, 2, 0.3)
	heart(r.position + Vector2(24, 24), 13.0 * (1.0 + 0.25 * maxf(0.0, 1.0 - (ui_time - core_hit_at) / 0.3)), color)
	label("吧台满意度", Rect2(r.position + Vector2(44, 3), Vector2(84, 22)), 12, CREAM, 0, 2)
	label(str(battle.core), Rect2(r.position + Vector2(120, 3), Vector2(48, 22)), 16, color, END, 2)
	var track := Rect2(r.position + Vector2(44, 28), Vector2(124, 10))
	box(track, COCOA, Color.TRANSPARENT, 5)
	if ratio > 0.0:
		box(Rect2(track.position + Vector2(1, 1), Vector2((track.size.x - 2) * ratio, 8)), color, Color.TRANSPARENT, 4)

func heart(c: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(28):
		var t := TAU * i / 28.0
		var hx := 16.0 * pow(sin(t), 3)
		var hy := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(hx, hy) * s / 16.0)
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, COCOA, maxf(1.5, s * 0.16), true)

func draw_conveyor(row: int) -> void:
	if not row in battle.conveyor_rows:
		return
	var y := lane_y(row)
	var h := row_height()
	var x0 := board_x(battle.conveyor_from) + 4.0
	var x1 := board_x(battle.conveyor_to) - 4.0
	var rev: bool = battle.reverse_until > battle.time
	var band := Rect2(x0, y + h * 0.6, x1 - x0, h * 0.28)
	box(band, Color("#3b3550", 0.85), SKY if rev else Color(CREAM, 0.55), 8, 2)
	var span := band.size.x - 20.0
	var dir := 1.0 if rev else -1.0
	var mid := band.get_center().y
	var half := band.size.y * 0.3
	for k in range(int(span / 26.0)):
		var px := band.position.x + 10.0 + fposmod(k * 26.0 + dir * battle.time * (70.0 if rev else 42.0), span)
		var color := Color(SKY, 0.9) if rev else Color(GOLD, 0.75)
		draw_polyline(PackedVector2Array([Vector2(px - dir * 5, mid - half), Vector2(px + dir * 5, mid), Vector2(px - dir * 5, mid + half)]), color, 3.0, true)

func draw_residues(row: int) -> void:
	for residue in battle.residues:
		if residue.row != row:
			continue
		var alpha := clampf((float(residue.until) - battle.time) / 1.5, 0.0, 1.0)
		var p := Vector2(board_x(residue.x), lane_y(row) + row_height() - 12)
		ellipse(p, Vector2(24, 6), Color("#5a3522", 0.75 * alpha))
		ellipse(p + Vector2(-8, -2), Vector2(5, 3), Color("#8a5a3c", alpha))
		ellipse(p + Vector2(7, 1), Vector2(4, 2.5), Color("#8a5a3c", alpha))

func draw_umbrellas(row: int) -> void:
	for cell in battle.props:
		if cell.y != row:
			continue
		var prop: Dictionary = battle.props[cell]
		var c := cell_center(row, cell.x)
		var h := row_height()
		var base := Vector2(c.x, lane_y(row) + h - 10)
		if prop.get("wall", false):
			var left: float = prop.until - battle.time
			var alpha := clampf(left / 1.2, 0.25, 1.0) if left < 1.2 else 1.0
			if left < 1.2 and fmod(ui_time * 8.0, 1.0) < 0.3:
				alpha *= 0.5
			effect("paint_wall", Vector2(c.x, lane_y(row) + h * 0.5), Vector2(CELL - 10, h), alpha)
			if prop.hp < prop.max:
				hp_bar(Vector2(c.x - 22, lane_y(row) + h - 6), 44, float(prop.hp) / float(prop.max), Color("#b48cff"))
			continue
		ellipse(base, Vector2(22, 5), Color(PLUM, 0.5))
		if prop.hp <= 0.0:
			draw_line(base, base + Vector2(16, -h * 0.55), Color("#8a6a55"), 4.0, true)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-4, -h * 0.5), base + Vector2(30, -h * 0.72), base + Vector2(34, -h * 0.4), base + Vector2(8, -h * 0.3)]), Color("#b9a69a"))
			var pulse := 0.5 + 0.5 * sin(ui_time * 5.0)
			var tag := Rect2(c + Vector2(-34, -h * 0.5 - 4), Vector2(68, 24))
			box(tag, COCOA, GOLD if battle.power >= Battle.REPAIR_COST else Color(CREAM, 0.5), 12, 2)
			label("修复 %d" % Battle.REPAIR_COST, tag, 13, Color(GOLD, 0.7 + 0.3 * pulse), MID, 2)
			continue
		var hit: bool = battle.time - float(prop.hit) < 0.12
		var top := base + Vector2(0, -h * 0.68)
		draw_line(base, top, COCOA, 5.0, true)
		draw_line(base, top, Color("#c8a27a"), 2.5, true)
		var radius := 40.0
		var steps := 6
		for k in range(steps):
			var a0 := PI + PI * k / steps
			var a1 := PI + PI * (k + 1) / steps
			var pts := PackedVector2Array([top + Vector2(0, -2)])
			for j in range(5):
				var a := lerpf(a0, a1, j / 4.0)
				pts.append(top + Vector2(cos(a) * radius, sin(a) * radius * 0.55 + 14))
			var color := (SAKURA if k % 2 == 0 else CREAM)
			draw_colored_polygon(pts, Color(1.0, 0.7, 0.7) * color if hit else color)
		draw_arc(top + Vector2(0, 14), radius, PI, TAU, 24, COCOA, 2.5, true)
		draw_circle(top + Vector2(0, -4), 4, GOLD_DEEP, true, -1.0, true)
		if prop.hp < prop.max:
			hp_bar(Vector2(c.x - 22, lane_y(row) + h - 6), 44, float(prop.hp) / float(prop.max), GOLD)

func draw_weather() -> void:
	if battle.rain:
		for i in range(80):
			var x := fposmod(i * 97.0 - battle.time * 160.0, 1320.0) - 20.0
			var y := fposmod(i * 53.0 + battle.time * 820.0, 760.0) - 20.0
			draw_line(Vector2(x, y), Vector2(x - 6, y + 18), Color(0.82, 0.9, 1.0, 0.38), 1.5, true)
	if battle.blackout_until > battle.time:
		var left: float = battle.blackout_until - battle.time
		draw_rect(Rect2(-16, -16, 1312, 752), Color(0.04, 0.02, 0.08, 0.42 + 0.08 * sin(ui_time * 30.0)))
		var tag := Rect2(500, 400, 280, 50)
		box(tag, COCOA, GOLD, 25, 3)
		glyph("bolt", tag.position + Vector2(32, 25), 13, GOLD)
		label("停电中 %.1f 秒" % left, Rect2(tag.position + Vector2(50, 0), Vector2(220, 50)), 20, GOLD, MID, 2)

func draw_status(tower: Dictionary, x: float, y: float, h: float) -> void:
	var t: float = battle.time
	if tower.get("backup", 0.0) > t:
		var bc := Vector2(x - 34, y + 10)
		draw_circle(bc, 13, Color(COCOA, 0.85), true, -1.0, true)
		draw_arc(bc, 13, -PI * 0.5, -PI * 0.5 + TAU * (tower.backup - t) / 40.0, 24, SKY, 3.0, true)
		glyph("cloud", bc, 8, SKY)
	if tower.get("groove", 0.0) > t:
		for k in range(2):
			var age := fposmod(ui_time * 1.2 + k * 0.5, 1.0)
			glyph("note", Vector2(x + 22 + k * 12, y + 18 - age * 22), 6, Color(Color("#ff6fb1"), 1.0 - age))
	if tower.get("acquire", 0.0) > t:
		var left: float = tower.acquire - t
		var tag := Rect2(x - 52, y - 10, 104, 24)
		box(tag, GOLD, COCOA, 12, 2)
		label("收购 %.1f · %d/3" % [left, tower.acq_taps], tag, 12, COCOA, MID, 2)
		draw_set_transform(cam + Vector2(x, y + h * 0.5), -0.25)
		box(Rect2(-40, -14, 80, 28), Color(BERRY, 0.85), CREAM, 6, 2)
		label("SOLD", Rect2(-40, -14, 80, 28), 16, TEXT, MID, 2)
		draw_set_transform(cam)
	elif tower.get("lock", 0) != 0:
		var lc := Vector2(x, y + h * 0.42)
		draw_circle(lc, 20, Color(COCOA, 0.8), true, -1.0, true)
		glyph("lock", lc, 11, BERRY)
		label("被加密", Rect2(x - 32, y - 6, 64, 20), 12, BERRY, MID, 2, 4, COCOA)
	elif tower.audit > t:
		for angle in [0.35, -0.35]:
			draw_set_transform(cam + Vector2(x, y + h * 0.45), angle)
			box(Rect2(-46, -7, 92, 14), Color("#e0405f"), COCOA, 3, 2)
			draw_set_transform(cam)
		var tag := Rect2(x - 46, y - 8, 92, 22)
		box(tag, COCOA, BERRY, 11, 2)
		label("点我撕封条 %d/3" % tower.taps, tag, 12, TEXT, MID, 2)
	elif tower.emp > t:
		for k in range(3):
			var a := ui_time * 9.0 + k * TAU / 3.0
			var p := Vector2(x + cos(a) * 26.0, y + h * 0.45 + sin(a) * 16.0)
			draw_polyline(PackedVector2Array([p, p + Vector2(5, 6), p + Vector2(-2, 9), p + Vector2(4, 16)]), SKY, 2.5, true)
		label("瘫痪", Rect2(x - 30, y - 6, 60, 20), 13, SKY, MID, 2, 4, COCOA)
	elif tower.blind > t:
		for k in range(3):
			var a := ui_time * 6.0 + k * TAU / 3.0
			star(Vector2(x + cos(a) * 20.0, y + 4 + sin(a) * 5.0), 6, GOLD, COCOA, 1.5, a)
	if t >= tower.boost and t < tower.cool:
		for k in range(3):
			var age := fposmod(ui_time * 1.4 + k * 0.33, 1.0)
			draw_circle(Vector2(x - 10 + k * 10, y + 10 - age * 26), 5 + age * 5, Color(0.9, 0.9, 0.95, 0.5 * (1.0 - age)), true, -1.0, true)
		label("过热", Rect2(x - 30, y + h - 28, 60, 18), 12, CREAM, MID, 2, 4, COCOA)
	if tower.trap > t:
		for k in range(4):
			var a := ui_time * 4.0 + k * TAU / 4.0
			var p := Vector2(x + cos(a) * 30.0, y + h * 0.55 + sin(a) * 9.0)
			draw_circle(p, 6, COCOA, true, -1.0, true)
			draw_circle(p, 4.5, GOLD, true, -1.0, true)
		label("被挖角", Rect2(x - 32, y - 6, 64, 20), 12, GOLD, MID, 2, 4, COCOA)

func tool_button(icon: String, c: Vector2, action: Callable, active: bool, caption: String, wait: float, cooldown: float, affordable: bool) -> void:
	round_button(icon, c, 30, action, active, caption)
	if wait > 0.0:
		draw_circle(c, 27, Color(PLUM, 0.62), true, -1.0, true)
		draw_arc(c, 31, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - wait / cooldown), 36, GOLD, 4.0, true)
		label(str(ceili(wait)), Rect2(c - Vector2(20, 12), Vector2(40, 24)), 17, TEXT, MID, 2, 4, PLUM)
	elif not affordable:
		draw_circle(c + Vector2(21, -21), 7, BERRY, true, -1.0, true)

# ---------------------------------------------------------------- 美术占位：art/ 里没有对应图片时画这些

func figure(key: String, rect: Rect2, tint: Color) -> void:
	var base := key.trim_suffix("_act")
	var acting := key.ends_with("_act")
	match base:
		"mistral": cup_mascot(rect, tint, true, acting)
		"doubao": cup_mascot(rect, tint, false, acting)
		"drone": drone_figure(rect, tint)
		"influencer":
			sprite("clerk", rect, tint * Color(1.0, 0.78, 0.92))
			glyph("cup", rect.position + rect.size * Vector2(0.3, 0.55), rect.size.x * 0.1, Color(COCOA, tint.a))
		"sweeper": sprite("robot", rect, tint * Color(1.0, 0.55, 0.5))
		"hacker": sprite("stealth", rect, tint * Color(0.55, 1.0, 0.7))
		"victor": sprite("advisor", rect, tint * Color(0.75, 0.55, 0.6))
		"crawler": sprite("robot", rect, tint * Color(0.6, 0.9, 1.0))
		"ransomware": sprite("stealth", rect, tint * Color(1.0, 0.5, 0.5))
		"miner": sprite("robot", rect, tint * Color(1.0, 0.85, 0.4))
		"phishing": sprite("clerk", rect, tint * Color(0.6, 0.8, 1.0))
		"behemoth": sprite("sweeper" if art.has("sweeper") else "robot", rect, tint * Color(0.5, 0.65, 1.0))
		"cyrus", "cyrus2", "cyrus3": sprite("victor" if art.has("victor") else "advisor", rect, tint * Color(0.75, 0.8, 1.0))
		"copilot", "perplexity": sprite("gpt", rect, tint * Color(0.75, 0.9, 1.0))
		"suno", "k2": sprite("kimi", rect, tint * Color(1.0, 0.8, 0.95))
		"sora", "nano": sprite("gemini", rect, tint * Color(0.85, 0.95, 1.0))
		"sd": sprite("grok", rect, tint * Color(0.85, 0.7, 1.0))
		"hug", "opus": sprite("claude", rect, tint * Color(1.0, 0.92, 0.7))
		"kling": sprite("qwen", rect, tint * Color(0.7, 0.95, 1.0))
		"skywork", "glm_flash": sprite("glm", rect, tint * Color(0.75, 0.8, 1.0))
		"ministral": sprite("mistral" if art.has("mistral") else "clerk", rect, tint * Color(1.0, 0.85, 0.7))
		"doubao_lite": sprite("doubao" if art.has("doubao") else "clerk", rect, tint * Color(1.0, 0.85, 0.9))
		"gpt4o": sprite("gpt", rect, tint * Color(1.0, 0.9, 0.7))
		"ultra": sprite("gemini", rect, tint * Color(0.75, 0.85, 1.0))
		"heavy": sprite("grok", rect, tint * Color(1.0, 0.75, 0.6))
		"qwenmax": sprite("qwen", rect, tint * Color(0.9, 0.75, 1.0))
		"firewall":
			var c := rect.get_center()
			for k in range(4):
				box(Rect2(c.x - rect.size.x * 0.18, rect.position.y + k * rect.size.y * 0.25, rect.size.x * 0.36, rect.size.y * 0.22), Color(1.0, 0.45 + k * 0.08, 0.2, 0.85 * tint.a), Color(COCOA, tint.a), 3, 2)
		"skywork_strike":
			var c := rect.get_center()
			draw_rect(Rect2(c.x - rect.size.x * 0.15, rect.position.y, rect.size.x * 0.3, rect.size.y), Color(0.75, 0.85, 1.0, 0.7 * tint.a))
			draw_rect(Rect2(c.x - rect.size.x * 0.05, rect.position.y, rect.size.x * 0.1, rect.size.y), Color(1, 1, 1, 0.9 * tint.a))
		"suno_wave", "sora_rewind":
			var c := rect.get_center()
			for k in range(3):
				draw_arc(c, rect.size.y * (0.2 + k * 0.14), -0.9, 0.9, 16, Color(SAKURA if base == "suno_wave" else SKY, (0.9 - k * 0.25) * tint.a), 4.0, true)
		"sd_shot", "kling_shot":
			var c := rect.get_center()
			draw_circle(c, rect.size.y * 0.3, Color(Color("#b07cff") if base == "sd_shot" else SKY, tint.a), true, -1.0, true)
			draw_circle(c, rect.size.y * 0.15, Color(1, 1, 1, 0.8 * tint.a), true, -1.0, true)
		"mistral_shot":
			var c := rect.get_center()
			var s := rect.size.y * 0.4
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 1.6, 0), c + Vector2(0, -s * 0.6), c + Vector2(-s * 1.2, 0), c + Vector2(0, s * 0.6)]), Color(SKY, tint.a))
			draw_line(c + Vector2(-s * 2.4, 0), c + Vector2(-s, 0), Color(1, 1, 1, 0.6 * tint.a), s * 0.4, true)
		"doubao_fx":
			var c := rect.get_center()
			heart(c, rect.size.y * 0.3, Color(1, 1, 1, 0.85 * tint.a))
			heart(c + Vector2(rect.size.x * 0.3, -rect.size.y * 0.2), rect.size.y * 0.12, Color(SAKURA, tint.a))
		_:
			box(rect.grow(-6), Color(CREAM, 0.6 * tint.a), COCOA, 8, 2)

# 新店员的占位吉祥物：冷萃杯 / 拉花杯，带一张小脸。
func cup_mascot(rect: Rect2, tint: Color, cold: bool, acting: bool) -> void:
	var w := minf(rect.size.x * 0.62, rect.size.y * 0.7)
	var h := w * (1.25 if cold else 0.95)
	var bottom := Vector2(rect.get_center().x, rect.end.y - 2)
	var top_y := bottom.y - h
	var body := PackedVector2Array([Vector2(bottom.x - w * 0.5, top_y), Vector2(bottom.x + w * 0.5, top_y),
		Vector2(bottom.x + w * (0.36 if cold else 0.42), bottom.y), Vector2(bottom.x - w * (0.36 if cold else 0.42), bottom.y)])
	var glass := Color(0.85, 0.95, 1.0, 0.9) if cold else Color("#fff3e6")
	draw_colored_polygon(body, glass * tint)
	if cold:
		draw_colored_polygon(PackedVector2Array([Vector2(bottom.x - w * 0.46, top_y + h * 0.25), Vector2(bottom.x + w * 0.46, top_y + h * 0.25),
			Vector2(bottom.x + w * 0.36, bottom.y), Vector2(bottom.x - w * 0.36, bottom.y)]), Color("#6b3f2a") * tint)
		for k in range(3):
			box(Rect2(bottom.x - w * 0.32 + k * w * 0.22, top_y + h * 0.18 + (k % 2) * 6, w * 0.18, w * 0.18), Color(0.8, 0.95, 1.0, 0.85 * tint.a), Color.TRANSPARENT, 3)
		draw_line(Vector2(bottom.x + w * 0.2, top_y - h * 0.3), Vector2(bottom.x + w * 0.05, bottom.y - h * 0.3), Color(SKY, tint.a), 4.0, true)
		star(Vector2(bottom.x - w * 0.42, top_y), w * 0.16, Color(1, 1, 1, tint.a), COCOA, 1.5)
	else:
		ellipse(Vector2(bottom.x, top_y + 2), Vector2(w * 0.5, w * 0.14), Color("#f4e1c8") * tint)
		heart(Vector2(bottom.x, top_y + 2), w * 0.1, Color(1, 1, 1, tint.a))
		draw_arc(Vector2(bottom.x + w * 0.5, top_y + h * 0.45), w * 0.18, -1.4, 1.4, 12, Color(COCOA, tint.a), 3.0, true)
		box(Rect2(bottom.x - w * 0.25, top_y - w * 0.32, w * 0.5, w * 0.16), Color(SAKURA, tint.a), Color.TRANSPARENT, 4)
	body.append(body[0])
	draw_polyline(body, Color(COCOA, tint.a), 2.5, true)
	var face := Vector2(bottom.x, bottom.y - h * 0.42)
	for side in [-1.0, 1.0]:
		draw_circle(face + Vector2(side * w * 0.16, 0), w * 0.06, Color(COCOA, tint.a), true, -1.0, true)
		draw_circle(face + Vector2(side * w * 0.16 + w * 0.02, -w * 0.02), w * 0.02, Color(1, 1, 1, tint.a), true, -1.0, true)
		draw_circle(face + Vector2(side * w * 0.27, w * 0.08), w * 0.05, Color(SAKURA, 0.6 * tint.a), true, -1.0, true)
	draw_arc(face + Vector2(0, w * 0.06), w * 0.06, 0.2, PI - 0.2, 8, Color(COCOA, tint.a), 2.0, true)
	if acting:
		star(Vector2(bottom.x + w * 0.7, face.y - h * 0.2), w * 0.18, Color(SKY if cold else SAKURA, tint.a), COCOA, 1.5, ui_time * 6.0)

func drone_figure(rect: Rect2, tint: Color) -> void:
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y) * 0.32
	for side in [-1.0, 1.0]:
		draw_line(c, c + Vector2(side * s * 1.3, -s * 0.7), Color(COCOA, tint.a), 4.0, true)
		var spin := absf(sin(ui_time * 40.0 + side))
		ellipse(c + Vector2(side * s * 1.3, -s * 0.8), Vector2(s * 0.9 * (0.3 + 0.7 * spin), s * 0.15), Color(0.9, 0.9, 0.9, 0.7 * tint.a))
	draw_circle(c, s, COCOA * Color(1, 1, 1, tint.a), true, -1.0, true)
	draw_circle(c, s - 3, Color("#ffcf3d") * tint, true, -1.0, true)
	box(Rect2(c + Vector2(-s * 0.7, -s * 0.25), Vector2(s * 1.0, s * 0.4)), Color(COCOA, tint.a), Color.TRANSPARENT, 4)
	draw_circle(c + Vector2(-s * 0.45, -s * 0.05), s * 0.12, Color(BERRY, tint.a), true, -1.0, true)
	box(Rect2(c + Vector2(-s * 0.45, s * 0.85), Vector2(s * 0.9, s * 0.7)), Color("#c98b5a") * tint, COCOA, 3, 2)


# mini 附属炮台：和主力同格时缩小站在右下角，单独放时站在格子中间。
func draw_mini(row: int, col: int, unit: Dictionary, shared: bool) -> void:
	var card: Dictionary = Campaign.CARDS[unit.card]
	var y := lane_y(row)
	var h := row_height()
	var x := board_x(col + (0.74 if shared else 0.5))
	var w := (CELL * 0.48) if shared else CELL * 0.7
	var hgt := (h * 0.58) if shared else h * 0.78
	var born: float = battle.time - float(unit.get("born", -9.0))
	var scale := Vector2.ONE
	if born < 0.3:
		var k := ease_back(born / 0.3)
		scale = Vector2(k, k)
	var tint := Color.WHITE
	if battle.time - unit.hit < 0.12:
		tint = Color(1.0, 0.6, 0.6)
	elif battle.idle_reason(unit) != "":
		tint = Color(0.72, 0.7, 0.78)
	var bob := sin(battle.time * 4.0 + col * 1.3 + row) * 1.5
	var rect := Rect2(x - w * 0.5, y + h - hgt - 4 + bob, w, hgt)
	ellipse(Vector2(x, y + h - 8), Vector2(w * 0.32, 4), Color(PLUM, 0.5))
	sprite_at(card.key, rect, tint, scale, Vector2(x, rect.end.y))
	if battle.time - unit.cast < 0.25 and unit.card in [17, 19, 20]:
		effect(SHOT_ART[unit.card], Vector2(x + w * 0.4, y + h * 0.55), Vector2(30, 20), 1.0 - (battle.time - unit.cast) / 0.25)
	if unit.hp < card.hp:
		hp_bar(Vector2(x - 16, y + h - 6), 32, float(unit.hp) / float(card.hp), ACCENTS[unit.card])
	if unit.blind > battle.time or unit.emp > battle.time:
		star(Vector2(x, rect.position.y), 5, GOLD if unit.blind > battle.time else SKY, COCOA, 1.5, ui_time * 5.0)
	if unit.get("lock", 0) != 0:
		draw_circle(Vector2(x, rect.position.y + 6), 10, Color(COCOA, 0.85), true, -1.0, true)
		glyph("lock", Vector2(x, rect.position.y + 6), 6, BERRY)


# ---------------------------------------------------------------- 第 03 章「云端分店」

func draw_cloud() -> void:
	if art.has("cloud"):
		draw_texture_rect(art["cloud"], Rect2(Vector2(-16, -16), SIZE + Vector2(32, 32)), false)
	else:
		draw_texture_rect(art["night"], Rect2(Vector2(-16, -16), SIZE + Vector2(32, 32)), false)
		draw_rect(Rect2(-16, -16, 1312, 752), Color("#1a2a6c", 0.4))
		for k in range(14):
			var rx := -10.0 + k * 94.0
			box(Rect2(rx, 150, 70, 60), Color("#121a3a", 0.9), Color("#3a5aa8"), 6, 2)
			for j in range(4):
				var on := fposmod(ui_time * 2.0 + k * 0.37 + j * 0.61, 1.0) < 0.6
				draw_circle(Vector2(rx + 12 + j * 14, 168), 3, MINT if on else Color("#24406a"), true, -1.0, true)
	if battle.level.get("boss", false):
		draw_rect(Rect2(-16, -16, 1312, 752), Color("#2a0f3c", 0.3))
	elif battle.storm_until > battle.time:
		draw_rect(Rect2(-16, -16, 1312, 752), Color("#0e1d40", 0.3))
	else:
		draw_rect(Rect2(-16, -16, 1312, 752), Color("#0b1030", 0.08))

# 熄灯：最前排店员前方 3 格以外是黑的，那里的来客打不到（Boss 和被照亮的除外）。
func draw_fog(row: int) -> void:
	if not battle.is_dark():
		return
	var y := lane_y(row)
	var h := row_height()
	var edge: float = board_x(battle.front[row] + 3.0)
	var right := board_x(9.0) + 8.0
	if edge >= right:
		return
	for k in range(4):
		draw_rect(Rect2(edge + k * 10.0, y - 3, 10.0, h + 6), Color(0.02, 0.03, 0.1, 0.12 + k * 0.12))
	draw_rect(Rect2(edge + 40.0, y - 3, maxf(0.0, right - edge - 40.0), h + 6), Color(0.02, 0.03, 0.1, 0.6))
	draw_line(Vector2(edge, y), Vector2(edge, y + h), Color(1, 1, 0.75, 0.35), 2.0, true)

# 防火墙闸门：第 7 列前。没升起时只画两根桩。
func draw_gate(row: int) -> void:
	if not battle.has_gates or row >= battle.gates.size():
		return
	var y := lane_y(row)
	var h := row_height()
	var gx := board_x(6.62)
	var left: float = battle.gates[row] - battle.time
	if left <= 0.0:
		for py in [y + 6.0, y + h - 14.0]:
			box(Rect2(gx - 5, py, 10, 10), Color("#3a4a78"), Color("#8aa6ff"), 3, 2)
		return
	var pulse := 0.8 + 0.2 * sin(ui_time * 12.0)
	if art.has("firewall"):
		effect("firewall", Vector2(gx, y + h * 0.5), Vector2(70, h + 10), pulse)
	else:
		figure("firewall", Rect2(gx - 30, y - 4, 60, h + 8), Color(1, 1, 1, pulse))
	draw_rect(Rect2(gx - 3, y, 6, h), Color(1.0, 0.75, 0.3, 0.5 * pulse))
	var tag := Rect2(gx - 24, y - 4, 48, 20)
	box(tag, COCOA, GOLD, 10, 2)
	label("%.1f" % left, tag, 12, GOLD, MID, 2)

# 云备份恢复中的店员、天工光柱的落点：店员可以带进任何一章，所以每章都要画。
func draw_unit_overlay() -> void:
	var t: float = battle.time
	for item in battle.restores:
		var c := cell_center(item.row, item.col)
		var k := clampf(1.0 - (float(item.at) - t) / 2.0, 0.0, 1.0)
		sprite(Campaign.CARDS[item.card].key, Rect2(c.x - 50, lane_y(item.row) - 2, 100, row_height() - 8), Color(0.6, 0.85, 1.0, 0.25 + 0.35 * k))
		glyph("cloud", c + Vector2(0, -row_height() * 0.38), 12, Color(SKY, 0.9))
		draw_arc(c, 34, -PI * 0.5, -PI * 0.5 + TAU * k, 32, SKY, 4.0, true)
	for strike in battle.strikes:
		var p := lane_point(strike.row, strike.x)
		var k := clampf(1.0 - (float(strike.at) - t) / 1.0, 0.0, 1.0)
		draw_set_transform(cam + p + Vector2(0, row_height() * 0.3), 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, 70.0 - 30.0 * k, 0.0, TAU, 40, Color("#8aa6ff", 0.6 + 0.4 * k), 4.0, true)
		draw_circle(Vector2.ZERO, 70.0 * k, Color("#8aa6ff", 0.18), true, -1.0, true)
		draw_set_transform(cam)
		draw_line(p + Vector2(0, -260), p + Vector2(0, 20), Color(0.8, 0.88, 1.0, 0.25 * k), 3.0 + 8.0 * k, true)

func draw_cloud_overlay() -> void:
	var t: float = battle.time
	if battle.storm_until > t:
		for i in range(60):
			var x := fposmod(i * 97.0 - t * 90.0, 1320.0) - 20.0
			var y := fposmod(i * 53.0 + t * 520.0, 760.0) - 20.0
			draw_line(Vector2(x, y), Vector2(x - 3, y + 14), Color(0.55, 0.85, 1.0, 0.35), 2.0, true)
			if i % 7 == 0:
				label("1" if i % 2 == 0 else "0", Rect2(x - 6, y + 14, 12, 14), 11, Color(0.6, 0.9, 1.0, 0.5), MID, 2)
	if battle.is_dark():
		var vignette := 0.22 if battle.dark else 0.32
		draw_rect(Rect2(-16, -16, 1312, 752), Color(0.02, 0.02, 0.08, vignette))
	if battle.facilities_locked():
		var tag := Rect2(500, 196, 280, 40)
		box(tag, COCOA, BERRY, 20, 3)
		glyph("lock", tag.position + Vector2(28, 20), 9, BERRY)
		label("断网中 %.1f 秒" % (battle.facility_lock_until - t), Rect2(tag.position + Vector2(44, 0), Vector2(226, 40)), 17, GOLD, MID, 2)

func lock_cover(c: Vector2) -> void:
	draw_circle(c, 29, Color(PLUM, 0.72), true, -1.0, true)
	glyph("lock", c, 12, BERRY)


# ---------------------------------------------------------------- 金币图标、商店

func coin(c: Vector2, r: float) -> void:
	draw_circle(c, r, COCOA, true, -1.0, true)
	draw_circle(c, r - maxf(1.5, r * 0.14), Color("#ffcf3d"), true, -1.0, true)
	draw_circle(c, r * 0.58, Color("#f2a826"), true, -1.0, true)
	draw_arc(c, r * 0.58, -2.4, -0.6, 10, Color(1, 1, 1, 0.7), maxf(1.0, r * 0.12), true)
	box(Rect2(c + Vector2(-r * 0.12, -r * 0.34), Vector2(r * 0.24, r * 0.68)), Color("#fff1a8"), Color.TRANSPARENT, 2)

func gold_pill(rect: Rect2, small: bool = false) -> void:
	box(rect, COCOA, GOLD, int(rect.size.y * 0.5), 3 if not small else 2, 0.3)
	var r := rect.size.y * 0.36
	coin(rect.position + Vector2(rect.size.y * 0.5, rect.size.y * 0.5), r)
	label(str(gold), Rect2(rect.position + Vector2(rect.size.y * 0.95, 0), Vector2(rect.size.x - rect.size.y * 1.15, rect.size.y)), 15 if small else 22, GOLD, MID, 2)

# 中文按字换行。
func paragraph(value: String, rect: Rect2, size: int, color: Color, gap: float = 1.5) -> void:
	var face: Font = fonts[1]
	var lines := []
	var line := ""
	for ch in value:
		var probe: String = line + ch
		if line != "" and face.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x:
			lines.append(line)
			line = ch
		else:
			line = probe
	if line != "":
		lines.append(line)
	var y := rect.position.y + face.get_ascent(size)
	for text in lines:
		if y > rect.end.y:
			break
		draw_string(face, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		y += size * gap

func draw_shop() -> void:
	backdrop("cafe", 0.66)
	draw_petals()
	header("咖啡店商城", "商店", "用金币雇用 AI 娘、扩充卡槽。买下的店员任何一关都能带。", close_shop)
	var wallet := Rect2(950, 38, 276, 84)
	paper(wallet, 20)
	coin(Vector2(994, 80), 22)
	label(str(gold), Rect2(1026, 46, 186, 40), 30, COCOA, 0, 2)
	label("卡槽 %d / %d · 店员 %d / %d" % [slots, Campaign.MAX_SLOTS, owned.count(true), owned.size()], Rect2(1027, 84, 190, 26), 13, INK_SOFT, 0, 1)
	for t in range(SHOP_TABS.size()):
		var tab := Rect2(134 + t * 132, 140, 122, 34)
		var on := t == shop_tab
		box(tab, SAKURA if on else CREAM, COCOA, 17, 3)
		label(SHOP_TABS[t], tab, 15, TEXT if on else COCOA, MID, 2, 4 if on else 0, SAKURA_DEEP)
		if not on:
			buttons.append([tab, set_shop_tab.bind(t), "page"])
	var panel := Rect2(56, 186, 808, 470)
	paper(panel, 22)
	var detail := Rect2(880, 136, 344, 520)
	paper(detail, 22)
	if shop_tab == 3:
		draw_slot_shop(panel, detail)
		return
	var items := shop_items(shop_tab)
	var columns := 8
	var gap := 8.0
	var w := (panel.size.x - 36.0 - (columns - 1) * gap) / columns
	var h := 140.0
	for k in range(items.size()):
		var rect := Rect2(panel.position.x + 18 + (k % columns) * (w + gap), panel.position.y + 18 + floorf(float(k) / columns) * (h + 10), w, h)
		draw_shop_tile(items[k], rect)
	if shop_tab == 1:
		var note := Rect2(panel.position.x + 18, panel.end.y - 64, panel.size.x - 36, 46)
		box(note, Color(GOLD, 0.25), GOLD_DEEP, 14, 2)
		label("No.36 ~ 39 是商店限定 SP：GPT-4o、Gemini Ultra、Grok Heavy、Qwen-Max，只能用金币买到。", note.grow_individual(-16, 0, -16, 0), 15, COCOA, MID, 2)
	if shop_focus in items:
		draw_shop_detail(shop_focus, detail)

func draw_shop_tile(c: int, r: Rect2) -> void:
	var card: Dictionary = Campaign.CARDS[c]
	var have := owns(c)
	var on := c == shop_focus
	var hot := r.has_point(pointer)
	var rect := r
	if hot or on:
		rect.position.y -= 3
	if on:
		box(rect.grow(4), Color(ACCENTS[c], 0.5), Color.TRANSPARENT, 16)
	box(rect, CREAM if have else Color("#fff1dc"), ACCENTS[c].darkened(0.25) if on else COCOA, 13, 3 if on else 2, 0.2)
	box(Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, 16)), ACCENTS[c], Color.TRANSPARENT, 8)
	label("No.%d" % (c + 1), Rect2(rect.position + Vector2(7, 3), Vector2(50, 16)), 10, TEXT, 0, 2, 2, Color(COCOA, 0.6))
	sprite(card.key, Rect2(rect.position + Vector2(5, 20), Vector2(rect.size.x - 10, 76)))
	label(card.name, Rect2(rect.position.x + 3, rect.position.y + 96, rect.size.x - 6, 18), 12, COCOA, MID, 2)
	var tag := Rect2(rect.position.x + 6, rect.position.y + 116, rect.size.x - 12, 18)
	if have:
		box(tag, Color(MINT, 0.6), COCOA, 9, 1)
		label("已拥有", tag, 11, COCOA, MID, 2)
	else:
		box(tag, COCOA, Color.TRANSPARENT, 9)
		coin(tag.position + Vector2(11, 9), 6)
		label(str(Campaign.PRICES[c]), Rect2(tag.position + Vector2(18, 0), Vector2(tag.size.x - 20, 18)), 11, GOLD if gold >= Campaign.PRICES[c] else Color("#c9a58a"), MID, 2)
	buttons.append([r, focus_item.bind(c), "select"])

func draw_shop_detail(c: int, r: Rect2) -> void:
	var card: Dictionary = Campaign.CARDS[c]
	var accent: Color = ACCENTS[c]
	var appear := clampf((ui_time - shop_at) / 0.3, 0.0, 1.0)
	for i in range(4):
		draw_circle(r.position + Vector2(172, 150), 110.0 - i * 22.0, Color(accent, 0.06 + i * 0.03), true, -1.0, true)
	sprite(card.key, Rect2(r.position.x + 52, r.position.y + 22, 240, 220), Color(1, 1, 1, appear))
	var tag: String = card.get("tag", "")
	if tag != "":
		var pill := Rect2(r.end.x - 70, r.position.y + 18, 54, 26)
		box(pill, COCOA if tag == "SP" else Color("#5a3d8a"), Color.TRANSPARENT, 13)
		label(tag, pill, 14, GOLD if tag == "SP" else TEXT, MID, 2)
	label(card.name, Rect2(r.position.x + 20, r.position.y + 248, r.size.x - 40, 36), 26, COCOA, 0, 2)
	label(card.role, Rect2(r.position.x + 20, r.position.y + 284, r.size.x - 40, 22), 15, accent.darkened(0.3), 0, 2)
	var stats := "部署 %d 算力 · 生命 %d" % [card.cost, card.hp]
	if float(card.interval) > 0.0:
		stats += " · 间隔 %.1f 秒" % card.interval
	label(stats, Rect2(r.position.x + 20, r.position.y + 310, r.size.x - 40, 20), 13, INK_SOFT, 0, 1)
	paragraph(card.desc, Rect2(r.position.x + 20, r.position.y + 338, r.size.x - 40, 110), 14, COCOA)
	var buy := Rect2(r.position.x + 20, r.end.y - 70, r.size.x - 40, 54)
	if owns(c):
		box(buy, Color(MINT, 0.5), COCOA, 27, 2)
		label("已拥有 · 去配卡页带上她", buy, 16, COCOA, MID, 2)
	else:
		var price: int = Campaign.PRICES[c]
		candy("购买  %d 金币" % price if gold >= price else "还差 %d 金币" % (price - gold), buy, buy_card.bind(c) if gold >= price else Callable(), 0, 19)

func draw_slot_shop(panel: Rect2, detail: Rect2) -> void:
	label("卡槽决定每一局能带几位店员。开局 4 个，最多 %d 个。" % Campaign.MAX_SLOTS, Rect2(panel.position.x + 28, panel.position.y + 18, panel.size.x - 56, 30), 17, COCOA, 0, 2)
	for k in range(Campaign.MAX_SLOTS):
		var c := Vector2(panel.position.x + 92 + k * 104, panel.position.y + 150)
		var have := k < slots
		var next := k == slots
		box(Rect2(c - Vector2(42, 56), Vector2(84, 112)), CREAM if have else Color("#efe0cc"), SAKURA_DEEP if next else COCOA, 14, 3 if next else 2, 0.2)
		if have:
			glyph("check", c + Vector2(0, -6), 16, MINT_DEEP)
		else:
			glyph("lock", c + Vector2(0, -8), 13, INK_SOFT)
		label("第 %d 槽" % (k + 1), Rect2(c.x - 42, c.y + 24, 84, 24), 13, COCOA if have else INK_SOFT, MID, 2)
		if not have and k >= Campaign.START_SLOTS:
			var price := int(Campaign.SLOT_PRICES[k - Campaign.START_SLOTS])
			var tag := Rect2(c.x - 38, c.y + 64, 76, 22)
			box(tag, COCOA, Color.TRANSPARENT, 11)
			coin(tag.position + Vector2(13, 11), 7)
			label(str(price), Rect2(tag.position + Vector2(22, 0), Vector2(52, 22)), 12, GOLD, MID, 2)
	paragraph("小提示：第 02、03 章的推荐阵容都是 6 位店员。每关第一次通关、第一次拿到二星和三星都会给金币，没拿到新星的重玩也有少量金币。",
		Rect2(panel.position.x + 28, panel.position.y + 290, panel.size.x - 56, 120), 15, INK_SOFT)
	label("卡槽", Rect2(detail.position.x + 20, detail.position.y + 24, detail.size.x - 40, 36), 26, COCOA, 0, 2)
	label("现在可以带 %d 位店员" % slots, Rect2(detail.position.x + 20, detail.position.y + 64, detail.size.x - 40, 26), 16, INK_SOFT, 0, 1)
	for k in range(Campaign.MAX_SLOTS):
		var p := Vector2(detail.position.x + 44 + k * 42, detail.position.y + 140)
		box(Rect2(p - Vector2(17, 24), Vector2(34, 48)), SAKURA if k < slots else Color("#e6d2ba"), COCOA, 8, 2)
	var buy := Rect2(detail.position.x + 20, detail.end.y - 70, detail.size.x - 40, 54)
	var price := Campaign.slot_price(slots)
	if price < 0:
		box(buy, Color(MINT, 0.5), COCOA, 27, 2)
		label("卡槽已经全部解锁", buy, 16, COCOA, MID, 2)
	else:
		candy("购买第 %d 个卡槽  %d 金币" % [slots + 1, price] if gold >= price else "还差 %d 金币" % (price - gold), buy, buy_slot if gold >= price else Callable(), 0, 17)
