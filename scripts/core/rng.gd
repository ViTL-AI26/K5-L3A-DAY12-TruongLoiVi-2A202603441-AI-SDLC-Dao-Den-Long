extends RefCounted
class_name SeededRNG

const MASK: int = 0xFFFFFFFF
const ZERO_SEED_FALLBACK: int = 0x6D2B79F5

var _state: int = ZERO_SEED_FALLBACK


func seed(value: int) -> void:
	_state = value & MASK
	if _state == 0:
		_state = ZERO_SEED_FALLBACK


func next_u32() -> int:
	var x: int = _state
	x = x ^ ((x << 13) & MASK)
	x = x ^ (x >> 17)
	x = x ^ ((x << 5) & MASK)
	_state = x & MASK

	if _state == 0:
		_state = ZERO_SEED_FALLBACK

	return _state


func randf() -> float:
	return float(next_u32()) / float(MASK)
