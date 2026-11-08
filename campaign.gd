extends RefCounted
# 关卡与数值数据：店员、来客、第 01 章与第 02 章的关卡表。

const CARDS = [
	{"name": "GPT", "role": "光弹输出", "desc": "向同一路发射光弹。", "key": "gpt", "cost": 100, "hp": 100, "cooldown": 5.0, "interval": 1.2, "pose": 0.4},
	{"name": "Kimi", "role": "算力支援", "desc": "指挥星音，部署 8 秒后产出算力。", "key": "kimi", "cost": 50, "hp": 100, "cooldown": 6.0, "interval": 12.0, "pose": 0.85},
	{"name": "DeepSeek", "role": "水炮减速", "desc": "水弹减速 30%，持续 3 秒。", "key": "deepseek", "cost": 125, "hp": 100, "cooldown": 8.0, "interval": 1.65, "pose": 0.52},
	{"name": "Claude", "role": "书盾防御", "desc": "用四倍耐久挡住同路敌人。", "key": "claude", "cost": 75, "hp": 400, "cooldown": 12.0, "interval": 0.0, "pose": 0.56},
	{"name": "Gemini", "role": "邻路支援", "desc": "分别攻击本路和两条相邻路线。", "key": "gemini", "cost": 175, "hp": 115, "cooldown": 9.0, "interval": 1.6, "pose": 0.5},
	{"name": "Qwen", "role": "折扇破甲", "desc": "扇刃对护盾和装甲造成双倍伤害。", "key": "qwen", "cost": 150, "hp": 110, "cooldown": 10.0, "interval": 1.5, "pose": 0.46},
	{"name": "GLM", "role": "扫描解封", "desc": "扫描本路，揭示潜行并解除封锁。", "key": "glm", "cost": 100, "hp": 100, "cooldown": 12.0, "interval": 4.2, "pose": 0.62},
	{"name": "Grok", "role": "爆发溅射", "desc": "星弹命中时攻击同路一格内的敌人。", "key": "grok", "cost": 200, "hp": 115, "cooldown": 22.0, "interval": 7.0, "pose": 0.56},
	{"name": "Mistral", "role": "寒风狙击", "desc": "寒风冰弹减速 30%；同一来客连中 3 发会被冻结，并受到额外伤害。", "key": "mistral", "cost": 125, "hp": 100, "cooldown": 9.0, "interval": 2.0, "pose": 0.5},
	{"name": "豆包", "role": "暖心守护", "desc": "挡路并横扫前方三路，削弱来客；治疗身边店员、加快其攻速。", "key": "doubao", "cost": 100, "hp": 650, "cooldown": 14.0, "interval": 1.0, "pose": 0.45},
	{"name": "海螺", "role": "声波穿透", "desc": "吹响海螺，声波贯穿整条路，打中路上每一位来客。", "key": "hailuo", "cost": 150, "hp": 100, "cooldown": 10.0, "interval": 2.4, "pose": 0.5},
	{"name": "讯飞星火", "role": "星火燎原", "desc": "火球点燃来客持续掉血；燃烧的来客倒下时会把火传给身边的同伴。", "key": "spark", "cost": 150, "hp": 100, "cooldown": 10.0, "interval": 1.8, "pose": 0.5},
	{"name": "文心一言", "role": "一言标记", "desc": "墨笔标记本路最前面的来客，被标记者 5 秒内受到的伤害 +25%。", "key": "ernie", "cost": 100, "hp": 100, "cooldown": 8.0, "interval": 3.0, "pose": 0.5},
	{"name": "元宝", "role": "招财进宝", "desc": "部署 10 秒后开始产出金元宝，每枚 40 算力，产出比 Kimi 慢。", "key": "yuanbao", "cost": 100, "hp": 100, "cooldown": 10.0, "interval": 15.0, "pose": 0.85},
	{"name": "Llama", "role": "毛球击退", "desc": "发射毛球，把来客往后推开半格（重甲减半，Boss 无效）。", "key": "llama", "cost": 125, "hp": 110, "cooldown": 9.0, "interval": 2.4, "pose": 0.5},
	{"name": "Midjourney", "role": "绘梦屏障", "desc": "在前方 2~4 格画出一道颜料墙挡住地面来客，墙持续 9 秒。", "key": "midjourney", "cost": 150, "hp": 100, "cooldown": 16.0, "interval": 12.0, "pose": 0.6},
	{"name": "DeepSeek-R1", "role": "SP · 深度思考", "desc": "SP 版 DeepSeek：深度思考 2 秒后发射贯穿整路的光束，每个来客 90 伤害。", "key": "r1", "cost": 225, "hp": 100, "cooldown": 20.0, "interval": 6.0, "pose": 0.6, "tag": "SP"},
	{"name": "GPT mini", "role": "mini · 小光弹", "desc": "附属炮台：可以和主力店员站在同一格，跟着一起发射小光弹。", "key": "gpt_mini", "cost": 50, "hp": 40, "cooldown": 4.0, "interval": 1.0, "pose": 0.35, "tag": "mini"},
	{"name": "Claude Haiku", "role": "mini · 俳句护盾", "desc": "附属炮台：同格的主力店员受到的伤害 −30%；单独放时可以挡路。", "key": "haiku", "cost": 50, "hp": 120, "cooldown": 8.0, "interval": 0.0, "pose": 0.4, "tag": "mini"},
	{"name": "Gemini Flash", "role": "mini · 闪电加速", "desc": "附属炮台：同格的主力店员攻速 +25%，自己也会放小电弧。", "key": "flash", "cost": 75, "hp": 40, "cooldown": 8.0, "interval": 0.8, "pose": 0.3, "tag": "mini"},
	{"name": "Qwen Turbo", "role": "mini · 小破甲", "desc": "附属炮台：发射小扇刃，对护盾和装甲造成双倍伤害。", "key": "turbo", "cost": 60, "hp": 40, "cooldown": 6.0, "interval": 1.4, "pose": 0.35, "tag": "mini"}
]

const UNLOCKS = [0, 1, 2, 3, 5, 7, 9, 11, 22, 23, 24, 26, 27, 29, 30, 31, 28, 22, 24, 25, 28]
const CHAPTER_STARTS = [0, 22]
const CHAPTER_NAMES = ["算力咖啡厅", "露台风波"]
const TRIAL = [
	{"title": "开店准备", "rows": 1, "power": 150, "waves": 1, "brief": "捡起算力，部署 GPT，拦住第一批票据职员。",
		"spawns": [[15, 0, 1, false], [29, 0, 1, false]]},
	{"title": "第一张订单", "rows": 2, "power": 150, "waves": 2, "brief": "Kimi 会产出算力。两路都有敌人，记得分别布防。",
		"spawns": [[15, 0, 1, false], [24, 1, 1, false], [39, 1, 2, false], [42, 0, 2, false], [47, 1, 2, false], [50, 0, 2, false]]},
	{"title": "浪花迎宾", "rows": 3, "power": 175, "waves": 2, "brief": "猎手比职员跑得快。DeepSeek 的水炮可以拖住它。",
		"spawns": [[13, 1, 1, true], [23, 0, 1, false], [26, 2, 1, false], [42, 2, 2, true], [44, 1, 2, false], [45, 1, 2, true], [49, 0, 2, true], [54, 2, 2, false], [57, 1, 2, false]]},
	{"title": "书盾值班", "rows": 3, "power": 225, "waves": 3, "brief": "把 Claude 放在火力前面挡路，也要留意最后一波的边路。",
		"spawns": [[12, 1, 1, false], [14, 1, 1, false], [18, 1, 1, false], [31, 0, 2, false], [33, 1, 2, true], [36, 0, 2, true], [39, 1, 2, false], [51, 2, 3, true], [53, 2, 3, false], [56, 1, 3, true], [57, 0, 3, false], [59, 2, 3, false], [62, 1, 3, false], [65, 2, 3, true]]}
]

# core：第 02 章里漏到吧台时扣的满意度。fly：飞行，不会被挡。armor：受到的伤害减免比例。
const ENEMIES = {
	"C": {"key": "clerk", "name": "票据职员", "hp": 82.0, "speed": 0.53, "bite": 17.0, "core": 5},
	"R": {"key": "runner", "name": "快递猎手", "hp": 56.0, "speed": 0.84, "bite": 21.0, "core": 6},
	"B": {"key": "guard", "name": "箱盾保镖", "hp": 113.0, "shield": 105.0, "speed": 0.4, "bite": 21.0, "core": 10},
	"A": {"key": "advisor", "name": "加班顾问", "hp": 93.0, "speed": 0.47, "bite": 15.0, "core": 8},
	"S": {"key": "stealth", "name": "潜行职员", "hp": 71.0, "speed": 0.57, "bite": 19.0, "core": 8},
	"T": {"key": "trump", "name": "特朗普", "hp": 235.0, "speed": 0.35, "bite": 25.0, "core": 20},
	"D": {"key": "dario", "name": "达里奥", "hp": 213.0, "speed": 0.34, "bite": 23.0, "core": 20},
	"I": {"key": "tibo", "name": "tibo", "hp": 160.0, "speed": 0.53, "bite": 23.0, "core": 15},
	"X": {"key": "boss1", "name": "算力收购机甲", "hp": 2050.0, "speed": 0.16, "bite": 27.0, "core": 100},
	"Y": {"key": "drone", "name": "暴走外卖无人机", "hp": 70.0, "speed": 1.15, "bite": 0.0, "core": 8, "fly": true},
	"P": {"key": "influencer", "name": "挑剔探店博主", "hp": 180.0, "speed": 0.42, "bite": 16.0, "core": 10},
	"W": {"key": "sweeper", "name": "重装清洁机甲客", "hp": 500.0, "speed": 0.27, "bite": 26.0, "core": 20, "armor": 0.4},
	"H": {"key": "hacker", "name": "漏洞散布黑客", "hp": 105.0, "speed": 0.62, "bite": 18.0, "core": 10},
	"V": {"key": "victor", "name": "督察官维克多", "hp": 4200.0, "speed": 0.2, "bite": 40.0, "core": 100},
	"Q": {"key": "troll", "name": "差评水军", "hp": 40.0, "speed": 0.95, "bite": 8.0, "core": 3},
	"K": {"key": "scalper", "name": "黄牛", "hp": 150.0, "speed": 0.55, "bite": 15.0, "core": 8},
	"M": {"key": "carrier", "name": "外卖无人机母舰", "hp": 1300.0, "speed": 0.11, "bite": 0.0, "core": 100, "fly": true}
}

# 第 02 章：标题、初始算力、简介、各波出怪（"3Q" 表示第 3 路来一队 3 个差评水军）、遮阳伞 (列, 路)、关卡事件、是否 Boss 关。
# 上 2 路是带传送带的主街外卖线，无人机只走这两路。
const CHAPTER_TWO = [
	["露台初启", 300, "外卖无人机会飞过所有店员。上两路有传送带，点「逆流」可以把来客推回去。", ["3C 4C 1Y 5C", "1Y 2Y 4R 5C 3C", "2Y 1Y 3B 4C 5C 1Y", "1Y 2Y 3R 4R 5B 2Y 1C 4C"], [Vector2i(5, 2), Vector2i(4, 4)], "", false],
	["豆包开张", 320, "探店博主会用闪光让前方的店员停手。让豆包站在前排替大家挡下来。", ["3C 4P 1Y", "2Y 3P 5C 4C", "1Y 2Y 4P 3B 5R", "3P 5P 1C 2Y 4A", "1Y 2Y 3P 4B 5P 1Y 2R 3C"], [Vector2i(5, 3), Vector2i(3, 2)], "", false],
	["海螺回声", 330, "差评水军成群结队地来。海螺的声波能一口气打穿整条路。", ["3Q 1Y 4C", "4Q 2Y 5C 3C", "3Q 5Q 1Y 2Y 4P", "2Y 3Q 4Q 5B 1Y 3P", "3Q 4Q 5Q 1Y 2Y 3B 4P"], [Vector2i(6, 2), Vector2i(5, 4)], "", false],
	["骤雨午后", 360, "雨天来客跑得更快，但减速效果翻倍。黑客倒下时会瘫痪击杀它的店员。", ["3H 4C 1Y", "2H 4H 5C 3C 1Y", "3Q 4P 5H 1Y 2Y", "2H 3H 4Q 5R 1Y", "3P 5H 4Q 1Y 2Y 3H 4B"], [Vector2i(4, 3), Vector2i(6, 4)], "rain", false],
	["午间跳闸", 370, "第 3 波会停电 5 秒。清洁机甲客很耐打，还会吃掉咖啡残渣回血。", ["4W 3C 5C 1Y", "2Y 3P 4C 5Q 1C", "3W 4Q 5R 1Y 2Y", "4P 5P 2C 3H 1Y", "5W 3B 4Q 2Y 1Y", "3W 4W 5P 1Y 2Y 3Q 4R"], [Vector2i(5, 2), Vector2i(5, 4)], "blackout", false],
	["母舰空投", 420, "外卖无人机母舰会飞过所有防线，还会不断放出无人机。集中火力把它打下来。", ["3C 4Q 1Y 5C", "2Y 4P 5H 3Q", "3M 1Y 2Y 4C 5C", "4Q 5W 2Y 1Y 3P", "3H 4H 5Q 1Y 2Y"], [Vector2i(6, 3), Vector2i(6, 4)], "", true],
	["黄牛排队", 380, "黄牛会偷走路上的算力，打倒他就能拿回来。算力要早点收。", ["3K 4C 1Y", "4K 2Y 5C 3Q", "3K 5K 1Y 2Y 4P", "2Y 4K 3W 5Q 1Y", "3K 4K 5H 1Y 2Y 3P 4Q"], [Vector2i(5, 2), Vector2i(4, 4)], "", false],
	["外卖高峰", 400, "无人机一波接一波。用 Mistral 和 mini 守住上两路，传送带记得逆流。", ["1Y 2Y 3C 1Y", "2Y 1Y 4Q 2Y 5C", "1Y 2Y 1Y 2Y 3P 4K", "2Y 1Y 3W 2Y 1Y 5H", "1Y 2Y 1Y 2Y 3K 4P 5W 1Y 2Y"], [Vector2i(5, 3), Vector2i(6, 4)], "", false],
	["雨夜清扫", 430, "雨夜里清洁机甲客成队出动。Llama 的毛球能把它们推开，争取输出时间。", ["3W 4C 1Y", "4W 5Q 2Y 3H", "3W 5W 1Y 2Y 4P", "2Y 4W 3K 5H 1Y", "3W 4W 5W 1Y 2Y 3Q", "2Y 3H 4P 5W 1Y 4K 3W"], [Vector2i(4, 2), Vector2i(6, 3)], "rain", false],
	["博主围城", 440, "博主和黑客一起来。Midjourney 画的墙能替店员挡住闪光和冲撞。", ["3P 4P 1Y", "2Y 4H 5P 3Q", "3P 4H 5H 1Y 2Y", "4P 5P 3K 1Y 2Y", "3H 4H 5P 3P 1Y 2Y", "2Y 3P 4P 5W 1Y 4H 3Q"], [Vector2i(5, 2), Vector2i(5, 4)], "", false],
	["全线停电", 460, "第 3 波停电，所有来客一起压上。提前铺好挡路的店员。", ["3W 4P 1Y 5H", "2Y 3K 4Q 5W", "3H 4W 5P 1Y 2Y 3Q", "4K 5H 3P 2Y 1Y", "3W 4W 5K 1Y 2Y 4P", "2Y 1Y 3H 4H 5W 3P 4Q 5K"], [Vector2i(6, 2), Vector2i(4, 3)], "blackout", false],
	["督察官维克多", 480, "维克多有三个阶段：先撕掉封条，再顶住资金冻结，最后在 4 秒内打断他的终极差评。", ["3C 4P 1Y", "2H 4W 5Q 1Y 2Y", "3P 4H 5W 1Y 2Y", "3V 1Y 2Y 4Q 5C", "2H 4P 5W 1Y 4K", "3H 4H 5P 1Y 2Y 3Q", "4W 5W 3P 2H 1Y 2Y 4K"], [Vector2i(6, 3), Vector2i(5, 4)], "", true]
]

const CHAPTER = [
	["周末排队", 4, 205, "门口", "四路交错来敌，最后一波要同时顾好中路和外路。", ["2C 4C 1C", "3R 2C 4R 1C", "2C 4R 2R 1C 3C 4C"]],
	["双星侧援", 5, 235, "主厅", "让 Gemini 站在中间，她能同时照顾三路。", ["3C 2C 4C", "4R 3C 2R 1C 5C", "2R 3R 4R 1C 5C 2C 4C"]],
	["公文箱快递", 5, 250, "主厅", "箱盾保镖第一次出现。用两层火力磨掉他的护盾。", ["3B 3C 2C", "4B 1C 5R 2C", "2B 4B 3R 5C 1C 4C 2R"]],
	["折扇破盾", 5, 380, "主厅", "Qwen 的扇刃会对箱盾造成双倍伤害。", ["3B 3B 1R", "4B 2B 5R", "1B 3R 5B 2C 4C", "2B 4B 1R 5R 3B 4C"]],
	["赶单时间", 5, 315, "主厅", "加班顾问会让同路附近的来客短时加速。", ["3A 3C 3C", "2A 2B 4A 4C", "1R 5R 3A 3B 3R", "2A 2C 2R 4A 4B 1R 5C"]],
	["熄灯试营业", 5, 375, "夜班", "把 GLM 放在潜行路线，或用 Claude 拦住来客让它显形。", ["3S 3C 2C", "3S 4S 1R 5R 4C", "4S 2A 2R 1C 3B 3S 5C"]],
	["金牌来访", 5, 390, "夜班", "特朗普会停下来举起扩音器，召来同路职员。", ["3T 3C 1C 5C", "2A 2R 4A 4C", "1B 5B 3T 3R 2C 4C", "2T 4B 3A 1R 5R 2C"]],
	["甜点开火", 5, 410, "夜班", "Grok 的星弹能清掉扎堆的来客。", ["2C 2C 2C 4C", "4A 4C 4C 2B 3R", "1S 5S 2C 2C 2C 4C", "2T 2C 4B 4C 4C 3R 5R"]],
	["算力紧张", 5, 100, "夜班", "开局只有 100 算力。来客会晚一点到，给 Kimi 留个位置。", ["3C 3C 2C", "4R 2C 3B 1C 5C", "2A 2R 4A 4C 5S", "3B 1R 5B 2S 4C 3R"]],
	["封条来信", 5, 400, "后厨", "达里奥会封住同路的炮台。用 GLM 解封，或在后排补火力。", ["3D 3C 2C", "2B 4B 1R 5R", "4D 4C 2B 3S 1C", "2D 2B 4B 3A 3R 5S"]],
	["临时封台", 5, 400, "后厨", "两格暂时封闭，用 Gemini 的跨路火力补上。", ["2C 4C 3B", "2B 4B 3R 1S 5R", "2D 4S 5B 3C 1R", "2B 4B 3T 1A 1R 5S 4C"]],
	["影子走廊", 5, 540, "后厨", "tibo 和潜行职员会避开单体锁定。用扫描或挡路让他们显形。", ["3I 3S 2C", "4I 4S 2B 1R 5R", "1S 5C 3A 3R 2I 4C", "2S 4I 3B 1C 5S 2R 4R"]],
	["箱盾列队", 5, 425, "后厨", "箱盾重队和快递突袭交替。把破甲与减速分给不同路线。", ["2B 4B 3C", "1R 3R 5R 2C 4C", "3B 3B 2A 4B 1C", "1R 5R 4R 2R 3D", "2B 4B 3T 3B 1S 5S 4R"]],
	["无人收单", 5, 435, "核心区", "自然算力每 14 秒才来一枚，外路轮流承压。", ["1C 5C 3B", "1B 5R 2S 4C", "5B 1R 4A 4R 2C", "1D 5I 1B 5C 3R", "1B 5B 3T 2S 4S 1R 5R"]],
	["联合检查", 5, 505, "核心区", "达里奥与 tibo 会压相邻路，分配好扫描位置。", ["2D 3I 5C", "3S 4D 4B 1R", "2I 3D 3B 2S 5R", "4I 3D 1A 1R 5B", "2D 3I 4B 1C 5S 3R 4D"]],
	["打烊倒计时", 5, 530, "核心区", "最后两波到得更快，箱盾和快递会互相掩护。", ["3T 3C 2R 4R", "2B 4B 1R 5R", "3D 4I 2A 2R 5B", "1B 5B 3T 2R 4R 3S", "2D 4I 1R 5R 3B 3R 4C"]],
	["守住算力核心", 5, 490, "核心区", "三位具名来客轮番上阵，最后一波会同时到场。", ["3T 3C 1C", "2D 2B 4C", "4I 4S 1R 5R", "2B 4B 3A 3R 5S", "1T 5D 2I 2S 4B", "2T 3D 4I 1B 5B 3R 4R"]],
	["算力收购机甲", 5, 525, "核心区", "中路机甲有三阶段。先破甲，再应对封锁和潜行随从。", ["3X 2B 4B 1C 5C", "2D 4S 1R 5R", "1S 5S 2I 4I 3R"]]
]

static var levels: Array = make_levels()

static func make_levels() -> Array:
	var result := TRIAL.duplicate(true)
	for stage in range(result.size()):
		result[stage].arena = "arena"
		result[stage].blocked = []
		result[stage].drop = 9.0
		for spawn in result[stage].spawns:
			spawn[3] = "R" if spawn[3] else "C"
	var arenas := {"门口": "arena", "主厅": "hall", "夜班": "night", "后厨": "kitchen", "核心区": "core"}
	for idx in range(CHAPTER.size()):
		var row: Array = CHAPTER[idx]
		var stage := idx + 4
		var spawns := []
		var at := 40.0 if stage == 12 else 24.0 if stage == 21 else 16.0
		for wave in range(row[5].size()):
			var group: String = row[5][wave]
			for token in group.split(" ", false):
				spawns.append([at, int(token[0]) - 1, wave + 1, token[1]])
				at += 2.6 if stage >= 18 else 3.0
			at += 5.0 if stage == 19 and wave >= 2 else 9.0
		result.append({"title": row[0], "rows": row[1], "power": row[2], "brief": row[4], "waves": row[5].size(),
			"arena": arenas[row[3]], "blocked": [Vector2i(3, 1), Vector2i(5, 3)] if stage == 14 else [],
			"drop": 14.0 if stage == 17 else 9.0, "spawns": spawns})
	for idx in range(CHAPTER_TWO.size()):
		var row: Array = CHAPTER_TWO[idx]
		var spawns := []
		var at := 16.0
		for wave in range(row[3].size()):
			for token in String(row[3][wave]).split(" ", false):
				for k in range(3 if token[1] == "Q" else 1):
					spawns.append([at + k * 0.45, int(token[0]) - 1, wave + 1, token[1]])
				at += 2.8
			at += 9.0
		result.append({"title": row[0], "rows": 5, "power": row[1], "brief": row[2], "waves": row[3].size(),
			"arena": "terrace", "blocked": [], "drop": 9.0, "spawns": spawns, "chapter": 2,
			"umbrellas": row[4], "event": row[5], "event_wave": 3, "conveyor": [0, 1], "charger": true, "boss": row[6]})
	return result

static func chapter(stage: int) -> int:
	return 2 if stage >= CHAPTER_STARTS[1] else 1

static func chapter_range(number: int) -> Array:
	var start: int = CHAPTER_STARTS[number - 1]
	var stop: int = CHAPTER_STARTS[number] if number < CHAPTER_STARTS.size() else levels.size()
	return range(start, stop)

static func code(stage: int) -> String:
	if stage >= CHAPTER_STARTS[1]:
		return "2-%d" % (stage - CHAPTER_STARTS[1] + 1)
	return "1-20EX" if stage == 21 else "1-%d" % stage

static func is_mini(card: int) -> bool:
	return CARDS[card].get("tag", "") == "mini"

static func available(card: int, stage: int) -> bool:
	return card >= 0 and card < UNLOCKS.size() and UNLOCKS[card] <= stage
