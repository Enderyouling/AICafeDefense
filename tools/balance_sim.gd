extends SceneTree
# 第 02、03 章数值模拟：用一个「中等水平玩家」策略自动打每一关，输出胜负、满意度、星级与用时。运行：
#   godot --headless --path . -s res://tools/balance_sim.gd                 # 两章都跑
#   CHAPTER=3 godot --headless --path . -s res://tools/balance_sim.gd       # 只跑第 03 章
#   DETAIL=1 godot --headless --path . -s res://tools/balance_sim.gd        # 额外打印漏怪记录
#   STAGE=42 LINEUP=0,1,27,22,29,34 godot ...                               # 只跑一关、试别的阵容
# 策略：每隔「反应时间」收一次算力（认得出钓鱼假算力）；按自动生成的布阵表部署（mini 挂在主力身上）；有来客上传送带时逆流；
# 来客多或 Boss 在场时给狙击位超频；遮阳伞坏了就修；封条、收购合同立刻撕掉；倒下的店员补回去；
# 第 03 章：某一路挤了 3 个以上来客时升防火墙，来客逼近的那一路最贵的店员上云备份。

const Battle = preload("res://battle.gd")
const Campaign = preload("res://campaign.gd")
const Main = preload("res://main.gd")

func lineup(cards: Array) -> Array:
	var list := []
	list.resize(Campaign.CARDS.size())
	list.fill(false)
	for c in cards:
		list[c] = true
	return list

func pick(cards: Array, options: Array) -> int:
	for c in options:
		if c in cards:
			return c
	return -1

# 按阵容生成布阵顺序：先经济和每路一个输出，再挡路、补火力、挂 mini。
func build_plan(cards: Array, boss_lane: int = -1) -> Array:
	var prod := pick(cards, [13, 1])
	var shooters := []
	for c in [0, 27, 10, 11, 25, 5, 14, 2, 4, 16]:
		if c in cards:
			shooters.append(c)
	var main: int = shooters[0] if shooters.size() > 0 else 0
	var second: int = shooters[1] if shooters.size() > 1 else main
	var sniper := pick(cards, [8, 22, 28, 0])
	var blocker := pick(cards, [29, 9, 26, 3])
	var support := pick(cards, [21, 23, 24, 28, 15, 12, 4, 30])
	var mini := pick(cards, [17, 19, 20, 18, 32, 34, 31, 33])
	if prod < 0:
		prod = main
	var raw := [[prod, 2, 0], [main, 2, 1], [sniper, 0, 1], [prod, 1, 0], [main, 3, 1], [sniper, 1, 1], [prod, 3, 0], [blocker, 2, 4],
		[prod, 4, 0], [main, 4, 1], [blocker, 3, 4], [prod, 0, 0], [mini, 0, 1], [mini, 1, 1], [second, 2, 2], [second, 3, 2],
		[blocker, 4, 4], [support, 3, 3], [mini, 2, 1], [mini, 3, 1], [sniper, 0, 2], [second, 4, 2], [sniper, 1, 2], [mini, 4, 1], [support, 2, 3]]
	if boss_lane >= 0:
		# Boss 关：Boss 走的那一路叠满火力。
		raw.insert(8, [sniper, boss_lane, 2])
		raw.insert(10, [second, boss_lane, 3])
		raw.insert(14, [mini, boss_lane, 2])
	var plan := []
	for p in raw:
		if p[0] >= 0:
			plan.append(p)
	return plan

func occupied(b, p: Array) -> bool:
	return (b.minis[p[1]][p[2]] if Campaign.is_mini(p[0]) else b.towers[p[1]][p[2]]) != null

func play(stage: int, reaction: float, cards: Array) -> Dictionary:
	var b = Battle.new(stage, lineup(cards))
	var plan := build_plan(cards, 2 if b.level.get("boss", false) else -1)
	var next := 0
	var leaks := []
	var last_kind := {}
	var think := 0.0
	while b.result == 0 and b.time < 900.0:
		b.step(0.02)
		for e in b.events:
			if e.type == "leak":
				leaks.append("%s@%d %.0fs" % [last_kind.get(e.row, "?"), e.row + 1, b.time])
			elif e.type == "lose":
				leaks.append("LOSE@%d" % (e.row + 1))
		for e in b.enemies:
			if e.x < 0.3:
				last_kind[e.row] = e.kind
		b.events.clear()
		think += 0.02
		if think < reaction:
			continue
		think = 0.0
		for i in range(b.tokens.size() - 1, -1, -1):
			if not b.tokens[i].get("fake", false):
				b.collect(i)
		for cell in b.all_towers():
			var unit: Dictionary = b.towers[cell.y][cell.x]
			if unit.audit > b.time or unit.acquire > b.time:
				for k in range(3):
					b.tear_seal(cell.y, cell.x)
		if b.chapter == 3:
			# 防火墙：哪一路在第 7~8.8 列挤了 3 个以上来客就拦住。
			for row in range(b.level.rows):
				var crowd := 0
				for e in b.enemies:
					if e.row == row and e.x >= 7.0 and e.x <= 8.8 and not e.kind in Battle.BOSSES:
						crowd += 1
				if crowd >= 3 and b.power >= Battle.GATE_COST + 40 and b.raise_gate(row):
					break
			# 云备份：来客逼近的那一路，最贵的店员。
			if b.backup_wait() <= 0.0 and b.power >= Battle.BACKUP_COST + 60:
				var best := Vector2i(-1, -1)
				var best_cost := 0
				for cell in b.all_towers():
					var unit: Dictionary = b.towers[cell.y][cell.x]
					var cost: int = Campaign.CARDS[unit.card].cost
					var hot := false
					for e in b.enemies:
						if e.row == cell.y and e.x < cell.x + 3.0:
							hot = true
					if hot and unit.backup <= b.time and cost > best_cost:
						best = cell
						best_cost = cost
				if best.x >= 0:
					b.backup_tower(best.y, best.x)
		for cell in b.props:
			if b.wreck_at(cell.y, cell.x) and b.power >= 160:
				b.repair(cell.y, cell.x)
		var on_belt := 0
		for e in b.enemies:
			if b.on_conveyor(e.row, e.x) and e.x < 5.0:
				on_belt += 1
		if on_belt >= 2 and b.power >= 30 + (100 if next < plan.size() else 0):
			b.reverse_conveyor()
		if b.boss_kind != "" or b.enemies.size() >= 6:
			for cell in b.all_towers():
				if b.towers[cell.y][cell.x].card in [8, 16, 10] and b.power >= 50 + (80 if next < plan.size() else 0):
					if b.overclock(cell.y, cell.x):
						break
		# 像真人一样先救急：有来客的路如果还没有输出，就先在那一路补一个主力。
		var main_shooter: int = plan[1][0]
		for row in range(b.level.rows):
			var threatened := false
			for e in b.enemies:
				if e.row == row and e.x < 8.8:
					threatened = true
			var covered := false
			for col in range(4):
				var t = b.towers[row][col]
				if t != null and not t.card in [1, 13, 3, 9, 15, 21, 26, 29, 30, 23, 24]:
					covered = true
			if threatened and not covered:
				for col in [1, 2, 3]:
					if b.towers[row][col] == null and not b.blocked_cell(row, col):
						b.place(main_shooter if not row in b.conveyor_rows or not 8 in cards else 8, row, col)
						break
		while next < plan.size():
			var p: Array = plan[next]
			if occupied(b, p) or b.blocked_cell(p[1], p[2]):
				next += 1
				continue
			if b.place(p[0], p[1], p[2]):
				next += 1
			else:
				break
		if next >= plan.size():
			for p in plan:
				if not occupied(b, p) and not b.blocked_cell(p[1], p[2]) and b.place(p[0], p[1], p[2]):
					break
	var stars := 0
	if b.result == 1:
		stars = 3 if b.core >= 100 and b.facility_uses > 0 else 2 if b.core >= 80 else 1
	if OS.get_environment("DETAIL") != "":
		var boss := ""
		for e in b.enemies:
			if e.kind in Battle.BOSSES:
				boss = " Boss %s hp=%d 阶段=%d x=%.1f" % [e.kind, e.hp, b.boss_phase, e.x]
		print("   ", Campaign.code(stage), " 反应 %.1fs 漏怪：" % reaction, leaks, boss, "  店员：", b.all_towers().size())
	return {"result": b.result, "core": b.core, "time": b.time, "stars": stars, "uses": b.facility_uses, "leaked": b.leaked, "wave": b.wave}

func _init() -> void:
	var only := OS.get_environment("CHAPTER")
	var stages := []
	if only != "3":
		stages += Campaign.chapter_range(2)
	if only != "2":
		stages += Campaign.chapter_range(3)
	# 调参用：STAGE=42 LINEUP=0,1,27,22,29,34 只跑这一关、换阵容。
	if OS.get_environment("STAGE") != "":
		stages = [int(OS.get_environment("STAGE"))]
	for stage in stages:
		var number := Campaign.chapter(stage)
		var cards: Array = (Main.CHAPTER_TWO_LINEUPS if number == 2 else Main.CHAPTER_THREE_LINEUPS)[stage - Campaign.CHAPTER_STARTS[number - 1]]
		if OS.get_environment("LINEUP") != "":
			cards = Array(OS.get_environment("LINEUP").split(",")).map(func(v): return int(v))
		var line := "%s %-6s" % [Campaign.code(stage), Campaign.levels[stage].title]
		for reaction in [1.0, 0.5]:
			var r := play(stage, reaction, cards)
			line += "  | 反应 %.1fs：%s 满意度 %3d 星 %d 漏 %2d 设施 %2d 用时 %3ds" % [reaction, "胜" if r.result == 1 else "败", r.core, r.stars, r.leaked, r.uses, int(r.time)]
		print(line)
	quit()
