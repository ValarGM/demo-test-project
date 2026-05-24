extends Control

@export var 初始相机数量: int = 20
@export var 每秒删除数量: int = 5
@export var 每秒新增数量: int = 5
@export var 抖动强度: int = 8

@export var 文本生成数量: int = 100

# 这个表示“世界中要被拼接显示的完整区域大小”
@export var 世界显示范围大小: Vector2 = Vector2(1920.0, 1080.0)
@export var 视口大小: Vector2 = Vector2(1960.0, 1080.0)
const 窗口大小_最小值 := Vector2i(480, 270)
const 窗口大小_最大值 := Vector2i(960, 720)

const 相机生成范围_最小值 := Vector2(0.0, 0.0)

const 文本2 = preload("uid://5p2avsm0ghm7")

var 随机数 := RandomNumberGenerator.new()

var 窗口列表: Array[Window] = []
var 相机列表: Array[Camera2D] = []

# 用来记录每个窗口的基础位置，抖动时围绕这个位置抖
var 窗口基础位置表: Dictionary = {}

var 生成编号: int = 0
var 正在批量生成: bool = false

var 文本容器: Node2D

@export var 文本最大数量: int = 100
@export var 文本每次新增数量: int = 3
@export var 文本每次删除数量: int = 3
@export var 文本刷新间隔_最小值: float = 0.05
@export var 文本刷新间隔_最大值: float = 0.25

var 文本列表: Array[Node] = []
var 文本生成消失运行中: bool = false

func _ready() -> void:
	随机数.randomize()

	文本容器 = Node2D.new()
	文本容器.name = "文本容器"
	add_child(文本容器)

	创建初始文本()
	启动文本随机生成和消失()
	创建随机相机和窗口(初始相机数量)

	var 定时器 := Timer.new()
	定时器.wait_time = 1.0
	定时器.autostart = true
	定时器.timeout.connect(_每秒刷新窗口)
	add_child(定时器)

func _process(_delta: float) -> void:
	更新窗口抖动()


func 创建初始文本() -> void:
	for i: int in range(文本生成数量):
		创建单个文本()


func 启动文本随机生成和消失() -> void:
	if 文本生成消失运行中:
		return

	文本生成消失运行中 = true
	文本随机生成和消失循环()


func 文本随机生成和消失循环() -> void:
	while 文本生成消失运行中:
		var 等待时间: float = 随机数.randf_range(
			文本刷新间隔_最小值,
			文本刷新间隔_最大值
		)

		await get_tree().create_timer(等待时间).timeout

		var 删除数量: int = 随机数.randi_range(1, 文本每次删除数量)
		var 新增数量: int = 随机数.randi_range(1, 文本每次新增数量)

		随机删除文本(删除数量)

		for i: int in range(新增数量):
			if 文本列表.size() < 文本最大数量:
				创建单个文本()


func 创建单个文本() -> void:
	var 文本实例: Node = 文本2.instantiate()

	var 随机位置: Vector2 = Vector2(
		随机数.randf_range(0.0, 世界显示范围大小.x),
		随机数.randf_range(0.0, 世界显示范围大小.y)
	)

	文本容器.add_child(文本实例)

	if 文本实例 is Node2D:
		var 节点2D: Node2D = 文本实例 as Node2D
		节点2D.global_position = 随机位置

	elif 文本实例 is Control:
		var 控件: Control = 文本实例 as Control
		控件.set_anchors_preset(Control.PRESET_TOP_LEFT)
		控件.position = 随机位置

	if 文本实例 is CanvasItem:
		var 画布物体: CanvasItem = 文本实例 as CanvasItem
		var 透明度: float = 根据位置计算中心明显度(随机位置)

		var 新颜色: Color = 画布物体.modulate
		新颜色.a = 透明度
		画布物体.modulate = 新颜色

	文本列表.append(文本实例)


func 随机删除文本(数量: int) -> void:
	var 实际删除数量: int = min(数量, 文本列表.size())

	for i: int in range(实际删除数量):
		if 文本列表.is_empty():
			return

		var 删除索引: int = 随机数.randi_range(0, 文本列表.size() - 1)
		var 文本实例: Node = 文本列表[删除索引]

		文本列表.remove_at(删除索引)

		if is_instance_valid(文本实例):
			文本实例.queue_free()
func 根据位置计算中心明显度(位置: Vector2) -> float:
	var 中心点: Vector2 = 世界显示范围大小 * 0.5

	var 到中心距离: float = 位置.distance_to(中心点)

	# 最远距离应该是中心到角落的距离
	var 最大距离: float = 中心点.distance_to(Vector2.ZERO)

	var 距离比例: float = 到中心距离 / 最大距离
	距离比例 = clamp(距离比例, 0.0, 1.0)

	# 重点：越靠近中心，数值越大
	var 明显度: float = 1.0 - 距离比例

	# 曲线强化：中心更亮，边缘更暗
	明显度 = pow(明显度, 1.8)

	return clamp(明显度, 0.05, 1.0)

func _每秒刷新窗口() -> void:
	if 正在批量生成:
		return

	随机删除窗口(每秒删除数量)

	# 不是一下子生成 5 个，而是在 1 秒内一个一个生成
	分批生成随机相机和窗口(每秒新增数量, 1.0)


func 分批生成随机相机和窗口(数量: int, 总耗时: float) -> void:
	正在批量生成 = true

	var 间隔时间: float = 总耗时 / float(max(数量, 1))

	for i: int in range(数量):
		创建单个随机相机和窗口()

		# 等待期间 _process 仍然会执行，所以其他窗口会继续抖动
		await get_tree().create_timer(间隔时间).timeout

	正在批量生成 = false


func 创建随机相机和窗口(数量: int) -> void:
	for i: int in range(数量):
		创建单个随机相机和窗口()


func 创建单个随机相机和窗口() -> void:
	生成编号 += 1

	var 随机窗口大小: Vector2i = 生成随机窗口大小()

	# 相机生成范围最大值由当前窗口大小动态决定
	var 当前相机生成范围最大值: Vector2 = 计算当前相机生成范围最大值(随机窗口大小)

	var 相机位置: Vector2 = 生成随机相机位置(当前相机生成范围最大值)

	# 根据当前窗口大小和当前相机范围进行映射
	var 窗口位置: Vector2i = 根据相机位置计算窗口位置(
		相机位置,
		随机窗口大小,
		当前相机生成范围最大值
	)

	var 窗口 := Window.new()

	# 窗口标题改为黑方块
	窗口.title = "⬛⬛⬛"

	窗口.size = 随机窗口大小
	窗口.position = 窗口位置
	窗口.visible = true

	# 让所有窗口共享主场景的 2D 世界
	窗口.world_2d = get_viewport().world_2d

	add_child(窗口)

	窗口列表.append(窗口)
	窗口基础位置表[窗口] = 窗口位置

	var 相机 := Camera2D.new()
	相机.name = "相机_%d" % 生成编号
	相机.global_position = 相机位置
	相机.zoom = Vector2.ONE
	相机.enabled = true

	# 相机位置代表视野左上角
	相机.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT

	窗口.add_child(相机)
	相机.make_current()

	相机列表.append(相机)

	print("==========")
	print("窗口编号：", 生成编号)
	print("窗口大小：", 随机窗口大小)
	print("当前相机生成范围最大值：", 当前相机生成范围最大值)
	print("相机位置：", 相机位置)
	print("窗口位置：", 窗口位置)


func 生成随机窗口大小() -> Vector2i:
	return Vector2i(
		随机数.randi_range(窗口大小_最小值.x, 窗口大小_最大值.x),
		随机数.randi_range(窗口大小_最小值.y, 窗口大小_最大值.y)
	)


func 计算当前相机生成范围最大值(当前窗口大小: Vector2i) -> Vector2:
	# 因为 Camera2D 是左上角锚点，
	# 所以相机最大位置必须保证：
	# 相机位置 + 窗口大小 不超过 世界显示范围大小
	var 最大值: Vector2 = 世界显示范围大小 - Vector2(当前窗口大小)

	最大值.x = max(最大值.x, 0.0)
	最大值.y = max(最大值.y, 0.0)

	return 最大值


func 生成随机相机位置(当前相机生成范围最大值: Vector2) -> Vector2:
	return Vector2(
		随机数.randf_range(相机生成范围_最小值.x, 当前相机生成范围最大值.x),
		随机数.randf_range(相机生成范围_最小值.y, 当前相机生成范围最大值.y)
	)


func 根据相机位置计算窗口位置(
	相机位置: Vector2,
	当前窗口大小: Vector2i,
	当前相机生成范围最大值: Vector2
) -> Vector2i:
	var 屏幕编号: int = DisplayServer.window_get_current_screen()

	# 获取可用屏幕矩形，避免窗口跑到任务栏下面
	var 屏幕矩形: Rect2i = DisplayServer.screen_get_usable_rect(屏幕编号)

	var 逻辑屏幕左上角: Vector2 = Vector2(屏幕矩形.position)
	var 逻辑屏幕大小: Vector2 = Vector2(屏幕矩形.size)

	# 窗口必须完整显示在屏幕内
	var 窗口可移动范围: Vector2 = 逻辑屏幕大小 - Vector2(当前窗口大小)

	窗口可移动范围.x = max(窗口可移动范围.x, 0.0)
	窗口可移动范围.y = max(窗口可移动范围.y, 0.0)

	var 相机范围大小: Vector2 = 当前相机生成范围最大值 - 相机生成范围_最小值

	var x比例: float = 0.0
	var y比例: float = 0.0

	if 相机范围大小.x > 0.0:
		x比例 = (相机位置.x - 相机生成范围_最小值.x) / 相机范围大小.x

	if 相机范围大小.y > 0.0:
		y比例 = (相机位置.y - 相机生成范围_最小值.y) / 相机范围大小.y

	x比例 = clamp(x比例, 0.0, 1.0)
	y比例 = clamp(y比例, 0.0, 1.0)

	var 窗口逻辑位置: Vector2 = 逻辑屏幕左上角 + Vector2(
		窗口可移动范围.x * x比例,
		窗口可移动范围.y * y比例
	)

	return Vector2i(
		roundi(窗口逻辑位置.x),
		roundi(窗口逻辑位置.y)
	)


func 随机删除窗口(数量: int) -> void:
	var 实际删除数量: int = min(数量, 窗口列表.size())

	for i: int in range(实际删除数量):
		if 窗口列表.is_empty():
			return

		var 删除索引: int = 随机数.randi_range(0, 窗口列表.size() - 1)

		var 窗口: Window = 窗口列表[删除索引]
		窗口列表.remove_at(删除索引)

		var 相机: Camera2D = null

		if 删除索引 < 相机列表.size():
			相机 = 相机列表[删除索引]
			相机列表.remove_at(删除索引)

		if 窗口基础位置表.has(窗口):
			窗口基础位置表.erase(窗口)

		if is_instance_valid(相机):
			相机.queue_free()

		if is_instance_valid(窗口):
			窗口.queue_free()


func 更新窗口抖动() -> void:
	for 窗口: Window in 窗口列表:
		if not is_instance_valid(窗口):
			continue

		if not 窗口基础位置表.has(窗口):
			continue

		var 基础位置: Vector2i = 窗口基础位置表[窗口] as Vector2i

		var 抖动偏移 := Vector2i(
			随机数.randi_range(-抖动强度, 抖动强度),
			随机数.randi_range(-抖动强度, 抖动强度)
		)

		var 新位置: Vector2i = 基础位置 + 抖动偏移

		# 抖动后也尽量保证整个窗口仍在屏幕内
		新位置 = 限制窗口位置在屏幕内(新位置, 窗口.size)

		窗口.position = 新位置


func 限制窗口位置在屏幕内(窗口位置: Vector2i, 当前窗口大小: Vector2i) -> Vector2i:
	var 屏幕编号: int = DisplayServer.window_get_current_screen()
	var 屏幕矩形: Rect2i = DisplayServer.screen_get_usable_rect(屏幕编号)

	var 最小位置: Vector2i = 屏幕矩形.position
	var 最大位置: Vector2i = 屏幕矩形.position + 屏幕矩形.size - 当前窗口大小

	最大位置.x = max(最大位置.x, 最小位置.x)
	最大位置.y = max(最大位置.y, 最小位置.y)

	return Vector2i(
		clampi(窗口位置.x, 最小位置.x, 最大位置.x),
		clampi(窗口位置.y, 最小位置.y, 最大位置.y)
	)


func _exit_tree() -> void:
	文本生成消失运行中 = false

	for 文本实例: Node in 文本列表:
		if is_instance_valid(文本实例):
			文本实例.queue_free()

	文本列表.clear()

	for 窗口: Window in 窗口列表:
		if is_instance_valid(窗口):
			窗口.queue_free()

	窗口列表.clear()
	相机列表.clear()
	窗口基础位置表.clear()
