extends Node2D

signal home_requested
var home_enabled: bool = false
var selected_ancient_id: String = "horror"
var selected_dice_id: String = "bone"

const HELD_ITEM_Z := 400
const MENU_Z := 500
const ATTACK_SHAKE_SCALE := 0.5
const MULTI_HIT_SPEED_GAIN := 0.08
const MULTI_HIT_SPEED_CAP := 3.0
const AUTO_ATTACK_REVEAL_PAUSE := 0.5
const AUTO_ATTACK_TRAVEL := 0.36
const AUTO_ATTACK_RECOVERY := 0.11
const BattleBackdrop = preload("res://scripts/combat/battle_backdrop.gd")
var backdrop: Node2D
const BattlefieldView = preload("res://scripts/combat/battlefield_view.gd")
const TargetFeedback = preload("res://scripts/shared/cast_drag_feedback.gd")
var battlefield_view = BattlefieldView.new()
var arena_clip: Control
var arena_actors: Node2D
var arena_shade: Node2D
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const SkillBubble = preload("res://scripts/combat/skill_bubble.gd")
const ScreenRipple = preload("res://scripts/effects/screen_ripple.gd")
var screen_ripple: CanvasLayer
const RelicOrbit = preload("res://scripts/relics/relic_orbit.gd")
const RelicUI = preload("res://scripts/relics/relic_ui.gd")
var relic_ui: Node2D
var inventory_page: Node2D
const TarotUI = preload("res://scripts/tarot/tarot_ui.gd")
var tarot_ui: Node2D
const TarotCast = preload("res://scripts/tarot/tarot_cast.gd")
var tarot_cast: Node2D
var dice_group: Node2D
const DamageFeedback = preload("res://scripts/combat/damage_feedback.gd")
var damage_feedback: Node2D
const CombatMotion = preload("res://scripts/combat/combat_motion.gd")
var combat_motion = CombatMotion.new()
var status_layout_key: String = ""
var status_layout_points: Array = []
const Die = preload("res://scripts/dice/die.gd")
const PatternStyle = preload("res://scripts/dice/dice_pattern_style.gd")
var bonus_turn_banner: Node2D
const Effects = preload("res://scripts/effects/effects.gd")
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const City = preload("res://scripts/city/city_paint.gd")
const CityLife = preload("res://scripts/city/city_life.gd")
const ThrowMeter = preload("res://scripts/dice/throw_meter.gd")
const SoundCatalog = preload("res://scripts/audio/sound_catalog.gd")
const CrystalPickup = preload("res://scripts/rewards/crystal_pickup.gd")
var crystal_pickup: Node2D
var soul_pickup: Node2D
const ChargeAudio = preload("res://scripts/dice/charge_audio.gd")
const WaveChest = preload("res://scripts/rewards/battlefield_reward.gd")
var wave_chest: Node2D
var evolution: Node2D
var shop_ui: Node2D
const RewardChest = preload("res://scripts/rewards/reward_chest.gd")
const RewardIcons = preload("res://scripts/rewards/reward_icons.gd")
const Rewards = preload("res://scripts/rewards/reward_catalog.gd")
const Statuses = preload("res://scripts/status/status_catalog.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const StatusPaint = preload("res://scripts/status/status_paint.gd")
const StatusOverlay = preload("res://scripts/status/status_overlay.gd")
const EnemyInspection = preload("res://scripts/enemies/enemy_inspection.gd")
const EnemyVisuals = preload("res://scripts/enemies/enemy_visuals.gd")
const EnemyDebris = preload("res://scripts/enemies/enemy_debris.gd")
var enemy_debris = EnemyDebris.new()
const INK := Color("171b1a")
const PANEL := Color("30352c")
const EDGE := Color("776448")
const CREAM := Color("eee0b9")
const MUTED := Color("aca486")
const TEAL := Color("aed085")
const GOLD := Color("dfb866")
const PURPLE := Color("c5a4de")
const RED := Color("e99b81")
# Layout geometry is instance-local; the portrait scene overrides it before setup.
var ARENA := Rect2(24, 80, 1232, 372)
var DICE_CENTER := Vector2(639, 610)
var DICE_RADIUS := 144.0
var DICE_POSITIONS: Array = []
var dice_selection: Node2D
var leftover_volley: Node2D
var MENU_RECT := Rect2(1200, 24, 40, 34)
var MENU_CLOSE := Rect2(836, 148, 44, 40)
var MENU_RESUME := Rect2(400, 548, 480, 72)
var GUIDE_RECT := Rect2(400, 374, 480, 60)
var AUDIO_RECT := Rect2(1146, 24, 40, 34)
var FX_RECT := Rect2(400, 296, 480, 60)
var SPEED_RECT := Rect2(1084, 24, 50, 34)
var DEBUG_RECT := Rect2(400, 218, 480, 60)
var LANGUAGE_RECT := Rect2(400, 480, 480, 50)
var REPLAY_RECT := Rect2(531, 433, 218, 53)
var GUIDE_CLOSE := Rect2(1132, 96, 40, 36)
var GUIDE_STATUSES := Rect2(742,96,220,36)
var guide_status_page: bool = false
var DEBUG_CLOSE := Rect2(1120, 121, 42, 36)
var DEBUG_REPEAT := Rect2(888, 176, 252, 40)
var DEBUG_PERFECT := Rect2(888, 228, 252, 40)
var DEBUG_WAVE_INPUT := Rect2(238, 626, 100, 40)
var DEBUG_WAVE_LOAD := Rect2(356, 626, 160, 40)
var DEBUG_TAROTS := Rect2(808,568,332,44)
var DEBUG_TAROT_DRAW := Rect2(808,626,332,40)
var DEBUG_CHEST := Rect2(136,568,300,44)
var DEBUG_TREASURE := Rect2(456,568,332,44)
var REWARD_CENTER := Vector2(195, 625)
var CITY_POINT := Vector2(925, 282)
static var HORROR_SIZES: Array = range(Run.Waves.COUNT).map(Run.Waves.player_size)
static var HUMAN_SIZES: Array = range(Run.Waves.COUNT).map(Run.Waves.enemy_size)
static var PAVING_SIZES: Array = range(Run.Waves.COUNT).map(Run.Waves.paving_size)
static var SCENERY_SIZES: Array = range(Run.Waves.COUNT).map(Run.Waves.scenery_size)

var model = Run.new()
var pixel_font: FontFile = preload("res://assets/fonts/Silkscreen-Regular.ttf").duplicate()
var description_font: FontFile = GameText.description_font()
var dice: Array = []
var fx: Node2D
var view_phase: String = "ready"
var result: MultiHitSkill = MultiHitSkill.new()
var last_result: MultiHitSkill = MultiHitSkill.new()
var ring_hover: float = 0
var art: Dictionary = {}
var clock_time: float = 0
var attack_target: int = -1
var muted: bool = false
var reduced: bool = false
var speed: float = 1.0
var guide: bool = false
var debug_open: bool = false
var menu_open: bool = false
var menu_canvas: Node2D
var debug_wave_input: LineEdit
var debug_wave_error: String = ""
var debug_choice: int = -1 # -1 natural; 0 all-different; 1..6 pairs; 7..12 triples.
var debug_repeat: bool = false
var debug_perfect: bool = false
var status_title: String = "READY"
var status_color: Color = TEAL
var active_human: int = -1
var hit_times: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var chest: Node2D
var fallen: Dictionary = {}
var city_corpses: Array = []
var city_life = CityLife.new()
var corpse_alpha: float = 1
var visual_stage: float = 0
var monster_side: float = 224
var background_offset: float = 0
var background_vertical_offset: float = 0
var travel_direction := Vector2.RIGHT
var travel_progress: float = 0
var transition_tween: Tween
var run_id: int = 0
var shake: float = 0
var rattle_clock: float = 0
var start_snapshot: String = ""
var sounds: Dictionary = {}
var charge_audio: Node
var debug_rng = RandomNumberGenerator.new()
var active_touch: int = -1
var touch_position := Vector2.ZERO
var throw_meter = ThrowMeter.new()
var charge_stamp: int = 0
var throw_power: float = 0
var throw_perfect: bool = false
var power_lock_until: float = 0
var combo_flash_until: float = 0
var skill_counter_flash_until: float = 0
var skill_bubble: Node2D
var saved_bubble: Node2D
var skill_source: String = "current"
var skill_return_phase: String = "skill"
var casting_source: String = ""
var skill_pressed: bool = false
var skill_was_selected: bool = false
var skill_dragging: bool = false
var skill_press_origin := Vector2.ZERO
var skill_pointer := Vector2.ZERO
var hover_target: int = -1
const ENEMY_HOLD_DELAY := 0.25
var pressed_enemy: int = -1
var inspecting_enemy: int = -1
var enemy_hold_age: float = 0.0
var cinematic_remaining: float = 0
var cinematic_duration: float = 0
var cinematic_ultimate: bool = false
var cinematic_pause: float = 0
var cinematic_speed: float = 1
var cinematic_dim: float = 0
var cinematic_recovery: float = 0.25
const KILL_SLOW_HOLD := 0.15
const KILL_SLOW_OUT := 0.24
const KILL_SLOW_SPEED := 0.10
const KILL_SLOW_DURATION := KILL_SLOW_HOLD+KILL_SLOW_OUT
var kill_slow_remaining: float = 0
const AUTO_CLAIM_DURATION := 2.4
const CHEST_NAMES := ["Normal", "Perfect", "Greed", "Ultra"]
var auto_claim_tier: int = 0
var auto_claim_remaining: float = 0
var auto_claim_notice: Node2D
@export var chest_pity_path: String = "" # Scene instances persist; isolated model tests do not.

## Build battle presentation nodes, load assets and connect model events to visual effects.
func _ready() -> void:
	if not chest_pity_path.is_empty(): model.chest_pity.configure(chest_pity_path)
	_configure_layout()
	# Both layouts use the same six outer vertices of the two rune triangles.
	for index in range(Rules.DiceTurn.COUNT):
		DICE_POSITIONS.append(DICE_CENTER+Vector2.from_angle(-PI/2+index*TAU/6)*106*(DICE_RADIUS/144.0))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	GameText.prepare_font(pixel_font)
	pixel_font.oversampling = 1.0
	debug_rng.randomize()
	# Modal pages must cover every battle sprite and held item.
	menu_canvas = Node2D.new()
	menu_canvas.name = "MenuCanvas"
	menu_canvas.z_index = MENU_Z
	add_child(menu_canvas)
	menu_canvas.draw.connect(_draw_menu_canvas)
	_create_debug_wave_input()
	dice_group = Node2D.new()
	add_child(dice_group)
	for i in range(Rules.DiceTurn.COUNT):
		var die = Die.new()
		die.position = DICE_POSITIONS[i]
		die.face = i + 1
		die.roll_center = DICE_CENTER
		die.roll_radius = DICE_RADIUS
		dice_group.add_child(die)
		die.landed.connect(_die_landed.bind(i))
		dice.append(die)
	fx = Effects.new()
	fx.font = pixel_font
	add_child(fx)
	_configure_effects()
	bonus_turn_banner = preload("res://scripts/effects/bonus_turn_banner.gd").new()
	bonus_turn_banner.battle = self
	add_child(bonus_turn_banner)
	dice_selection = preload("res://scripts/dice/dice_selection.gd").new()
	dice_selection.battle = self
	add_child(dice_selection)
	leftover_volley = preload("res://scripts/dice/leftover_volley.gd").new()
	leftover_volley.battle = self
	add_child(leftover_volley)
	skill_bubble = SkillBubble.new()
	skill_bubble.battle = self
	add_child(skill_bubble)
	saved_bubble = SkillBubble.new()
	saved_bubble.battle = self
	saved_bubble.stored = true
	add_child(saved_bubble)
	screen_ripple = ScreenRipple.new()
	screen_ripple.battle = self
	add_child(screen_ripple)
	relic_ui = RelicUI.new()
	relic_ui.battle = self
	add_child(relic_ui)
	model.relic_activated.connect(relic_ui.activate)
	damage_feedback = DamageFeedback.new()
	damage_feedback.battle = self
	add_child(damage_feedback)
	var status_overlay := StatusOverlay.new()
	status_overlay.battle = self
	add_child(status_overlay)
	var enemy_inspection := EnemyInspection.new()
	enemy_inspection.battle = self
	add_child(enemy_inspection)
	chest = RewardChest.new()
	chest.battle = self
	add_child(chest)
	wave_chest = WaveChest.new()
	wave_chest.battle = self
	add_child(wave_chest)
	evolution = preload("res://scripts/progression/character_evolution.gd").new()
	evolution.battle = self
	add_child(evolution)
	wave_chest.route_pressed.connect(_select_route)
	shop_ui = preload("res://scripts/rewards/shop_ui.gd").new()
	shop_ui.battle = self
	add_child(shop_ui)
	inventory_page = preload("res://scripts/relics/inventory_page.gd").new()
	inventory_page.battle = self
	add_child(inventory_page)
	crystal_pickup = CrystalPickup.new()
	crystal_pickup.battle = self
	add_child(crystal_pickup)
	soul_pickup = preload("res://scripts/rewards/soul_pickup.gd").new()
	soul_pickup.battle = self
	add_child(soul_pickup)
	model.enemy_crystals_dropped.connect(crystal_pickup.enqueue)
	tarot_ui = TarotUI.new()
	tarot_ui.battle = self
	add_child(tarot_ui)
	tarot_cast = TarotCast.new()
	tarot_cast.battle = self
	add_child(tarot_cast)
	auto_claim_notice = Node2D.new()
	auto_claim_notice.z_index = 100
	add_child(auto_claim_notice)
	auto_claim_notice.draw.connect(_draw_auto_claim)
	chest.opened.connect(func():
		crystal_pickup.enqueue_chest(chest.chest_point(),model.release_chest_crystals(chest.tier))
		if not reduced: shake = 5+chest.tier*2
		_sound("item/book", 0.65, -10)
		_sound("item/crash", 1.25, -20)
		_sound("item/bell", 1.4, -15))
	chest.upgraded.connect(func(tier):
		crystal_pickup.enqueue_chest(chest.chest_point(),model.release_chest_crystals(tier))
		_sound("item/bong_001",0.8+tier*0.15,-10)
		_sound("item/bell",1+tier*0.15,-9)
		if not reduced: shake = 5+tier*2)
	chest.revealed.connect(func(tier):
		if not reduced: shake = maxf(shake,16 if tier == 3 else 6 if tier == 2 else 3))
	chest.landed.connect(func(_index):
		if not reduced: shake = maxf(shake,7+chest.tier*2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			start_snapshot = arg.trim_prefix("--capture=")
	for key in ["eldritch", "vanguard", "archer", "mage", "paladin", "high_priest", "civilian", "civilian_gray", "aristocrat", "floor0", "floor1", "floor2", "floor3", "stone", "arch", "column", "mangrove", "grass", "book", "shield", "attack", "heal", "feast", "crown", "fx"]:
		art[key] = load("res://assets/art/fantasy/" + key + ".png")
	for key in ["vanguard", "archer", "mage", "paladin", "high_priest"]:
		var silhouette: Image = art[key].get_image()
		for y in range(silhouette.get_height()):
			for x in range(silhouette.get_width()):
				silhouette.set_pixel(x, y, Color(1, 1, 1, silhouette.get_pixel(x, y).a))
		art[key+"_glow"] = ImageTexture.create_from_image(silhouette)
	art["mage_normal"] = EnemyVisuals.MAGE_SPRITE
	sounds = SoundCatalog.load_streams()
	if AudioServer.get_bus_index("Combat") == -1:
		AudioServer.add_bus()
		var bus: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Combat")
		AudioServer.add_bus_effect(bus, AudioEffectLimiter.new())
	charge_audio = ChargeAudio.new()
	add_child(charge_audio)
	_create_battlefield_view()
	_start_round()
	if not start_snapshot.is_empty():
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(start_snapshot)
		get_tree().quit()

## Advance battle presentation, city activity, charge audio and pointer feedback.
func _process(delta: float) -> void:
	_update_battlefield_view(delta)
	_update_enemy_hold(delta)
	if not _menus_open() and inspecting_enemy < 0:
		cinematic_remaining = maxf(0, cinematic_remaining - delta)
		kill_slow_remaining = maxf(0, kill_slow_remaining - delta)
		auto_claim_remaining = maxf(0, auto_claim_remaining - delta)
	var world_delta: float = delta * _world_time_scale()
	if not _menus_open(): enemy_debris.advance(world_delta*speed,reduced)
	if not _menus_open() and inspecting_enemy < 0: combat_motion.advance(world_delta)
	clock_time += world_delta
	_update_charge()
	shake = maxf(0, shake - delta * 24)
	var camera_offset := Vector2.ZERO if reduced else (Vector2(sin(clock_time * 67), cos(clock_time * 83)) * shake).snapped(Vector2.ONE * 2)
	if kill_slow_remaining > 0: camera_offset = _kill_impact_shake()
	get_viewport().canvas_transform = Transform2D(0, camera_offset)
	for i in range(hit_times.size()):
		hit_times[i] = maxf(0, hit_times[i] - delta * 2.8)
	for index in fallen:
		fallen[index] += world_delta
	var modal: bool = _menus_open()
	chest.paused = tarot_ui.ceremony.active()
	debug_wave_input.visible = debug_open
	menu_canvas.visible = menu_open or guide or debug_open
	menu_canvas.queue_redraw()
	auto_claim_notice.visible = not modal and view_phase == "over" and auto_claim_remaining > 0
	auto_claim_notice.queue_redraw()
	for index in range(dice.size()):
		var die = dice[index]
		die.visible = true
		var brightness: float = 0.18 if modal else 0.35 if index in model.dice_turn.locked or model.dice_turn.has_pending_group() else 0.55 if view_phase not in ["ready", "charging", "rolling"] else 1.0
		if not modal and index == leftover_volley.active_die: brightness = 0.95
		die.self_modulate = Color(brightness,brightness,brightness,0.18 if modal or view_phase == "over" else 1.0)
		die.set_process(not modal and not model.is_frozen())
		die.reduced = reduced
		die.playback_rate = _roll_speed() / 2.0 if model.is_city() else 1.0
	fx.visible = not modal
	fx.set_process(not modal)
	fx.time_factor = _world_time_scale()
	if model.is_city() and not modal and view_phase in ["ready", "charging", "rolling", "forming", "skill", "targeting", "resolving", "frozen"]:
		_show_events(model.tick_city(world_delta, delta))
		city_life.tick(world_delta, model.city_hp / float(Run.CITY_MAX_HP))
		if model.outcome() == "defeat" or view_phase != "resolving":
			_check_over()
	var mouse := _pointer_position()
	charge_audio.update(delta, view_phase == "charging" and not modal, throw_meter.sample().power, muted)
	if view_phase == "targeting": hover_target = _target_at(skill_pointer if skill_dragging else mouse)
	if view_phase == "charging" and not modal:
		rattle_clock -= delta
		if rattle_clock <= 0:
			var energy: float = throw_meter.sample().power
			rattle_clock = lerpf(0.19, 0.07, energy)
			_sound("dice/click_001", lerpf(0.7, 1.5, energy), lerpf(-32, -23, energy))
	if view_phase == "rolling" and not modal and dice.any(func(die): return die.rolling):
		rattle_clock -= delta
		if rattle_clock <= 0:
			rattle_clock = 0.1 / _roll_speed()
			_sound("dice/click_001", 0.8 + fmod(clock_time * 2, 0.6) + throw_power * 0.25, -27 + throw_power * 7)
	var in_ring: bool = dice_selection.center_hit(mouse) and view_phase in ["ready", "skill", "charging"] and not modal
	ring_hover = move_toward(ring_hover, 1.0 if in_ring else 0.0, delta * 7)
	var interactive := in_ring or MENU_RECT.has_point(mouse) or AUDIO_RECT.has_point(mouse) or SPEED_RECT.has_point(mouse)
	if guide:
		interactive = GUIDE_CLOSE.has_point(mouse) or GUIDE_STATUSES.has_point(mouse) or (home_enabled and _home_rect().has_point(mouse))
	elif debug_open:
		interactive = DEBUG_TREASURE.has_point(mouse) or DEBUG_CLOSE.has_point(mouse) or DEBUG_REPEAT.has_point(mouse) or DEBUG_PERFECT.has_point(mouse) or DEBUG_WAVE_LOAD.has_point(mouse) or DEBUG_TAROTS.has_point(mouse) or DEBUG_TAROT_DRAW.has_point(mouse) or (_can_debug_chest() and DEBUG_CHEST.has_point(mouse))
		for i in range(-1, 13):
			interactive = interactive or _debug_option_rect(i).has_point(mouse)
	elif menu_open:
		interactive = [MENU_CLOSE, MENU_RESUME, DEBUG_RECT, FX_RECT, GUIDE_RECT, LANGUAGE_RECT].any(func(rect): return rect.has_point(mouse))
	elif view_phase == "over":
		interactive = interactive or REPLAY_RECT.has_point(mouse) or (home_enabled and _home_rect().has_point(mouse))
	if view_phase in ["skill", "targeting"]:
		interactive = interactive or _in_skill_bubble(mouse) or (view_phase == "targeting" and _target_at(mouse) != -1)
	interactive = interactive or (_can_end_turn() and _in_saved_slot(mouse))
	interactive = interactive or _chest_tier_at(mouse) > 0
	interactive = interactive or (_can_inspect_enemy() and _enemy_inspect_at(mouse) >= 0)
	interactive = interactive or (view_phase == "frozen" and not modal and (_ice_rect().has_point(mouse) or _player_ice_rect().has_point(mouse)))
	if shop_ui.visible: interactive = shop_ui.hit(mouse)
	elif wave_chest.visible: interactive = wave_chest.hit(mouse)
	elif view_phase == "reward": interactive = chest.closed_rect().grow(18).has_point(mouse) if chest.roll_phase == "closed" else chest.active or chest.pickup_at(mouse) >= 0 or (chest.can_skip() and chest.skip_rect().has_point(mouse))
	interactive = interactive or (inventory_page.available() and inventory_page.button_rect().has_point(mouse))
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if interactive else Input.CURSOR_ARROW)
	queue_redraw()

## Build one clipped battlefield for scenery and actors, below the fixed interface.
func _create_battlefield_view() -> void:
	var surround := Node2D.new()
	surround.z_index = -3
	add_child(surround)
	surround.draw.connect(func(): _stone(Rect2(Vector2.ZERO,fx.canvas_size),Color("303129"),"stone",64,surround))
	arena_clip = Control.new()
	arena_clip.name = "BattlefieldClip"
	arena_clip.position = ARENA.position
	arena_clip.size = ARENA.size
	arena_clip.clip_contents = true
	arena_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_clip.z_index = -2
	add_child(arena_clip)
	backdrop = BattleBackdrop.new()
	backdrop.battle = self
	arena_clip.add_child(backdrop)
	arena_shade = Node2D.new()
	arena_shade.position = -ARENA.position
	arena_clip.add_child(arena_shade)
	arena_shade.draw.connect(_draw_backdrop_shade.bind(arena_shade))
	arena_actors = Node2D.new()
	arena_actors.name = "BattlefieldActors"
	arena_clip.add_child(arena_actors)
	arena_actors.draw.connect(_draw_world_actors)
	_update_battlefield_view(0)

## Recognize aimed skills and enemy-targeted tarot without zooming support actions.
func _target_focus_requested() -> bool:
	if model.is_city() or _menus_open() or not model.outcome().is_empty(): return false
	if view_phase == "targeting" and _skill_needs_target(): return true
	if is_instance_valid(tarot_cast) and tarot_cast.choice_type == "repeat_target": return true
	if is_instance_valid(tarot_ui) and tarot_ui.gesture == "card":
		var index: int = tarot_ui.pressed_card
		if index >= 0 and index < model.tarots.items.size():
			return tarot_ui.Catalog.ITEMS[model.tarots.items[index].id].target == "enemy"
	return false

## Ease one world transform; hit testing always uses the same current projection.
func _update_battlefield_view(delta: float) -> void:
	var bounds := Rect2()
	for index in model.living():
		var feet: Vector2 = _enemy_layout_feet(index)
		var side: float = _enemy_side()
		var rect := Rect2(feet-Vector2(side*0.55,side),Vector2(side*1.1,side))
		bounds = rect if not bounds.has_area() else bounds.merge(rect)
	if inspecting_enemy < 0:
		battlefield_view.advance(delta,_target_focus_requested(),ARENA,bounds,fx.canvas_size.y > fx.canvas_size.x,_enemy_side())
	fx.world_transform = battlefield_view.transform
	if not is_instance_valid(arena_actors): return
	var projected: Transform2D = Transform2D(0,-ARENA.position)*battlefield_view.transform
	backdrop.transform = projected
	arena_actors.transform = projected
	arena_actors.visible = not model.is_city()
	arena_actors.queue_redraw()
	arena_shade.queue_redraw()

## Draw world-space characters and fragments under the shared battlefield camera.
func _draw_world_actors() -> void:
	_draw_player_actor(arena_actors)
	for index in range(model.enemies.size()): _draw_human(index,arena_actors)

## Restore the viewport transform after leaving the battle scene.
func _exit_tree() -> void:
	get_viewport().canvas_transform = Transform2D.IDENTITY

## Cancel unfinished touch, drag and charge gestures when the app loses focus.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(dice_selection): dice_selection.cancel_gesture()
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(tarot_ui): tarot_ui.cancel_gesture()
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(relic_ui): relic_ui.cancel_hold()
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(shop_ui): shop_ui.cancel_drag()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		active_touch = -1
		_cancel_charge()
		_cancel_targeting()
	if what == NOTIFICATION_APPLICATION_PAUSED:
		active_touch = -1
		_cancel_charge()
		_cancel_targeting()

## Provide the layout hook overridden by the portrait battle scene.
func _configure_layout() -> void:
	preload("res://scripts/shared/display_quality.gd").configure(get_window(), Vector2i(1280, 800))

## Set landscape dice scale and presentation defaults.
func _configure_effects() -> void:
	for die in dice:
		die.base_scale = 0.75
		die.scale = Vector2.ONE * die.base_scale

## Report modal pages and tarot ceremonies that suspend battle interaction.
func _menus_open() -> bool:
	return menu_open or guide or debug_open or (is_instance_valid(inventory_page) and inventory_page.opened) or (is_instance_valid(tarot_ui) and tarot_ui.ceremony.active())

## Draw the active modal page above every battle sprite and held item.
func _draw_menu_canvas() -> void:
	if guide: _draw_guide(menu_canvas)
	elif debug_open: _draw_debug(menu_canvas)
	elif menu_open: _draw_menu(menu_canvas)

## Create the numeric wave-entry field used by the debug page.
func _create_debug_wave_input() -> void:
	debug_wave_input = LineEdit.new()
	debug_wave_input.position = DEBUG_WAVE_INPUT.position
	debug_wave_input.size = DEBUG_WAVE_INPUT.size
	debug_wave_input.z_index = 1
	debug_wave_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_wave_input.max_length = 2
	debug_wave_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	debug_wave_input.placeholder_text = "1-%d" % Run.PLAYABLE_WAVES
	debug_wave_input.add_theme_font_override("font", preload("res://assets/fonts/Silkscreen-Regular.ttf"))
	debug_wave_input.add_theme_font_size_override("font_size", 28 if DEBUG_WAVE_INPUT.size.y > 50 else 22)
	debug_wave_input.add_theme_color_override("font_color", CREAM)
	debug_wave_input.add_theme_color_override("caret_color", GOLD)
	for style_name in ["normal", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = INK
		style.border_color = GOLD if style_name == "focus" else EDGE
		style.set_border_width_all(3 if style_name == "focus" else 2)
		debug_wave_input.add_theme_stylebox_override(style_name, style)
	debug_wave_input.hide()
	menu_canvas.add_child(debug_wave_input)
	debug_wave_input.text_submitted.connect(_debug_load_wave)
	debug_wave_input.text_changed.connect(func(_value): debug_wave_error = "")

func _open_debug() -> void:
	menu_open = false
	debug_open = true
	debug_wave_error = ""
	debug_wave_input.text = str(model.stage + 1)
	debug_wave_input.show()

func _close_debug(to_menu: bool = true) -> void:
	debug_open = false
	menu_open = to_menu
	debug_wave_input.hide()
	debug_wave_input.release_focus()

## Validate a debug wave number and restart at that wave.
func _debug_load_wave(value: String) -> void:
	if not debug_open: return
	var trimmed: String = value.strip_edges()
	if not trimmed.is_valid_int() or trimmed.to_int() < 1 or trimmed.to_int() > Run.PLAYABLE_WAVES:
		debug_wave_error = "请输入1到%d之间的关卡。" % Run.PLAYABLE_WAVES
		return
	_restart(trimmed.to_int())

## Grant all 22 tarot cards without checking existing ownership.
func _debug_give_tarots() -> void:
	if not debug_open: return
	# Debug grants deliberately ignore ownership and Hanged Man's reward exclusions.
	for id in Run.Tarot.ITEMS: model.grant_tarot(id)
	_sound("ui/confirmation_002",1,-14)

## Trigger the normal tarot selection ceremony from debug.
func _debug_draw_tarot() -> void:
	if not debug_open: return
	if tarot_ui.begin_reward("debug"): _close_debug(false)

## Fill the Reroll Treasure meter without completing a battle.
func _debug_charge_treasure() -> void:
	if not debug_open: return
	model.reroll_progress = Run.CHEST_THRESHOLDS[-1]
	_sound("ui/confirmation_002",1,-14)
	queue_redraw()

func _can_debug_chest() -> bool:
	return debug_open and view_phase in ["ready","charging","skill","targeting","frozen","over"] and model.open_rewards.is_empty() and model.tarot_source.is_empty()

## Open an upgradeable debug chest and preserve the underlying battle phase.
func _debug_spawn_chest() -> void:
	if not _can_debug_chest(): return
	var outcomes: Array = model.open_debug_chest()
	if outcomes.is_empty(): return
	if view_phase == "charging": _cancel_charge()
	if view_phase == "targeting": _cancel_targeting()
	_close_debug(false)
	_show_chest(outcomes,true)

## Use the active touch location or mouse position for shared pointer input.
func _pointer_position() -> Vector2:
	return touch_position if active_touch >= 0 else get_global_mouse_position()

## Route mouse and touch events through modal, item and combat controls.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			touch_position = get_global_transform_with_canvas().affine_inverse() * event.position
			_handle_click(touch_position)
		elif not event.pressed and event.index == active_touch:
			touch_position = get_global_transform_with_canvas().affine_inverse() * event.position
			_handle_release(touch_position)
			active_touch = -1
		return
	if event is InputEventScreenDrag:
		if event.index == active_touch:
			touch_position = get_global_transform_with_canvas().affine_inverse() * event.position
			_handle_motion(touch_position)
		return
	if event is InputEventMouseMotion:
		if event.device != -1 and active_touch < 0:
			_handle_motion(get_global_transform_with_canvas().affine_inverse() * event.position)
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Touch is handled directly: ignore its synthesized mouse events.
	if event.device == -1 or active_touch >= 0:
		return
	var mouse: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event.pressed: _handle_click(mouse)
	else: _handle_release(mouse)

func _in_dice_range(mouse: Vector2) -> bool:
	return mouse.distance_squared_to(DICE_CENTER) <= DICE_RADIUS * DICE_RADIUS

## Dispatch a battle press according to the active menu and gameplay phase.
func _handle_click(mouse: Vector2) -> void:
	if is_instance_valid(inventory_page) and inventory_page.click(mouse): return
	if is_instance_valid(shop_ui) and shop_ui.click(mouse): return
	if view_phase == "shop":
		relic_ui.click(mouse)
		return
	if is_instance_valid(tarot_cast) and tarot_cast.click(mouse): return
	if is_instance_valid(tarot_ui) and tarot_ui.click(mouse): return
	if view_phase == "wave_reward" and relic_ui.click(mouse): return
	if is_instance_valid(wave_chest) and wave_chest.click(mouse): return
	if view_phase == "reward" and chest.active:
		chest.click(mouse)
		return
	if view_phase == "reward" and chest.can_skip() and chest.skip_rect().has_point(mouse):
		model.discard_unclaimed_rewards()
		chest.skip_remaining()
		relic_ui.reset()
		fx.skill.clear()
		return
	if is_instance_valid(relic_ui) and relic_ui.click(mouse): return
	if view_phase == "reward":
		_pick_reward(mouse)
		return
	_update_charge()
	if home_enabled and (guide or (view_phase == "over" and not _menus_open())) and _home_rect().has_point(mouse):
		_cancel_charge()
		home_requested.emit()
		return
	if guide:
		if GUIDE_STATUSES.has_point(mouse): guide_status_page = not guide_status_page
		if GUIDE_CLOSE.has_point(mouse):
			guide = false
			menu_open = true
		return
	if debug_open:
		if DEBUG_CLOSE.has_point(mouse): _close_debug()
		elif DEBUG_REPEAT.has_point(mouse): debug_repeat = not debug_repeat
		elif DEBUG_PERFECT.has_point(mouse): debug_perfect = not debug_perfect
		elif DEBUG_TAROTS.has_point(mouse): _debug_give_tarots()
		elif DEBUG_TAROT_DRAW.has_point(mouse): _debug_draw_tarot()
		elif DEBUG_CHEST.has_point(mouse): _debug_spawn_chest()
		elif DEBUG_TREASURE.has_point(mouse): _debug_charge_treasure()
		elif DEBUG_WAVE_LOAD.has_point(mouse): _debug_load_wave(debug_wave_input.text)
		else:
			for i in range(-1, 13):
				if _debug_option_rect(i).has_point(mouse):
					debug_choice = i
					_close_debug(false)
					_sound("ui/book", 1.4, -17)
		return
	if menu_open:
		if MENU_CLOSE.has_point(mouse) or MENU_RESUME.has_point(mouse): menu_open = false
		elif DEBUG_RECT.has_point(mouse): _open_debug()
		elif GUIDE_RECT.has_point(mouse):
			menu_open = false
			guide = true
			_sound("ui/book", 1.0, -14)
		elif FX_RECT.has_point(mouse):
			reduced = not reduced
			fx.reduced = reduced
			if reduced: shake = 0
		else:
			for i in range(GameText.LANGUAGES.size()):
				if _language_rect(i).has_point(mouse): GameText.set_language(GameText.LANGUAGES[i])
		return
	if AUDIO_RECT.has_point(mouse):
		muted = not muted
		if muted:
			charge_audio.silence()
			for child in get_children():
				if child is AudioStreamPlayer: child.queue_free()
		return
	if view_phase in ["ready", "charging", "skill", "targeting", "frozen", "over"]:
		if MENU_RECT.has_point(mouse):
			dice_selection.cancel_gesture()
			_cancel_charge()
			_cancel_targeting()
			menu_open = true
			return
	var tier: int = _chest_tier_at(mouse)
	if tier > 0:
		_reward_sequence(tier)
		return
	if view_phase == "over":
		if REPLAY_RECT.has_point(mouse): _restart()
		return
	if SPEED_RECT.has_point(mouse) and not model.is_city():
		speed = 2.0 if speed == 1.0 else 1.0
		return
	if view_phase == "frozen":
		if _ice_rect().has_point(mouse) or _player_ice_rect().has_point(mouse): _hit_ice(mouse)
		return
	if _in_saved_slot(mouse) and _can_end_turn():
		_end_dice_turn()
		return
	if dice_selection.click(mouse): return
	if _can_inspect_enemy() and not skill_pressed and (result.is_empty() or not _in_skill_bubble(mouse)) and not _in_saved_slot(mouse):
		var enemy: int = _enemy_inspect_at(mouse)
		if enemy >= 0:
			pressed_enemy = enemy
			enemy_hold_age = 0.0
			return
	if view_phase in ["skill", "targeting"] or (view_phase == "ready" and _can_use_saved() and _in_saved_slot(mouse)):
		_handle_skill_click(mouse)
		return

func _skill_radius() -> float:
	return 96.0 if fx.canvas_size.y > fx.canvas_size.x else 78.0

func _skill_reveal_point() -> Vector2:
	return Vector2(402, 668) if fx.canvas_size.y > fx.canvas_size.x else Vector2(640, 340)

func _skill_rest_point() -> Vector2:
	return Vector2(402, 1196) if fx.canvas_size.y > fx.canvas_size.x else Vector2(640, 420)

func _skill_center() -> Vector2:
	return skill_bubble.center_at() if is_instance_valid(skill_bubble) else _skill_rest_point()

func _in_skill_bubble(point: Vector2) -> bool:
	return point.distance_to(_skill_center()) <= _skill_radius() + 12

func _skill_needs_target(roll: MultiHitSkill = null) -> bool:
	if roll == null: roll = _source_roll(skill_source)
	return not roll.is_empty() and Rules.is_attack(roll) and not Rules.hits_all(roll) and not roll.random_target_per_use()

func _saved_slot_center() -> Vector2:
	return DICE_CENTER+Vector2(274,-218) if fx.canvas_size.y > fx.canvas_size.x else DICE_CENTER+Vector2(195,-64)

func _saved_slot_radius() -> float:
	return 56.0 if fx.canvas_size.y > fx.canvas_size.x else 40.0

func _perfect_combo_center() -> Vector2:
	var saved: Vector2 = _saved_slot_center()
	return Vector2(2 * DICE_CENTER.x - saved.x, saved.y)

func _in_saved_slot(point: Vector2) -> bool:
	return point.distance_to(_saved_slot_center()) <= _saved_slot_radius()+12

## Check whether the banked skill is ready for a bonus cast.
func _can_use_saved() -> bool:
	if not Rules.SAVED_SKILLS_ENABLED: return false
	if is_instance_valid(tarot_ui) and tarot_ui.inventory_visible(): return false
	return not model.saved_skill.is_empty() and view_phase in ["ready", "skill", "targeting"] and not _menus_open() and model.outcome().is_empty()

## Resolve a skill source to the current roll or saved skill.
func _source_roll(source: String) -> MultiHitSkill:
	return model.saved_skill if source == "saved" else result

## Resolve a skill source to its animated bubble.
func _source_bubble(source: String) -> Node2D:
	return saved_bubble if source == "saved" else skill_bubble

## Match the saved-skill visual to the model’s banked skill.
func _sync_saved_bubble() -> void:
	if not is_instance_valid(saved_bubble): return
	if model.saved_skill.is_empty(): saved_bubble.clear()
	elif not saved_bubble.roll.same_as(model.saved_skill):
		saved_bubble.begin(model.saved_skill)
		saved_bubble.age = saved_bubble.formation

## Validate a skill drop against the battlefield and targeting rules.
func _field_drop_valid(point: Vector2) -> bool:
	return ARENA.grow(-8).has_point(point)

## Get the eligible targets for the held skill, including taunt restrictions.
func _skill_targets() -> Array:
	if model.is_city(): return [-2] if model.city_hp > 0 else []
	return model.attack_targets()

## Keep taunt brackets synchronized across skills and enemy-targeted cards.
func _draw_target_indicator(canvas: CanvasItem, target: int, selected: bool, color: Color) -> void:
	var bounds: Rect2 = _target_rect(target)
	if target in model.taunting_enemies():
		var pulse: float = _taunt_pulse()
		bounds = bounds.grow(pulse*4)
		color = Color("ff525e").lerp(Color("ffb0b6"),pulse*0.3)
	TargetFeedback.paint_target(canvas,bounds,selected,color,fx.canvas_size.y > fx.canvas_size.x)

func _target_rect(target: int) -> Rect2:
	if target == -2:
		var size := Vector2(560, 360) if fx.canvas_size.y > fx.canvas_size.x else Vector2(530, 260)
		return Rect2(CITY_POINT-size/2, size)
	var side: float = _enemy_side()*battlefield_view.zoom
	var minimum: float = 88 if fx.canvas_size.y > fx.canvas_size.x else 48
	return Rect2(_enemy_point(target)-Vector2(maxf(minimum,side*0.82),maxf(minimum,side+30))/2,Vector2(maxf(minimum,side*0.82),maxf(minimum,side+30)))

## Find a legal skill target beneath the pointer.
func _target_at(point: Vector2) -> int:
	var closest: int = -1
	var distance: float = INF
	for target in _skill_targets():
		var rect: Rect2 = _target_rect(target)
		var d: float = point.distance_squared_to(rect.get_center())
		if ARENA.has_point(point) and rect.has_point(point) and d < distance:
			closest = target
			distance = d
	return closest

func _can_inspect_enemy() -> bool:
	return not model.is_city() and not _menus_open() and view_phase in ["ready", "skill", "targeting"] and model.outcome().is_empty()

func _enemy_hold_rect(index: int) -> Rect2:
	return _target_rect(index).merge(_enemy_intent_rect(index))

func _enemy_inspect_at(point: Vector2) -> int:
	if model.is_city(): return -1
	var closest: int = -1
	var distance: float = INF
	for index in model.living():
		if _enemy_intent_data(index).is_empty(): continue
		var d: float = point.distance_squared_to(_enemy_point(index))
		if _enemy_hold_rect(index).has_point(point) and d < distance:
			closest = index
			distance = d
	return closest

## Open enemy intent and status inspection after the hold threshold.
func _update_enemy_hold(delta: float) -> void:
	if pressed_enemy < 0: return
	if not _can_inspect_enemy() or pressed_enemy >= model.enemies.size() or _enemy_intent_data(pressed_enemy).is_empty():
		_cancel_enemy_hold()
		return
	enemy_hold_age += delta
	if enemy_hold_age >= ENEMY_HOLD_DELAY: inspecting_enemy = pressed_enemy

## Clear a pending or visible enemy inspection.
func _cancel_enemy_hold() -> void:
	pressed_enemy = -1
	inspecting_enemy = -1
	enemy_hold_age = 0.0

## Select the current or saved skill for dragging or targeted casting.
func _handle_skill_click(point: Vector2) -> void:
	var source: String = "saved" if _in_saved_slot(point) and _can_use_saved() else "current" if not result.is_empty() and _in_skill_bubble(point) else ""
	if view_phase == "targeting" and skill_source == "saved" and source == "current": return
	if not source.is_empty():
		var already_selected: bool = view_phase == "targeting" and skill_source == source
		if already_selected and source == "saved":
			_cancel_targeting()
			return
		if not already_selected:
			if view_phase == "targeting": _cancel_targeting()
			skill_return_phase = view_phase
		skill_was_selected = already_selected
		skill_source = source
		view_phase = "targeting"
		status_title = "CHOOSE A FOE" if _skill_needs_target() else "DRAG TO CAST"
		skill_pressed = true
		skill_press_origin = point
		skill_pointer = point
		_sound("player/book", 1.3, -19)
	elif view_phase == "targeting" and _skill_needs_target():
		var target: int = _target_at(point)
		if target != -1: _activate_skill(target)
		else: _cancel_targeting()

## Move a held skill and refresh its target highlight.
func _handle_motion(point: Vector2) -> void:
	if is_instance_valid(inventory_page) and inventory_page.opened: return
	if is_instance_valid(shop_ui) and shop_ui.motion(point): return
	if is_instance_valid(dice_selection) and dice_selection.motion(point): return
	if is_instance_valid(tarot_cast) and tarot_cast.active(): return
	if is_instance_valid(relic_ui) and relic_ui.motion(point): return
	if is_instance_valid(tarot_ui) and tarot_ui.motion(point): return
	if pressed_enemy >= 0:
		if not _enemy_hold_rect(pressed_enemy).grow(12).has_point(point): _cancel_enemy_hold()
		return
	if view_phase != "targeting": return
	skill_pointer = point
	if skill_pressed and point.distance_to(skill_press_origin) > (14 if fx.canvas_size.y > fx.canvas_size.x else 8): skill_dragging = true
	hover_target = _target_at(point)

## Resolve a skill drop into casting, saving or cancellation.
func _handle_release(point: Vector2) -> void:
	if is_instance_valid(inventory_page) and inventory_page.opened: return
	if is_instance_valid(shop_ui) and shop_ui.release(point): return
	if is_instance_valid(dice_selection) and dice_selection.release(point): return
	if is_instance_valid(tarot_cast) and tarot_cast.active(): return
	if is_instance_valid(relic_ui) and relic_ui.release(point): return
	if is_instance_valid(tarot_ui) and tarot_ui.release(point): return
	if pressed_enemy >= 0:
		var target: int = pressed_enemy
		var held: bool = inspecting_enemy >= 0
		_cancel_enemy_hold()
		if not held and view_phase == "targeting" and _skill_needs_target() and _enemy_inspect_at(point) == target:
			_activate_skill(target)
		return
	if not skill_pressed: return
	_handle_motion(point)
	var dragged: bool = skill_dragging
	var cast_point: Vector2 = _source_bubble(skill_source).display_center()
	skill_pressed = false
	skill_dragging = false
	if view_phase != "targeting": return
	if not dragged:
		if skill_was_selected or (skill_source == "saved" and not _skill_needs_target()): _cancel_targeting()
		return
	if skill_source == "current" and dice_selection.skill_cancel_rect().has_point(point):
		_cancel_targeting()
		if model.cancel_formed_skill():
			_clear_skill()
			_sound("ui/book",0.85,-20)
			_show_pending_skill(false)
		return
	if Rules.SAVED_SKILLS_ENABLED and skill_source == "current" and _in_saved_slot(point):
		if model.saved_skill.is_empty(): _save_skill()
		else: _cancel_targeting()
		return
	var target: int = _target_at(point)
	if _skill_needs_target():
		if target != -1: _activate_skill(target, cast_point)
		else: _cancel_targeting()
	elif _field_drop_valid(point): _activate_skill(-1, cast_point)
	else: _cancel_targeting()

## Return a held skill to its resting state without spending it.
func _cancel_targeting() -> void:
	_cancel_enemy_hold()
	skill_pressed = false
	skill_was_selected = false
	skill_dragging = false
	hover_target = -1
	if view_phase == "targeting":
		view_phase = skill_return_phase
		status_title = "SKILL READY" if view_phase == "skill" else "FEVER" if model.is_city() else "READY"
	skill_source = "current"

## Bank the current skill and advance its normal turn flow.
func _save_skill() -> void:
	if not model.save_pending_skill():
		_cancel_targeting()
		return
	_cancel_targeting()
	_clear_skill()
	result = MultiHitSkill.new()
	last_result = MultiHitSkill.new()
	fx.activate_circle(_saved_slot_center(), GOLD, _saved_slot_radius()+8, 0.6)
	_sound("player/book", 1.1, -14)
	view_phase = "resolving"
	status_title = "SAVED"
	if not await _resolve_roll_triggers(run_id): return
	if model.phase in ["roll", "player"]: _show_pending_skill()
	else: await _enemy_phase()

## Commit a valid skill target and begin its cast presentation.
func _activate_skill(target: int, cast_point: Vector2 = Vector2.INF) -> void:
	if view_phase not in ["skill", "targeting"] or _menus_open() or not model.outcome().is_empty(): return
	var source: String = skill_source
	var roll: MultiHitSkill = _source_roll(source)
	if roll.is_empty(): return
	if source == "current" and model.phase != "player": return
	if _skill_needs_target() and target not in _skill_targets(): return
	var bubble: Node2D = _source_bubble(source)
	if cast_point == Vector2.INF: cast_point = bubble.display_center()
	_cancel_targeting()
	if source == "saved" and not model.begin_saved_cast(): return
	casting_source = source
	bubble.lock_cast_position(cast_point)
	status_color = PatternStyle.color(roll)
	fx.burst(cast_point, status_color, 20, 150)
	fx.activate_circle(_player_point(), status_color, monster_side*0.4, 0.4,true)
	_sound("player/confirmation_002", 0.85, -18)
	_resolve_player(target, source)

func _begin_cinematic(ultimate: bool) -> void:
	cinematic_ultimate = ultimate
	cinematic_pause = 0
	cinematic_speed = 0.12 if ultimate else 0.25
	cinematic_dim = 0.58 if ultimate else 0.0
	cinematic_recovery = 0.25
	cinematic_duration = 1.65 if ultimate else 0.9
	cinematic_remaining = cinematic_duration
	fx.flash(Color.WHITE, 0.6 if ultimate else 0.42)

func _begin_cast_cinematic(kind: int) -> void:
	# Real-time anticipation stays perceptible at 2x fever speed, including each rapid cast.
	cinematic_ultimate = kind == Rules.Kind.ULTIMATE
	cinematic_pause = [0.06, 0.08, 0.10, SkillBubble.SLAM_IMPACT_TIME][kind]
	cinematic_speed = [0.5, 0.45, 0.3, 0.18][kind]
	cinematic_dim = [0.4, 0.44, 0.52, 0.62][kind]
	cinematic_recovery = 0.18
	cinematic_duration = cinematic_pause + [0.16, 0.20, 0.26, 0.44][kind] + cinematic_recovery
	cinematic_remaining = cinematic_duration
	fx.time_factor = 0

## Compute presentation time scaling with menus and cast pauses accounted for.
func _world_time_scale() -> float:
	if is_instance_valid(tarot_ui) and tarot_ui.ceremony.active(): return 0.0
	if inspecting_enemy >= 0: return 0.0
	var rate: float = 1.0
	if cinematic_remaining > 0 and not (is_instance_valid(damage_feedback) and damage_feedback.building):
		if cinematic_duration-cinematic_remaining < cinematic_pause: return 0.0
		rate = lerpf(cinematic_speed, 1.0, 1.0-clampf(cinematic_remaining/cinematic_recovery,0,1))
	# Immediate impact slowdown, a moving hold, then smooth real-time recovery.
	if kill_slow_remaining > 0:
		var kill_rate: float = KILL_SLOW_SPEED
		if kill_slow_remaining < KILL_SLOW_OUT:
			kill_rate = lerpf(KILL_SLOW_SPEED,1,smoothstep(0,KILL_SLOW_OUT,KILL_SLOW_OUT-kill_slow_remaining))
		rate = minf(rate,kill_rate)
	return rate

## Start a small camera wobble at impact and settle it over the full slowdown.
func _kill_impact_shake() -> Vector2:
	if reduced or _menus_open() or inspecting_enemy >= 0 or kill_slow_remaining <= 0: return Vector2.ZERO
	var progress: float = clampf(1-kill_slow_remaining/KILL_SLOW_DURATION,0,1)
	var envelope: float = 1-smoothstep(0,1,progress)
	return Vector2(sin(progress*TAU)*4,sin(progress*TAU+PI/3)*2)*envelope

func _cinematic_gloom() -> float:
	if cinematic_remaining <= 0: return 0.0
	return cinematic_dim * minf(1, cinematic_remaining/(0.4 if cinematic_pause == 0 else cinematic_recovery))

func _clear_skill() -> void:
	for die in dice: die.clear_auto_attack()
	if is_instance_valid(leftover_volley): leftover_volley.clear()
	if is_instance_valid(dice_selection): dice_selection.cancel_gesture()
	if is_instance_valid(damage_feedback): damage_feedback.clear()
	if is_instance_valid(screen_ripple): screen_ripple.clear()
	_cancel_targeting()
	cinematic_remaining = 0
	cinematic_ultimate = false
	cinematic_pause = 0
	cinematic_speed = 1
	cinematic_dim = 0
	if is_instance_valid(skill_bubble): skill_bubble.clear()
	casting_source = ""
	_sync_saved_bubble()
	if is_instance_valid(fx): fx.time_factor = 1.0

## Begin the timer-based throw meter and charge feedback.
func _start_charge() -> void:
	if view_phase != "ready" or not model.pending.is_empty() or not model.dice_turn.can_roll() or _menus_open() or not model.outcome().is_empty(): return
	throw_meter.reset(model.is_stunned())
	charge_stamp = Time.get_ticks_usec()
	power_lock_until = 0
	view_phase = "charging"
	status_title = "POWER"
	status_color = GOLD
	last_result = MultiHitSkill.new()
	rattle_clock = 0
	for index in model.dice_turn.unused(): dice[index].charge(0)

## Sample the charging timer and update the displayed Perfect indicator.
func _update_charge() -> void:
	var now: int = Time.get_ticks_usec()
	if view_phase == "charging" and not _menus_open():
		# Also sampled at click time, not rounded to the last rendered marker position.
		throw_meter.advance((now - charge_stamp) / 1000000.0)
		for index in model.dice_turn.unused(): dice[index].charge(throw_meter.sample().power)
	charge_stamp = now

## Judge Perfect timing at input time and launch the committed dice roll.
func _release_charge() -> void:
	if view_phase != "charging" or _menus_open(): return
	_update_charge()
	if debug_perfect or model.forces_perfect():
		throw_meter.erratic = false
		throw_meter.elapsed = ThrowMeter.PERIOD / 4.0
	var stopped: Dictionary = throw_meter.sample()
	power_lock_until = clock_time + 0.65
	for die in dice: die.stop_charge()
	view_phase = "ready"
	_roll(stopped.power, stopped.perfect)

## Stop an unfinished charge without consuming the player’s roll.
func _cancel_charge() -> void:
	if view_phase != "charging": return
	for die in dice: die.stop_charge()
	throw_meter.reset()
	power_lock_until = 0
	view_phase = "skill" if not model.pending.is_empty() else "ready"
	status_title = "SKILL READY" if view_phase == "skill" else "READY"
	status_color = TEAL

func _power_meter_visible() -> bool:
	return view_phase == "charging" or (clock_time < power_lock_until and view_phase == "rolling")

func _power_flash_strength() -> float:
	if view_phase != "rolling" or not throw_perfect: return 0.0
	var age: float = clock_time - (power_lock_until - 0.65)
	# One brief white flash on a successful stop, followed by a smooth fade.
	return clampf(1.0 - (age - 0.06) / 0.22, 0, 1)

func _draw_power_meter(rect: Rect2, text_size: int = 16) -> void:
	var stopped: Dictionary = throw_meter.sample()
	var unit: float = rect.size.x / ThrowMeter.WIDTH
	var flash: float = _power_flash_strength()
	_frame(rect.grow(4), PANEL, GOLD.lerp(Color.WHITE, flash))
	for x in range(0, ceili(rect.size.x), 4):
		var central: float = 1.0 - absf(float(x) / rect.size.x - 0.5) * 2
		draw_rect(Rect2(rect.position + Vector2(x, 0), Vector2(minf(4, rect.size.x - x), rect.size.y)), PURPLE.darkened(0.65).lerp(GOLD, central * central))
	var center: float = rect.get_center().x
	draw_rect(Rect2(center - ThrowMeter.perfect_tolerance_pixels() * unit, rect.position.y, 2 * ThrowMeter.perfect_tolerance_pixels() * unit, rect.size.y), CREAM)
	if flash > 0: draw_rect(rect, Color(1, 1, 1, flash))
	# Center the successful stop feedback, while charging stays continuous.
	var marker_ratio: float = 0.5 if view_phase == "rolling" and throw_perfect else stopped.position
	var marker: float = rect.position.x + marker_ratio * rect.size.x
	draw_rect(Rect2(marker - unit * 5, rect.position.y - 6, unit * 10, rect.size.y + 12), INK)
	draw_rect(Rect2(marker - unit * 3, rect.position.y - 4, unit * 6, rect.size.y + 8), GOLD.lerp(Color.WHITE, flash))
	_center(Vector2(center, rect.position.y - 12), GameText.format("POWER %d%%", roundi(stopped.power * 100)), text_size, GOLD)

## Interpolate visual sizes across wave growth and transitions.
func _stage_size(sizes: Array) -> float:
	var stage: float = clampf(visual_stage / float(Run.WAVE_NAMES.size()-1) * (sizes.size()-1), 0, sizes.size()-1)
	var index: int = floori(stage)
	return lerpf(sizes[index], sizes[mini(index+1,sizes.size()-1)], stage-index)

func _enemy_side() -> float:
	return _stage_size(HUMAN_SIZES)

## Reserve indicator and health lanes while keeping the formation compact.
func _enemy_layout_feet(index: int) -> Vector2:
	return preload("res://scripts/enemies/enemy_formation.gd").feet(ARENA,index,model.enemies.size(),_enemy_side(),false)

## Move an incoming wave across the ground with the scrolling scenery.
func _enemy_world_feet(index: int) -> Vector2:
	return _enemy_layout_feet(index)+_arrival_offset()

## Share the selected route's entry path between enemy formations and the shopkeeper.
func _arrival_offset() -> Vector2:
	return BattlefieldView.entrance_translation(ARENA,travel_progress,travel_direction) if view_phase == "transition" else Vector2.ZERO

func _enemy_feet(index: int) -> Vector2:
	return battlefield_view.transform*_enemy_world_feet(index)

func _enemy_world_point(index: int) -> Vector2:
	return _enemy_world_feet(index)-Vector2(0,_enemy_side()*0.48)

func _enemy_point(index: int) -> Vector2:
	return battlefield_view.transform*_enemy_world_point(index)

func _enemy_impact_point(index: int) -> Vector2:
	var point: Vector2 = _enemy_point(index)
	if model.is_enemy_alive(index): return point
	var fall: float = minf(1,fallen.get(index,0.0)/0.3)
	return point.lerp(battlefield_view.transform*(_enemy_world_feet(index)-Vector2(0,_enemy_side()*0.08)),fall)

func _player_world_feet() -> Vector2:
	return Vector2(259, 414)

func _player_feet() -> Vector2:
	return battlefield_view.transform*_player_world_feet()

func _player_point() -> Vector2:
	return battlefield_view.transform*(_player_world_feet()-Vector2(0,monster_side*0.48))

func _player_growth_scale() -> Vector2:
	return CombatMotion.growth_scale(travel_progress,reduced) if view_phase == "transition" else Vector2.ONE

func _player_sprite_rect(dx: float = 0, bob: float = 0) -> Rect2:
	return battlefield_view.transform*_player_world_sprite_rect(dx,bob)

func _player_world_sprite_rect(dx: float = 0, bob: float = 0) -> Rect2:
	var size: Vector2 = Vector2.ONE*monster_side*_player_growth_scale()
	# Keep growth grounded; ordinary idle bob and hit recoil still use their own offsets.
	var feet: Vector2 = _player_world_feet()+Vector2(dx,0 if view_phase == "transition" else bob)
	return Rect2(feet-Vector2(size.x/2,size.y),size)

func _city_gate_point() -> Vector2:
	return City.gate_point()

func _city_wall_point(section: float) -> Vector2:
	return City.wall_point(section)

func _roll_speed() -> float:
	return 2.0 if model.is_city() else speed

## Reset round presentation and expose the next player action.
func _start_round() -> void:
	_clear_skill()
	_show_events(model.begin_round())
	result = MultiHitSkill.new()
	view_phase = "ready"
	status_title = "FEVER" if model.is_city() else "READY"
	status_color = GOLD if model.is_city() else TEAL
	active_human = -1
	attack_target = -1
	if model.phase == "frozen":
		view_phase = "frozen"
		status_title = "FROZEN"
		status_color = Statuses.ENTRIES[Status.FROZEN].color

func _ice_rect() -> Rect2:
	var radius: float = DICE_RADIUS+8
	return Rect2(DICE_CENTER-Vector2.ONE*radius,Vector2.ONE*radius*2)

func _player_ice_rect() -> Rect2:
	return battlefield_view.transform*_player_world_ice_rect()

func _player_world_ice_rect() -> Rect2:
	return Rect2(_player_world_feet()+Vector2(-monster_side*0.5,-monster_side*0.93),Vector2(monster_side,monster_side*0.95))

## Count manual ice-breaking taps and finish the frozen turn on the third hit.
func _hit_ice(point: Vector2) -> void:
	if view_phase != "frozen" or _menus_open(): return
	var token: int = run_id
	var events: Array = model.break_ice()
	if events.is_empty(): return
	fx.burst(point,Color("b9f2ff"),12,140)
	_sound("player/crash",1.7,-21)
	if model.is_frozen(): return
	_show_events(events)
	view_phase = "resolving"
	if model.is_city():
		if not await _resolve_turn_end(token): return
		_start_round()
	else: await _enemy_phase()

func _debug_values() -> Array:
	if debug_choice < 0: return []
	var count: int = model.dice_turn.unused().size()
	if debug_choice == 0: return range(1,count+1)
	if debug_choice > 6:
		var values: Array = []
		values.resize(count)
		values.fill(debug_choice-6)
		return values
	var values: Array = []
	for i in range(count): values.append(debug_choice if i < 2 else 1+(debug_choice+i-2)%6)
	return values

func _roll(strength: float = 0.0, perfect: bool = false, free: bool = false) -> void:
	if view_phase not in ["ready", "skill"] or _menus_open() or not model.outcome().is_empty(): return
	var token: int = run_id
	throw_power = clampf(strength, 0, 1)
	throw_perfect = perfect or debug_perfect or model.forces_perfect()
	if throw_perfect: throw_power = 1.0
	var forced: Array = _debug_values()
	var changed: Array = model.roll_pool(throw_perfect, forced, free)
	if changed.is_empty(): return
	view_phase = "rolling"
	combo_flash_until = clock_time + 0.45 if throw_perfect else 0.0
	if not debug_repeat: debug_choice = -1
	status_title = "ROLLING"
	status_color = CREAM
	fx.activate_circle(DICE_CENTER, GOLD, DICE_RADIUS, 0.8 / _roll_speed())
	_sound("dice/soft_sweep", 1.0, lerpf(-21, -8, throw_power))
	if throw_perfect:
		_sound("dice/perfect", 1.0, -14)
		fx.reveal_perfect(DICE_CENTER - Vector2(0, DICE_RADIUS * 0.62))
		fx.burst(DICE_CENTER, GOLD, 35, 200)
	# Normal throws sweep counterclockwise; Perfect dice share one landing time.
	var reveal_order: int = 0
	for step in range(dice.size()):
		var index: int = posmod(-step,dice.size())
		if index not in changed: continue
		dice[index].roll_to(model.dice_turn.values[index], reveal_order, speed, throw_power, throw_perfect)
		reveal_order += 1
	while dice.any(func(die): return die.rolling):
		await get_tree().process_frame
		if not _valid_turn(token): return
	# Let every revealed face read before queued matches fire; fast-forward keeps this pause.
	if not model.roll_attacks.is_empty() and not await _wait(AUTO_ATTACK_REVEAL_PAUSE,token,true): return
	if not await _resolve_roll_triggers(token): return
	_show_pending_skill(false)

## Finish roll and formation procs before accepting the next player action.
func _resolve_roll_triggers(token: int) -> bool:
	while model.perfect_relic_ready:
		var relic_speed: float = model.roll_relic_animation_speed()
		_show_events(model.resolve_roll_relic_step())
		if not await _wait(0.25/relic_speed,token): return false
		if _check_over(): return false
	while not model.roll_attacks.is_empty() and model.phase == "roll_attacks":
		var group: Dictionary = model.roll_attacks[0]
		var auto: MultiHitSkill = group.skill
		var target: int = model.roll_attack_target()
		if target < 0: break
		if auto.uses_spent == 0:
			for index in group.indices:
				dice[index].auto_attack_active = true
				dice[index].pulse_auto_attack()
			# Let the matching group bounce before the player starts firing.
			if not await _wait(0.24,token): return false
		var firing_die = dice[group.indices[auto.uses_spent % group.indices.size()]]
		firing_die.pulse_auto_attack()
		var origin: Vector2 = _player_point()
		combat_motion.attack(-1)
		var destination: Vector2 = _enemy_impact_point(target)
		var hit_speed: float = minf(MULTI_HIT_SPEED_CAP,1.0+auto.uses_spent*MULTI_HIT_SPEED_GAIN)
		var damage: int = model.attack_damage(auto,target)
		fx.flame_cast(0,origin,[destination],AUTO_ATTACK_TRAVEL/(_roll_speed()*hit_speed),[damage])
		_sound("player/slash",1.6,-22)
		if not await _wait(AUTO_ATTACK_TRAVEL*0.55/hit_speed,token): return false
		fx.attack_burst(_enemy_impact_point(target),Color("ffb057"),damage,5 if reduced else 10,95)
		_show_events(model.resolve_roll_attack_step())
		if auto.uses_left() == 0:
			for index in group.indices: dice[index].auto_attack_active = false
		_sound("player/hit",1.35,-20)
		if _check_over(): return false
		if not await _wait(AUTO_ATTACK_RECOVERY/hit_speed,token): return false
	return not _check_over()

## Summon the selected pattern without spending the remaining dice.
func _form_selected_skill() -> void:
	if view_phase not in ["ready", "skill"] or _menus_open(): return
	var formed: MultiHitSkill = model.form_selected_skill()
	if formed.is_empty(): return
	view_phase = "forming"
	var token: int = run_id
	if not await _resolve_roll_triggers(token): return
	_sound("dice/confirmation_002",1.1,-12)
	_show_pending_skill(true)

## Restore the active skill bubble after rolling, cancellation or spending a skill.
func _show_pending_skill(animate: bool = true) -> void:
	result = model.pending.duplicate(true)
	if result.is_empty():
		skill_bubble.clear()
		view_phase = "ready"
		status_title = "READY" if not model.dice_turn.has_rolled() else "SELECT DICE"
		return
	skill_bubble.begin(result)
	if animate:
		view_phase = "forming"
		var token: int = run_id
		while skill_bubble.age < skill_bubble.formation:
			await get_tree().process_frame
			if not _valid_turn(token): return
	else: skill_bubble.age = skill_bubble.formation
	view_phase = "skill"
	status_title = "SKILL READY"
	status_color = PatternStyle.color(result)

func _combo_chime(ultimate: bool, token: int) -> bool:
	for pitch in [1.0, 1.25, 1.5, 2.0]:
		_sound("dice/pluck_001", pitch * (0.75 if ultimate else 1.0), -14)
		if not await _wait(0.09, token): return false
	return true

## Build the skill name, description and value preview for its bubble.
func _skill_caption(roll: MultiHitSkill) -> Dictionary:
	if roll.pattern == "straight": return Rules.CharacterSkills.caption(roll)
	if roll.pattern == "cleanup": return {"name":"Healing Embers","description":"End Turn: leftover pip sum x 1% of maximum HP is restored. Darkness blocks healing."}
	if roll.is_freeze():
		var stacks: int = roundi(model.tarot_effects.skill_factor(roll))
		var description: String = GameText.text("City is immune to freeze.") if model.is_city() else GameText.format("Freeze all: %d stack. No attack." if stacks == 1 else "Freeze all: %d stacks. No attack.",stacks)
		return {"name": Rules.PAIR_NAMES[1], "description": description}
	var label: String = Rules.NORMAL_NAME
	var description: String = "attack"
	if roll.kind == Rules.Kind.PAIR:
		label = Rules.PAIR_NAMES[roll.face - 1]
		var spare_text: String = str(roll.spare * Rules.DAMAGE_PER_PIP) if roll.face in [1,4,5] else str(roll.spare)
		var template: String = ["attack x1.5 +%s", "", "DMG +0.5 for %s attacks", "attack all +%s", "random attack +%s", "invincible for %s turns"][roll.face - 1]
		if model.is_city() and roll.face == 5: template = "city attack +%s"
		description = GameText.format(template,spare_text)
		if model.is_city() and roll.face == 6: description = GameText.format("invincible for %d seconds",roll.spare*2)
	elif roll.kind >= Rules.Kind.SPECIAL:
		label = Rules.SPECIAL_NAMES[roll.face - 1]
		description = ["instant kill", "full heal", "DMG +2.0 for 3 attacks", "attack all x2", "random attack", ""][roll.face - 1]
		if model.is_city() and roll.face == 1: description = "attack x5"
	if model.is_city() and roll.kind >= Rules.Kind.SPECIAL and roll.face == 5: description = "city attack"
	var factor: float = model.tarot_effects.skill_factor(roll)
	if not Rules.is_attack(roll) and factor > 1:
		if roll.face == 3: description = GameText.format("DMG +%.1f for %d attacks",[(0.5 if roll.kind == Rules.Kind.PAIR else 2.0)*factor,roll.spare if roll.kind == Rules.Kind.PAIR else 3])
	return {"name": label, "description": description}

## Describe the bonus gained by refreshing an already active support effect.
func _skill_reapply_bonus(roll: MultiHitSkill) -> String:
	if not roll.pattern.is_empty(): return ""
	var id: int = roll.face if roll.kind == Rules.Kind.PAIR else Status.ASCENSION if roll.kind == Rules.Kind.SPECIAL and roll.face == 3 else -1
	if model.status_count(id) <= 0: return ""
	match id:
		Status.MIGHT, Status.ASCENSION: return GameText.format("Recast: %d-base shockwave.",10 if id == Status.MIGHT else 50)
		Status.IMMUNITY: return GameText.text("Recast extends duration.")
	return ""

## Accent each landing with a rising chime and a small burst.
func _die_landed(index: int) -> void:
	if not throw_perfect or dice[index].reveal_order == 0:
		_sound("dice/drop_001", 0.95 + dice[index].reveal_order * 0.13 - throw_power * 0.25, -17 + throw_power * 7)
	fx.burst(dice[index].position + Vector2(0, 35), GOLD, roundi(12 + throw_power * 18), 90 + throw_power * 70)

## Animate every use of a committed skill before ending its action.
func _resolve_player(target: int, source: String = "current") -> void:
	if model.phase != "player" or model.pending.is_empty() or view_phase == "resolving" or not model.outcome().is_empty(): return
	var token: int = run_id
	if not model.begin_player_cast(target): return
	var roll: MultiHitSkill = model.pending.duplicate()
	var bubble: Node2D = _source_bubble(source)
	bubble.roll = roll.duplicate()
	view_phase = "resolving"
	if not await _resolve_roll_triggers(token): return
	var kind: int = roll.kind
	var attacking: bool = Rules.is_attack(roll)
	status_title = "CASTING" if kind >= Rules.Kind.SPECIAL else "ATTACKING" if attacking else "BLESSED"
	# A cast starts consuming its visual use budget immediately; damage still
	# waits for the modifier buildup and impact animation below.
	bubble.consume_use()
	if attacking and not model.is_instant_kill(roll):
		damage_feedback.start(model.attack_damage_steps(roll))
		while damage_feedback.building:
			await get_tree().process_frame
			if not _valid_turn(token): return
	_begin_cast_cinematic(kind)
	if kind == Rules.Kind.ULTIMATE:
		bubble.begin_slam()
		# Presentation time keeps the slam readable during fever and fast-forward.
		while bubble.slam_age < SkillBubble.SLAM_IMPACT_TIME:
			await get_tree().process_frame
			if not _valid_turn(token): return
		screen_ripple.trigger(bubble.cast_position)
		fx.ring(bubble.cast_position, GOLD, _skill_radius() * 2.0)
		fx.burst(bubble.cast_position, GOLD, 16 if reduced else 48, 240)
		shake = 0.0 if reduced else 14.0*ATTACK_SHAKE_SCALE
		_sound("player/crash", 0.55, -12)
	var count: int = model.skill_use_count(roll)
	for impact in range(count):
		roll = model.pending.duplicate()
		# Local to this cast: gradually compress both travel and recovery, while
		# preserving every impact and the player's existing speed setting.
		var hit_speed: float = minf(MULTI_HIT_SPEED_CAP,1.0+impact*MULTI_HIT_SPEED_GAIN) if attacking and count > 1 else 1.0
		if attacking:
			damage_feedback.sync_value(model.cast_damage_multiplier(roll))
		if impact > 0: bubble.consume_use()
		if not attacking:
			if roll.is_freeze():
				var ice: Color = Statuses.ENTRIES[Status.FROZEN].color
				fx.ring(_player_point(),ice,ARENA.size.x,ARENA)
				for enemy in model.living(): fx.burst(_enemy_impact_point(enemy),ice,18,120)
			else:
				var support_color: Color = TEAL
				fx.activate_circle(_player_point(), support_color, monster_side * 0.45, 0.85)
				fx.burst(_player_point(), support_color, 30)
			_sound("player/bell", 1.6, -16)
			if not await _wait(0.3, token): return
			_show_events(model.apply_player_step())
		else:
			target = model.player_target()
			attack_target = target
			var targets: Array = [CITY_POINT] if model.is_city() else []
			var damages: Array = [0 if model.is_instant_kill(roll) else model.attack_damage(roll)] if model.is_city() else []
			if not model.is_city():
				for hit in model.preview(roll, target):
					targets.append(_enemy_impact_point(hit.target))
					damages.append(0 if hit.ignore else hit.damage)
			var face: int = roll.face if kind >= Rules.Kind.SPECIAL or kind == Rules.Kind.PAIR else 0
			var flame_tier: int = roll.dice.size()-2 if roll.pattern == "straight" else 0
			var duration: float = 0.18 if count > 1 else 1.6 if kind == Rules.Kind.ULTIMATE else 0.7 if kind >= Rules.Kind.SPECIAL else 0.38
			if flame_tier > 0: duration = [0.0,0.46,0.57,0.78,1.1][flame_tier]
			duration /= hit_speed
			combat_motion.attack(-1)
			if flame_tier > 0: fx.flame_cast(flame_tier,_player_point(),targets,duration/_roll_speed(),damages)
			else: fx.cast(face, _player_point(), targets, duration / _roll_speed(),true,true)
			var world_impacts: Array = targets.map(func(point): return battlefield_view.transform.affine_inverse()*point)
			_sound("player/slash", 1.0 + impact * 0.08 if count > 1 else 0.8, -9)
			if kind >= Rules.Kind.SPECIAL and impact == 0: _sound("player/rumble", 0.5 if kind == Rules.Kind.ULTIMATE else 0.8, -12)
			if not await _wait(duration * 0.55, token): return
			if not model.outcome().is_empty(): return
			for i in range(world_impacts.size()):
				fx.attack_burst(battlefield_view.transform*world_impacts[i],PatternStyle.color(roll),damages[i],(6+flame_tier*9) if flame_tier > 0 else 14,90+flame_tier*40)
			if kind >= Rules.Kind.SPECIAL and impact == 0: fx.flash(status_color, 0.12)
			shake = (2.0+flame_tier*2.0 if flame_tier > 0 else 3.0)*ATTACK_SHAKE_SCALE if not reduced else 0.0
			_sound("player/crash" if kind == Rules.Kind.ULTIMATE else "player/hit", 0.65 + impact * 0.08 if kind >= Rules.Kind.SPECIAL else 1.0, -9)
			_show_events(model.apply_player_step(target))
		if model.phase != "executing": break
		if not await _wait(0.12/hit_speed, token): return
	damage_feedback.finish()
	bubble.dissolve()
	# The particle finish uses presentation time so it stays readable at fever speed.
	while bubble.dissolving and bubble.dissolve_age < bubble.DISSOLVE_TIME:
		await get_tree().process_frame
		if not _valid_turn(token): return
	if not await _wait(0.25 if kind == Rules.Kind.ULTIMATE else 0.05, token): return
	attack_target = -1
	if model.phase == "turn_end" and not await _resolve_turn_end(token): return
	if _check_over(): return
	bubble.clear()
	casting_source = ""
	if source == "saved":
		view_phase = "skill" if model.phase == "player" else "ready"
		status_title = "SKILL READY" if view_phase == "skill" else "FEVER" if model.is_city() else "READY"
		status_color = PatternStyle.color(result) if not result.is_empty() else GOLD if model.is_city() else TEAL
		return
	if model.phase in ["roll", "player"]:
		_show_pending_skill()
	elif model.is_city():
		result = MultiHitSkill.new()
		view_phase = "ready"
		status_title = "FEVER"
	else:
		await _enemy_phase()

## Play each enemy’s locked move and its individual impacts in order.
func _enemy_phase() -> void:
	view_phase = "resolving"
	var token: int = run_id
	status_color = RED
	for i in range(model.enemies.size()):
		if model.enemies[i].hp <= 0: continue
		active_human = i
		var human: Dictionary = model.enemies[i]
		status_title = "ENEMY TURN"
		if not await _wait(0.12, token): return
		while not human.acted and human.hp > 0 and model.phase == "enemy":
			var immobilized: bool = model.enemy_cannot_act(i) and human.get("action_hit",0) == 0
			var attacking: bool = human.intent.get("type","") == "attack"
			if not human.canceled and model.status_count(Status.HIDDEN) == 0 and not immobilized and attacking:
				combat_motion.attack(i)
				fx.enemy_cast(human.role,_enemy_point(i),_player_point(),0.22/speed,human.intent.get("attribute",Status.Attribute.NONE))
				_sound("enemy/bell" if human.role in [2,4] else "enemy/slash",1.4,-17)
				if not await _wait(0.18,token): return
			var events: Array = model.enemy_act_step(i)
			if not human.canceled and not immobilized and not attacking and not events.is_empty():
				for event in events:
					if event.target >= 0: fx.activate_circle(_enemy_point(event.target),PURPLE if human.intent.type in ["empower","team_empower","charge"] else TEAL,maxf(12,_enemy_side()*0.22),0.4)
				_sound("enemy/bell",1.7,-20)
			_show_events(events)
			if not await _wait(0.24,token): return
			if _check_over(): return
	active_human = -1
	if not await _resolve_turn_end(token): return
	_start_round()

## Present status ticks and relic procs before checking the completed turn.
func _resolve_turn_end(token: int) -> bool:
	while model.phase in ["enemy", "turn_end"]:
		if not _valid_turn(token): return false
		var events: Array = model.end_round_step()
		# An incomplete enemy phase must return to its caller, never spin here.
		if model.phase == "enemy": return false
		_show_events(events)
		if not events.is_empty():
			status_title = "BURNING"
			if not await _wait(0.18, token): return false
		if _check_over(): return false
	return _valid_turn(token)

## Allow treasure claims only when no combat action is still resolving.
func _can_claim_chest() -> bool:
	if model.chest_tier() == 0 or _menus_open(): return false
	if view_phase == "over": return true
	# This also blocks claims between individual casts of a multi-use skill.
	return view_phase == "ready" and model.pending.is_empty() and skill_bubble.roll.is_empty()

func _pick_reward(point: Vector2) -> void:
	var index: int = chest.pickup_at(point)
	if index < 0: return
	if not _claim_chest_reward(index) and model.reward_item(index).has("relic_id"):
		relic_ui.chest_slot = index
		inventory_page.open("chest")

## Collect, replace or discard one locked chest prize through the model.
func _claim_chest_reward(index: int, replace_index: int = -1, discard: bool = false) -> bool:
	if not discard and model.reward_item(index).get("id","") == "tarot": return tarot_ui.begin_reward("chest",index)
	var previous_ids: Array = model.relics.items.map(func(relic): return relic.id)
	var item: Dictionary = model.claim_reward(index,replace_index,discard)
	if item.is_empty(): return false
	chest.collected.append(index)
	if not discard: chest.celebrate(index)
	if not discard and item.has("relic_id"):
		var replacing: bool = relic_ui.chest_slot >= 0
		var origin: Vector2 = Vector2(fx.canvas_size.x/2,620 if relic_ui.portrait() else 280) if replacing else chest.reel_rect(index).get_center()
		relic_ui.collect(item.relic_id,origin,80 if replacing else chest.reel_rect(index).size.x*0.305,previous_ids)
	fx.reveal_skill(item.name,GameText.format(item.text,item.text_values) if item.has("text_values") else item.text,item.color)
	_sound("item/rumble" if item.id == "curse" else "item/confirmation_002", 0.65 if item.id == "curse" else 1.0, -12)
	return true

## Run the shared chest flow for reroll, wave, victory and debug rewards.
func _reward_sequence(tier: int = 0, automatic: bool = false, bonus: bool = false, wave: bool = false) -> void:
	if wave:
		if view_phase != "wave_reward": return
	elif automatic:
		if view_phase != "over" or model.outcome() != "victory" or model.open_rewards.is_empty(): return
	elif bonus:
		if view_phase not in ["ready","skill"]: return
	elif not _can_claim_chest(): return
	var outcomes: Array = model.open_wave_chest() if wave else model.open_rewards.duplicate() if automatic else model.open_bonus_chest() if bonus else model.open_chest(tier)
	if outcomes.is_empty(): return
	await _show_chest(outcomes,wave,wave)

## Pass locked rewards and tier information into the cosmetic chest presentation.
func _show_chest(outcomes: Array, upgrades: bool = false, auto_open: bool = false) -> void:
	var token: int = run_id
	var previous_phase: String = view_phase
	var previous_title: String = status_title
	view_phase = "reward"
	status_title = "TREASURE"
	fx.skill.clear()
	fx.floats.clear()
	fx.sigils.clear()
	fx.z_index = 90
	var prizes: Array = []
	for slot in range(outcomes.size()): prizes.append(model.reward_item(slot))
	chest.start(outcomes, fx.canvas_size, description_font, reduced, prizes, model.opened_chest_tier, upgrades, model.chest_pity.last_misses)
	if auto_open: chest.open_chest()
	while chest.active or not model.rewards_collected() or relic_ui.pickup.active or tarot_ui.ceremony.active() or crystal_pickup.pending_total > 0:
		await get_tree().process_frame
		if not _valid_turn(token): return
	if not chest.skip_requested and not await _wait(0.45 * _roll_speed(), token): return
	model.close_chest()
	chest.cancel()
	fx.z_index = 0
	view_phase = previous_phase
	status_title = previous_title

## Record newly defeated enemies without duplicating death visuals.
func _sync_corpses() -> void:
	for i in range(model.enemies.size()):
		if model.enemies[i].hp <= 0 and not fallen.has(i):
			fallen[i] = 0.0
			kill_slow_remaining = KILL_SLOW_DURATION
			shake = 0
			if not enemy_debris.spawn(i,model.enemies[i],_enemy_world_sprite_rect(i),ARENA,reduced):
				fx.burst(_enemy_point(i), Color("b9857c"), 14, 80)
			_sound("enemy/chop", 0.7, -15)

## Detect defeat or a cleared wave and start the matching reward transition.
func _check_over() -> bool:
	# Finish both sides' status ticks before treating a damage-over-time kill as
	# victory. Otherwise the relic screen can interrupt player burning midway.
	if model.phase == "turn_end" and model.hp > 0: return false
	var outcome: String = model.outcome()
	if outcome.is_empty(): return false
	if is_instance_valid(tarot_ui): tarot_ui.close_inventory()
	if view_phase in ["over", "reward", "wave_reward", "collecting", "shop"]: return true
	_clear_skill()
	if outcome == "wave_clear":
		if view_phase not in ["feeding", "transition"]: _advance_wave()
		return true
	if outcome == "victory":
		_finish_victory(run_id)
		return true
	view_phase = "over"
	for die in dice: die.stop_charge()
	active_human = -1
	_sound("player/rumble", 0.5, -13)
	return true

## Present the chosen wave reward as a chest that opens on the battlefield.
func _offer_wave_rewards(token: int) -> bool:
	if model.wave_kind == Run.WaveRewards.SHOP: return _valid_turn(token)
	view_phase = "collecting"
	while crystal_pickup.pending_total > 0:
		await get_tree().process_frame
		if not _valid_turn(token): return false
	if not model.begin_wave_reward(): return _valid_turn(token)
	view_phase = "wave_reward"
	status_title = "WAVE CLEARED"
	relic_ui.reset()
	wave_chest.present_chest(model.wave_kind)
	while wave_chest.phase == "closed":
		await get_tree().process_frame
		if not _valid_turn(token): return false
	while wave_chest.age < wave_chest.SHAKE_SECONDS:
		await get_tree().process_frame
		if not _valid_turn(token): return false
	if model.wave_kind == Run.WaveRewards.RELIC:
		chest.size = fx.canvas_size
		wave_chest.begin_lift()
		while wave_chest.age < wave_chest.LIFT_SECONDS:
			await get_tree().process_frame
			if not _valid_turn(token): return false
		wave_chest.cancel()
		await _reward_sequence(0,false,false,true)
	else:
		var before_souls: int = model.souls
		var before_level: int = model.character_level
		var amount: int = model.claim_wave_resource()
		wave_chest.reveal_amount(amount)
		var origin: Vector2 = wave_chest.chest_rect().get_center()
		fx.burst(origin,Run.WaveRewards.COLORS[model.wave_kind],48,180)
		_sound("enemy/bell",1.2,-12)
		if model.wave_kind == Run.WaveRewards.BLOOD_GEMS: crystal_pickup.enqueue_chest(origin,amount)
		else: soul_pickup.enqueue(origin,amount,before_souls,before_level)
		if not await _wait(1.4,token): return false
		while crystal_pickup.pending_total > 0 or not soul_pickup.orbs.is_empty() or evolution.active():
			await get_tree().process_frame
			if not _valid_turn(token): return false
	if not _valid_turn(token): return false
	model.finish_wave_reward()
	wave_chest.cancel()
	return true

## Latch route direction only when the model accepts the destination.
func _select_route(index: int) -> void:
	if model.choose_route(index): travel_direction = BattlefieldView.route_direction(index)

## Keep route input on the arena while inventory and settings remain accessible.
func _choose_next_route(token: int) -> bool:
	view_phase = "wave_reward"
	wave_chest.present_routes(model.offer_routes())
	while model.next_route.is_empty():
		await get_tree().process_frame
		if not _valid_turn(token): return false
	wave_chest.cancel()
	return true

func _finish_victory(token: int) -> void:
	if not await _offer_wave_rewards(token): return
	view_phase = "over"
	for die in dice: die.stop_charge()
	active_human = -1
	auto_claim_tier = model.auto_claim_victory_chest()
	auto_claim_remaining = AUTO_CLAIM_DURATION if auto_claim_tier > 0 else 0.0
	fx.activate_circle(CITY_POINT, GOLD, 200, 1.5)
	fx.burst(CITY_POINT, GOLD, 120, 320)
	_sound("enemy/crash", 0.55, -8)
	_sound("enemy/bell", 0.65, -12)
	if auto_claim_tier > 0: _victory_rewards(token)

func _victory_rewards(token: int) -> void:
	# Let the success screen and claim notice land before opening the reels.
	while auto_claim_remaining > 0 or _menus_open():
		await get_tree().process_frame
		if token != run_id or not is_inside_tree() or view_phase != "over": return
	if token == run_id and is_inside_tree(): _reward_sequence(0, true)

## Visit checkpoint shops after rewards, then resume the normal wave transition.
func _visit_shop(token: int) -> bool:
	if not model.shop.open(model): return _valid_turn(token)
	view_phase = "shop"
	shake = 0
	kill_slow_remaining = 0
	tarot_ui.close_inventory()
	relic_ui.cancel_hold()
	wave_chest.enter_shop()
	while wave_chest.age < 0.45:
		await get_tree().process_frame
		if not _valid_turn(token): return false
	wave_chest.cancel()
	shop_ui.open()
	shop_ui.modulate.a = 0
	create_tween().tween_property(shop_ui,"modulate:a",1.0,0.25)
	bonus_turn_banner.play("Shop")
	while model.shop.active or relic_ui.pickup.active:
		await get_tree().process_frame
		if not _valid_turn(token): return false
	shop_ui.cancel()
	bonus_turn_banner.clear()
	return true

## Animate feeding and growth before starting the next wave.
func _advance_wave() -> void:
	bonus_turn_banner.clear()
	var token: int = run_id
	if not await _offer_wave_rewards(token): return
	if not await _choose_next_route(token): return
	var leaving_shop: bool = model.wave_kind == Run.WaveRewards.SHOP
	view_phase = "feeding"
	status_title = "FEEDING"
	status_color = RED
	active_human = -1
	_sync_corpses()
	if not await _wait(0.08 if leaving_shop else 0.65, token): return
	for i in fallen:
		fx.feed(_enemy_feet(i) - Vector2(0,_enemy_side()*0.1), _player_point(), 0.85 / speed)
	fx.activate_circle(_player_point() + Vector2(0, 50), RED, 118, 1.2 / speed)
	_sound("player/rumble", 0.55, -10)
	transition_tween = create_tween()
	transition_tween.tween_property(self, "corpse_alpha", 0.0, 0.08 if leaving_shop else 1.2 / speed)
	while transition_tween.is_running() and _valid_turn(token):
		await get_tree().process_frame
	if not _valid_turn(token): return
	if not model.advance_wave(): return
	combat_motion.clear()
	fallen.clear()
	enemy_debris.clear()
	city_corpses.clear()
	city_life.clear()
	corpse_alpha = 1
	fx.burst(_player_point(), RED, 42, 140)
	view_phase = "transition"
	status_title = "ADVANCING"
	travel_progress = 0
	if model.wave_kind == Run.WaveRewards.SHOP: wave_chest.present_keeper()
	transition_tween = create_tween().set_parallel(true)
	transition_tween.tween_property(self, "monster_side", HORROR_SIZES[model.stage], 1.65 / speed).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "visual_stage", float(model.stage), 1.65 / speed).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "background_offset", background_offset + 960*travel_direction.x, 1.65 / speed).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "background_vertical_offset", background_vertical_offset + 960*travel_direction.y, 1.65 / speed).set_trans(Tween.TRANS_SINE)
	transition_tween.tween_property(self, "travel_progress", 1.0, 1.65 / speed).set_trans(Tween.TRANS_SINE)
	while transition_tween.is_running() and _valid_turn(token):
		await get_tree().process_frame
	if not _valid_turn(token): return
	if model.wave_kind == Run.WaveRewards.SHOP:
		if not await _visit_shop(token): return
		if model.outcome() == "victory": _finish_victory(token)
		else: _advance_wave()
		return
	_start_round()
	fx.activate_circle(_player_point() + Vector2(0, 60), GOLD, 100, 0.7)

## Reset run state and all pending presentation at the requested wave.
func _restart(wave_number: int = 1) -> void:
	if is_instance_valid(inventory_page): inventory_page.close(false)
	skill_counter_flash_until = 0
	battlefield_view.reset()
	kill_slow_remaining = 0
	bonus_turn_banner.clear()
	run_id += 1
	if is_instance_valid(shop_ui): shop_ui.cancel()
	if is_instance_valid(crystal_pickup): crystal_pickup.reset()
	if is_instance_valid(soul_pickup): soul_pickup.reset()
	if is_instance_valid(relic_ui): relic_ui.reset()
	if is_instance_valid(tarot_ui): tarot_ui.reset()
	if is_instance_valid(tarot_cast): tarot_cast.reset()
	_clear_skill()
	chest.cancel()
	wave_chest.cancel()
	auto_claim_tier = 0
	auto_claim_remaining = 0
	fx.z_index = 0
	if transition_tween and transition_tween.is_running(): transition_tween.kill()
	model.load_debug_wave(wave_number)
	combat_motion.clear()
	fx.clear()
	last_result = MultiHitSkill.new()
	result = MultiHitSkill.new()
	fallen.clear()
	city_corpses.clear()
	city_life.clear()
	corpse_alpha = 1
	visual_stage = model.stage
	enemy_debris.clear()
	monster_side = HORROR_SIZES[model.stage]
	evolution.reset()
	background_offset = model.stage * 960
	background_vertical_offset = 0
	travel_direction = Vector2.RIGHT
	travel_progress = 0
	throw_meter.reset()
	throw_power = 0
	throw_perfect = false
	combo_flash_until = 0
	power_lock_until = 0
	guide = false
	menu_open = false
	active_touch = -1
	debug_open = false
	debug_choice = -1
	debug_repeat = false
	debug_wave_error = ""
	debug_wave_input.hide()
	debug_wave_input.release_focus()
	shake = 0
	get_viewport().canvas_transform = Transform2D.IDENTITY
	hit_times.fill(0.0)
	for i in range(dice.size()):
		dice[i].stop_charge()
		dice[i].rolling = false
		dice[i].position = DICE_POSITIONS[i]
		dice[i].rotation = 0
		dice[i].face = i + 1
		dice[i].glow = 0
		dice[i].marked = false
	_start_round()

## Format actual calculated damage while suppressing instant-kill numbers.
static func _damage_popup(event: Dictionary) -> String:
	return "" if event.get("instant_kill",false) else "-%d" % event.get("display_amount",event.amount)

static func _event_font_size(event: Dictionary) -> int:
	return Effects.damage_font_size(event.get("display_amount",event.amount)) if event.type in ["damage","burn","shield_hit"] else Effects.FLOAT_FONT_SIZE

## Translate model combat events into damage numbers, sounds and character effects.
func _show_events(events: Array) -> void:
	var offsets: Dictionary = {}
	for event in events:
		if event.type == "bonus_skill":
			skill_counter_flash_until = clock_time+0.35
			fx.floating(battlefield_view.transform*_character_counter_center()-Vector2(0,12),GameText.text("Bonus Skill"),GOLD,28 if fx.canvas_size.y > fx.canvas_size.x else 22)
			continue
		if event.type == "bonus_turn":
			bonus_turn_banner.play()
			_sound("dice/confirmation_002",1.25,-12)
			continue
		if event.type in ["damage","burn","shield_hit"] and (event.amount > 0 or event.get("corpse_hit",false)):
			combat_motion.hit(event.target,0.4 if event.type == "burn" else 1.0)
		elif event.type in ["skip","cancel"]: combat_motion.skip(event.target)
		var point: Vector2 = _player_point() if event.target == -1 else CITY_POINT if event.target == -2 else _enemy_point(event.target)
		if event.target >= 0 and event.get("corpse_hit",false): point = _enemy_impact_point(event.target)
		if event.type == "boon_wave":
			var tint: Color = PURPLE if event.amount >= 50 else GOLD
			var radius: float = maxf(ARENA.size.x,ARENA.size.y)
			fx.ring(_player_point(),tint,radius,ARENA)
			fx.burst(_player_point(),tint,12 if reduced else 32,240)
			_sound("player/rumble",1.15 if event.amount < 50 else 0.8,-16)
			continue
		if event.type == "spawn":
			fx.burst(_city_gate_point(), GOLD, 10, 40)
			continue
		if event.type == "warning":
			fx.activate_circle(_city_wall_point(0) - Vector2(0,38), RED, 23, 0.8)
			continue
		if event.type == "volley":
			fx.enemy_cast(1, _city_wall_point(0) - Vector2(0,38), _player_point(), 0.35)
			_sound("enemy/slash", 0.65, -14)
			continue
		if event.type == "sweep":
			for i in range(int(event.get("first", 0)), int(event.get("first", 0)) + event.amount):
				city_corpses.append({"p": _troop_point(i), "role": i % 3})
				fx.burst(_troop_point(i), RED, 8, 70)
			while city_corpses.size() > 24: city_corpses.pop_front()
			continue
		if event.type in ["shield_hit","shield_break"]:
			fx.floating(point-Vector2(0,69), _damage_popup(event), PURPLE,_event_font_size(event))
			fx.floating(point-Vector2(0,41), event.text, PURPLE)
			fx.activate_circle(point, PURPLE, maxf(18,_enemy_side()*0.3), 0.3)
			_sound("player/bell" if event.target == -1 else "enemy/bell", 0.7, -14)
			continue
		if event.type == "relic":
			fx.floating(point-Vector2(0,65),event.text,GOLD)
			fx.activate_circle(point,GOLD,55,0.6)
			continue
		if event.type in ["status", "skip", "burn"]:
			var tint: Color = Statuses.ENTRIES[Status.BURNING].color if event.type == "burn" else Statuses.ENTRIES[event.get("status", Status.FROZEN)].color
			var status_text: String = event.text
			if event.type == "burn": status_text = _damage_popup(event)
			elif event.has("status"): status_text = GameText.format("%s +%d",[GameText.text(Statuses.ENTRIES[event.status].name),event.amount])
			fx.floating(point-Vector2(0,45),status_text,tint,_event_font_size(event))
			if event.type == "burn":
				if event.target >= -1: hit_times[event.target+1] = 0.35
				fx.burst(point, tint, 3, 35)
			else: fx.activate_circle(point, tint, monster_side*0.42, 0.45)
			continue
		var color: Color = RED if event.type == "damage" else PURPLE if event.type == "cancel" else TEAL
		if event.type == "shield" and event.target == -1: color = PatternStyle.SHIELD_COLOR
		var label: String = event.text if event.type == "immune" else _damage_popup(event) if event.type == "damage" else GameText.format("+%d SHIELD",event.amount) if event.type == "shield" else "+%d" % event.amount if event.type == "heal" else "DAZED" if event.type == "cancel" else "+ BOON"
		var offset: int = offsets.get(event.target, 0)
		if not label.is_empty():
			fx.floating(point - Vector2(0, 45 + offset), label, color,_event_font_size(event))
			offsets[event.target] = offset + _event_font_size(event)
		if event.type == "damage":
			if event.target >= -1: hit_times[event.target + 1] = 1.0
			if event.amount > 0 or event.get("corpse_hit",false):
				fx.slash(point,event.target == -2,0 if event.get("instant_kill",false) else event.get("display_amount",event.amount))
				if event.target == -1: _sound("player/hit", 0.8, -17)
				elif event.target == -2:
					fx.burst(CITY_POINT, GOLD, 16, 190)
					city_life.sync_destruction(model.city_hp / float(Run.CITY_MAX_HP))
	# Status ticks and reactive effects can kill too, even when no damage event is returned.
	# Register them before another frame can draw an unregistered corpse.
	_sync_corpses()

## Reject stale asynchronous work after a restart or replaced turn.
func _valid_turn(token: int) -> bool:
	return token == run_id and is_inside_tree() and view_phase != "over"

## Wait in battle or presentation time, honoring menus and canceled turn tokens.
func _wait(seconds: float, token: int = -1, real_time: bool = false) -> bool:
	var remaining: float = seconds
	while remaining > 0:
		await get_tree().process_frame
		if token != -1 and not _valid_turn(token): return false
		if _menus_open(): continue
		remaining -= get_process_delta_time() * (1.0 if real_time else _roll_speed() * _world_time_scale())
	return token == -1 or _valid_turn(token)

## Play a bounded combat sound effect with the requested pitch and volume.
func _sound(clip: String, pitch: float = 1.0, volume: float = -15.0) -> void:
	if muted or DisplayServer.get_name() == "headless" or not sounds.has(clip): return
	var voices: Array = get_children().filter(func(c): return c is AudioStreamPlayer)
	if voices.size() >= 12: voices[0].queue_free()
	var player := AudioStreamPlayer.new()
	player.stream = sounds[clip]
	player.bus = "Combat"
	player.pitch_scale = pitch
	player.volume_db = volume
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
## Draw live battlefield actors and controls over the retained scenery layer.
func _draw() -> void:
	_draw_header()
	_draw_arena()
	_draw_statuses()
	_draw_console()
	_draw_dice_circle()
	if view_phase == "over":
		_draw_ending()
		_draw_reward_progress(REWARD_CENTER,1.0)
	if not _menus_open(): _draw_tooltips()

## Draw translated pixel text with a shadow and an integer-aligned baseline.
func _text(at: Vector2, value: String, size: int = 16, color: Color = CREAM, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	value = GameText.text(value)
	# Latin pixel font with bundled CJK fallback; integer baselines.
	var p := at.round()
	canvas.draw_string(pixel_font, p + Vector2(2, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK, color.a))
	canvas.draw_string(pixel_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

## Measure translated text and draw it centered on a baseline.
func _center(at: Vector2, value: String, size: int = 16, color: Color = CREAM, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	value = GameText.text(value)
	var width: float = pixel_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(at - Vector2(width / 2, 0), value, size, color, canvas)

## Draw readable localized description lines within the supplied width.
func _wrapped(at: Vector2, value: String, width: float, color: Color = MUTED, size: int = 16, canvas: CanvasItem = null) -> float:
	if canvas == null: canvas = self
	size = maxi(size,22)
	var y: float = at.y
	for line in GameText.lines(value, description_font, size, width):
		canvas.draw_string(description_font,Vector2(at.x,y).round(),line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
		y += size+6
	return maxf(at.y,y-size-6)

func _buff_drag_active() -> bool:
	if view_phase != "targeting" or not skill_dragging or _menus_open(): return false
	var roll: MultiHitSkill = _source_roll(skill_source)
	return not roll.is_empty() and not Rules.is_attack(roll)

func _art(key: String, rect: Rect2, tint: Color = Color.WHITE, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	if _buff_drag_active() and key.trim_suffix("_glow") in ["vanguard", "archer", "mage", "mage_normal", "paladin", "high_priest"]:
		tint *= Color(0.38, 0.38, 0.38, 1)
	if art.has(key):
		canvas.draw_texture_rect(art[key], Rect2(rect.position.round(), rect.size), false, tint)

## Tile the stone texture inside a panel, cropping its grout for readability.
func _stone(rect: Rect2, tint: Color, key: String = "stone", unit: int = 64, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(rect, PANEL)
	if not art.has(key): return
	for y in range(int(rect.position.y), int(rect.end.y), unit):
		for x in range(int(rect.position.x), int(rect.end.x), unit):
			var size := Vector2(minf(unit, rect.end.x - x), minf(unit, rect.end.y - y))
			# Crop the dark grout from UI stone so it does not compete with text.
			var inset: float = 3.0 if key == "stone" else 0.0
			canvas.draw_texture_rect_region(art[key], Rect2(Vector2(x, y), size), Rect2(Vector2.ONE * inset, size * (32.0 - inset * 2) / unit), tint)

func _frame(rect: Rect2, fill: Color = PANEL, border: Color = EDGE, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(INK, 0.6))
	_stone(rect, fill, "stone", 64, canvas)
	canvas.draw_rect(rect, INK, false, 4)
	canvas.draw_rect(rect.grow(-3), border.darkened(0.35), false, 2)
	canvas.draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 2)), border)
	canvas.draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(2, rect.size.y - 10)), border)
	for p in [rect.position + Vector2(5, 5), Vector2(rect.end.x - 9, rect.position.y + 5), rect.end - Vector2(9, 9), Vector2(rect.position.x + 5, rect.end.y - 9)]:
		canvas.draw_rect(Rect2(p, Vector2(4, 4)), border.lightened(0.2))

func _button(rect: Rect2, value: String, enabled: bool = true, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	var hover: bool = enabled and rect.has_point(get_global_mouse_position())
	_frame(rect, Color("5f563a") if hover else Color("443c2d"), GOLD if hover else EDGE, canvas)
	_center(rect.get_center() + Vector2(0, 6), value, 16, GOLD if enabled else MUTED, canvas)

func _draw_header() -> void:
	_text(Vector2(42, 53), "%d / %d" % [model.stage + 1, Run.PLAYABLE_WAVES], 32, GOLD)
	_draw_currencies(_currency_point())
	_button(SPEED_RECT, "%.1f" % _roll_speed() if model.is_city() else "2x" if speed == 2 else "1x")
	for rect in [AUDIO_RECT, MENU_RECT]:
		_frame(rect, Color("443c2d"), GOLD if rect.has_point(get_global_mouse_position()) else EDGE)
	_glyph(AUDIO_RECT.get_center(), "mute" if muted else "sound", MUTED if muted else GOLD)
	_draw_menu_icon()

func _draw_menu_icon() -> void:
	var scale_factor: float = 2 if fx.canvas_size.y > fx.canvas_size.x else 1
	for row in [-1,0,1]:
		var at: Vector2 = MENU_RECT.get_center() + Vector2(0,row*6*scale_factor)
		draw_rect(Rect2(at-Vector2(10*scale_factor,scale_factor),Vector2(20*scale_factor,2*scale_factor)),GOLD)

func _draw_menu(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	canvas.draw_rect(Rect2(Vector2.ZERO,fx.canvas_size),INK)
	if not portrait: _frame(Rect2(360,120,560,560),PANEL,GOLD, canvas)
	_text(Vector2(40,188) if portrait else Vector2(400,184),"MENU",42 if portrait else 32,GOLD, canvas)
	_button(MENU_CLOSE,"X", true, canvas)
	_button(DEBUG_RECT,"DEBUG", true, canvas)
	_button(FX_RECT,"EFFECTS: " + ("REDUCED" if reduced else "FULL"), true, canvas)
	_button(GUIDE_RECT,"HELP / GRIMOIRE", true, canvas)
	_text(LANGUAGE_RECT.position-Vector2(0,14 if portrait else 12),"LANGUAGE",24 if portrait else 16,MUTED, canvas)
	for i in range(GameText.LANGUAGES.size()):
		var rect := _language_rect(i)
		_button(rect,GameText.LANGUAGE_NAMES[i], true, canvas)
		if GameText.language == GameText.LANGUAGES[i]: canvas.draw_rect(rect.grow(-4),TEAL,false,3)
	_button(MENU_RESUME,"RESUME", true, canvas)
	_center(Vector2(402,1350) if portrait else Vector2(640,650),"BATTLE PAUSED",24 if portrait else 16,MUTED, canvas)

func _language_rect(index: int) -> Rect2:
	var gap: float = 16 if fx.canvas_size.y > fx.canvas_size.x else 12
	var width: float = (LANGUAGE_RECT.size.x-gap)/2
	return Rect2(LANGUAGE_RECT.position+Vector2(index*(width+gap),0),Vector2(width,LANGUAGE_RECT.size.y))

func _backdrop_dim() -> float:
	if _menus_open(): return 0.0
	var tarot_aiming: bool = is_instance_valid(tarot_ui) and tarot_ui.gesture == "card"
	return maxf(0.58 if view_phase == "targeting" or tarot_aiming else 0.0, _cinematic_gloom())

func _draw_backdrop_shade(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	# Draw beneath the actors so targeting and cast anticipation never dim them.
	var amount: float = _backdrop_dim()
	if amount > 0: canvas.draw_rect(ARENA, Color(0.035,0.025,0.065,amount))

## Draw animated actors, targeting shade and arena borders above static scenery.
func _draw_arena() -> void:
	if model.is_city(): _draw_city()
	_draw_player()
	if not model.is_city():
		for i in range(model.enemies.size()): _draw_enemy_overlay(i)
	for i in range(4):
		draw_rect(Rect2(ARENA.position.x, ARENA.end.y - 12 + i * 3, ARENA.size.x, 3), Color(INK, 0.08 + i * 0.06))
	draw_rect(ARENA, EDGE, false, 4)
	draw_rect(ARENA.grow(-5), Color("d2c29a"), false, 2)
	if view_phase in ["feeding", "transition"]:
		_frame(Rect2(440, 105, 400, 45), PANEL, GOLD)
		_center(Vector2(640, 136), "THE FEAST" if view_phase == "feeding" else Run.WAVE_NAMES[model.stage], 24, GOLD)

func _troop_point(index: int) -> Vector2:
	var progress: float = fposmod(city_life.clock * 0.1 + index * 0.17, 1.0)
	return City.gate_point().lerp(Vector2(425,410),progress) + Vector2(0,(index % 2)*5)

## Draw city damage, residents, troops and city health in landscape layout.
func _draw_city() -> void:
	var remaining: float = model.city_hp / float(Run.CITY_MAX_HP)
	City.paint(self, art, remaining, city_life.clock, city_life.people, city_life.houses, reduced)
	for corpse in city_corpses:
		draw_set_transform(corpse.p, PI / 2, Vector2(0.35, 1))
		var side: float = _enemy_side()
		_art(["vanguard", "archer", "mage"][corpse.role], Rect2(-side/2, -side/2, side, side), Color("796c64"))
		draw_set_transform(Vector2.ZERO)
	for i in range(model.troops):
		var point := _troop_point(i)
		var stride: float = city_life.clock * 16 + i * 2.3
		var hop: float = 0 if reduced else snappedf(absf(sin(stride)) * 2, 1)
		var lean: float = 0 if reduced else sin(stride) * 0.16
		_shadow(point, 5, 0.22)
		draw_set_transform((point - Vector2(0, hop)).round(), lean)
		var side: float = _enemy_side()
		_art(["vanguard", "archer", "mage"][i % 3], Rect2(-side/2, -side, side, side))
		draw_set_transform(Vector2.ZERO)
	_hp_plate(Rect2(531, 88, 683, 55), "THE CITY", model.city_hp, Run.CITY_MAX_HP, 0, GOLD)
	if model.volley_warned:
		_center(City.wall_point(0) - Vector2(15,61), "VOLLEY", 16, RED)

func _shadow(point: Vector2, radius: float, alpha: float, canvas: CanvasItem = null) -> void:
	Pixel.disc(self if canvas == null else canvas, point, radius, Color(INK, alpha), 8, 0.19)

## Draw the Horror with growth, hurt motion, defenses and status effects.
func _draw_player() -> void:
	if model.is_city(): _draw_player_actor(self)
	_hp_plate(Rect2(129, 382, 260, 56), "HORROR %d" % (model.stage+1), model.hp, model.max_hp, model.shield, TEAL)

## Render the Horror in world coordinates while health and inventory remain fixed.
func _draw_player_actor(canvas: CanvasItem) -> void:
	var hurt: float = hit_times[0]
	var bob: float = 0 if reduced or model.is_frozen() else snappedf(sin(clock_time * (8 if view_phase == "transition" else 1.8)) * 3, 2)
	bob += combat_motion.attack_bob(-1,monster_side,reduced)
	var dx: float = combat_motion.offset(-1,monster_side,clock_time,false,reduced)
	var orbit: Array = RelicOrbit.poses(self)
	RelicOrbit.paint(canvas,self,orbit,false)
	_shadow(_player_world_feet(),monster_side*_player_growth_scale().x*0.48,0.27,canvas)
	if model.shield > 0 or model.statuses[6].count > 0:
		Pixel.circle(canvas,_player_world_feet()-Vector2(0,monster_side*0.48),monster_side*0.47,Color(TEAL,0.45),4)
	evolution.draw_actor(canvas,_player_world_sprite_rect(dx,bob),Color(Color.WHITE.lerp(RED,hurt*0.6),0.32 if model.status_count(Status.HIDDEN) > 0 else 1.0))
	RelicOrbit.paint(canvas,self,orbit,true)
	_draw_player_afflictions(canvas)
	_draw_character_skill_counter(canvas)

## Anchor charge UI to the resting sprite bounds, independent of idle, attacks and recoil.
func _character_counter_center() -> Vector2:
	var sprite := Rect2(_player_world_feet()-Vector2(monster_side*0.5,monster_side),Vector2.ONE*monster_side)
	var rect: Rect2 = evolution.visible_rect(sprite)
	return Vector2(rect.get_center().x,rect.position.y-10)

func _draw_character_skill_counter(canvas: CanvasItem) -> void:
	var center: Vector2 = _character_counter_center()
	var flash: float = clampf((skill_counter_flash_until-clock_time)/0.35,0,1)
	var filled: int = model.character_passive.displayed_charge(model.pending)
	for i in range(model.FlamelingsPassive.CHARGES):
		var at: Vector2 = center+Vector2((i-(model.FlamelingsPassive.CHARGES-1)*0.5)*24,0)
		canvas.draw_circle(at,8,Color("25202a"))
		if i < filled:
			# Staggered rising tongues stay local to each charged ember.
			for flame in range(5):
				var phase: float = 0.35 if reduced else fposmod(clock_time*1.8+flame*0.21+i*0.13,1)
				var tip: Vector2 = at+Vector2(sin(flame*2.1+clock_time*3)*(4-phase*2),-phase*18)
				canvas.draw_circle(tip,4*(1-phase)+1,Color(1,0.35+phase*0.4,0.08,(1-phase)*0.95))
			canvas.draw_circle(at,16,Color(1,0.50,0.10,0.24))
			canvas.draw_circle(at,12,Color(1,0.66,0.18,0.50))
			canvas.draw_circle(at,7,Color("fff1a3"))
			canvas.draw_circle(at,3,Color("fffde8"))
		canvas.draw_arc(at,8,0,TAU,24,Color("f1d4a5"),2,true)
		if flash > 0:
			canvas.draw_circle(at,8+12*(1-flash),Color(1,0.9,0.6,flash*0.8))

## Share the exact living sprite pose with its death-fragment emission points.
func _enemy_sprite_rect(index: int) -> Rect2:
	return battlefield_view.transform*_enemy_world_sprite_rect(index)

func _enemy_world_sprite_rect(index: int) -> Rect2:
	var side: float = _enemy_side()
	var feet: Vector2 = _enemy_world_feet(index)
	var human: Dictionary = model.enemies[index]
	var dx: float = combat_motion.offset(index,side,clock_time,model.enemy_cannot_act(index) or human.canceled,reduced)
	var bob: float = 0 if reduced or model.enemy_cannot_act(index) else snappedf(sin(clock_time*2+index*2)*minf(2,side/64.0),2)
	bob += combat_motion.attack_bob(index,side,reduced)
	return Rect2(feet-Vector2(side/2,side)+Vector2(dx,bob),Vector2.ONE*side)

## Draw an enemy with elite lighting, motion, health, statuses and intent.
func _draw_human(index: int, canvas: CanvasItem) -> void:
	var human: Dictionary = model.enemies[index]
	var point: Vector2 = _enemy_world_point(index)
	var floor_y: float = _enemy_world_feet(index).y
	var side: float = _enemy_side()
	var key: String = EnemyVisuals.art_key(human)
	var selected: bool = attack_target == index and view_phase == "resolving"
	if human.hp <= 0:
		if not EnemyVisuals.debris(human).is_empty():
			enemy_debris.draw(canvas,index,corpse_alpha,hit_times[index+1])
			return
		var t: float = minf(1, fallen.get(index, 1.0) / 0.3)
		var center: Vector2 = point.lerp(Vector2(point.x, floor_y-side*0.08), t)
		var hurt: float = hit_times[index + 1]
		center.x += combat_motion.offset(index,side,clock_time,false,reduced)
		_shadow(Vector2(point.x, floor_y-2), side * 0.42, 0.2 * corpse_alpha,canvas)
		canvas.draw_set_transform(center, t * PI / 2, Vector2(lerpf(1, 0.36, t), 1))
		_art(key, Rect2(Vector2.ONE * -side / 2, Vector2.ONE * side), Color(0.64, 0.52, 0.49, corpse_alpha).lerp(Color(RED,corpse_alpha),hurt*0.6),canvas)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	if selected or active_human == index:
		var color: Color = GOLD if selected else RED
		Pixel.disc(canvas, Vector2(point.x, floor_y-2), side * 0.35, Color(color, 0.35), 6, 0.23)
		_rune(point - Vector2(0, side * 0.55), 3, color, 3,canvas)
	if human.get("charging",false):
		var total: int = Rules.EnemyCatalog.ITEMS[human.role].charge_turns
		for orb in range(total):
			var at: Vector2 = Vector2(point.x+(orb-(total-1)/2.0)*12,floor_y+8)
			Pixel.disc(canvas,at,4,_elite_color(human.role) if orb < human.charge else Color(INK,0.8),2)
	var hurt: float = hit_times[index + 1]
	var sprite: Rect2 = _enemy_world_sprite_rect(index)
	var dx: float = sprite.position.x-(point.x-side/2)
	_shadow(Vector2(point.x, floor_y-1), side * 0.25, 0.25,canvas)
	if human.elite:
		var glow: Color = _elite_color(human.role)
		StatusPaint.aura(canvas, Vector2(point.x,floor_y), side, glow, clock_time, reduced)
		var pulse: float = 1.0 if reduced else 0.9 + sin(clock_time * 3 + index) * 0.1
		# White alpha silhouettes keep the halo bright even around dark sprite pixels.
		for ring in [2, 1]:
			var spread: float = ring * maxf(3, side * 0.045)
			for ray in range(8):
				var offset := Vector2.from_angle(ray*TAU/8)*spread
				_art(key+"_glow", Rect2(sprite.position+offset, sprite.size), Color(glow.lightened(0.2 if ring == 1 else 0), pulse*(0.6 if ring == 1 else 0.12)),canvas)
		var ground_glow: Color = glow.darkened(0.62) if _buff_drag_active() else glow
		Pixel.disc(canvas, Vector2(point.x, floor_y), maxf(16,side*0.42), Color(ground_glow,0.65*pulse), 3, 0.25)
	_art(key, sprite, Color.WHITE.lerp(RED, hurt * 0.6),canvas)
	if human.elite: StatusPaint.ellipse(canvas,Vector2(point.x,floor_y),maxf(22,side*0.53),_elite_color(human.role))
	if model.enemy_status_count(index,Status.FROZEN) > 0:
		StatusPaint.ice(canvas,Rect2(point.x-side*0.45+dx,floor_y-side,side*0.9,side),false)
	if index in model.taunting_enemies():
		var pulse: float = _taunt_pulse()
		var color := Color("ff525e")
		StatusPaint.ellipse(canvas,Vector2(point.x,floor_y),side*(0.47+0.05*pulse),Color(color,0.45+0.4*pulse))

## Draw readable enemy labels above the projected actors, without enlarging the HUD.
func _draw_enemy_overlay(index: int) -> void:
	if not model.is_enemy_alive(index): return
	if not ARENA.grow(-6).encloses(_enemy_health_rect(index)): return
	_draw_enemy_intent(index)
	_draw_enemy_health(index)
	_draw_enemy_statuses(index)

## Place enemy buffs and harmful status icons together above the character.
func _draw_enemy_statuses(index: int) -> void:
	var items: Array = Statuses.enemy_active(model.enemies[index])
	var bar: Rect2 = _enemy_health_rect(index)
	var radius: float = 8 if fx.canvas_size.y > fx.canvas_size.x else 5
	var step: float = minf(radius*3,bar.size.x/maxi(1,items.size()))
	for i in range(items.size()):
		var at: Vector2 = bar.get_center()+Vector2((i-(items.size()-1)/2.0)*step,bar.size.y/2+radius+8)
		Pixel.disc(self,at,radius+3,INK,2)
		StatusPaint.icon(self,at,radius,items[i].icon,items[i].color)
		_text(at+Vector2(radius*0.55,radius+5),items[i].get("badge","∞" if items[i].permanent else str(items[i].turns)),12,CREAM)

func _elite_color(role: int) -> Color:
	return Rules.EnemyCatalog.ITEMS[role].color

func _draw_player_afflictions(canvas: CanvasItem) -> void:
	var feet: Vector2 = _player_world_feet()
	var dx := Vector2(combat_motion.offset(-1,monster_side,clock_time,false,reduced),0)
	if model.is_frozen():
		var ice: Rect2 = _player_world_ice_rect()
		ice.position += dx
		StatusPaint.ice(canvas,ice,true,3-model.ice_hits_remaining if model.phase == "frozen" else 0)
	if model.is_stunned():
		StatusPaint.orbiting_stars(canvas,feet+dx-Vector2(0,monster_side*0.89),monster_side,clock_time,reduced)

func _enemy_intent_data(index: int) -> Dictionary:
	var enemy: Dictionary = model.enemies[index]
	if enemy.hp <= 0 or enemy.acted or enemy.intent.is_empty(): return {}
	if model.enemy_status_count(index,Status.IMMOBILIZED) > 0:
		return {"label":"IMMOBILIZED","detail":"SKIP","color":Statuses.ENTRIES[Status.IMMOBILIZED].color,"icon":"skip","name":"Immobilized","description":"Shield broken. Cannot act for one turn."}
	if model.enemy_status_count(index,Status.FROZEN) > 0:
		return {"label":"FROZEN","detail":"SKIP","color":Statuses.ENTRIES[Status.FROZEN].color,"icon":"skip","name":"Frozen","description":"Cannot act this turn. One freeze stack is consumed."}
	var intent: Dictionary = enemy.intent
	var label: String = ""
	var detail: String = ""
	var color: Color = TEAL
	var icon: String = "sword"
	var name: String = "Attack"
	var description: String = ""
	if enemy.canceled:
		label = "SKIP"
		color = MUTED
		icon = "skip"
		name = "Distracted"
		description = "This enemy will skip its next move."
	elif intent.type == "attack":
		var attribute: int = intent.get("attribute",Status.Attribute.NONE)
		var status: int = intent.get("status",{1:Status.FROZEN,2:Status.BURNING,3:Status.STUNNED}.get(attribute,-1))
		var amount: int = roundi(intent.amount*(enemy.get("action_multiplier",1.0) if enemy.get("action_hit",0) > 0 else 1.5 if enemy.attack_boost else 1.0)*(0.5 if model.enemy_status_count(index,Status.DARKNESS) > 0 else 1.0))
		var hits: int = intent.get("hits",1)
		label = "ATK"
		detail = str(amount) if hits == 1 else "%d x%d" % [amount,hits]
		name = intent.get("name","Attack")
		description = GameText.format("Deal %s damage.",detail)
		color = RED
		if status >= 0:
			var entry: Dictionary = Statuses.ENTRIES[status]
			color = entry.color
			description += " " + GameText.format("Apply %d stack(s) of %s on damage.",[intent.get("stacks",1),GameText.text(entry.name)])
	elif intent.type == "shield":
		icon = "shield"
		name = intent.get("name","Raise Shield")
		label = "SHIELD"
		var target: int = intent.target
		var amount: int = 0 if not model.is_enemy_alive(target) or model.enemy_status_count(target,Status.CORROSION) > 0 else maxi(0,mini(intent.amount,Rules.EnemyCatalog.shield_cap(model.enemies[target])-model.enemies[target].shield))
		detail = "+%d" % amount
		description = GameText.format("Give an ally %s shield." if target != index else "Gain %s shield.",str(amount))
	elif intent.type == "heal":
		icon = "plus"
		name = "Heal"
		label = "HEAL"
		detail = "+%d" % (0 if model.enemy_status_count(index,Status.DARKNESS) > 0 else mini(intent.amount,enemy.max_hp-enemy.hp))
		description = GameText.format("Restore %s health.",detail.trim_prefix("+"))
	elif intent.type == "team_heal":
		icon = "plus"
		name = "Group Heal"
		label = "HEAL ALL"
		detail = "20%"
		description = "Restore 20% max health to living allies. Darkness blocks healing."
	elif intent.type == "charge":
		icon = "charge"
		name = intent.name
		label = "CHARGE"
		detail = "%d / %d" % [intent.progress,intent.total]
		color = _elite_color(enemy.role)
		description = GameText.format("Charge %d/%d. After charging, attack %d times next turn. Freeze or immobilization resets charging.",[intent.progress,intent.total,Rules.EnemyCatalog.ITEMS[enemy.role].release_hits])
	elif intent.type == "rest":
		icon = "skip"; name = "Rest"; label = "REST"; color = MUTED
		description = "Rest this turn."
	else:
		icon = "boost"
		name = intent.get("name","Blessing")
		label = "BOOST"
		detail = "ALLY x1.5"
		color = PURPLE
		description = "Give all living allies, including self, 1.5x damage on their next attack." if intent.type == "team_empower" else "Give one ally or self 1.5x damage on its next attack."
	if index in model.taunting_enemies():
		description += " " + GameText.text("Taunt: protects allies from targeted attacks and halves area damage to them. 666 bypasses this.")
	return {"label":label,"detail":detail,"color":color,"icon":icon,"name":name,"description":description}

func _enemy_intent_rect(index: int) -> Rect2:
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var width: float = (40 if portrait else 26)*battlefield_view.zoom
	var feet: Vector2 = _enemy_feet(index)
	var columns: int = mini(5,model.enemies.size())
	if columns > 1:
		var spacing: float = absf(_enemy_feet(1).x-_enemy_feet(0).x)
		width = minf(width,spacing-6)
	var height: float = width
	var rect := Rect2(Vector2(feet.x-width/2,maxf(ARENA.position.y+8,feet.y-_enemy_side()*battlefield_view.zoom-height-12*battlefield_view.zoom)),Vector2(width,height))
	return rect

## Give every active taunter the same calm, synchronized red pulse.
func _taunt_pulse() -> float:
	return 0.75 if reduced else (sin(clock_time*TAU/1.2)+1)*0.5

func _draw_enemy_intent(index: int) -> void:
	var data: Dictionary = _enemy_intent_data(index)
	var taunting: bool = index in model.taunting_enemies()
	if data.is_empty() and not taunting: return
	var rect: Rect2 = _enemy_intent_rect(index)
	var pulse: float = _taunt_pulse()
	var red := Color("ff525e")
	if taunting:
		for ring in range(3,0,-1):
			Pixel.disc(self,rect.get_center(),rect.size.x*(0.55+ring*0.09+pulse*0.06),Color(red,(0.04+0.035*pulse)),2)
		Pixel.circle(self,rect.get_center(),rect.size.x*(0.57+0.07*pulse),Color(red,0.5+0.5*pulse),2)
		_center(Vector2(rect.get_center().x,rect.position.y-10*battlefield_view.zoom),"TAUNT",roundi((22 if fx.canvas_size.y > fx.canvas_size.x else 16)*battlefield_view.zoom),red.lerp(Color("ffb0b6"),pulse*0.25))
	Pixel.disc(self,rect.get_center(),rect.size.x*0.53,Color(INK,0.82),2)
	if not data.is_empty(): StatusPaint.intent_icon(self,rect.get_center(),rect.size.x*0.4,data.icon,data.color)

func _reward_scale() -> float:
	return 1.5 if fx.canvas_size.y > fx.canvas_size.x else 1.0

func _diamond_center(index: int) -> Vector2:
	var group: int = 0 if index < 3 else 1 if index < 8 else 2
	return REWARD_CENTER+Vector2((index-7)*19+(group-1)*9,0)*_reward_scale()

func _chest_milestone_rect(tier: int) -> Rect2:
	var side: float = 88 if _reward_scale() > 1 else 48
	return Rect2(_diamond_center(Run.CHEST_THRESHOLDS[tier]-1)-Vector2.ONE*side/2,Vector2(side,side/2+45*_reward_scale()))

func _chest_tier_at(point: Vector2) -> int:
	if not _can_claim_chest(): return 0
	var tier: int = model.chest_tier()
	return tier if _chest_milestone_rect(tier).has_point(point) else 0

## Draw Reroll Treasure milestones and highlight the highest claimable tier.
func _draw_reward_progress(at: Vector2, scale_factor: float) -> void:
	var available_tier: int = model.chest_tier() if _can_claim_chest() else 0
	for i in range(15):
		var group: int = 0 if i < 3 else 1 if i < 8 else 2
		var claimable: bool = available_tier == group+1
		var p := _diamond_center(i)
		var milestone: bool = i in [2,7,14]
		var filled: bool = i < model.reroll_progress
		var radius: float = (13 if milestone else 7)*scale_factor
		var tint: Color = Run.Chests.COLORS[group+1]
		if milestone and filled:
			var pulse: float = 0.9 if reduced else 0.85+sin(clock_time*4.5)*0.15
			for j in range(5,0,-1):
				var glow_radius: float = radius+j*3.5*scale_factor
				var glow := PackedVector2Array([p+Vector2(0,-glow_radius),p+Vector2(glow_radius,0),p+Vector2(0,glow_radius),p+Vector2(-glow_radius,0)])
				draw_colored_polygon(glow,Color(tint,pulse*(0.2 if claimable else 0.1)))
			if claimable:
				var halo: float = radius+(7+pulse*3)*scale_factor
				var corners := PackedVector2Array([p+Vector2(0,-halo),p+Vector2(halo,0),p+Vector2(0,halo),p+Vector2(-halo,0)])
				for edge in range(4): Pixel.line(self,corners[edge],corners[(edge+1)%4],Color(tint.lightened(0.5),pulse*0.8),2)
		var points := PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius,0),p+Vector2(0,radius),p+Vector2(-radius,0)])
		draw_colored_polygon(points,tint if filled else INK)
		for edge in range(4): Pixel.line(self,points[edge],points[(edge+1)%4],CREAM if milestone and filled else tint if filled else EDGE,3 if milestone else 2)
		if filled: draw_rect(Rect2(p-Vector2.ONE*(3 if milestone else 2),Vector2.ONE*(6 if milestone else 4)),CREAM)
		if milestone and filled and claimable:
			var label := Rect2(p+Vector2(-25,24)*scale_factor,Vector2(50,21)*scale_factor)
			draw_rect(label, tint.darkened(0.68))
			draw_rect(label,tint.lightened(0.25),false,2)
			_center(p+Vector2(0,39*scale_factor), "CLAIM", roundi(12*scale_factor), CREAM)

func _draw_auto_claim() -> void:
	if view_phase != "over" or auto_claim_tier == 0 or auto_claim_remaining <= 0: return
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var rect := Rect2(82,476,640,92) if portrait else Rect2(380,143,520,64)
	var alpha: float = minf(1.0, minf((AUTO_CLAIM_DURATION-auto_claim_remaining)/0.12,auto_claim_remaining/0.35))
	var color: Color = Run.Chests.COLORS[auto_claim_tier]
	for i in range(3,0,-1): auto_claim_notice.draw_rect(rect.grow(i*4),Color(color,0.055*alpha))
	auto_claim_notice.draw_rect(rect,Color(INK,0.97*alpha))
	auto_claim_notice.draw_rect(rect,Color(color,alpha),false,3)
	var side: float = 64 if portrait else 44
	var icon_at := Vector2(rect.position.x+side*0.65,rect.get_center().y)
	auto_claim_notice.draw_texture_rect(chest.art.chest_open,Rect2(icon_at-Vector2.ONE*side/2,Vector2.ONE*side),false,Color(1,1,1,alpha))
	var label: String = GameText.format("%s chest auto claimed",GameText.text(CHEST_NAMES[auto_claim_tier]))
	var font_size: int = 26 if portrait else 20
	var width: float = pixel_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline: Vector2 = (rect.get_center()+Vector2((side-width)/2,9 if portrait else 7)).round()
	auto_claim_notice.draw_string(pixel_font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(color.lightened(0.35),alpha))

func _damage_multiplier_label() -> String:
	return damage_feedback.label() if is_instance_valid(damage_feedback) and damage_feedback.active else ""

func _currency_point() -> Vector2:
	return Vector2(284,40)

## Share the exact soul icon destination with both header layouts and flying receipts.
func _soul_currency_point() -> Vector2:
	return _currency_point()+Vector2(138.6 if fx.canvas_size.y > fx.canvas_size.x else 126,0)

func _draw_currencies(at: Vector2, scale_factor: float = 1.0) -> void:
	var side: float = 32*scale_factor
	RewardIcons.paint(self,chest.art,"ruby",Rect2(at-Vector2.ONE*side/2,Vector2.ONE*side))
	var displayed: int = model.blood_gems-crystal_pickup.pending_total if is_instance_valid(crystal_pickup) else model.blood_gems
	_text(at+Vector2(23,7)*scale_factor,str(maxi(0,displayed)),roundi(18*scale_factor),Color("fa6086"))
	var soul_at: Vector2 = _soul_currency_point()
	RewardIcons.paint(self,chest.art,"soul",Rect2(soul_at-Vector2.ONE*side/2,Vector2.ONE*side))
	_text(soul_at+Vector2(23,7)*scale_factor,soul_pickup.counter_text(),roundi(18*scale_factor),Color("a5e4ef"))

func _enemy_health_rect(index: int) -> Rect2:
	var count: int = model.enemies.size()
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var feet: Vector2 = _enemy_feet(index)
	var width: float = (168 if count < 4 else 60) if portrait else (148 if count < 4 else 40 if count > 5 else 52)
	# Include an explicit gutter between adjacent bars, including their borders.
	if count > 1:
		var spacing: float = absf(_enemy_feet(1).x-_enemy_feet(0).x)
		width = minf(width, spacing-16)
	var height: float = (30 if count < 4 else 24) if portrait else (20 if count < 4 else 14)
	var y: float = feet.y+8
	return Rect2(feet.x-width/2, y, width, height)

func _draw_enemy_health(index: int) -> void:
	var human: Dictionary = model.enemies[index]
	var bar: Rect2 = _enemy_health_rect(index)
	var color: Color = _elite_color(human.role) if human.elite else RED
	var size: int = 16 if model.enemies.size() < 4 else 12
	draw_rect(bar.grow(2), EDGE)
	draw_rect(bar, INK)
	draw_rect(Rect2(bar.position+Vector2(2,2),Vector2((bar.size.x-4)*human.hp/float(human.max_hp),bar.size.y-4)),color.darkened(0.3))
	_center(bar.get_center()+Vector2(0,size*0.4), str(human.hp), size, CREAM)
	if human.shield > 0:
		_glyph(bar.position+Vector2(5,-10),"shield",TEAL)
		_text(bar.position+Vector2(17,-5),str(human.shield),12,TEAL)

func _hp_plate(rect: Rect2, title: String, hp: int, maximum: int, shield: int, color: Color) -> void:
	_frame(rect, Color("32382c"), EDGE)
	var localized_title: String = GameText.format("HORROR %d",title.trim_prefix("HORROR ").to_int()) if title.begins_with("HORROR ") else title
	_center(Vector2(rect.get_center().x, rect.position.y + 22), localized_title, 16, CREAM if hp else MUTED)
	var bar := Rect2(rect.position + Vector2(10, 30), Vector2(rect.size.x - 20, 18))
	draw_rect(bar, INK)
	var filled: int = floori((bar.size.x - 4) * hp / float(maximum))
	for x in range(0, filled, 4):
		var w: float = minf(4, filled - x)
		draw_rect(Rect2(bar.position + Vector2(2 + x, 2), Vector2(w, 14)), color.darkened(0.4 if x % 12 == 0 else 0.2))
		draw_rect(Rect2(bar.position + Vector2(2 + x, 2), Vector2(w, 3)), color)
		draw_rect(Rect2(bar.position + Vector2(2 + x, 13), Vector2(w, 3)), color.darkened(0.55))
	_center(bar.get_center() + Vector2(0, 6), "%d / %d" % [hp, maximum] if title.begins_with("HORROR") or title == "THE CITY" else str(hp), 16, CREAM)
	if shield > 0:
		var badge := Rect2(rect.end.x - 57, rect.position.y - 29, 55, 28)
		_frame(badge, PANEL, TEAL.darkened(0.25))
		_glyph(badge.position + Vector2(15, 13), "shield", TEAL)
		_text(badge.position + Vector2(28, 19), str(shield), 16, TEAL)

func _active_statuses() -> Array:
	return Statuses.active(model.statuses)

func _status_center(id: int) -> Vector2:
	var items: Array = _active_statuses()
	var slot: int = items.find_custom(func(item): return item.id == id)
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	if portrait:
		var key: String = "%d:%d:%.2f" % [model.stage,model.enemies.size(),monster_side]
		if key == status_layout_key and slot >= 0 and slot < status_layout_points.size(): return status_layout_points[slot]
		var base_y: float = _player_world_feet().y + 40 - monster_side - 44 + (16 if model.enemies.size() > 5 else 0)
		var candidates: Array = []
		for row in [0,1,-1,2,-2,3,-3]:
			for column in range(3):
				var point := Vector2(72+column*92,base_y+row*92)
				var rect := Rect2(point-Vector2.ONE*44,Vector2.ONE*88)
				if rect.position.y < ARENA.position.y+60 or rect.end.y > 896: continue
				var blocked: bool = false
				for enemy in range(model.enemies.size()):
					if rect.intersects(_target_rect(enemy)) or rect.intersects(_enemy_health_rect(enemy).grow(4)) or rect.intersects(_enemy_intent_rect(enemy).grow(3)): blocked = true; break
				if not blocked: candidates.append(point)
		status_layout_key = key
		status_layout_points = candidates
		if slot >= 0 and slot < candidates.size(): return candidates[slot]
		return Vector2(72+maxi(0,slot)%3*92,844-floori(maxi(0,slot)/3.0)*92)
	var step: float = 48
	var columns: int = 7
	var row: int = floori(slot/float(columns))
	var count: int = mini(columns, items.size() - row*columns)
	var anchor := _player_world_feet() - Vector2(0, monster_side + 24)
	var downward: bool = anchor.y-(ceili(items.size()/float(columns))-1)*step < ARENA.position.y+76
	if downward:
		# Keep top-row statuses clear of the damage readout in late waves.
		anchor.y = maxf(ARENA.position.y+80,anchor.y)
	return anchor + Vector2((slot % columns - (count-1)/2.0)*step, row*step*(1 if downward else -1))

func _status_rect(id: int) -> Rect2:
	var side: float = 88 if fx.canvas_size.y > fx.canvas_size.x else 44
	return Rect2(_status_center(id)-Vector2.ONE*side/2, Vector2.ONE*side)

func _draw_statuses() -> void:
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var side: float = 40 if portrait else 28
	for item in _active_statuses():
		var at := _status_center(item.id)
		Pixel.disc(self, at, side*0.65, Color(INK,0.85), 2)
		Pixel.circle(self, at, side*0.65, Color(item.color,0.6), 2)
		if item.id >= Status.FROZEN: StatusPaint.icon(self, at, side*0.42, item.icon, item.color)
		else: _art(item.icon, Rect2(at-Vector2.ONE*side/2, Vector2.ONE*side), item.color.lightened(0.3))
		var badge := at + Vector2(side*0.5, side*0.55)
		var timed: bool = model.is_city() and item.id == Status.IMMUNITY
		var value: String = "%ds" % ceili(model.city_immunity_seconds()) if timed else str(item.turns)
		var width: float = 48 if timed and portrait else 36 if timed else 20
		draw_rect(Rect2(badge-Vector2(width/2,13),Vector2(width,20)), INK)
		_center(badge+Vector2(0,4), value, 22 if portrait else 16, item.color)

func _status_description(id: int, count: int) -> String:
	if id == Status.IMMUNITY and model.is_city():
		return GameText.format("Invincible for %.1f more seconds. Each stack lasts 2 seconds.",model.city_immunity_seconds())+" "+GameText.text("Recast extends duration.")
	if id == Status.REGEN: return GameText.format("Heal %d at turn start.",roundi(5*model.statuses[id].potency))+" "+GameText.remaining(count,"turn")
	if id in [Status.MIGHT,Status.ASCENSION]: return GameText.format("Adds +%.1f to DMG. Stacks with other bonuses.",(0.5 if id == Status.MIGHT else 2.0)*model.statuses[id].potency)+" "+GameText.remaining(count,"attack")+" "+GameText.format("Recast: %d-base shockwave.",10 if id == Status.MIGHT else 50)
	var unit: String = "stack" if id in [Status.BURNING,Status.DARKNESS,Status.CORROSION,Status.PLAGUE] else "throw" if id == Status.STUNNED else "turn"
	return GameText.text(Statuses.ENTRIES[id].text)+" "+GameText.remaining(count,unit)

func _draw_console() -> void:
	_draw_reward_progress(REWARD_CENTER, 1.0)
	if _power_meter_visible(): _draw_power_meter(Rect2(967, 580, 216, 16),12)

func _dice_spent() -> bool:
	return view_phase in ["forming", "skill", "targeting", "resolving"]

func _show_dice_links() -> bool:
	return view_phase == "rolling" and dice.all(func(die): return die.visible) and not last_result.is_empty() and last_result.kind != Rules.Kind.NORMAL

## Expose drop hints from the first press or tap, before any dragging is required.
func _current_skill_selected() -> bool:
	return view_phase == "targeting" and skill_source == "current" and not model.pending.is_empty()

## Highlight an empty save slot as soon as the current skill is selected.
func _save_slot_accepts() -> bool:
	return Rules.SAVED_SKILLS_ENABLED and _current_skill_selected() and model.saved_skill.is_empty()

## Draw End Turn and effective leftover healing beside the dice.
func _draw_end_turn() -> void:
	if is_instance_valid(tarot_ui) and tarot_ui.inventory_visible(): return
	if view_phase in ["over","reward"]: return
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var at: Vector2 = _saved_slot_center()
	var radius: float = _saved_slot_radius()
	var enabled: bool = _can_end_turn()
	var color: Color = GOLD if enabled else MUTED
	var pop: float = dice_selection.PromptPulse.scale_at(dice_selection.end_turn_prompt_age) if enabled and not reduced else 1.0
	draw_set_transform(at,0,Vector2.ONE*pop)
	Pixel.disc(self,Vector2.ZERO,radius,Color(INK,0.75),2)
	Pixel.circle(self,Vector2.ZERO,radius,Color(color,0.9 if enabled else 0.35),3)
	_center(Vector2(0,5),"END TURN",22 if portrait else 14,color)
	draw_set_transform(Vector2.ZERO)
	if enabled:
		var total: int = model.leftover_total_healing()
		var caption_radius: float = radius*1.22
		_center(at+Vector2(0,caption_radius+29 if portrait else caption_radius+23),GameText.format("+%d HP",total),22 if portrait else 14,TEAL)
		_center(at+Vector2(0,caption_radius+54 if portrait else caption_radius+42),GameText.format("TREASURE +%d",model.dice_turn.rolls_left),18 if portrait else 12,color)

## End Turn replaces skill saving and is unavailable during every modal or cast.
func _can_end_turn() -> bool:
	return view_phase == "ready" and model.can_end_dice_turn() and not _menus_open() and not tarot_ui.inventory_visible() and not dice_selection.dragging

## Return leftover embers as healing, then let the enemies act.
func _end_dice_turn(from_tarot: bool = false) -> void:
	if (not from_tarot and not _can_end_turn()) or not model.end_dice_turn(): return
	var token: int = run_id
	_clear_skill()
	_sound("ui/book",1.0,-18)
	if model.pending.is_empty():
		await _enemy_phase()
		return
	if not model.begin_player_cast(): return
	result = MultiHitSkill.new()
	view_phase = "resolving"
	status_title = "HEALING EMBERS"
	status_color = TEAL
	if not await leftover_volley.play(token): return
	attack_target = -1
	if model.phase == "turn_end" and not await _resolve_turn_end(token): return
	if _check_over(): return
	if model.phase in ["roll","player"]: _show_pending_skill()
	else: await _enemy_phase()

func _draw_perfect_combo() -> void:
	if is_instance_valid(tarot_ui) and tarot_ui.inventory_visible(): return
	if view_phase in ["over", "reward"]: return
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var at: Vector2 = _perfect_combo_center()
	var radius: float = _saved_slot_radius()
	var active: bool = model.perfect_combo > 0
	var burning: bool = model.perfect_combo >= 5
	var color: Color = Color("ffb653") if burning else GOLD if active else MUTED
	if burning: _draw_combo_flames(at,radius)
	var flash: float = 0.0 if reduced else clampf((combo_flash_until-clock_time)/0.45,0,1)
	if active:
		for i in range(3,0,-1):
			Pixel.circle(self,at,radius+i*4,Color(GOLD,0.08+flash*0.16),3)
	Pixel.disc(self,at,radius,Color(INK,0.9),2)
	Pixel.circle(self,at,radius,Color(color,0.9 if active else 0.4),3)
	Pixel.circle(self,at,radius-7,Color(color,0.35),2)
	_center(at+Vector2(0,-radius-12),"PERFECT",20 if portrait else 12,color)
	var count_text: String = "x%.1f" % model.combo_multiplier()
	var count_size: int = 44 if portrait else 30
	while pixel_font.get_string_size(count_text,HORIZONTAL_ALIGNMENT_LEFT,-1,count_size).x > radius*1.5 and count_size > 12:
		count_size -= 2
	_center(at+Vector2(0,8),count_text,count_size,CREAM if active else MUTED)
	_center(at+Vector2(0,radius+27 if portrait else radius+20),"COMBO",20 if portrait else 12,color)

## A compact pixel fire celebrates five-plus Perfects without touching gameplay RNG.
func _draw_combo_flames(at: Vector2, radius: float) -> void:
	for i in range(4,0,-1):
		Pixel.disc(self,at,radius+i*5,Color(1,0.36,0.08,0.035),3)
	if reduced: return
	for i in range(11):
		var phase: float = i*2.399
		var x: float = sin(phase)*radius*0.85
		var lift: float = radius*(0.35+0.18*sin(clock_time*7+phase))
		var root := at+Vector2(x,-radius*0.35)
		var tip := root+Vector2(sin(clock_time*5+phase)*6,-radius*0.6-lift)
		draw_colored_polygon(PackedVector2Array([root-Vector2(10,0),tip,root+Vector2(10,0)]),Color(1,0.32,0.06,0.48))
		Pixel.line(self,root,root.lerp(tip,0.7),Color(1,0.72,0.19,0.7),4)
		var rise: float = fposmod(clock_time*0.7+i*0.17,1.0)
		Pixel.disc(self,at+Vector2(x,-radius*0.5-rise*radius*0.9),2.5,Color(1,0.8,0.33,(1-rise)*0.7),2)

func _draw_dice_circle() -> void:
	_draw_end_turn()
	_draw_perfect_combo()
	if is_instance_valid(tarot_ui): draw_set_transform_matrix(tarot_ui.dice_transform())
	var layout_scale: float = DICE_RADIUS / 144.0
	var available: bool = view_phase in ["ready", "skill", "charging"] and not _menus_open()
	var spent: bool = _dice_spent()
	var fever: bool = model.is_city() and view_phase in ["ready", "charging", "rolling"] and not _menus_open()
	var color: Color = Color("696a70") if spent else GOLD if available or fever else status_color
	Pixel.disc(self, DICE_CENTER + Vector2(0, 6), DICE_RADIUS + 6, Color(INK, 0.7))
	Pixel.disc(self, DICE_CENTER, DICE_RADIUS, Color("29292d") if spent else Color("303529"))
	Pixel.disc(self, DICE_CENTER, DICE_RADIUS - 10, Color("202024") if spent else Color("252d25"))
	for i in range(4, 0, -1):
		Pixel.circle(self, DICE_CENTER, DICE_RADIUS + i * 3, Color(color, ring_hover * (0.13 - i * 0.02)), 3)
	Pixel.circle(self, DICE_CENTER, DICE_RADIUS, Color(color, 0.6 + ring_hover * 0.4), 3)
	Pixel.circle(self, DICE_CENTER, DICE_RADIUS - 8, Color(color, 0.25 + ring_hover * 0.25), 2)
	if fever:
		var pulse: float = 0.7 if reduced else (sin(city_life.clock * TAU * 1.8) + 1) * 0.5
		Pixel.circle(self, DICE_CENTER, DICE_RADIUS+8, Color(GOLD,0.35+pulse*0.65),4)
		Pixel.circle(self, DICE_CENTER, DICE_RADIUS-3, Color(CREAM,0.15+pulse*0.6),3)
		for i in range(8):
			var direction := Vector2.from_angle(-PI/8 + i*TAU/8)
			var at: Vector2 = DICE_CENTER + direction*(DICE_RADIUS+13+(0 if reduced else pulse*4))
			var wing: Vector2 = direction.orthogonal()*7
			Pixel.line(self,at+direction*8-wing,at,Color(GOLD,0.5+pulse*0.5),3)
			Pixel.line(self,at+direction*8+wing,at,Color(GOLD,0.5+pulse*0.5),3)
	Pixel.circle(self, DICE_CENTER, 108 * layout_scale, Color(color, 0.3 + ring_hover * 0.2), 2)
	# Two interlaced triangles and twelve hand-drawn pixel runes form a seal.
	for offset in [0.0, PI]:
		for i in range(3):
			var a: Vector2 = DICE_CENTER + Vector2.from_angle(-PI / 2 + offset + i * TAU / 3) * 106 * layout_scale
			var b: Vector2 = DICE_CENTER + Vector2.from_angle(-PI / 2 + offset + (i + 1) * TAU / 3) * 106 * layout_scale
			Pixel.line(self, a, b, Color(color, 0.35 + ring_hover * 0.25), 2)
	for i in range(12):
		var p: Vector2 = DICE_CENTER + Vector2.from_angle(-PI / 2 + i * TAU / 12) * 124 * layout_scale
		_rune(p.snapped(Vector2.ONE * 2), i % 6, Color(color, 0.65 + ring_hover * 0.35), 2)
	draw_set_transform(Vector2.ZERO)

func _rune(at: Vector2, index: int, color: Color, unit: int = 2, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	var patterns := ["00100/01110/10101/00100/01010/10001/00100", "10001/01010/00100/11111/00100/00100/00100", "11110/10001/11110/10100/10010/10001/10000", "00100/01010/10001/01010/00100/00100/01110", "10001/10001/01110/00100/01110/10001/10001", "00100/10101/01110/10101/00100/01010/10001"]
	var rows: PackedStringArray = patterns[index % patterns.size()].split("/")
	for y in range(7):
		for x in range(5):
			if rows[y][x] == "1":
				canvas.draw_rect(Rect2((at + Vector2(x - 2, y - 3) * unit).round(), Vector2.ONE * unit), color)

func _glyph(at: Vector2, kind: String, color: Color, scale_factor: int = 1) -> void:
	if art.has(kind):
		var side: int = 32 * scale_factor
		_art(kind, Rect2(at - Vector2.ONE * side / 2, Vector2.ONE * side), color)
		return
	var patterns := {"thorns": "1001001/0101010/0011100/1111111/0011100/0101010/1001001", "sound": "0001000/0011010/1111001/1111001/1111001/0011010/0001000", "mute": "1001001/0111010/1111100/1111000/1111100/0011010/0001001", "close": "1000001/0100010/0010100/0001000/0010100/0100010/1000001"}
	var rows: PackedStringArray = patterns.get(kind, patterns.close).split("/")
	var unit: int = 2 * scale_factor
	for y in range(7):
		for x in range(7):
			if rows[y][x] == "1":
				draw_rect(Rect2((at + Vector2(x - 3, y - 3) * unit).round(), Vector2.ONE * unit), color)

func _draw_tooltips() -> void:
	var mouse := get_global_mouse_position()
	var value: String = ""
	if MENU_RECT.has_point(mouse): value = "Menu"
	elif AUDIO_RECT.has_point(mouse): value = "Sound off" if muted else "Sound on"
	elif SPEED_RECT.has_point(mouse): value = "Fever speed" if model.is_city() else "Animation speed"
	if not value.is_empty():
		_frame(Rect2(988, 66, 256, 36), PANEL, GOLD)
		_center(Vector2(1116, 91), value, 16, CREAM)
	for item in _active_statuses():
		if _status_rect(item.id).has_point(mouse):
			var description: String = _status_description(item.id,item.turns)
			var lines := GameText.lines(description,description_font,22,526)
			var top: float = 434-(74+lines.size()*28)
			_frame(Rect2(38,top,566,74+lines.size()*28), PANEL, GOLD)
			_text(Vector2(55,top+30), item.name, 20, item.color)
			_wrapped(Vector2(55,top+66), description, 526, CREAM,22)

func _remaining_turns(amount: int) -> String:
	return GameText.remaining(amount)

func _pair_description(index: int) -> String:
	if index == 1 and model.is_city(): return "City is immune to freeze."
	var remaining: int = int(model.status_count(index + 1))
	if index == 5 and model.is_city():
		return _status_description(Status.IMMUNITY,remaining) if remaining > 0 else "Invincible for 2 seconds per spare-die stack."
	if remaining > 0:
		match index:
			2: return GameText.text("Adds +0.5 to DMG. Stacks with other bonuses.") + " " + GameText.remaining(remaining,"attack")
			5: return GameText.text("Invincible.") + " " + _remaining_turns(remaining)
	return Rules.PAIR_TEXT[index]

func _special_description(index: int) -> String:
	if index == 2 and model.statuses[33].count > 0:
		return GameText.text("Adds +2.0 to DMG. Stacks with other bonuses.") + " " + GameText.remaining(model.statuses[33].count,"attack")
	return Rules.CITY_SPECIAL_TEXT[index] if model.is_city() else Rules.SPECIAL_TEXT[index]

func _draw_ending() -> void:
	draw_rect(Rect2(0, 80, 1280, 720), Color(0.06, 0.08, 0.05, 0.88))
	var won: bool = model.outcome() == "victory"
	var color: Color = GOLD if won else RED
	_frame(Rect2(350, 207, 580, 317), Color("39402e"), color)
	_rune(Vector2(640, 245), 5, color, 3)
	_center(Vector2(640, 284), "THE INNER SANCTUM FALLS" if won else "BACK TO THE ABYSS", 16, color)
	_center(Vector2(640, 354), "VICTORY" if won else "DEFEAT", 48)
	_center(Vector2(640, 397), GameText.format("STAGE %d / %d   -   %d HP", [model.stage + 1, Run.PLAYABLE_WAVES, model.hp]), 16, MUTED)
	_button(REPLAY_RECT, "RESTART")
	if home_enabled: _button(_home_rect(), "HOME")

func _home_rect() -> Rect2:
	return Rect2(974, 96, 140, 36) if guide else Rect2(531, 548, 218, 53)

func _draw_guide(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(0,0,1280,800),Color(0.06,0.08,0.05))
	_frame(Rect2(86,76,1108,681),Color("333b2e"),GOLD,canvas)
	_text(Vector2(116,126),"DICE GRIMOIRE",32,GOLD,canvas)
	_button(GUIDE_STATUSES,"SKILLS" if guide_status_page else "STATUS EFFECTS",true,canvas)
	_button(GUIDE_CLOSE,"X",true,canvas)
	if home_enabled: _button(_home_rect(),"HOME",true,canvas)
	_wrapped(Vector2(116,165),"Matching dice attack automatically. Connect 3-6 consecutive unique faces to summon a fire skill, or tap dice then OK. Three rolls per turn.",1040,CREAM,18,canvas)
	if guide_status_page:
		_draw_status_help(canvas)
		return
	for column in range(2):
		var x: float = 116+column*540
		_text(Vector2(x,232),"AUTO ATTACKS" if column == 0 else "FIRE SKILLS",22,TEAL if column == 0 else PURPLE,canvas)
		var entries: Array = Rules.Patterns.help_entries(column == 1)
		var y: float = 270
		for entry in entries:
			_text(Vector2(x,y),entry.name,19,GOLD,canvas)
			y += 25
			for line in GameText.lines(entry.text,description_font,20,504):
				canvas.draw_string(description_font,Vector2(x,y),line,HORIZONTAL_ALIGNMENT_LEFT,-1,20,CREAM)
				y += 24
			y += 18
	_wrapped(Vector2(116,670),"End Turn: leftover pip sum x 1% of maximum HP is restored. Darkness blocks healing.",1040,MUTED,18,canvas)
	_wrapped(Vector2(116,723),Rules.Patterns.BONUS_TURN_HELP,1040,MUTED,18,canvas)

func _draw_status_help(canvas: CanvasItem) -> void:
	var portrait: bool = fx.canvas_size.y > fx.canvas_size.x
	var items: Array = Statuses.help_entries()
	var per_column: int = items.size() if portrait else ceili(items.size()/2.0)
	var body_size: int = 26 if portrait else 22
	var width: float = 724 if portrait else 504
	var y: float = 550 if portrait else 238
	for i in range(items.size()):
		if i == per_column: y = 238
		var x: float = 40 if portrait else 116+floori(i/float(per_column))*540
		var item: Dictionary = items[i]
		StatusPaint.icon(canvas,Vector2(x+14,y+(18 if portrait else 10)),13 if portrait else 11,item.icon,item.color)
		_text(Vector2(x+40,y+(28 if portrait else 20)),item.name,28 if portrait else 20,item.color,canvas)
		y += 62 if portrait else 46
		y = _wrapped(Vector2(x,y),item.text,width,CREAM,body_size,canvas)+body_size+(18 if portrait else 10)
		canvas.draw_line(Vector2(x,y-8),Vector2(x+width,y-8),Color(EDGE,0.35),1)

func _debug_option_rect(choice: int) -> Rect2:
	if choice == -1: return Rect2(136, 176, 250, 40)
	if choice == 0: return Rect2(407, 176, 360, 40)
	var face: int = choice if choice <= 6 else choice - 6
	return Rect2(136 + (face - 1) * 158, 282 if choice <= 6 else 449, 148, 103)

func _mini_die(at: Vector2, face: int, tint: Color = CREAM, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	if face == 0:
		canvas.draw_rect(Rect2(at-Vector2(16,18),Vector2(32,36)),tint)
		_center(at + Vector2(0, 4), "?", 16, INK, canvas)
		return
	Die.Art.paint_face(canvas,at,face,34,Color.WHITE if tint == CREAM else tint)

## Render Chinese debug controls above all gameplay layers.
func _draw_debug(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	canvas.draw_rect(Rect2(0, 0, 1280, 800), INK)
	_frame(Rect2(106, 100, 1070, 592), PANEL, GOLD, canvas)
	_text(Vector2(136, 148), "调试", 32, GOLD, canvas)
	_button(DEBUG_CLOSE, "X", true, canvas)
	_button(_debug_option_rect(-1), "自然随机", true, canvas)
	_button(_debug_option_rect(0), "顺子 1—6", true, canvas)
	_button(DEBUG_REPEAT, "重复：" + ("开" if debug_repeat else "关"), true, canvas)
	_button(DEBUG_PERFECT, "完美投掷：" + ("开" if debug_perfect else "关"), true, canvas)
	if debug_perfect: canvas.draw_rect(DEBUG_PERFECT.grow(-3), GOLD, false, 2)
	_text(Vector2(136, 259), "两个一样 / 技能", 16, TEAL, canvas)
	_text(Vector2(136, 426), "六个一样 / 湮灭", 16, PURPLE, canvas)
	for choice in range(1, 13):
		var rect: Rect2 = _debug_option_rect(choice)
		var face: int = choice if choice <= 6 else choice - 6
		var color: Color = TEAL if choice <= 6 else GOLD if choice == 12 else PURPLE
		_frame(rect, Color("53613d") if choice == debug_choice else PANEL, color if rect.has_point(get_global_mouse_position()) or choice == debug_choice else EDGE, canvas)
		for i in range(3):
			_mini_die(rect.position + Vector2(30 + i * 44, 38), 0 if choice <= 6 and i == 2 else face, CREAM.darkened(0.3) if choice <= 6 and i == 2 else CREAM, canvas)
		_center(rect.get_center() + Vector2(0, 32), "%d%d" % [face, face] if choice <= 6 else str(face).repeat(6), 16, color, canvas)
	_button(DEBUG_CHEST,"生成普通宝箱",_can_debug_chest(),canvas)
	_button(DEBUG_TREASURE,"充满重投宝箱进度",true,canvas)
	_button(DEBUG_TAROTS,"获得全部22张塔罗牌", true, canvas)
	_button(DEBUG_TAROT_DRAW,"抽取塔罗牌", true, canvas)
	_text(Vector2(136, 653), "关卡", 16, GOLD, canvas)
	_button(DEBUG_WAVE_LOAD,"载入", true, canvas)
	_text(Vector2(548,653),debug_wave_error,16,RED, canvas)
