@tool
## Displays the health related to a [BattleBoardUnit]
class_name BattleBoardUnitHealthVisualComponent
extends Component

# -------------------------
# Team + color configuration
# -------------------------
enum Team { PLAYER, ENEMY }

var _team: Team = Team.PLAYER
@export var team: Team:
	get: return _team
	set(value):
		if _team == value: return
		_team = value
		_apply_team_colors()
		_update_critical_mix(true)

# Player palette
@export_group("Colors • Player")
@export var player_over_main: Color      = Color(0.329412, 0.784314, 0.0745098, 1.0) # green
@export var player_over_critical: Color  = Color(0.95, 0.16, 0.16, 1.0)              # red
@export var player_under_main: Color     = Color(0.768627, 0.105882, 0.207843, 1.0)  # red (lag)
@export var player_under_critical: Color = Color(0.95, 0.16, 0.16, 1.0)

# Enemy palette
@export_group("Colors • Enemy")
@export var enemy_over_main: Color      = Color(0.95, 0.65, 0.13, 1.0)               # orange
@export var enemy_over_critical: Color  = Color(0.88, 0.12, 0.18, 1.0)               # red
@export var enemy_under_main: Color     = Color(0.6, 0.08, 0.12, 1.0)                # darker red
@export var enemy_under_critical: Color = Color(0.88, 0.12, 0.18, 1.0)

@export_group("Critical Overlay Mix")
@export_range(0.0, 1.0, 0.01) var critical_start_ratio := 0.60  # starts blending at <= 40%
@export_range(0.0, 1.0, 0.01) var critical_full_ratio  := 0.10  # fully critical at <= 10%
@export var crit_tween_damage: float = 0.12  # quicker ramp as HP drops
@export var crit_tween_heal: float   = 0.08  # even snappier when healing back

# -------------------------
# Bar + behavior settings
# -------------------------
@export var max_hp: int = 100
@export var lag_delay: float = 0.12
@export var lag_duration: float = 0.45
@export var heal_snaps: bool = true

var hp: int = max_hp
var _lag_tw: Tween
var _crit_tw: Tween

# Cached active palette for quick lerp
var _over_main_color: Color
var _over_crit_color: Color

@onready var _fill: TextureProgressBar:   # OverBar (instant)
	get:
		for child in self.get_children():
			if child is SubViewport:
				for bar in child.get_children():
					if bar is TextureProgressBar and bar != _lag:
						return bar
		return null

@onready var _lag: TextureProgressBar:    # UnderBar (lag)
	get:
		for child in self.get_children():
			if child is SubViewport:
				for bar in child.get_children():
					if bar is TextureProgressBar and bar != _fill:
						return bar
		return null

#region Dependencies
var healthComponent: MeteormyteHealthComponent:
	get:
		return coComponents.get(&"MeteormyteHealthComponent")
#endregion

func _ready() -> void:
	print("READY FUNCTION")
	if not _fill or not _lag:
		push_warning("HealthVisual: OverBar/UnderBar not found under a SubViewport.")
		print("NO FILL OR LAG")
		return
	
	_fill.texture_under = preload("res://Assets/Noah UI/bar_under_transparent.png")
	_fill.texture_over = preload("res://Assets/Noah UI/bar_fill_white.png")
	_fill.texture_progress = preload("res://Assets/Noah UI/bar_fill_white.png")
	
	_lag.texture_over = preload("res://Assets/Noah UI/bar_fill_white.png")
	_lag.texture_under = preload("res://Assets/Noah UI/bar_under_transparent.png")
	_lag.texture_progress = preload("res://Assets/Noah UI/bar_fill_white.png")

	_fill.min_value = 0
	_lag.min_value = 0
	_fill.max_value = max_hp
	_lag.max_value  = max_hp
	_fill.value = hp
	_lag.value  = hp

	_apply_team_colors()
	_update_critical_mix(true)

	if healthComponent:
		max_hp = healthComponent.maxHealth
		hp     = healthComponent.currentHealth
		_fill.max_value = max_hp
		_lag.max_value  = max_hp
		_fill.value = hp
		_lag.value  = hp

		_apply_team_colors()
		_update_critical_mix(true)

		healthComponent.healthChanged.connect(_onHealthChanged)

func _onHealthChanged(current: int, maximum: int) -> void:
	if maximum != max_hp:
		max_hp = maximum
		_fill.max_value = max_hp
		_lag.max_value  = max_hp
	set_health(current)

func set_health(new_hp: int) -> void:
	if not _fill or not _lag:
		return

	new_hp = clampi(new_hp, 0, max_hp)
	if new_hp == hp:
		return

	var old_hp := hp
	hp = new_hp

	# OverBar (instant) jumps immediately
	_fill.value = hp

	# Kill previous tweens to avoid racing
	if _lag_tw:  _lag_tw.kill()
	if _crit_tw: _crit_tw.kill()

	if hp < old_hp:
		# DAMAGE: lag trails; critical tint updates quickly
		_lag.value = max(_lag.value, old_hp)
		_lag_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_lag_tw.tween_interval(lag_delay)
		_lag_tw.tween_property(_lag, "value", hp, lag_duration)

		_tween_critical_mix(crit_tween_damage)
	else:
		# HEAL
		if heal_snaps:
			_lag.value = hp
		else:
			_lag_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_lag_tw.tween_property(_lag, "value", hp, 0.18)

		_tween_critical_mix(crit_tween_heal)

func apply_damage(amount: int) -> void:
	set_health(hp - amount)

func heal(amount: int) -> void:
	set_health(hp + amount)

# -------------------------
# Internal helpers
# -------------------------

func _apply_team_colors() -> void:
	# Choose palette
	var o_main: Color
	var o_crit: Color
	var u_main: Color
	var u_crit: Color

	match _team:
		Team.PLAYER:
			o_main = player_over_main
			o_crit = player_over_critical
			u_main = player_under_main
			u_crit = player_under_critical
		Team.ENEMY:
			o_main = enemy_over_main
			o_crit = enemy_over_critical
			u_main = enemy_under_main
			u_crit = enemy_under_critical

	_over_main_color = o_main
	_over_crit_color = o_crit

	# Apply base colors
	_fill.tint_progress = o_main      # main color for filled region (this is what we blend)
	_lag.tint_progress  = u_main

	# Leave "over" textures invisible so they don't blanket the empty region
	var over_t = _fill.tint_over; over_t.a = 0.0; _fill.tint_over = over_t
	var lag_t  = _lag.tint_over;  lag_t.a  = 0.0; _lag.tint_over  = lag_t

func _critical_mix_value() -> float:
	# 0..1 where 0 = healthy (main color), 1 = critical (fully mixed)
	if max_hp <= 0:
		return 1.0
	var ratio: float = float(hp) / float(max_hp)
	var start :float= max(critical_start_ratio, critical_full_ratio)
	var full  :float= min(critical_start_ratio, critical_full_ratio)
	if ratio >= start:
		return 0.0
	if ratio <= full:
		return 1.0
	return (start - ratio) / (start - full)

func _target_fill_color() -> Color:
	return _over_main_color.lerp(_over_crit_color, _critical_mix_value())

func _tween_critical_mix(duration: float) -> void:
	var target := _target_fill_color()
	_crit_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_crit_tw.tween_property(_fill, "tint_progress", target, max(0.0, duration))

func _update_critical_mix(force_instant: bool = false) -> void:
	var target := _target_fill_color()
	if force_instant:
		_fill.tint_progress = target
	else:
		_tween_critical_mix(0.10)
