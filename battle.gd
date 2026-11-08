extends RefCounted
# 战斗规则。main.gd 每帧调用 step()，并从 events 里取出本帧发生的事来播放音效和特效。

const Campaign = preload("res://campaign.gd")
const COLS = 9
const WAVE_SUPPLY = 50
var level: Dictionary
var stage: int
var deck: Array
var towers: Array = []
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
var phase_until := 0.0
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
		robots.append(true)
		sweep_until.append(0.0)

func valid(row: int, col: int) -> bool:
	return row >= 0 and row < level.rows and col >= 0 and col < COLS

func place(card: int, row: int, col: int) -> bool:
	if result != 0 or not Campaign.available(card, stage) or not deck[card] or not valid(row, col) or towers[row][col] != null or Vector2i(col, row) in level.blocked:
		return false
	var item: Dictionary = Campaign.CARDS[card]
	if time < ready_at[card] or power < item.cost:
		return false
	power -= item.cost
	ready_at[card] = time + item.cooldown
	towers[row][col] = {"card": card, "hp": item.hp, "ready": time + (8.0 if card == 1 else 0.25), "cast": -5.0, "hit": -5.0, "sealed": 0.0, "born": time}
	placed += 1
	emit({"type": "place", "card": card, "row": row, "col": col})
	return true

func remove(row: int, col: int) -> bool:
	if result != 0 or not valid(row, col) or towers[row][col] == null:
		return false
	emit({"type": "remove", "card": towers[row][col].card, "row": row, "col": col})
	towers[row][col] = null
	return true

func collect(index: int) -> bool:
	if result != 0 or index < 0 or index >= tokens.size():
		return false
	var token: Dictionary = tokens[index]
	impact(8, token.row, token.x)
	emit({"type": "collect", "row": token.row, "x": token.x, "kimi": token.kimi})
	tokens.remove_at(index)
	power += 25
	collected += 1
	return true

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
	var enemy := {"kind": kind, "row": row, "x": x, "hp": template.hp, "max_hp": template.hp,
		"shield": armor, "max_shield": armor, "slow": 0.0, "hit": -5.0, "attack": 0.0, "boost": 0.0,
		"hidden": kind in ["S", "I"], "skill": time + 2.4, "wait": 0.0, "uses": 0, "armor": 0.0, "born": time}
	if kind == "X":
		boss_phase = 1
		boss_hp = template.hp
		boss_max = template.hp
		phase_until = time + 2.2
		enemy.armor = time + 6.0
	enemies.append(enemy)
	emit({"type": "spawn", "kind": kind, "row": row, "x": x})

func step(dt: float) -> void:
	if result != 0:
		return
	time += dt
	if time >= next_drop:
		tokens.append({"row": drops % level.rows, "x": 1.42 + drops * 3 % 7, "born": time, "kimi": false})
		drops += 1
		next_drop += level.drop
	for i in range(tokens.size() - 1, -1, -1):
		if time - tokens[i].born >= 10.0:
			tokens.remove_at(i)
	for i in range(impacts.size() - 1, -1, -1):
		if time - impacts[i].born > 0.7:
			impacts.remove_at(i)
	while not next_spawn().is_empty() and next_spawn()[0] <= time:
		var entry := next_spawn()
		if stage >= 4 and wave > 0 and wave < entry[2]:
			power += WAVE_SUPPLY
			emit({"type": "supply", "amount": WAVE_SUPPLY})
		if entry[2] != wave:
			emit({"type": "wave", "wave": entry[2], "last": entry[2] == level.waves})
		wave = entry[2]
		spawn_enemy(entry[3], entry[1])
		spawned += 1
	resolve_warnings()
	fire()
	move_shots(dt)
	move_enemies(dt)
	if result == 0 and next_spawn().is_empty() and enemies.is_empty():
		result = 1
		emit({"type": "win"})

func fire() -> void:
	for row in range(level.rows):
		for col in range(COLS):
			var tower = towers[row][col]
			if tower == null or tower.card == 3 or time < tower.ready or (tower.card != 6 and time < tower.sealed):
				continue
			var cast := true
			match tower.card:
				1:
					tokens.append({"row": row, "x": col + 0.51, "born": time, "kimi": true})
					emit({"type": "produce", "row": row, "col": col})
				6: cast = scan(row)
				_:
					cast = false
					var first := maxi(0, row - 1) if tower.card == 4 else row
					var last := mini(level.rows - 1, row + 1) if tower.card == 4 else row
					for lane in range(first, last + 1):
						if target_in_lane(lane, col + 0.49):
							shots.append({"card": tower.card, "row": lane, "x": col + 0.63, "born": time})
							cast = true
					if cast:
						emit({"type": "fire", "card": tower.card, "row": row, "col": col})
			if cast:
				tower.cast = time
				tower.ready = time + Campaign.CARDS[tower.card].interval

func target_in_lane(row: int, at: float) -> bool:
	for enemy in enemies:
		if enemy.row == row and enemy.x >= at and not enemy.hidden:
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
		var next_x: float = shot.x + (6.3 if shot.card in [2, 7] else 7.4) * dt
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
						damage(j, 72.0, 7)
			else:
				damage(target, {0: 29.0, 2: 21.0, 4: 25.0, 5: 31.0}[shot.card], shot.card)
			shots.remove_at(i)
		elif next_x > 9.65:
			shots.remove_at(i)
		else:
			shot.x = next_x

func damage(index: int, value: float, card: int) -> void:
	var enemy := enemies[index]
	enemy.hit = time
	if card == 2:
		enemy.slow = 3.0
	var shielded := false
	var broke := false
	if enemy.shield > 0.0:
		var factor := 2.0 if card == 5 else 1.0
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
	enemy.hp = maxf(0.0, enemy.hp - value)
	emit({"type": "hit", "card": card, "row": enemy.row, "x": enemy.x, "kind": enemy.kind, "shield": shielded or armored, "broke": broke, "pierce": card == 5 and (shielded or armored)})
	if enemy.kind == "X":
		boss_hp = enemy.hp
		if enemy.hp > 0.0 and ((boss_phase == 1 and boss_hp <= boss_max * 0.7) or (boss_phase == 2 and boss_hp <= boss_max * 0.35)):
			advance_boss(enemy)
	if enemy.hp <= 0.0:
		emit({"type": "kill", "kind": enemy.kind, "row": enemy.row, "x": enemy.x, "card": card})
		enemies.remove_at(index)
		defeated += 1

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
		_: enemy.skill = INF

func move_enemies(dt: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		var row: int = enemy.row
		if enemy.kind != "X" and sweep_until[row] > time:
			enemies.remove_at(i)
			defeated += 1
			continue
		if enemy.skill <= time:
			enemy_skill(enemy)
		if enemy.wait > time:
			continue
		var template: Dictionary = Campaign.ENEMIES[enemy.kind]
		var speed: float = template.speed * (0.7 if enemy.slow > 0 else 1.0)
		if enemy.boost > time:
			speed *= 1.32
		if enemy.kind == "X" and boss_phase == 3:
			speed *= 1.42
		enemy.slow = maxf(0.0, enemy.slow - dt)
		var col := floori(enemy.x - 0.2)
		var tower = towers[row][col] if valid(row, col) else null
		if tower != null and enemy.x < col + 0.82:
			if enemy.hidden:
				enemy.hidden = false
				emit({"type": "reveal", "row": row, "x": enemy.x})
			if enemy.attack <= time:
				tower.hp -= template.bite
				tower.hit = time
				enemy.attack = time + 0.7
				if tower.card == 3:
					tower.cast = time
					impact(3, row, col + 0.8)
				emit({"type": "bite", "card": tower.card, "row": row, "col": col})
				if tower.hp <= 0.0:
					towers[row][col] = null
					emit({"type": "lost", "card": tower.card, "row": row, "col": col})
		else:
			enemy.x -= speed * dt
		if enemy.x <= -0.3:
			if enemy.kind == "X" or not robots[row]:
				result = -1
				emit({"type": "lose", "row": row})
				return
			robots[row] = false
			sweep_until[row] = time + 0.85
			emit({"type": "sweep", "row": row})
			enemies.remove_at(i)
			defeated += 1
