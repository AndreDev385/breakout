package main

import rl "vendor:raylib"

brick_hit_sound: rl.Sound
life_lost_sound: rl.Sound
power_up_sound: rl.Sound

init_sounds :: proc() {
	brick_hit_sound = rl.LoadSound("./assets/hit_brick.wav")
	life_lost_sound = rl.LoadSound("./assets/live_lost.wav")
	power_up_sound = rl.LoadSound("./assets/power_up.wav")
}

deinit_sounds :: proc() {
	rl.UnloadSound(brick_hit_sound)
	rl.UnloadSound(life_lost_sound)
	rl.UnloadSound(power_up_sound)
}

process_sound_events :: proc(events: ^bit_set[GameEvent]) {
	if .BrickHit in events^ { rl.PlaySound(brick_hit_sound) }
	if .LifeLost in events^ { rl.PlaySound(life_lost_sound) }
	if .PowerUp in events^  { rl.PlaySound(power_up_sound) }
	events^ = {}
}
