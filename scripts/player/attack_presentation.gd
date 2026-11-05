extends RefCounted
## Evolution changes spectacle only; damage, status applications and hit counts stay in combat rules.
const FORMS := [
	{"size":0.50,"particles":0.25,"glow":0.45,"shake":0.25,"loops":1,"ritual":0.72},
	{"size":0.72,"particles":0.55,"glow":0.70,"shake":0.55,"loops":2,"ritual":0.86},
	{"size":1.0,"particles":1.0,"glow":1.0,"shake":1.0,"loops":4,"ritual":1.0}
]

## Capture one evolution's visual settings at cast start.
static func for_form(form: int) -> Dictionary:
	return FORMS[clampi(form,0,FORMS.size()-1)]

## Fewer visual cycles still leave the requested spacing between existing damage ticks.
static func loop_timing(form: int, frames: int, fps: float, ticks: int, tick_interval: float = 0.1) -> Dictionary:
	var total: int = frames*int(for_form(form).loops)
	var duration: float = maxf(total/fps,tick_interval*maxi(0,ticks-1))
	return {"loop_frames":total,"loop_duration":duration,"loop_fps":total/duration}
