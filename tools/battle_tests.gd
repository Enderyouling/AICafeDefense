extends SceneTree
# 战斗规则自动化测试。运行：
#   godot --headless --path . -s res://tools/battle_tests.gd
# 覆盖开发文档里的 TC-01 ~ TC-04、第 02 章与第 03 章各项机制，以及第 01 章与改动前版本的逐帧对比。

const Battle = preload("res://battle.gd")
const Campaign = preload("res://campaign.gd")
const ORIGINAL := "res://_旧版备份/完整版原始脚本/battle.gd"
var failures := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if ok else "    " + detail))
	if not ok:
		failures += 1

func lineup(cards: Array) -> Array:
	var list := []
	list.resize(Campaign.CARDS.size())
	list.fill(false)
	for c in cards:
		list[c] = true
	return list

# 一场没有预定出怪的空战斗，方便手动摆放来客。
func blank(stage: int, cards: Array = []):
	var b = Battle.new(stage, lineup(cards))
	b.level = b.level.duplicate(true)
	b.level.spawns = [[99999.0, 0, 1, "C"]]
	b.power = 9999
	b.next_drop = INF
	return b

func put(b, card: int, row: int, col: int) -> Dictionary:
	b.deck[card] = true
	b.ready_at[card] = 0.0
	b.power = 9999
	b.place(card, row, col)
	return b.minis[row][col] if Campaign.is_mini(card) else b.towers[row][col]

func run(b, seconds: float) -> void:
	var t: float = b.time + seconds
	while b.time < t and b.result == 0:
		b.step(0.02)

func _init() -> void:
	tc01()
	tc02()
	tc03()
	tc04()
	mechanics()
	chapter_three()
	regression()
	print("\n%s：%d 项失败" % ["全部通过" if failures == 0 else "有失败", failures])
	quit(failures)

func tc01() -> void:
	var b = blank(22)
	b.spawn_enemy("C", 0, -0.29)
	b.spawn_enemy("Y", 1, -0.29)
	b.step(0.02)
	check("TC-01 两路同一帧漏怪，满意度扣两者之和", b.core == 100 - 5 - 8 and b.leaked == 2 and b.enemies.is_empty(), "core=%d leaked=%d" % [b.core, b.leaked])
	var lose = blank(22)
	lose.core = 7
	lose.spawn_enemy("C", 2, -0.29)
	lose.spawn_enemy("C", 3, -0.29)
	lose.step(0.02)
	check("TC-01 满意度扣到 0 判负且不会变成负数", lose.result == -1 and lose.core == 0, "result=%d core=%d" % [lose.result, lose.core])

func tc02() -> void:
	var b = blank(22)
	b.spawn_enemy("R", 0, 5.0)
	var e: Dictionary = b.enemies[0]
	e.slow = 2.0
	b.reverse_until = 999.0
	var speed: float = b.enemy_speed(e)
	check("TC-02 冰萃减速与逆流按乘法叠加", absf(speed - 0.84 * 0.7 * 0.6) < 0.001, "speed=%.4f" % speed)
	b.rain = true
	speed = b.enemy_speed(e)
	check("TC-02 雨天减速翻倍后仍高于原速 20%", speed >= 0.84 * 0.2 - 0.0001 and absf(speed - maxf(0.84 * 0.4 * Battle.RAIN_SPEED * 0.6, 0.84 * 0.2)) < 0.001, "speed=%.4f" % speed)
	var x0: float = e.x
	run(b, 1.0)
	check("TC-02 来客只会向吧台方向移动，不会倒退", e.x < x0, "x %.3f -> %.3f" % [x0, e.x])

func tc03() -> void:
	var b = blank(33)
	b.spawn_enemy("V", 2, 8.0)
	b.damage(0, 99999.0, 0)
	var v: Dictionary = b.enemies[0]
	check("TC-03 一发高伤害只能打到第一阶段门槛", b.boss_phase == 2 and is_equal_approx(v.hp, 4200.0 * 0.66), "phase=%d hp=%.1f" % [b.boss_phase, v.hp])
	b.damage(0, 99999.0, 0)
	check("TC-03 转阶段期间无敌", b.boss_phase == 2 and is_equal_approx(v.hp, 4200.0 * 0.66), "phase=%d hp=%.1f" % [b.boss_phase, v.hp])
	b.time += 2.1
	b.damage(0, 99999.0, 0)
	check("TC-03 无敌结束后进入第三阶段，仍停在门槛", b.boss_phase == 3 and is_equal_approx(v.hp, 4200.0 * 0.33), "phase=%d hp=%.1f" % [b.boss_phase, v.hp])

func tc04() -> void:
	var b = blank(25, [0])
	var killer := put(b, 0, 2, 3)
	var neighbor := put(b, 0, 2, 1)
	b.spawn_enemy("H", 2, 6.0)
	b.enemies[0].hp = 1.0
	b.damage(0, 29.0, 0, Vector2i(3, 2))
	check("TC-04 黑客 EMP 瘫痪击杀者", killer.emp > b.time and b.idle_reason(killer) == "emp", "emp=%.2f" % killer.emp)
	check("TC-04 旁边的店员不受影响", neighbor.emp == 0.0 and b.idle_reason(neighbor) == "", "emp=%.2f" % neighbor.emp)

func mechanics() -> void:
	# 冷萃冰姬：连中 3 发冻结
	var b = blank(22, [8])
	b.spawn_enemy("W", 2, 6.0)
	for i in range(3):
		b.damage(0, 55.0, 8, Vector2i(1, 2))
	check("Mistral：同一来客连中 3 发被冻结", b.enemies[0].freeze > b.time)
	check("Mistral：无视清洁机甲客的装甲", b.enemies[0].hp < 560.0 - 3 * 55.0 + 1.0, "hp=%.1f" % b.enemies[0].hp)
	# 探店博主的闪光会被拉花甜心挡下
	b = blank(24, [0, 9])
	var front := put(b, 9, 1, 5)
	var behind := put(b, 0, 1, 4)
	b.spawn_enemy("P", 1, 6.6)
	b.camera_flash(b.enemies[0])
	check("探店博主：闪光致盲最前面的豆包", front.blind > b.time)
	check("探店博主：豆包身后的店员不受影响", behind.blind == 0.0)
	# 遮阳伞挡地面来客，不挡无人机
	b = blank(22)
	var cell := Vector2i(5, 2)
	b.spawn_enemy("C", 2, 5.85)
	b.spawn_enemy("Y", 2, 5.85)
	run(b, 1.5)
	var clerk_x: float = b.enemies[0].x
	var drone_x: float = b.enemies[1].x
	check("遮阳伞：票据职员被挡住并开始啃伞", clerk_x > 5.5 and b.props[cell].hp < Battle.UMBRELLA_HP, "x=%.2f hp=%.1f" % [clerk_x, b.props[cell].hp])
	check("遮阳伞：无人机直接飞过", drone_x < 4.5, "x=%.2f" % drone_x)
	# 传送带逆流
	b = blank(22)
	b.spawn_enemy("C", 0, 4.0)
	b.power = 100
	check("传送带：逆流消耗 30 算力并推回 2 格", b.reverse_conveyor() and b.power == 70 and is_equal_approx(b.enemies[0].x, 6.0))
	check("传送带：冷却中不能再次逆流", not b.reverse_conveyor())
	# 超频与过热
	b = blank(22, [0])
	var gpt := put(b, 0, 3, 1)
	b.power = 50
	check("充电桩：超频成功并扣 50 算力", b.overclock(3, 1) and b.power == 0)
	check("充电桩：超频期间攻击间隔缩短", is_equal_approx(b.interval(gpt, 3, 1), 1.2 / 1.5))
	b.time += 8.5
	check("充电桩：超频结束后过热 1.5 秒", b.idle_reason(gpt) == "overheat")
	b.time += 1.2
	check("充电桩：过热结束恢复正常", b.idle_reason(gpt) == "")
	# 停电事件
	b = Battle.new(26, lineup([0, 1]))
	put(b, 0, 2, 1)
	while b.wave < 3 and b.result == 0:
		b.step(0.02)
	check("2-5 停电：第 3 波开始时停电 5 秒", b.blackout_until > b.time and b.idle_reason(b.towers[2][1]) == "blackout")
	# 维克多资金冻结
	b = blank(33, [1])
	put(b, 1, 0, 0)
	b.towers[0][0].ready = 0.0
	b.income_frozen_until = 999.0
	b.next_drop = b.time + 0.01
	run(b, 0.5)
	check("维克多：资金冻结期间没有自然算力和 Kimi 产出", b.tokens.is_empty())
	# 维克多终极差评可以被打断
	b = blank(33, [0])
	put(b, 0, 2, 1)
	b.spawn_enemy("V", 2, 8.0)
	var boss: Dictionary = b.enemies[0]
	boss.hp = 1500.0
	b.boss_phase = 3
	b.victor_skill(boss)
	b.damage(0, Battle.INTERRUPT + 10.0, 0)
	check("维克多：蓄力期间受到足够伤害被打断", boss.charge == 0.0 and boss.wait > b.time)
	# 存档行数兼容
	check("关卡数据：第 02 章 12 关，编号 2-1 ~ 2-12", Campaign.chapter_range(2).size() == 12 and Campaign.code(22) == "2-1" and Campaign.code(33) == "2-12")
	check("关卡数据：新店员只在第 02 章可用", not Campaign.available(8, 21) and Campaign.available(8, 22) and not Campaign.available(15, 30) and Campaign.available(15, 31))
	new_cards()

func new_cards() -> void:
	# mini 附属炮台和主力同格共存
	var b = blank(33, [0, 17, 18, 19])
	var host := put(b, 0, 2, 2)
	b.deck[17] = true
	b.ready_at[17] = 0.0
	check("mini：可以和主力店员放在同一格", b.place(17, 2, 2) and b.minis[2][2] != null and b.towers[2][2] == host)
	check("mini：同一格不能放第二个 mini", not b.place(18, 2, 2))
	b.deck[19] = true
	b.ready_at[19] = 0.0
	check("mini：单独占一格也可以", b.place(19, 3, 2) and b.towers[3][2] == null)
	check("mini：主力格被 mini 占了副位，仍能放主力", put(b, 4, 3, 2) != null and b.towers[3][2] != null)
	check("Gemini Flash：同格主力攻速 +25%", is_equal_approx(b.interval(b.towers[3][2], 3, 2), 1.6 * 0.8))
	# Claude Haiku 给同格主力减伤
	b = blank(33, [3, 18])
	var wall := put(b, 3, 1, 3)
	put(b, 18, 1, 3)
	b.spawn_enemy("C", 1, 3.7)
	run(b, 0.3)
	check("Claude Haiku：同格主力受到的伤害 −30%", is_equal_approx(wall.hp, 400.0 - 17.0 * 0.7), "hp=%.1f" % wall.hp)
	# 主力倒下后 mini 留在原地被啃
	b = blank(33, [0, 17])
	put(b, 0, 1, 3)
	put(b, 17, 1, 3)
	b.towers[1][3].hp = 1.0
	b.spawn_enemy("C", 1, 3.7)
	run(b, 1.0)
	check("mini：主力倒下后 mini 继续挡路", b.towers[1][3] == null and b.minis[1][3] != null and b.minis[1][3].hp < 40.0)
	# 海螺声波穿透整路
	b = blank(24, [10])
	put(b, 10, 2, 0)
	for x in [3.0, 4.5, 6.0]:
		b.spawn_enemy("C", 2, x)
	run(b, 1.8)
	var hurt := 0
	for e in b.enemies:
		if e.hp < 82.0:
			hurt += 1
	check("海螺：一道声波打中路上所有来客", hurt == 3, "hurt=%d" % hurt)
	# 星火燃烧与传火
	b = blank(26, [11])
	b.spawn_enemy("C", 2, 6.0)
	b.spawn_enemy("C", 2, 6.6)
	b.enemies[0].burn = b.time + 4.0
	b.enemies[0].hp = 3.0
	run(b, 0.6)
	check("讯飞星火：燃烧持续掉血，倒下时把火传给身边同伴", b.enemies.size() == 1 and b.enemies[0].burn > b.time)
	# 文心一言标记增伤
	b = blank(27, [12])
	b.spawn_enemy("C", 2, 6.0)
	b.enemies[0].mark = b.time + 5.0
	b.damage(0, 20.0, 0)
	check("文心一言：被标记的来客受到的伤害 +25%", is_equal_approx(b.enemies[0].hp, 82.0 - 25.0), "hp=%.1f" % b.enemies[0].hp)
	# 元宝产出 40 算力的金元宝
	b = blank(29, [13])
	put(b, 13, 0, 0)
	run(b, 10.2)
	check("元宝：10 秒后产出 40 算力的金元宝", b.tokens.size() == 1 and b.tokens[0].get("value", 25) == 40)
	# Llama 击退
	b = blank(30, [14])
	b.spawn_enemy("C", 2, 5.0)
	b.knockback(b.enemies[0])
	check("Llama：毛球把来客往后推 0.55 格", is_equal_approx(b.enemies[0].x, 5.55))
	b.spawn_enemy("V", 3, 5.0)
	b.knockback(b.enemies[1])
	check("Llama：Boss 不会被推开", is_equal_approx(b.enemies[1].x, 5.0))
	# Midjourney 颜料墙
	b = blank(31, [15])
	put(b, 15, 2, 1)
	b.spawn_enemy("C", 2, 7.0)
	b.towers[2][1].ready = 0.0
	run(b, 0.1)
	check("Midjourney：在前方 2 格画出颜料墙", b.props.has(Vector2i(3, 2)) and b.props[Vector2i(3, 2)].get("wall", false))
	run(b, 9.5)
	check("Midjourney：颜料墙 9 秒后消失", not b.props.has(Vector2i(3, 2)) or b.props[Vector2i(3, 2)].until > 9.0)
	# DeepSeek-R1 蓄力光束
	b = blank(28, [16])
	put(b, 16, 2, 0)
	b.spawn_enemy("C", 2, 4.0)
	b.spawn_enemy("C", 2, 7.0)
	run(b, 0.4)
	var before: float = b.enemies[0].hp
	run(b, 2.2)
	check("DeepSeek-R1：思考 2 秒后光束贯穿整路", before == 82.0 and b.enemies.is_empty())
	# 黄牛偷算力、倒下吐出来
	b = blank(28)
	b.tokens.append({"row": 2, "x": 5.0, "born": b.time, "kimi": false})
	b.spawn_enemy("K", 2, 5.2)
	run(b, 0.6)
	check("黄牛：路过时偷走算力", b.tokens.is_empty() and b.enemies[0].stolen == 25)
	b.damage(0, 999.0, 0)
	check("黄牛：被打倒后把偷的算力吐出来", b.tokens.size() == 1 and b.tokens[0].value == 25)
	# 无人机母舰空投
	b = blank(27)
	b.spawn_enemy("M", 2, 8.0)
	run(b, 5.2)
	var drones := 0
	for e in b.enemies:
		if e.kind == "Y":
			drones += 1
	check("无人机母舰：定时在上两路空投无人机", drones == 2, "drones=%d" % drones)

# ---------------------------------------------------------------- 第 03 章「云端分店」

func count_kind(b, kind: String) -> int:
	var n := 0
	for e in b.enemies:
		if e.kind == kind:
			n += 1
	return n

func chapter_three() -> void:
	check("第 03 章：3-1 是第 35 关，共 46 关", Campaign.chapter(34) == 3 and Campaign.code(34) == "3-1" and Campaign.levels.size() == 46 and Campaign.code(45) == "3-12")
	# 漏怪扣吧台满意度（不是第 01 章的机器人规则）
	var b = blank(34)
	b.spawn_enemy("J", 2, -0.29)
	b.step(0.02)
	check("第 03 章：漏怪扣满意度", b.core == 96 and b.leaked == 1 and b.result == 0, "core=%d" % b.core)
	# mini 在第 03 章也能挡路、开火
	b = blank(36, [32])
	put(b, 32, 2, 0)
	b.spawn_enemy("C", 2, 4.0)
	run(b, 2.0)
	check("Ministral：mini 小冰弹打中并减速", b.enemies[0].hp < 82.0 and b.enemies[0].slow > 0.0, "hp=%.1f" % b.enemies[0].hp)
	b = blank(34, [31])
	put(b, 31, 2, 3)
	b.spawn_enemy("C", 2, 3.7)
	run(b, 1.0)
	check("第 03 章：单独放的 mini 也会挡路", b.minis[2][3] != null and b.minis[2][3].hp < 40.0 and b.enemies[0].x > 3.6)
	# Copilot：相邻店员伤害 +20%，开火时跟一发
	b = blank(34, [0, 21])
	put(b, 0, 2, 1)
	put(b, 21, 2, 2)
	b.spawn_enemy("C", 2, 7.0)
	b.damage(0, 20.0, 0, Vector2i(1, 2))
	check("Copilot：相邻店员伤害 +20%", is_equal_approx(b.enemies[0].hp, 82.0 - 24.0), "hp=%.1f" % b.enemies[0].hp)
	run(b, 0.3)
	var assist := 0
	for shot in b.shots:
		if shot.card == 21:
			assist += 1
	check("Copilot：相邻店员开火时补一发协同弹", assist >= 1)
	# Perplexity：锁定三路里生命最高的来客，第 3 发暴击
	b = blank(35, [22])
	var px := put(b, 22, 2, 0)
	b.spawn_enemy("C", 1, 6.0)
	b.spawn_enemy("N", 3, 7.0)
	for k in range(3):
		b.search_shot(px, 2, 0)
	check("Perplexity：打相邻路里最耐打的来客，第 3 发 80 伤害", is_equal_approx(b.enemies[1].hp, Campaign.ENEMIES["N"].hp - 160.0) and is_equal_approx(b.enemies[0].hp, 82.0), "hp=%.1f" % b.enemies[1].hp)
	# Suno：节拍减速 + 身边店员攻速
	b = blank(36, [0, 23])
	var gpt := put(b, 0, 2, 1)
	put(b, 23, 2, 2)
	b.spawn_enemy("C", 2, 4.0)
	var speed0: float = b.enemy_speed(b.enemies[0])
	b.beat_pulse(2, 2)
	check("Suno：节拍让来客减速 40%", is_equal_approx(b.enemy_speed(b.enemies[0]), speed0 * 0.6))
	check("Suno：身边店员攻速 +15%（间隔 ×0.87）", is_equal_approx(b.interval(gpt, 2, 1), Campaign.CARDS[0].interval * 0.87))
	# Sora：倒带 1.2 格，Boss 无效
	b = blank(38, [24])
	put(b, 24, 2, 0)
	b.spawn_enemy("C", 2, 4.0)
	b.spawn_enemy("G", 2, 6.0)
	b.rewind(2, 0)
	check("Sora：本路来客倒带 1.2 格，Boss 不受影响", is_equal_approx(b.enemies[0].x, 5.2) and is_equal_approx(b.enemies[1].x, 6.0))
	# Hugging Face：抱住定身
	b = blank(38, [26])
	put(b, 26, 2, 3)
	b.spawn_enemy("C", 2, 4.5)
	b.hug(2, 3)
	var x0: float = b.enemies[0].x
	run(b, 1.0)
	check("Hugging Face：抱住前方来客 2.5 秒不能动", b.enemies[0].root > b.time and is_equal_approx(b.enemies[0].x, x0) and b.enemies[0].hp < 82.0)
	# Stable Diffusion：上下两路扩散
	b = blank(39, [25])
	b.spawn_enemy("C", 1, 4.2)
	b.spawn_enemy("C", 2, 4.0)
	b.spawn_enemy("C", 3, 3.7)
	b.spawn_enemy("C", 4, 4.0)
	b.diffuse(2, 4.0, Vector2i(0, 2))
	check("Stable Diffusion：扩散打中上下两路 12 伤害", is_equal_approx(b.enemies[0].hp, 70.0) and is_equal_approx(b.enemies[1].hp, 82.0) and is_equal_approx(b.enemies[2].hp, 70.0) and is_equal_approx(b.enemies[3].hp, 82.0))
	# 可灵：一次连射 3 发
	b = blank(41, [27])
	put(b, 27, 2, 0)
	b.spawn_enemy("N", 2, 8.0)
	b.events.clear()
	run(b, 0.6)
	var volley := 0
	for e in b.events:
		if e.type == "fire" and e.card == 27:
			volley += 1
	check("可灵：每次连射 3 发", volley == 3, "fire=%d" % volley)
	# 天工：1 秒后天降光柱
	b = blank(43, [28])
	put(b, 28, 2, 0)
	b.spawn_enemy("C", 2, 6.0)
	b.spawn_enemy("C", 2, 6.4)
	b.spawn_enemy("C", 1, 6.2)
	b.sky_strike(2, 0)
	for e in b.enemies:
		e.root = b.time + 5.0
	run(b, 0.9)
	var alive: int = b.enemies.size()
	run(b, 0.2)
	check("天工：锁定最密集处，1 秒后光柱打中周围一格", alive == 3 and b.enemies.is_empty(), "left=%d" % b.enemies.size())
	# Claude Opus：反弹 40%
	b = blank(40, [29])
	var opus := put(b, 29, 2, 3)
	b.spawn_enemy("C", 2, 3.7)
	run(b, 0.3)
	check("Claude Opus：被啃时反弹 40% 伤害", is_equal_approx(opus.hp, 900.0 - 17.0) and is_equal_approx(b.enemies[0].hp, 82.0 - 17.0 * 0.4), "hp=%.1f" % b.enemies[0].hp)
	# Kimi-K2：代收真算力 +5，删掉假算力
	b = blank(43, [30])
	put(b, 30, 2, 0)
	b.tokens.append({"row": 1, "x": 5.0, "born": b.time, "kimi": false})
	b.tokens.append({"row": 3, "x": 6.0, "born": b.time, "kimi": true, "value": 40, "gold": true})
	b.tokens.append({"row": 2, "x": 4.0, "born": b.time, "kimi": false, "fake": true})
	b.power = 0
	b.agent_collect(2, 0)
	check("Kimi-K2：收走所有真算力（每枚 +5），假算力直接删除", b.power == 30 + 45 and b.tokens.is_empty(), "power=%d" % b.power)
	# Gemini Nano：同格回血
	b = blank(34, [0, 31])
	var host := put(b, 0, 2, 2)
	put(b, 31, 2, 2)
	host.hp = 50.0
	run(b, 1.0)
	check("Gemini Nano：同格主力每秒回复 4 生命", absf(host.hp - 54.0) < 0.1, "hp=%.2f" % host.hp)
	# 豆包 Lite：6 秒后产出 10 算力
	b = blank(35, [33])
	put(b, 33, 0, 0)
	run(b, 5.8)
	var before: int = b.tokens.size()
	run(b, 0.4)
	check("豆包 Lite：部署 6 秒后产出 10 算力", before == 0 and b.tokens.size() == 1 and b.tokens[0].value == 10)
	# 熄灯：只看得见前排 3 格以内；GLM Flash 照亮
	b = blank(37, [0, 34])
	put(b, 0, 2, 0)
	b.spawn_enemy("C", 2, 6.0)
	b.spawn_enemy("C", 2, 2.6)
	b.spawn_enemy("G", 3, 8.0)
	b.step(0.02)
	check("熄灯：前排 3 格外的来客打不到，近处和 Boss 打得到", not b.can_target(b.enemies[0]) and b.can_target(b.enemies[1]) and b.can_target(b.enemies[2]))
	b = blank(37, [34])
	put(b, 34, 2, 1)
	b.spawn_enemy("C", 2, 5.2)
	b.step(0.02)
	var dark_before: bool = b.can_target(b.enemies[0])
	b.flashlight(2, 1)
	check("GLM Flash：照亮前方 4 格，熄灯中也能瞄准", not dark_before and b.can_target(b.enemies[0]))
	# 勒索软件：咬到就加密，倒下解锁
	b = blank(35, [0])
	var locked := put(b, 0, 2, 3)
	b.spawn_enemy("L", 2, 3.7)
	run(b, 0.3)
	check("勒索软件：咬到的店员被加密停手", locked.lock != 0 and b.idle_reason(locked) == "locked")
	b.damage(0, 999.0, 0)
	check("勒索软件：被打倒后解锁", locked.lock == 0 and b.idle_reason(locked) == "")
	# 爬虫机器人：跳过第一个挡路店员
	b = blank(41, [3])
	put(b, 3, 2, 4)
	put(b, 3, 2, 1)
	b.spawn_enemy("J", 2, 4.75)
	run(b, 0.1)
	var hopped: bool = b.enemies[0].hopped and b.enemies[0].x < 4.0
	run(b, 4.0)
	check("爬虫机器人：跳过第一个挡路店员，第二个挡得住", hopped and b.enemies[0].x > 1.7 and b.towers[2][1].hp < 400.0, "x=%.2f" % b.enemies[0].x)
	# 挖矿机：每秒吸 2 算力
	b = blank(36)
	b.spawn_enemy("N", 2, 8.5)
	b.power = 100
	run(b, 2.01)
	check("挖矿机：在场时每秒吸走 2 算力", b.power == 96, "power=%d" % b.power)
	# 钓鱼邮件：假算力点了扣钱
	b = blank(43)
	b.spawn_enemy("F", 2, 8.5)
	run(b, 3.1)
	var fake := -1
	for i in range(b.tokens.size()):
		if b.tokens[i].get("fake", false):
			fake = i
	b.power = 100
	if fake >= 0:
		b.collect(fake)
	check("钓鱼邮件：丢下假算力，点了扣 25", fake >= 0 and b.power == 75, "power=%d" % b.power)
	# 宕机巨兽：蓝屏冲击
	b = blank(39, [0])
	var near := put(b, 0, 2, 4)
	var side := put(b, 0, 1, 2)
	var far := put(b, 0, 0, 4)
	b.spawn_enemy("G", 2, 6.0)
	run(b, 7.1)
	check("宕机巨兽：蓝屏冲击瘫痪相邻三路身前的店员", near.emp > b.time and side.emp > b.time and far.emp <= b.time)
	# 防火墙闸门
	b = blank(34)
	b.power = 100
	var raised: bool = b.raise_gate(2)
	b.spawn_enemy("C", 2, 7.3)
	b.spawn_enemy("G", 2, 7.1)
	run(b, 2.0)
	check("防火墙：花 40 算力把一路拦在第 7 列前 5 秒", raised and b.power == 60 and is_equal_approx(b.enemies[0].x, 7.0), "x=%.2f" % b.enemies[0].x)
	check("防火墙：拦不住 Boss，且有 20 秒冷却", b.enemies[1].x < 7.0 and not b.raise_gate(1))
	run(b, 3.1)
	check("防火墙：5 秒后放行", b.enemies[0].x < 7.0)
	b.gate_ready = 0.0
	b.facility_lock_until = b.time + 5.0
	check("断网时设施不能用", not b.raise_gate(1) and not b.backup_tower(2, 3))
	# 云备份
	b = blank(34, [0])
	var saved := put(b, 0, 2, 3)
	check("云备份：花 30 算力给店员上备份", b.backup_tower(2, 3) and saved.backup > b.time)
	saved.hp = 1.0
	b.spawn_enemy("C", 2, 3.7)
	run(b, 0.3)
	var gone: bool = b.towers[2][3] == null
	b.enemies.clear()
	run(b, 2.0)
	check("云备份：倒下 2 秒后满血恢复", gone and b.towers[2][3] != null and b.towers[2][3].hp == Campaign.CARDS[0].hp)
	b.towers[2][3].hp = 1.0
	b.spawn_enemy("C", 2, 3.7)
	run(b, 3.0)
	check("云备份：只救一次", b.towers[2][3] == null)
	# 数据风暴：来客带护盾
	b = blank(38)
	b.storm_until = b.time + 10.0
	b.spawn_enemy("C", 2, 8.0)
	check("数据风暴：期间出现的来客带 40 护盾", b.enemies[0].shield >= 40.0)
	# 赛勒斯
	b = blank(45, [0])
	b.spawn_enemy("Z", 2, 8.6)
	run(b, 5.1)
	check("赛勒斯一阶段：并购来三只爬虫", count_kind(b, "J") == 3 and b.boss_phase == 1, "J=%d" % count_kind(b, "J"))
	var z: Dictionary = b.enemies[0]
	b.damage(0, 99999.0, 0)
	check("赛勒斯：一次打不穿阶段线，70% 时进二阶段", b.boss_phase == 2 and is_equal_approx(z.hp, Campaign.ENEMIES["Z"].hp * 0.7) and z.invuln > b.time)
	b = blank(45, [0])
	b.spawn_enemy("Z", 2, 8.6)
	z = b.enemies[0]
	var staff := put(b, 0, 2, 3)
	b.boss_phase = 2
	b.cyrus_skill(z)
	check("赛勒斯二阶段：断网清算，设施锁定并熄灯 8 秒", b.facilities_locked() and b.is_dark())
	b.cyrus_skill(z)
	check("赛勒斯二阶段：裁员，本路店员 −60", is_equal_approx(staff.hp, Campaign.CARDS[0].hp - 60.0))
	b = blank(45, [0])
	b.spawn_enemy("Z", 2, 8.9)
	z = b.enemies[0]
	z.root = INF
	var star := put(b, 0, 1, 1)
	put(b, 0, 3, 1)
	star.dealt = 500.0
	b.boss_phase = 3
	b.cyrus_skill(z)
	check("赛勒斯三阶段：收购输出最高的店员", star.acquire > b.time)
	for k in range(3):
		b.tear_seal(1, 1)
	check("赛勒斯三阶段：点 3 下撕掉收购合同", star.acquire == 0.0 and b.towers[1][1] == star)
	b.cyrus_skill(z)
	z.skill = INF
	run(b, 4.1)
	check("赛勒斯三阶段：4 秒没撕掉，店员被收购变成来客", b.towers[1][1] == null and count_kind(b, "C") == 1)

# ---------------------------------------------------------------- 第 01 章回归：新旧 battle.gd 逐帧对比

func autoplay(b, plan: Array, seconds: float) -> Array:
	var trace := []
	var next := 0
	while b.time < seconds and b.result == 0:
		for i in range(b.tokens.size() - 1, -1, -1):
			if b.time - b.tokens[i].born > 0.6:
				b.collect(i)
		if next < plan.size():
			var p: Array = plan[next]
			if b.place(p[0], p[1], p[2]) or b.towers[p[1]][p[2]] != null:
				next += 1
		b.step(0.02)
		if int(round(b.time / 0.02)) % 50 == 0:
			var sig := [snappedf(b.time, 0.01), b.power, b.defeated, b.enemies.size(), b.result]
			for e in b.enemies:
				sig.append(snappedf(e.x, 0.0001))
				sig.append(snappedf(e.hp, 0.01))
			trace.append(sig)
	trace.append(["end", b.result, b.defeated, b.power, b.robots.count(false)])
	return trace

func regression() -> void:
	if not ResourceLoader.exists(ORIGINAL) and not FileAccess.file_exists(ORIGINAL):
		print("SKIP  第 01 章回归（找不到改动前的 battle.gd）")
		return
	var Original = load(ORIGINAL)
	var plans := {
		3: [[1, 0, 0], [0, 1, 1], [1, 1, 0], [3, 1, 4], [0, 0, 1], [1, 2, 0], [0, 2, 1], [0, 1, 2]],
		10: [[1, 2, 0], [0, 2, 1], [1, 0, 0], [1, 4, 0], [0, 0, 1], [0, 4, 1], [1, 1, 0], [1, 3, 0], [5, 2, 2], [4, 1, 2], [4, 3, 2], [3, 2, 4], [0, 1, 1], [0, 3, 1]],
		21: [[1, 2, 0], [0, 2, 1], [1, 1, 0], [1, 3, 0], [5, 2, 2], [0, 1, 1], [0, 3, 1], [1, 0, 0], [1, 4, 0], [4, 2, 3], [6, 0, 1], [6, 4, 1], [5, 1, 2], [5, 3, 2], [3, 2, 5]],
	}
	var cards := {3: [0, 1, 2, 3, 4], 10: [0, 1, 3, 4, 5], 21: [0, 1, 4, 5, 6]}
	for stage in plans:
		var a = autoplay(Battle.new(stage, lineup(cards[stage])), plans[stage], 200.0)
		var b = autoplay(Original.new(stage, lineup(cards[stage])), plans[stage], 200.0)
		var same: bool = a.size() == b.size()
		var first_diff := -1
		if same:
			for i in range(a.size()):
				if str(a[i]) != str(b[i]):
					same = false
					first_diff = i
					break
		check("第 01 章回归 %s：与改动前逐帧一致（结果 %s）" % [Campaign.code(stage), str(a[-1])], same,
			"首个差异在第 %d 个采样：%s vs %s" % [first_diff, str(a[first_diff]) if first_diff >= 0 else "", str(b[first_diff]) if first_diff >= 0 else ""])
