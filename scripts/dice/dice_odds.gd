extends RefCounted
## Pure conditional odds, cached by weight values rather than roll power.
## Snapshot arrays detect both replacement and in-place mutation by modifiers.
var _triples: Array = []
var _pairs: Array = []
var _faces: Array = []
var _conditional: Array = [0.0,0.0,0.0] # normal, pair, triple; 64-bit floats

func six_probability(rates: Dictionary, triples: Array, pairs: Array, faces: Array) -> float:
	if triples != _triples or pairs != _pairs or faces != _faces:
		_triples = triples.duplicate()
		_pairs = pairs.duplicate()
		_faces = faces.duplicate()
		_conditional = _calculate(triples,pairs,faces)
	return rates.normal*_conditional[0] + rates.pair*_conditional[1] + rates.triple*_conditional[2]

static func _calculate(triples: Array, pairs: Array, faces: Array) -> Array:
	var triple_weights: Array = triples.map(func(w): return maxf(0,float(w)))
	var pair_weights: Array = pairs.map(func(w): return maxf(0,float(w)))
	var face_weights: Array = faces.map(func(w): return maxf(0,float(w)))
	var triple_total: float = _sum(triple_weights)
	var pair_total: float = _sum(pair_weights)
	var face_total: float = _sum(face_weights)
	var triple: float = triple_weights[5]/triple_total if triple_total > 0 else 1.0/6
	var pair: float = pair_weights[5]/pair_total if pair_total > 0 else 1.0/6
	for face in range(5):
		var paired: float = pair_weights[face]/pair_total if pair_total > 0 else 1.0/6
		var remaining: float = _sum(face_weights,face)
		# Match _match_values: exhausted spare weights choose the next face.
		var spare_six: float = face_weights[5]/remaining if remaining > 0 else 1.0 if face == 4 else 0.0
		pair += paired*spare_six
	var no_six: float = 0
	for a in range(5):
		var first: float = face_weights[a]/face_total if face_total > 0 else 1.0/6
		var second_total: float = _sum(face_weights,a)
		for b in range(5):
			if b == a: continue
			var second: float = face_weights[b]/second_total if second_total > 0 else 1.0/5
			var third_total: float = _sum(face_weights,a,b)
			for c in range(5):
				if c == a or c == b: continue
				var third: float = face_weights[c]/third_total if third_total > 0 else 1.0/4
				no_six += first*second*third
	return [1-no_six,pair,triple]

static func _sum(weights: Array, exclude_a: int = -1, exclude_b: int = -1) -> float:
	var total: float = 0
	for i in range(weights.size()):
		if i != exclude_a and i != exclude_b: total += weights[i]
	return total
