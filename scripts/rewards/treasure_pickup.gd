extends Node2D
## Cosmetic receipts: banked rerolls light one meter diamond per arriving orb.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const GOLD := Color("ffd773")
const FLIGHT_TIME := 0.58
const STAGGER := 0.12
const IMPACT_TIME := 0.34
var battle
var orbs: Array = []
var impacts: Array = []
var last_progress := 0

func _ready() -> void:
	z_index = 65
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Claims and restarts discard old receipts without touching the committed reward.
func reset() -> void:
	orbs.clear()
	impacts.clear()
	last_progress = 0
	queue_redraw()

## The model emits earned points as End Turn commits, before enemies act.
func progress_changed(previous: int, current: int) -> void:
	if current <= previous:
		reset()
		last_progress = current
		return
	last_progress = current
	var origin: Vector2 = battle._saved_slot_center()
	for index in range(previous,current):
		orbs.append({"index":index,"origin":origin,"age":-STAGGER*(index-previous),"side":1 if index%2 == 0 else -1})
	queue_redraw()

## Show earned points as filled only when their receipt has reached the diamond.
func displayed_progress() -> int:
	return maxi(0,battle.model.reroll_progress-orbs.size())

## A small rising curve accelerates into the exact destination diamond.
func position_of(orb: Dictionary, age: float = -INF) -> Vector2:
	if age == -INF: age = orb.age
	var t: float = clampf(age/FLIGHT_TIME,0,1)
	var progress: float = t*t*(3-2*t)
	var target: Vector2 = battle._diamond_center(orb.index)
	var bow: float = (54 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 32)*sin(t*PI)
	return orb.origin.lerp(target,progress)+Vector2(orb.side*bow*0.22,-bow if not battle.reduced else 0.0)

## Pause with menus and hide beneath full-screen rewards; never block battle controls.
func _process(delta: float) -> void:
	if battle.model.reroll_progress < last_progress: reset()
	last_progress = battle.model.reroll_progress
	visible = not battle._menus_open() and not battle.inventory_page.opened and not battle.tarot_ui.ceremony.active() and battle.view_phase not in ["shop","reward","over"]
	if visible: advance(delta*clampf(battle.speed,1,2))

## Each landing lights one point, with a brief ring and soft rising collection tone.
func advance(delta: float) -> void:
	for impact in impacts: impact.age += delta
	impacts = impacts.filter(func(impact): return impact.age < IMPACT_TIME)
	var pending: Array = []
	for orb in orbs:
		orb.age += delta
		if orb.age >= FLIGHT_TIME:
			impacts.append({"index":orb.index,"age":0.0})
			battle._sound("item/crystal_collect",1.05+orb.index*0.035,-21)
		else: pending.append(orb)
	orbs = pending
	battle.queue_redraw()
	queue_redraw()

## Shiny gold cores, fading trails and a diamond-shaped impact echo the meter.
func _draw() -> void:
	var scale_factor: float = battle._reward_scale()
	for orb in orbs:
		if orb.age < 0: continue
		var at: Vector2 = position_of(orb)
		var radius: float = 7*scale_factor
		if not battle.reduced:
			for trail in range(5,0,-1):
				var past: Vector2 = position_of(orb,maxf(0,orb.age-trail*0.026))
				Pixel.disc(self,past,radius*(1-trail*0.12),Color(GOLD,0.32*(1-trail/6.0)),2)
		for layer in range(3,0,-1): Pixel.disc(self,at,radius+layer*4*scale_factor,Color(GOLD,0.08),2)
		Pixel.disc(self,at,radius,GOLD.lightened(0.25),2)
		Pixel.disc(self,at,radius*0.48,Color("fffdf1"),2)
		if not battle.reduced:
			Pixel.line(self,at-Vector2(radius*1.4,0),at+Vector2(radius*1.4,0),Color("fff1b7",0.65),2)
			Pixel.line(self,at-Vector2(0,radius*1.4),at+Vector2(0,radius*1.4),Color("fff1b7",0.65),2)
	for impact in impacts:
		var t: float = impact.age/IMPACT_TIME
		var at: Vector2 = battle._diamond_center(impact.index)
		var radius: float = (10+(5 if battle.reduced else 24)*t)*scale_factor
		Pixel.disc(self,at,radius,Color(GOLD,(1-t)*0.16),2)
		var corners := [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
		for i in range(4): Pixel.line(self,at+corners[i]*radius,at+corners[(i+1)%4]*radius,Color("fff4c4",(1-t)*0.9),2)
