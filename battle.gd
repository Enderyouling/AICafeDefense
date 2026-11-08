extends RefCounted
# 战斗规则。main.gd 每帧调用 step()，并从 events 里取出本帧发生的事来播放音效和特效。
# 第 01 章：每路一台清洁机器人兜底；第 02 章：吧台满意度、场景设施、关卡事件、mini 附属炮台与 Boss。

const Campaign = preload("res://campaign.gd")
const COLS = 9
const WAVE_SUPPLY = 50
const CORE_MAX := 100
const CONVEYOR_COST := 30
const CONVEYOR_CD := 25.0
const CHARGER_COST := 50
const CHARGER_CD := 35.0
const REPAIR_COST := 40
const UMBRELLA_HP := 320.0
const INTERRUPT := 450.0
const BLAST_DAMAGE := 70.0
const RAIN_SPEED := 1.1
const EMP_TIME := 2.5
# 卡牌编号
const MISTRAL := 8
const DOUBAO := 9
const HAILUO := 10
const SPARK := 11
const ERNIE := 12
const YUANBAO := 13
const LLAMA := 14
const MIDJOURNEY := 15
const R1 := 16
const GPT_MINI := 17
const HAIKU := 18
const FLASH := 19
const TURBO := 20
const SHOT_DAMAGE := {0: 29.0, 2: 21.0, 4: 25.0, 5: 31.0, MISTRAL: 55.0, HAILUO: 16.0, SPARK: 18.0, ERNIE: 12.0, LLAMA: 15.0, GPT_MINI: 10.0, FLASH: 6.0, TURBO: 12.0}
const SHOT_SPEED := {2: 6.3, 7: 6.3, MISTRAL: 10.5, HAILUO: 6.0, SPARK: 7.0, ERNIE: 9.0, LLAMA: 6.5, GPT_MINI: 8.0, FLASH: 12.0, TURBO: 8.0}
const PIERCE_SHIELD := [5, TURBO]
const IGNORE_ARMOR := [5, MISTRAL, R1, TURBO]
const BOSSES := ["X", "V", "M"]
var level: Dictionary
var stage: int
var deck: Array
var towers: Array = []
var minis: Array = []
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var tokens: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var warnings: Array[Dictionary] = []
var robots: Array[bool] = []
var sweep_until: Array[float] = []
var ready_at: Array[float] = []
var time := 0.0
var power: int
var result := 0
var wave := 0
var spawned := 0
var collected := 0
var placed := 0
var defeated := 0
var next_drop := 6.0
var drops := 0
var boss_phase := 0
var boss_hp := 0.0
var boss_max := 0.0
var boss_kind := ""
var phase_until := 0.0
var next_id := 0
# 第 02 章
var chapter := 1
var core := CORE_MAX
var leaked := 0
var props := {}
var residues: Array[Dictionary] = []
var conveyor_rows: Array = []
var conveyor_from := 3.0
var conveyor_to := 7.0
var reverse_until := 0.0
var conveyor_ready := 0.0
var charger := false
var charger_ready := 0.0
var facility_uses := 0
var blackout_until := 0.0
var rain := false
var income_frozen_until := 0.0
# 本帧发生的事件（放置、命中、击倒、波次……），由 main.gd 读取后清空。
var events: Array[Dictionary] = []

func emit(event: Dictionary) -> void:
	events.append(event)

func _init(id: int, lineup: Array):
	stage = id
	level = Campaign.levels[id]
	deck = lineup.duplicate()
	deck.resize(Campaign.CARDS.size())
	power = level.power
	for card in range(Campaign.CARDS.size()):
		deck[card] = deck[card] == true and Campaign.available(card, stage)
		ready_at.append(0.0)
	for lane in range(level.rows):
		var row := []
		row.resize(COLS)
		towers.append(row)
		var extra := []
		extra.resize(COLS)
		minis.append(extra)
		robots.append(true)
		sweep_until.append(0.0)
	chapter = level.get("chapter", 1)
	if chapter == 2:
		for cell in level.get("umbrellas", []):
			props[cell] = {"hp": UMBRELLA_HP, "max": UMBRELLA_HP, "hit": -5.0}
		conveyor_rows = level.get("conveyor", [])
		charger = level.get("charger", false)
		rain = level.get("event", "") == "rain"

func valid(row: int, col: int) -> bool:
	return row >= 0 and row < level.rows and col >= 0 and col < COLS

func on_conveyor(row: int, x: float) -> bool:
	return row in conveyor_rows and x >= conveyor_from and x < conveyor_to

func blocked_cell(row: int, col: int) -> bool:
	return Vector2i(col, row) in level.blocked or props.has(Vector2i(col, row))

func make_unit(card: int) -> Dictionary:
	var item: Dictionary = Campaign.CARDS[card]
	var first := 8.0 if card == 1 else 10.0 if card == YUANBAO else 0.25
	return {"card": card, "hp": item.hp, "ready": time + first, "cast": -5.0, "hit": -5.0, "sealed": 0.0, "born": time,
		"dealt": 0.0, "blind": 0.0, "emp": 0.0, "audit": 0.0, "taps": 0, "boost": 0.0, "cool": 0.0, "trap": 0.0, "charge": 0.0}

# mini 附属炮台占格子的「副位」：可以和主力店员共存一格，也能单独放。
func place(card: int, row: int, col: int) -> bool:
	if result != 0 or not Campaign.available(card, stage) or not deck[card] or not valid(row, col) or blocked_cell(row, col):
		return false
	var mini := Campaign.is_mini(card)
	if (minis[row][col] if mini else towers[row][col]) != null:
		return false
	var item: Dictionary = Campaign.CARDS[card]
	if time < ready_at[card] or power < item.cost:
		return false
	power -= item.cost
	ready_at[card] = time + item.cooldown
	if mini:
		minis[row][col] = make_unit(card)
	else:
		towers[row][col] = make_unit(card)
	placed += 1
	emit({"type": "place", "card": card, "row": row, "col": col, "mini": mini})
	return true

func remove(row: int, col: int) -> bool:
	if result != 0 or not valid(row, col):
		return false
	if towers[row][col] != null:
		emit({"type": "remove", "card": towers[row][col].card, "row": row, "col": col, "mini": false})
		towers[row][col] = null
		return true
	if minis[row][col] != null:
		emit({"type": "remove", "card": minis[row][col].card, "row": row, "col": col, "mini": true})
		minis[row][col] = null
		return true
	return false

func collect(index: int) -> bool:
	if result != 0 or index < 0 or index >= tokens.size():
		return false
	var token: Dictionary = tokens[index]
	impact(8, token.row, token.x)
	var value: int = token.get("value", 25)
	emit({"type": "collect", "row": token.row, "x": token.x, "kimi": token.kimi, "value": value})
	tokens.remove_at(index)
	power += value
	collected += 1
	return true

# ---------------------------------------------------------------- 第 02 章场景设施

func conveyor_wait() -> float:
	return maxf(0.0, conveyor_ready - time)

func charger_wait() -> float:
	return maxf(0.0, charger_ready - time)

# 传送带逆流：附近来客后退 2 格，6 秒内在传送带上减速 40%。
func reverse_conveyor() -> bool:
	if result != 0 or conveyor_rows.is_empty() or time < conveyor_ready or power < CONVEYOR_COST:
		return false
	power -= CONVEYOR_COST
	conveyor_ready = time + CONVEYOR_CD
	reverse_until = time + 6.0
	facility_uses += 1
	for enemy in enemies:
		if not enemy.kind in BOSSES and enemy.row in conveyor_rows and enemy.x >= conveyor_from - 0.5 and enemy.x <= conveyor_to + 0.5:
			enemy.x = minf(9.26, enemy.x + 2.0)
	emit({"type": "reverse"})
	return true

# 超频充电桩：8 秒攻速 +50%，之后过热 1.5 秒。
func overclock(row: int, col: int) -> bool:
	if result != 0 or not charger or time < charger_ready or power < CHARGER_COST or not valid(row, col) or towers[row][col] == null:
		return false
	var tower: Dictionary = towers[row][col]
	power -= CHARGER_COST
	charger_ready = time + CHARGER_CD
	tower.boost = time + 8.0
	tower.cool = time + 9.5
	tower.ready = minf(tower.ready, time + 0.1)
	facility_uses += 1
	emit({"type": "overclock", "row": row, "col": col})
	return true

func repair(row: int, col: int) -> bool:
	var cell := Vector2i(col, row)
	if result != 0 or not props.has(cell) or props[cell].get("wall", false) or props[cell].hp > 0.0 or power < REPAIR_COST:
		return false
	power -= REPAIR_COST
	props[cell].hp = props[cell].max
	facility_uses += 1
	emit({"type": "repair", "row": row, "col": col})
	return true

func wreck_at(row: int, col: int) -> bool:
	var cell := Vector2i(col, row)
	return props.has(cell) and not props[cell].get("wall", false) and props[cell].hp <= 0.0

# 撕维克多的停业封条：点 3 下。
func tear_seal(row: int, col: int) -> bool:
	if not valid(row, col) or towers[row][col] == null or towers[row][col].audit <= time:
		return false
	var tower: Dictionary = towers[row][col]
	tower.taps += 1
	if tower.taps >= 3:
		tower.audit = time
		emit({"type": "tear", "row": row, "col": col})
	else:
		emit({"type": "tap", "row": row, "col": col, "taps": tower.taps})
	return true

# ---------------------------------------------------------------- 主循环

func impact(kind: int, row: int, x: float) -> void:
	impacts.append({"kind": kind, "row": row, "x": x, "born": time})

func next_spawn() -> Array:
	return level.spawns[spawned] if spawned < level.spawns.size() else []

func spawn_enemy(kind: String, row: int, x: float = 9.26) -> void:
	if sweep_until[row] > time and kind != "X":
		defeated += 1
		return
	var template: Dictionary = Campaign.ENEMIES[kind]
	var armor: float = template.get("shield", 0.0)
	next_id += 1
	var enemy := {"kind": kind, "row": row, "x": x, "hp": template.hp, "max_hp": template.hp,
		"shield": armor, "max_shield": armor, "slow": 0.0, "hit": -5.0, "attack": 0.0, "boost": 0.0,
		"hidden": kind in ["S", "I"], "skill": time + 2.4, "wait": 0.0, "uses": 0, "armor": 0.0, "born": time,
		"fly": template.get("fly", false), "freeze": 0.0, "chill": 0, "weak": 0.0, "invuln": 0.0,
		"aim": 0.0, "charge": 0.0, "charge_dmg": 0.0, "summon": 0.0, "id": next_id, "mark": 0.0, "burn": 0.0, "burn_tick": 0.0, "stolen": 0}
	if kind in BOSSES:
		boss_phase = 1
		boss_kind = kind
		boss_hp = template.hp
		boss_max = template.hp
		phase_until = time + 2.2
		if kind == "X":
			enemy.armor = time + 6.0
		elif kind == "V":
			enemy.skill = time + 4.0
			enemy.summon = time + 6.0
		else:
			enemy.skill = time + 5.0
	enemies.append(enemy)
	emit({"type": "spawn", "kind": kind, "row": row, "x": x})

func step(dt: float) -> void:
	if result != 0:
		return
	time += dt
	if time >= next_drop:
		if income_frozen_until <= time:
			tokens.append({"row": drops % level.rows, "x": 1.42 + drops * 3 % 7, "born": time, "kimi": false})
		drops += 1
		next_drop += level.drop
	for i in range(tokens.size() - 1, -1, -1):
		if time - tokens[i].born >= 10.0:
			tokens.remove_at(i)
	for i in range(impacts.size() - 1, -1, -1):
		if time - impacts[i].born > 0.7:
			impacts.remove_at(i)
	if chapter == 2:
		for i in range(residues.size() - 1, -1, -1):
			if residues[i].until <= time:
				residues.remove_at(i)
		for cell in props.keys():
			if props[cell].get("wall", false) and (props[cell].until <= time or props[cell].hp <= 0.0):
				props.erase(cell)
				emit({"type": "wall_gone", "row": cell.y, "col": cell.x})
	while not next_spawn().is_empty() and next_spawn()[0] <= time:
		var entry := next_spawn()
		if stage >= 4 and wave > 0 and wave < entry[2]:
			power += WAVE_SUPPLY
			emit({"type": "supply", "amount": WAVE_SUPPLY})
		if entry[2] != wave:
			emit({"type": "wave", "wave": entry[2], "last": entry[2] == level.waves})
			if level.get("event", "") == "blackout" and entry[2] == level.get("event_wave", 3):
				blackout_until = time + 5.0
				emit({"type": "blackout"})
		wave = entry[2]
		spawn_enemy(entry[3], entry[1])
		spawned += 1
	resolve_warnings()
	if chapter == 2:
		aura(dt)
	fire()
	move_shots(dt)
	if chapter == 2:
		burn_tick(dt)
	move_enemies(dt)
	if result == 0 and next_spawn().is_empty() and enemies.is_empty():
		result = 1
		emit({"type": "win"})

func near_doubao(row: int, col: int) -> bool:
	for r in range(row - 1, row + 2):
		for c in range(col - 1, col + 2):
			if (r != row or c != col) and valid(r, c) and towers[r][c] != null and towers[r][c].card == DOUBAO:
				return true
	return false

# 豆包的光环：周围店员（包括 mini）每秒回复 6 点生命。
func aura(dt: float) -> void:
	for row in range(level.rows):
		for col in range(COLS):
			if not near_doubao(row, col):
				continue
			for unit in [towers[row][col], minis[row][col]]:
				if unit != null and unit.card != DOUBAO:
					unit.hp = minf(float(Campaign.CARDS[unit.card].hp), unit.hp + 6.0 * dt)

# 店员这一刻能不能行动（停电、致盲、瘫痪、封条、过热都会让她停手）。
func idle_reason(tower: Dictionary) -> String:
	if blackout_until > time:
		return "blackout"
	if tower.emp > time:
		return "emp"
	if tower.audit > time:
		return "audit"
	if tower.blind > time:
		return "blind"
	if time >= tower.boost and time < tower.cool:
		return "overheat"
	return ""

func interval(tower: Dictionary, row: int, col: int) -> float:
	var base: float = Campaign.CARDS[tower.card].interval
	if tower.boost > time:
		base /= 1.5
	if tower.trap > time:
		base *= 2.5
	if chapter == 2:
		if near_doubao(row, col):
			base *= 0.9
		var helper = minis[row][col]
		if helper != null and helper != tower and helper.card == FLASH:
			base *= 0.8
	return base

func fire() -> void:
	for row in range(level.rows):
		for col in range(COLS):
			act(towers[row][col], row, col, false)
			if chapter == 2:
				act(minis[row][col], row, col, true)

func act(tower, row: int, col: int, mini: bool) -> void:
	if tower == null or tower.card in [3, HAIKU] or time < tower.ready or (tower.card != 6 and time < tower.sealed):
		return
	if chapter == 2 and idle_reason(tower) != "":
		return
	var cast := true
	match tower.card:
		1, YUANBAO:
			if income_frozen_until > time:
				return
			var gold: bool = tower.card == YUANBAO
			var token := {"row": row, "x": col + 0.51, "born": time, "kimi": true}
			if gold:
				token["value"] = 40
				token["gold"] = true
			tokens.append(token)
			emit({"type": "produce", "row": row, "col": col, "gold": gold})
		6: cast = scan(row)
		DOUBAO: cast = sweep_attack(row, col)
		ERNIE: cast = brush_mark(row, col)
		MIDJOURNEY: cast = paint_wall(row, col)
		R1: cast = deep_think(tower, row, col)
		_:
			cast = false
			var first := maxi(0, row - 1) if tower.card == 4 else row
			var last := mini(level.rows - 1, row + 1) if tower.card == 4 else row
			var reach := 3.0 if tower.card == FLASH else 99.0
			for lane in range(first, last + 1):
				if target_in_lane(lane, col + 0.49, col + reach):
					shots.append({"card": tower.card, "row": lane, "x": col + 0.63, "born": time, "src": Vector2i(col, row), "mini": mini,
						"pierce": tower.card == HAILUO, "hits": []})
					cast = true
			if cast:
				emit({"type": "fire", "card": tower.card, "row": row, "col": col, "mini": mini})
	if cast:
		tower.cast = time
		tower.ready = time + interval(tower, row, col)

# 豆包横扫前方 1.4 格内、本路和相邻两路的来客。
func sweep_attack(row: int, col: int) -> bool:
	var hit := false
	for j in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[j]
		if absi(enemy.row - row) <= 1 and enemy.x >= col + 0.3 and enemy.x <= col + 1.75 and not enemy.hidden:
			enemy.weak = time + 2.0
			damage(j, 20.0, DOUBAO, Vector2i(col, row))
			hit = true
	if hit:
		emit({"type": "fire", "card": DOUBAO, "row": row, "col": col, "mini": false})
	return hit

# 文心一言：标记本路最前面的来客，5 秒内受到的伤害 +25%。
func brush_mark(row: int, col: int) -> bool:
	var target := -1
	for j in range(enemies.size()):
		var enemy := enemies[j]
		if enemy.row == row and enemy.x >= col + 0.49 and not enemy.hidden and (target == -1 or enemy.x < enemies[target].x):
			target = j
	if target == -1:
		return false
	shots.append({"card": ERNIE, "row": row, "x": col + 0.63, "born": time, "src": Vector2i(col, row), "mini": false, "pierce": false, "hits": [], "target": enemies[target].id})
	emit({"type": "fire", "card": ERNIE, "row": row, "col": col, "mini": false})
	return true

# Midjourney：在前方 2~4 格的空地画一道颜料墙。
func paint_wall(row: int, col: int) -> bool:
	if not target_in_lane(row, col + 0.5, col + 6.0):
		return false
	for c in range(col + 2, mini(COLS, col + 5)):
		var cell := Vector2i(c, row)
		if towers[row][c] == null and minis[row][c] == null and not props.has(cell) and not cell in level.blocked:
			props[cell] = {"hp": 220.0, "max": 220.0, "hit": -5.0, "wall": true, "until": time + 9.0}
			emit({"type": "paint", "row": row, "col": c, "from": col})
			return true
	return false

# DeepSeek-R1：发现目标后深度思考 2 秒，再发射贯穿整路的光束。
func deep_think(tower: Dictionary, row: int, col: int) -> bool:
	if tower.charge == 0.0:
		if not target_in_lane(row, col + 0.49):
			return false
		tower.charge = time + 2.0
		tower.ready = tower.charge
		emit({"type": "think", "row": row, "col": col})
		return false
	tower.charge = 0.0
	for j in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[j]
		if enemy.row == row and enemy.x >= col + 0.4 and not enemy.hidden:
			damage(j, 90.0, R1, Vector2i(col, row))
	emit({"type": "beam", "row": row, "col": col})
	return true

func target_in_lane(row: int, at: float, until: float = 99.0) -> bool:
	for enemy in enemies:
		if enemy.row == row and enemy.x >= at and enemy.x <= until and not enemy.hidden:
			return true
	return false

func scan(row: int) -> bool:
	var cast := false
	for enemy in enemies:
		if enemy.row == row and enemy.hidden:
			enemy.hidden = false
			cast = true
			emit({"type": "reveal", "row": row, "x": enemy.x})
	for tower in towers[row]:
		if tower != null and tower.sealed > time:
			tower.sealed = time
			cast = true
	if cast:
		impact(6, row, 4.5)
		emit({"type": "scan", "row": row})
	return cast

func move_shots(dt: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot := shots[i]
		var next_x: float = shot.x + SHOT_SPEED.get(shot.card, 7.4) * dt
		var src: Vector2i = shot.get("src", Vector2i(-1, -1))
		if shot.get("pierce", false):
			for j in range(enemies.size() - 1, -1, -1):
				var enemy := enemies[j]
				if not enemy.hidden and enemy.row == shot.row and enemy.x >= shot.x - 0.18 and enemy.x <= next_x + 0.23 and not enemy.id in shot.hits:
					shot.hits.append(enemy.id)
					impact(100 + shot.card, shot.row, enemy.x)
					damage(j, SHOT_DAMAGE[shot.card], shot.card, src, shot.mini)
			if next_x > 9.65:
				shots.remove_at(i)
			else:
				shot.x = next_x
			continue
		var target := -1
		for j in range(enemies.size()):
			var enemy := enemies[j]
			if not enemy.hidden and enemy.row == shot.row and enemy.x >= shot.x - 0.18 and enemy.x <= next_x + 0.23:
				if target == -1 or enemy.x < enemies[target].x:
					target = j
		if target != -1:
			var hit: Dictionary = enemies[target]
			var x: float = hit.x
			impact(shot.card, shot.row, x)
			if shot.card == 7:
				emit({"type": "boom", "row": shot.row, "x": x})
				for j in range(enemies.size() - 1, -1, -1):
					if enemies[j].row == shot.row and absf(enemies[j].x - x) <= 1.05:
						damage(j, 72.0, 7, src)
			else:
				if shot.card == ERNIE:
					hit.mark = time + 5.0
					emit({"type": "mark", "row": hit.row, "x": x})
				elif shot.card == SPARK and not hit.kind in ["V"]:
					hit.burn = time + 4.0
				elif shot.card == LLAMA:
					knockback(hit)
				damage(target, SHOT_DAMAGE[shot.card], shot.card, src, shot.mini)
			shots.remove_at(i)
		elif next_x > 9.65:
			shots.remove_at(i)
		else:
			shot.x = next_x

func knockback(enemy: Dictionary) -> void:
	if enemy.kind in BOSSES:
		return
	var push := 0.28 if enemy.kind == "W" else 0.55
	enemy.x = minf(9.26, enemy.x + push)
	emit({"type": "knock", "row": enemy.row, "x": enemy.x})

# 星火燃烧：每 0.5 秒结算一次，每秒 6 点伤害。
func burn_tick(dt: float) -> void:
	for j in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[j]
		if enemy.burn <= time:
			continue
		enemy.burn_tick += dt
		if enemy.burn_tick >= 0.5:
			enemy.burn_tick -= 0.5
			damage(j, 3.0, -SPARK, Vector2i(-1, -1), false, true)

func unit_at(src: Vector2i, mini: bool):
	if not valid(src.y, src.x):
		return null
	return minis[src.y][src.x] if mini else towers[src.y][src.x]

func damage(index: int, value: float, card: int, src: Vector2i = Vector2i(-1, -1), from_mini: bool = false, quiet: bool = false) -> void:
	var enemy := enemies[index]
	if enemy.invuln > time:
		emit({"type": "hit", "card": card, "row": enemy.row, "x": enemy.x, "kind": enemy.kind, "shield": true, "broke": false, "pierce": false})
		return
	if not quiet:
		enemy.hit = time
	if card == 2:
		enemy.slow = 3.0
	var froze := false
	if card == MISTRAL:
		enemy.slow = maxf(enemy.slow, 2.5)
		enemy.chill += 1
		if enemy.chill >= 3:
			enemy.chill = 0
			value += minf(60.0, enemy.max_hp * 0.08)
			if not (enemy.kind == "V" and boss_phase == 3) and enemy.kind != "M":
				enemy.freeze = time + (2.2 if rain else 1.2)
				froze = true
	if enemy.mark > time:
		value *= 1.25
	var shielded := false
	var broke := false
	if enemy.shield > 0.0:
		var factor := 2.0 if card in PIERCE_SHIELD else 1.3 if card == MISTRAL else 1.0
		var used := minf(enemy.shield, value * factor)
		enemy.shield -= used
		value -= used / factor
		shielded = true
		broke = enemy.shield <= 0.0
	var armored: bool = enemy.kind == "X" and enemy.armor > time
	if enemy.kind == "X" and enemy.armor > time:
		value *= 0.4
		if card == 5:
			enemy.armor = maxf(time, enemy.armor - 0.9)
	var plating: float = Campaign.ENEMIES[enemy.kind].get("armor", 0.0)
	if plating > 0.0 and card not in IGNORE_ARMOR:
		value *= 1.0 - plating
		armored = true
	if enemy.kind == "V":
		value = victor_cap(enemy, value)
		if enemy.charge > time:
			enemy.charge_dmg += value
	enemy.hp = maxf(0.0, enemy.hp - value)
	var source = unit_at(src, from_mini)
	if source != null:
		source.dealt += value
	if not quiet:
		emit({"type": "hit", "card": card, "row": enemy.row, "x": enemy.x, "kind": enemy.kind, "shield": shielded or armored, "broke": broke, "pierce": card in [5, MISTRAL, TURBO] and (shielded or armored)})
	if froze:
		emit({"type": "freeze", "row": enemy.row, "x": enemy.x})
	if enemy.kind in BOSSES:
		boss_hp = enemy.hp
	if enemy.kind == "X":
		if enemy.hp > 0.0 and ((boss_phase == 1 and boss_hp <= boss_max * 0.7) or (boss_phase == 2 and boss_hp <= boss_max * 0.35)):
			advance_boss(enemy)
	elif enemy.kind == "V":
		if enemy.hp > 0.0 and ((boss_phase == 1 and boss_hp <= boss_max * 0.66) or (boss_phase == 2 and boss_hp <= boss_max * 0.33)):
			advance_victor(enemy)
		elif enemy.charge > time and enemy.charge_dmg >= INTERRUPT:
			enemy.charge = 0.0
			enemy.wait = time + 1.5
			enemy.skill = time + 9.0
			emit({"type": "interrupt", "row": enemy.row, "x": enemy.x})
	if enemy.hp <= 0.0:
		finish_enemy(index, card, src, from_mini)

func finish_enemy(index: int, card: int, src: Vector2i, from_mini: bool) -> void:
	var enemy := enemies[index]
	emit({"type": "kill", "kind": enemy.kind, "row": enemy.row, "x": enemy.x, "card": card})
	if enemy.kind == "H":
		var killer = unit_at(src, from_mini)
		if killer != null:
			killer.emp = time + EMP_TIME
			emit({"type": "emp", "row": src.y, "col": src.x, "from_row": enemy.row, "x": enemy.x, "mini": from_mini})
	if enemy.stolen > 0:
		tokens.append({"row": enemy.row, "x": clampf(enemy.x, 0.5, 8.5), "born": time, "kimi": true, "value": enemy.stolen, "gold": true})
		emit({"type": "refund", "row": enemy.row, "x": enemy.x, "value": enemy.stolen})
	if chapter == 2 and not enemy.fly and not enemy.kind in BOSSES:
		residues.append({"row": enemy.row, "x": enemy.x, "until": time + 8.0})
	if enemy.burn > time:
		for other in enemies:
			if other != enemy and other.row == enemy.row and absf(other.x - enemy.x) <= 1.0 and other.kind != "V":
				other.burn = maxf(other.burn, time + 3.0)
				emit({"type": "ignite", "row": other.row, "x": other.x})
	enemies.remove_at(index)
	defeated += 1

# 维克多的血量不会越过阶段线：一发高伤害也只能把他打到下一阶段的门槛。
func victor_cap(enemy: Dictionary, value: float) -> float:
	var floor_hp := 0.0
	if boss_phase == 1:
		floor_hp = boss_max * 0.66
	elif boss_phase == 2:
		floor_hp = boss_max * 0.33
	return minf(value, maxf(0.0, enemy.hp - floor_hp)) if floor_hp > 0.0 else value

func advance_boss(enemy: Dictionary) -> void:
	boss_phase += 1
	phase_until = time + 2.0
	emit({"type": "phase", "phase": boss_phase, "row": enemy.row, "x": enemy.x})
	enemy.wait = phase_until
	enemy.skill = phase_until + 2.4
	enemy.armor = 0.0
	for i in range(warnings.size() - 1, -1, -1):
		if warnings[i].boss:
			warnings.remove_at(i)

func advance_victor(enemy: Dictionary) -> void:
	boss_phase += 1
	phase_until = time + 2.0
	enemy.wait = phase_until
	enemy.invuln = phase_until
	enemy.skill = phase_until + 2.0
	enemy.charge = 0.0
	if boss_phase == 3:
		enemy.freeze = 0.0
	emit({"type": "phase", "phase": boss_phase, "row": enemy.row, "x": enemy.x})

func resolve_warnings() -> void:
	for i in range(warnings.size() - 1, -1, -1):
		var alert := warnings[i]
		if alert.at > time:
			continue
		for col in range(COLS):
			var tower = towers[alert.row][col]
			if tower != null and (alert.col == -1 or tower == alert.tower):
				tower.sealed = maxf(tower.sealed, time + 4.0)
				emit({"type": "seal", "row": alert.row, "col": col})
		impact(9, alert.row, 4.5 if alert.col == -1 else alert.col + 0.5)
		warnings.remove_at(i)

func all_towers() -> Array:
	var list := []
	for row in range(level.rows):
		for col in range(COLS):
			if towers[row][col] != null:
				list.append(Vector2i(col, row))
	return list

func enemy_skill(enemy: Dictionary) -> void:
	var row: int = enemy.row
	match enemy.kind:
		"A":
			enemy.skill = time + 4.6
			for friend in enemies:
				if friend.kind in ["C", "R", "B", "S"] and friend.row == row and absf(friend.x - enemy.x) < 2.35:
					friend.boost = time + 2.7
			impact(10, row, enemy.x)
			emit({"type": "skill", "kind": "A", "row": row, "x": enemy.x})
		"T":
			enemy.skill = time + 7.8
			if enemy.uses < 2:
				enemy.wait = time + 0.9
				enemy.uses += 1
				spawn_enemy("C", row, minf(9.26, enemy.x + 0.45))
				impact(10, row, enemy.x)
				emit({"type": "skill", "kind": "T", "row": row, "x": enemy.x})
		"D":
			enemy.skill = time + 7.8
			for col in range(COLS - 1, -1, -1):
				var tower = towers[row][col]
				if tower != null and col + 0.4 < enemy.x:
					warnings.append({"row": row, "col": col, "tower": tower, "boss": false, "at": time + 1.55})
					emit({"type": "warning", "row": row, "col": col})
					enemy.wait = time + 1.55
					break
		"X":
			enemy.skill = time + 8.6
			if boss_phase == 1:
				enemy.armor = time + 4.7
				emit({"type": "skill", "kind": "X", "row": row, "x": enemy.x})
				spawn_enemy("B", 1 if enemy.uses % 2 == 0 else 3)
			elif boss_phase == 2:
				for offset in range(level.rows):
					var lane: int = (enemy.uses + offset) % level.rows
					if towers[lane].any(func(t): return t != null):
						warnings.append({"row": lane, "col": -1, "tower": null, "boss": true, "at": time + 2.0})
						emit({"type": "warning", "row": lane, "col": -1})
						break
			else:
				enemy.wait = time + 0.7
				spawn_enemy("S", 0 if enemy.uses % 2 == 0 else 4)
				spawn_enemy("S", 3 if enemy.uses % 2 == 0 else 1)
			enemy.uses += 1
		"P":
			# 探店博主：先举相机蓄力 0.7 秒，再闪光。
			if enemy.aim == 0.0:
				enemy.aim = time + 0.7
				enemy.wait = enemy.aim
				enemy.skill = enemy.aim
				emit({"type": "aim", "row": row, "x": enemy.x})
			else:
				enemy.aim = 0.0
				enemy.skill = time + 7.0
				camera_flash(enemy)
		"M":
			# 无人机母舰：每 8 秒在上两路空投两架无人机。
			enemy.skill = time + 10.0
			spawn_enemy("Y", 0, minf(9.26, enemy.x + 0.3))
			spawn_enemy("Y", 1, minf(9.26, enemy.x + 0.3))
			emit({"type": "summon", "row": row, "x": enemy.x})
		"V":
			victor_skill(enemy)
		_: enemy.skill = INF

# 闪光让前方 3 格内的同路店员致盲 2.5 秒；豆包或颜料墙会挡在前面吸收闪光。
func camera_flash(enemy: Dictionary) -> void:
	var row: int = enemy.row
	var hit := []
	for col in range(mini(COLS - 1, floori(enemy.x - 0.2)), maxi(-1, floori(enemy.x - 3.2)), -1):
		if props.has(Vector2i(col, row)) and props[Vector2i(col, row)].get("wall", false):
			break
		var tower = towers[row][col]
		var helper = minis[row][col]
		if helper != null:
			helper.blind = time + 2.5
		if tower == null:
			if helper != null:
				hit.append(col)
			continue
		tower.blind = time + 2.5
		hit.append(col)
		if tower.card == DOUBAO:
			break
	emit({"type": "flash", "row": row, "x": enemy.x, "cols": hit})

func victor_skill(enemy: Dictionary) -> void:
	var row: int = enemy.row
	match boss_phase:
		1:
			enemy.skill = time + 7.0
			if enemy.uses % 2 == 0:
				var best = null
				var best_cell := Vector2i(-1, -1)
				for cell in all_towers():
					var tower: Dictionary = towers[cell.y][cell.x]
					if tower.audit <= time and (best == null or tower.dealt > best.dealt):
						best = tower
						best_cell = cell
				if best != null:
					best.audit = time + 5.0
					best.taps = 0
					emit({"type": "audit", "row": best_cell.y, "col": best_cell.x, "from_row": row, "x": enemy.x})
			enemy.uses += 1
		2:
			enemy.skill = time + 7.0
			if enemy.uses % 2 == 0:
				income_frozen_until = time + 8.0
				emit({"type": "income_freeze", "row": row, "x": enemy.x})
			else:
				var cells := all_towers()
				if not cells.is_empty():
					var cell: Vector2i = cells[(enemy.uses * 7 + int(time)) % cells.size()]
					towers[cell.y][cell.x].trap = time + 10.0
					emit({"type": "trap", "row": cell.y, "col": cell.x})
			enemy.uses += 1
		3:
			enemy.charge = time + 4.0
			enemy.charge_dmg = 0.0
			enemy.wait = enemy.charge
			enemy.skill = time + 15.0
			emit({"type": "charge", "row": row, "x": enemy.x})

# 终极差评蓄力结束：没被打断就伤害所有店员（含 mini）并扣满意度。
func victor_blast(enemy: Dictionary) -> void:
	enemy.charge = 0.0
	for row in range(level.rows):
		for col in range(COLS):
			for layer in [towers, minis]:
				var unit = layer[row][col]
				if unit == null:
					continue
				unit.hp -= BLAST_DAMAGE
				unit.hit = time
				if unit.hp <= 0.0:
					layer[row][col] = null
					emit({"type": "lost", "card": unit.card, "row": row, "col": col, "mini": layer == minis})
	emit({"type": "blast", "row": enemy.row, "x": enemy.x})
	hurt_core(15, enemy.row)

func hurt_core(amount: int, row: int) -> void:
	core = maxi(0, core - amount)
	emit({"type": "leak", "row": row, "amount": amount, "core": core})
	if core <= 0 and result == 0:
		result = -1
		emit({"type": "lose", "row": row})

func enemy_speed(enemy: Dictionary) -> float:
	var template: Dictionary = Campaign.ENEMIES[enemy.kind]
	var base: float = template.speed
	var slowed := 0.4 if rain else 0.7
	if enemy.kind == "V" and boss_phase == 3:
		slowed = 1.0 - (1.0 - slowed) / 3.0
	var speed := base * (slowed if enemy.slow > 0 else 1.0)
	if enemy.boost > time:
		speed *= 1.32
	if enemy.kind == "X" and boss_phase == 3:
		speed *= 1.42
	if enemy.kind == "V":
		speed *= 1.2 if boss_phase == 2 else 1.3 if boss_phase == 3 else 1.0
	if chapter == 2:
		if rain:
			speed *= RAIN_SPEED
		if not enemy.kind in BOSSES and on_conveyor(enemy.row, enemy.x):
			speed *= 0.6 if reverse_until > time else 1.2
		speed = maxf(speed, base * 0.2)
	return speed

func bite(enemy: Dictionary, unit: Dictionary, row: int, col: int, mini: bool, template: Dictionary) -> void:
	var amount: float = template.bite * (0.8 if enemy.weak > time else 1.0)
	var helper = minis[row][col]
	if not mini and helper != null and helper.card == HAIKU:
		amount *= 0.7
	unit.hp -= amount
	unit.hit = time
	enemy.attack = time + 0.7
	if unit.card == 3:
		unit.cast = time
		impact(3, row, col + 0.8)
	emit({"type": "bite", "card": unit.card, "row": row, "col": col, "mini": mini})
	if unit.hp <= 0.0:
		if mini:
			minis[row][col] = null
		else:
			towers[row][col] = null
		emit({"type": "lost", "card": unit.card, "row": row, "col": col, "mini": mini})

func move_enemies(dt: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		var row: int = enemy.row
		if enemy.kind != "X" and sweep_until[row] > time:
			enemies.remove_at(i)
			defeated += 1
			continue
		if enemy.kind == "V":
			if enemy.charge > 0.0 and enemy.charge <= time:
				victor_blast(enemy)
				if result != 0:
					return
			if boss_phase == 1 and enemy.summon <= time and enemy.wait <= time:
				enemy.summon = time + 15.0
				spawn_enemy("Y", 0)
				spawn_enemy("Y", 1)
				emit({"type": "summon", "row": row, "x": enemy.x})
		if enemy.freeze > time:
			continue
		if enemy.skill <= time:
			enemy_skill(enemy)
		if enemy.wait > time:
			continue
		var template: Dictionary = Campaign.ENEMIES[enemy.kind]
		var speed := enemy_speed(enemy)
		enemy.slow = maxf(0.0, enemy.slow - dt)
		if enemy.kind == "W":
			absorb_residue(enemy)
		elif enemy.kind == "K":
			steal_tokens(enemy)
		var col := floori(enemy.x - 0.2)
		var tower = towers[row][col] if valid(row, col) and not enemy.fly else null
		var helper = null
		if tower == null and chapter == 2 and valid(row, col) and not enemy.fly:
			helper = minis[row][col]
		var umbrella = null
		if tower == null and helper == null and not enemy.fly and props.has(Vector2i(col, row)) and props[Vector2i(col, row)].hp > 0.0:
			umbrella = props[Vector2i(col, row)]
		if (tower != null or helper != null) and enemy.x < col + 0.82:
			if enemy.hidden:
				enemy.hidden = false
				emit({"type": "reveal", "row": row, "x": enemy.x})
			if enemy.attack <= time:
				if tower != null:
					bite(enemy, tower, row, col, false, template)
				else:
					bite(enemy, helper, row, col, true, template)
		elif umbrella != null and enemy.x < col + 0.82:
			if enemy.attack <= time:
				umbrella.hp = maxf(0.0, umbrella.hp - template.bite * (0.8 if enemy.weak > time else 1.0))
				umbrella.hit = time
				enemy.attack = time + 0.7
				emit({"type": "bite", "card": -1, "row": row, "col": col, "mini": false})
				if umbrella.hp <= 0.0:
					emit({"type": "wall_break" if umbrella.get("wall", false) else "umbrella_break", "row": row, "col": col})
		else:
			enemy.x -= speed * dt
		if enemy.x <= -0.3:
			if chapter == 2:
				if enemy.kind in BOSSES:
					result = -1
					emit({"type": "lose", "row": row})
					return
				enemies.remove_at(i)
				leaked += 1
				hurt_core(int(template.get("core", 5)), row)
				if result != 0:
					return
				continue
			if enemy.kind == "X" or not robots[row]:
				result = -1
				emit({"type": "lose", "row": row})
				return
			robots[row] = false
			sweep_until[row] = time + 0.85
			emit({"type": "sweep", "row": row})
			enemies.remove_at(i)
			defeated += 1

# 清洁机甲客经过咖啡残渣时把它吸掉回血。
func absorb_residue(enemy: Dictionary) -> void:
	for i in range(residues.size() - 1, -1, -1):
		var residue := residues[i]
		if residue.row == enemy.row and absf(residue.x - enemy.x) < 0.45:
			enemy.hp = minf(enemy.max_hp, enemy.hp + 60.0)
			residues.remove_at(i)
			emit({"type": "absorb", "row": enemy.row, "x": enemy.x})

# 黄牛把路过的算力揣进口袋，被打倒时会掉出来。
func steal_tokens(enemy: Dictionary) -> void:
	for i in range(tokens.size() - 1, -1, -1):
		var token := tokens[i]
		if token.row == enemy.row and absf(token.x - enemy.x) < 0.35:
			enemy.stolen += int(token.get("value", 25))
			tokens.remove_at(i)
			emit({"type": "steal", "row": enemy.row, "x": enemy.x, "total": enemy.stolen})
