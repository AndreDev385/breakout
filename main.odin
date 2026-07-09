package main

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

SCREEN_WIDTH :: 640 * 2
SCREEN_HEIGHT :: 480 * 2

MAX_ANGLE :: math.PI / 3

MAX_BRICKS :: 1000

PADDLE_WIDTH :: 100
PADDLE_HEIGHT :: 20
PADDLE_SPEED :: 450

BALL_SPEED :: 500
BALL_RADIUS :: 12.0

POWER_UP_SIZE :: 25
POWER_UP_SPEED :: 300

LEVELS := []string{"./assets/level_01.json", "./assets/level_02.json", "./assets/level_03.json"}

HIGH_SCORE_COUNT :: 5

TILESET_COLUMNS :: 3
TILESET_TILE_SIZE :: 32

Tiled_Property :: struct {
	name:  string `json:"name"`,
	type:  string `json:"type"`,
	value: json.Value `json:"value"`,
}

Tiled_Object :: struct {
	x:          f64 `json:"x"`,
	y:          f64 `json:"y"`,
	width:      f64 `json:"width"`,
	height:     f64 `json:"height"`,
	gid:        i32 `json:"gid"`,
	name:       string `json:"name"`,
	properties: []Tiled_Property `json:"properties"`,
}

Tiled_Layer :: struct {
	name:       string `json:"name"`,
	type:       string `json:"type"`,
	width:      i32 `json:"width"`,
	height:     i32 `json:"height"`,
	data:       []i32 `json:"data"`,
	objects:    []Tiled_Object `json:"objects"`,
	properties: []Tiled_Property `json:"properties"`,
}

Tiled_Map :: struct {
	width:      i32 `json:"width"`,
	height:     i32 `json:"height"`,
	tilewidth:  i32 `json:"tilewidth"`,
	tileheight: i32 `json:"tileheight"`,
	layers:     []Tiled_Layer `json:"layers"`,
}

Brick :: struct {
	using rec: rl.Rectangle,
	lives:     int,
}

GameState :: enum {
	StartScreen,
	Serving,
	Playing,
	Paused,
	GameOver,
	GameWon,
}

Paddle :: struct {
	using rec: rl.Rectangle,
	speed:     f32,
	texture:   ^rl.Texture2D,
}

Ball :: struct {
	radius:  f32,
	speed:   f32,
	vel:     rl.Vector2,
	pos:     rl.Vector2,
	texture: ^rl.Texture2D,
}

PowerUpKind :: enum {
	WidePaddle,
	ExtraLife,
	SlowBall,
}

PowerUp :: struct {
	kind:      PowerUpKind,
	duration:  f32,
	timer:     f32,
	is_active: bool,
	chance:    f32,
}

PowerSquare :: struct {
	using rec: rl.Rectangle,
	kind:      PowerUpKind,
}

GameData :: struct {
	score:               int,
	high_scores:         [HIGH_SCORE_COUNT]int,
	lives:               int,
	ball:                Ball,
	paddle:              Paddle,
	bricks:              [MAX_BRICKS]Brick,
	bricks_count:        int,
	brick_texture:       ^rl.Texture2D,
	tileset_texture:     ^rl.Texture2D,
	power_ups:           [len(PowerUpKind)]PowerUp,
	power_squares:       [dynamic]PowerSquare,
	// power ups textures
	slow_ball_texture:   ^rl.Texture2D,
	life_texture:        ^rl.Texture2D,
	wide_paddle_texture: ^rl.Texture2D,
	level:               Tiled_Map,
	current_level:       int,
}

load_level :: proc(path: string) -> (map_data: Tiled_Map, ok: bool) {
	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil do return
	defer delete(data)

	unmarshal_err := json.unmarshal(data, &map_data)
	if unmarshal_err != nil do return

	return map_data, true
}

get_play_area_from_level :: proc(map_data: ^Tiled_Map) -> rl.Rectangle {
	for layer in map_data.layers {
		if layer.name != "scene" do continue
		for obj in layer.objects {
			if obj.name == "play_area" {
				return {
					x = f32(obj.x),
					y = f32(obj.y),
					width = f32(obj.width),
					height = f32(obj.height),
				}
			}
		}
	}
	return {0, 0, 640, 864}
}

load_scene_from_level :: proc(map_data: ^Tiled_Map) -> rl.Rectangle {
	play_area := get_play_area_from_level(map_data)
	map_total_height := f32(map_data.height * map_data.tileheight)
	map_offset_y := SCREEN_HEIGHT - map_total_height
	return {
		x = (SCREEN_WIDTH - play_area.width) / 2,
		y = play_area.y + map_offset_y,
		width = play_area.width,
		height = play_area.height,
	}
}

load_bricks_from_level :: proc(
	map_data: ^Tiled_Map,
	offset: rl.Vector2,
	bricks: ^[MAX_BRICKS]Brick,
) -> int {
	count := 0

	for layer in map_data.layers {
		if layer.name != "bricks" || layer.type != "objectgroup" do continue

		for obj in layer.objects {
			lives := 1
			for prop in obj.properties {
				if prop.name == "lives" && prop.type == "int" {
					#partial switch v in prop.value {
					case f64:
						lives = int(v)
					case i64:
						lives = int(v)
					}
				}
			}

			bricks[count] = {
				x      = offset.x + f32(obj.x),
				y      = offset.y + f32(obj.y),
				width  = f32(obj.width),
				height = f32(obj.height),
				lives  = lives,
			}
			count += 1
		}
	}

	return count
}

load_current_level :: proc(data: ^GameData, scene: ^rl.Rectangle) -> bool {
	level_path := LEVELS[data.current_level]
	level, ok := load_level(level_path)
	if !ok {
		fmt.eprintf("Failed to load level: %s\n", level_path)
		return false
	}

	data.level = level
	play_area := get_play_area_from_level(&data.level)
	scene^ = load_scene_from_level(&data.level)
	map_offset := rl.Vector2{scene.x - play_area.x, scene.y - play_area.y}
	data.bricks_count = load_bricks_from_level(&data.level, map_offset, &data.bricks)
	return true
}

draw_level_background :: proc(map_data: ^Tiled_Map, texture: ^rl.Texture2D, offset: rl.Vector2) {
	for layer in map_data.layers {
		if layer.name != "background" || layer.type != "tilelayer" do continue

		for tile_id, i in layer.data {
			if tile_id == 0 do continue

			tile_id_0 := tile_id - 1
			src := rl.Rectangle {
				x      = f32((tile_id_0 % TILESET_COLUMNS) * TILESET_TILE_SIZE),
				y      = f32((tile_id_0 / TILESET_COLUMNS) * TILESET_TILE_SIZE),
				width  = TILESET_TILE_SIZE,
				height = TILESET_TILE_SIZE,
			}

			col := i % int(layer.width)
			row := i / int(layer.width)
			dst := rl.Rectangle {
				x      = offset.x + f32(col * TILESET_TILE_SIZE),
				y      = offset.y + f32(row * TILESET_TILE_SIZE),
				width  = TILESET_TILE_SIZE,
				height = TILESET_TILE_SIZE,
			}

			rl.DrawTexturePro(texture^, src, dst, {0, 0}, 0, rl.WHITE)
		}
	}
}

reset_game_data :: proc(data: ^GameData, scene: rl.Rectangle) {
	data.lives = 5
	data.score = 0
	data.power_ups = {
		{timer = 0, duration = 5, is_active = false, kind = .WidePaddle, chance = 20},
		{timer = 0, duration = 0, is_active = false, kind = .ExtraLife, chance = 1},
		{timer = 0, duration = 5, is_active = false, kind = .SlowBall, chance = 10},
	}
	clear(&data.power_squares)
	reset_ball_and_paddle(&data.ball, &data.paddle, scene)
}

reset_ball_and_paddle :: proc(ball: ^Ball, paddle: ^Paddle, scene: rl.Rectangle) {
	paddle.rec = {
		x      = (scene.x + (scene.width / 2)) - (PADDLE_WIDTH / 2),
		y      = scene.y + scene.height - PADDLE_HEIGHT - 64,
		width  = PADDLE_WIDTH,
		height = PADDLE_HEIGHT,
	}
	paddle.speed = PADDLE_SPEED

	ball.speed = BALL_SPEED
	ball.radius = BALL_RADIUS
	ball.vel = {0, -BALL_SPEED}
	ball.pos = {f32(scene.x + (scene.width / 2)), f32(paddle.y - BALL_RADIUS)}
}

process_input :: proc(data: ^GameData, state: GameState, scene: rl.Rectangle, dt: f32) {
	if state == .Playing {
		if rl.IsKeyDown(.D) {
			data.paddle.x += (data.paddle.speed * dt)
			if data.paddle.x + data.paddle.width > scene.x + scene.width {
				data.paddle.x = (scene.x + scene.width) - data.paddle.width
			}
		}

		if rl.IsKeyDown(.A) {
			data.paddle.x -= (data.paddle.speed * dt)
			if data.paddle.x < scene.x {
				data.paddle.x = scene.x
			}
		}
	}
}

apply_power_up :: proc(data: ^GameData, scene: rl.Rectangle, kind: PowerUpKind) {
	switch kind {
	case .WidePaddle:
		data.paddle.x -= PADDLE_WIDTH / 2
		data.paddle.width = PADDLE_WIDTH * 2
		if data.paddle.x + data.paddle.width > scene.x + scene.width {
			data.paddle.x = scene.x + scene.width - data.paddle.width
		}

		if data.paddle.x < 0 {
			data.paddle.x = 0
		}
	case .ExtraLife:
		data.lives += 1
	case .SlowBall:
		data.ball.speed = BALL_SPEED / 2

		velx := data.ball.vel.x / 2
		vely := data.ball.vel.y / 2
		data.ball.vel.x = math.clamp(velx, -BALL_SPEED, BALL_SPEED)
		data.ball.vel.y = math.clamp(vely, -BALL_SPEED, BALL_SPEED)
	}
}

revert_power_up :: proc(data: ^GameData, kind: PowerUpKind) {
	switch kind {
	case .WidePaddle:
		data.paddle.width = PADDLE_WIDTH
		data.paddle.x += PADDLE_WIDTH / 2
	case .ExtraLife:
		return
	case .SlowBall:
		data.ball.speed = BALL_SPEED

		velx := data.ball.vel.x * 2
		vely := data.ball.vel.y * 2
		data.ball.vel.x = math.clamp(velx, -BALL_SPEED, BALL_SPEED)
		data.ball.vel.y = math.clamp(vely, -BALL_SPEED, BALL_SPEED)
	}
}

update_simulation :: proc(data: ^GameData, state: GameState, scene: rl.Rectangle, dt: f32) {
	if state == .Playing {
		// move ball
		data.ball.pos += data.ball.vel * dt

		ball_fell := data.ball.pos.y >= scene.y + scene.height

		// ball collisions
		if data.ball.pos.x - data.ball.radius <= scene.x {
            data.ball.pos.x = scene.x + data.ball.radius
			data.ball.vel.x = -data.ball.vel.x
		}

		if data.ball.pos.y - data.ball.radius <= scene.y {
			data.ball.vel.y = -data.ball.vel.y
		}

		if data.ball.pos.x + data.ball.radius >= scene.x + scene.width {
            data.ball.pos.x = scene.x + scene.width - data.ball.radius
			data.ball.vel.x = -data.ball.vel.x
		}

		if ball_fell {
			data.lives -= 1
		}

		// ball + paddle collision
		nearest_x := math.clamp(data.ball.pos.x, data.paddle.x, data.paddle.x + data.paddle.width)
		nearest_y := math.clamp(data.ball.pos.y, data.paddle.y, data.paddle.y + data.paddle.height)

		dx := data.ball.pos.x - nearest_x
		dy := data.ball.pos.y - nearest_y

		distance := math.sqrt_f32(dx * dx + dy * dy)

		if distance <= data.ball.radius {
			data.ball.pos.y = nearest_y - data.ball.radius
			hit_factor :=
				(data.ball.pos.x - (data.paddle.x + data.paddle.width / 2)) /
				(data.paddle.width / 2)
			angle := hit_factor * MAX_ANGLE
			data.ball.vel.x = data.ball.speed * math.sin_f32(angle)
			data.ball.vel.y = -data.ball.speed * math.cos_f32(angle)
		}

		for &brick in data.bricks[:data.bricks_count] {
			nearest_x := math.clamp(data.ball.pos.x, brick.x, brick.x + brick.width)
			nearest_y := math.clamp(data.ball.pos.y, brick.y, brick.y + brick.height)

			dx := data.ball.pos.x - nearest_x
			dy := data.ball.pos.y - nearest_y

			distance := math.sqrt_f32(dx * dx + dy * dy)

			if distance <= data.ball.radius {
				left := data.ball.pos.x + data.ball.radius - brick.x
				right := brick.x + brick.width - data.ball.pos.x - data.ball.radius
				up := data.ball.pos.y + data.ball.radius - brick.y
				bottom := brick.y + brick.height - data.ball.pos.y - data.ball.radius

				min_overlap_x := min(left, right)
				min_overlap_y := min(up, bottom)

				if min_overlap_x < min_overlap_y {
					data.ball.vel.x = -data.ball.vel.x
				} else {
					data.ball.vel.y = -data.ball.vel.y
				}

				brick.lives -= 1
				data.score += 10

				// create power up
				for power_up in data.power_ups {
					random := rand.float32_range(0, 101)
					if random <= power_up.chance {
						kind := PowerUpKind(rand.int31_max(len(PowerUpKind)))
						sq := PowerSquare {
							x      = brick.x + brick.width / 2 - POWER_UP_SIZE / 2,
							y      = brick.y + brick.height / 2 - POWER_UP_SIZE / 2,
							width  = POWER_UP_SIZE,
							height = POWER_UP_SIZE,
							kind   = kind,
						}
						append(&data.power_squares, sq)
					}
				}
			}
		}

		// Move dead bricks to the end
		j := 0
		for i in 0 ..< data.bricks_count {
			if data.bricks[i].lives > 0 {
				data.bricks[j] = data.bricks[i]
				j += 1
			}
		}
		data.bricks_count = j

		// move power squares down & check collision
		for &sq, i in data.power_squares {
			sq.y += POWER_UP_SPEED * dt

			if rl.CheckCollisionRecs(sq, data.paddle) {
				pu := &data.power_ups[int(sq.kind)]
				if !pu.is_active do apply_power_up(data, scene, pu.kind)
				pu.is_active = true
				if pu.duration > 0 do pu.timer = pu.duration
				data.score += 30
				unordered_remove(&data.power_squares, i)
			}

			if sq.y >= scene.y + scene.height {
				unordered_remove(&data.power_squares, i)
			}
		}

		for &pu in data.power_ups {
			if pu.is_active {
				if pu.duration > 0 {
					pu.timer -= dt

					if pu.timer <= 0 {
						pu.timer = 0
						pu.is_active = false
						revert_power_up(data, pu.kind)
					}
				} else {
					pu.is_active = false
					revert_power_up(data, pu.kind)
				}
			}
		}
	}
}

compute_next_state :: proc(state: GameState, data: ^GameData, scene: ^rl.Rectangle) -> GameState {
	// CHANGE GAME STATE =======
	ball_fell := data.ball.pos.y >= scene.y + scene.height

	if state == .StartScreen && rl.IsKeyPressed(.SPACE) {
		return .Playing
	} else if state == .Playing && ball_fell {
		clear(&data.power_squares)
		if data.lives == 0 {
			insert_score(&data.high_scores, data.score)
			save_high_scores(&data.high_scores)
			return .GameOver
		} else {
			return .Serving
		}
	} else if state == .Playing && rl.IsKeyPressed(.P) {
		return .Paused
	} else if state == .Paused && rl.IsKeyPressed(.P) {
		return .Playing
	} else if state == .Playing && data.bricks_count == 0 {
		data.current_level += 1
		if data.current_level < len(LEVELS) {
			load_current_level(data, scene)
			reset_ball_and_paddle(&data.ball, &data.paddle, scene^)
			clear(&data.power_squares)
			return .Serving
		} else {
			insert_score(&data.high_scores, data.score)
			save_high_scores(&data.high_scores)
			return .GameWon
		}
	} else if state == .GameOver && rl.IsKeyPressed(.SPACE) {
		data.current_level = 0
		load_current_level(data, scene)
		reset_game_data(data, scene^)
		return .StartScreen
	} else if state == .GameWon && rl.IsKeyPressed(.SPACE) {
		data.current_level = 0
		load_current_level(data, scene)
		reset_game_data(data, scene^)
		return .StartScreen
	} else if state == .Serving && rl.IsKeyPressed(.SPACE) {
		reset_ball_and_paddle(&data.ball, &data.paddle, scene^)
		return .Playing
	}

	return state
}

draw_frame :: proc(data: ^GameData, state: GameState, scene: rl.Rectangle) {
	// DRAW ====================
	rl.ClearBackground(rl.BLACK)

	hud_font_size: i32 = 30

	lives_text := fmt.ctprintf("Lives %d  Score %d", data.lives, data.score)
	rl.DrawText(lives_text, i32(scene.x), i32(scene.y / 2), hud_font_size, rl.WHITE)

	bricks_text := fmt.ctprintf("Bricks left %d", data.bricks_count)
	text_width := rl.MeasureText(bricks_text, hud_font_size)
	rl.DrawText(
		bricks_text,
		i32(scene.x + scene.width) - text_width,
		i32(scene.y / 2),
		hud_font_size,
		rl.WHITE,
	)

	// Draw playable scene
	play_area := get_play_area_from_level(&data.level)
	map_offset := rl.Vector2{scene.x - play_area.x, scene.y - play_area.y}
	draw_level_background(&data.level, data.tileset_texture, map_offset)

	for sq in data.power_squares {
		texture: rl.Texture2D
		switch sq.kind {
		case .WidePaddle:
			texture = data.wide_paddle_texture^
		case .ExtraLife:
			texture = data.life_texture^
		case .SlowBall:
			texture = data.slow_ball_texture^
		}

		rl.DrawTexturePro(texture, {0, 0, 32, 32}, sq, {0, 0}, 0, rl.WHITE)
	}

	for i in 0 ..< data.bricks_count {
		brick := data.bricks[i]
		rl.DrawTexturePro(
			data.brick_texture^,
			{0, 0, 64, 32},
			brick,
			{0, 0},
			0,
			brick_color(brick.lives),
		)
	}

	rl.DrawTexturePro(data.paddle.texture^, {0, 0, 32, 16}, data.paddle, {0, 0}, 0, rl.WHITE)

	rl.DrawTexturePro(
		data.ball.texture^,
		{0, 0, 32, 32},
		{
			data.ball.pos.x - data.ball.radius,
			data.ball.pos.y - data.ball.radius,
			data.ball.radius * 2,
			data.ball.radius * 2,
		},
		{0, 0},
		0,
		rl.WHITE,
	)

	switch state {
	case .Serving, .StartScreen:
		text: cstring = "Press SPACE to start"
		text_width := rl.MeasureText(text, 32)
		rl.DrawText(
			text,
			i32(scene.x) + i32(scene.width / 2) - (text_width / 2),
			i32(scene.y + scene.height / 2),
			32,
			rl.WHITE,
		)
	case .Paused:
		text: cstring = "Press 'P' to resume"
		text_width := rl.MeasureText(text, 32)
		rl.DrawText(
			text,
			i32(scene.x) + i32(scene.width / 2) - (text_width / 2),
			i32(scene.y + scene.height / 2),
			32,
			rl.WHITE,
		)
	case .GameOver:
		text: cstring = "Game Over"
		text_width := rl.MeasureText(text, 32)
		rl.DrawText(
			text,
			i32(scene.x) + i32(scene.width / 2) - (text_width / 2),
			i32(scene.y + scene.height / 2),
			32,
			rl.WHITE,
		)
	case .GameWon:
		text: cstring = "Congratulations!"
		text_width := rl.MeasureText(text, 32)
		rl.DrawText(
			text,
			i32(scene.x) + i32(scene.width / 2) - (text_width / 2),
			i32(scene.y + scene.height / 2),
			32,
			rl.WHITE,
		)
	case .Playing:
	}

	if state == .StartScreen || state == .Serving || state == .GameOver || state == .GameWon {
		y_base := i32(scene.y + scene.height / 2) + 70
		hs_header: cstring = "HIGH SCORES"
		header_width := rl.MeasureText(hs_header, 24)
		rl.DrawText(hs_header, i32(scene.x) + i32(scene.width / 2) - header_width / 2, y_base, 24, rl.YELLOW)
		for i in 0 ..< HIGH_SCORE_COUNT {
			entry := fmt.ctprintf("%d. %d", i + 1, data.high_scores[i])
			entry_width := rl.MeasureText(entry, 22)
			rl.DrawText(entry, i32(scene.x) + i32(scene.width / 2) - entry_width / 2, y_base + 30 + i32(i * 28), 22, rl.WHITE)
		}
	}
}

brick_color :: proc(lives: int) -> rl.Color {
	switch lives {
	case 1:
		return rl.WHITE
	case 2:
		return {136, 192, 112, 255}
	case 3:
		return {220, 214, 70, 255}
	case 4:
		return {238, 152, 73, 255}
	case 5:
		return {230, 95, 60, 255}
	case 6:
		return {200, 50, 50, 255}
	case:
		return {160, 50, 120, 255}
	}
}

get_hs_save_dir :: proc() -> string {
	xdg := os.get_env_alloc("XDG_DATA_HOME", context.allocator)
	if xdg != "" {
		defer delete(xdg)
		return fmt.tprintf("%s/breakout", xdg)
	}
	home := os.get_env_alloc("HOME", context.allocator)
	defer delete(home)
	return fmt.tprintf("%s/.local/share/breakout", home)
}

get_hs_save_path :: proc() -> string {
	dir := get_hs_save_dir()
	defer delete(dir)
	return fmt.tprintf("%s/highscores.txt", dir)
}

load_high_scores :: proc(scores: ^[HIGH_SCORE_COUNT]int) {
	path := get_hs_save_path()
	defer delete(path)

	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil {
		for i in 0 ..< HIGH_SCORE_COUNT { scores[i] = 0 }
		return
	}
	defer delete(data)

	count := 0
	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		if count >= HIGH_SCORE_COUNT { break }
		val := 0
		for ch in line {
			if ch >= '0' && ch <= '9' {
				val = val * 10 + int(ch - '0')
			}
		}
		scores[count] = val
		count += 1
	}
	for i in count ..< HIGH_SCORE_COUNT { scores[i] = 0 }
}

save_high_scores :: proc(scores: ^[HIGH_SCORE_COUNT]int) {
	dir := get_hs_save_dir()
	defer delete(dir)
	os.make_directory(dir, os.Permissions_All)

	path := get_hs_save_path()
	defer delete(path)

	data := fmt.tprintf("%d\n%d\n%d\n%d\n%d\n", scores[0], scores[1], scores[2], scores[3], scores[4])
	defer delete(data)
	_ = os.write_entire_file(path, transmute([]byte)(data))
}

insert_score :: proc(scores: ^[HIGH_SCORE_COUNT]int, new_score: int) {
	for i in 0 ..< HIGH_SCORE_COUNT {
		if new_score > scores[i] {
			for j := HIGH_SCORE_COUNT - 1; j > i; j -= 1 {
				scores[j] = scores[j - 1]
			}
			scores[i] = new_score
			return
		}
	}
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Breakout")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	ball_texture := rl.LoadTexture("./assets/ball.png")
	defer rl.UnloadTexture(ball_texture)
	paddle_texture := rl.LoadTexture("./assets/paddle.png")
	defer rl.UnloadTexture(paddle_texture)
	brick_texture := rl.LoadTexture("./assets/brick.png")
	defer rl.UnloadTexture(brick_texture)
	tileset_texture := rl.LoadTexture("./assets/tileset.png")
	defer rl.UnloadTexture(tileset_texture)

	// power ups textures
	slow_ball_texture := rl.LoadTexture("./assets/slow_ball.png")
	defer rl.UnloadTexture(slow_ball_texture)
	life_texture := rl.LoadTexture("./assets/life.png")
	defer rl.UnloadTexture(life_texture)
	wide_paddle_texture := rl.LoadTexture("./assets/wide_paddle.png")
	defer rl.UnloadTexture(wide_paddle_texture)

	game_state := GameState.StartScreen
	game_data: GameData
	game_data.ball.texture = &ball_texture
	game_data.paddle.texture = &paddle_texture
	game_data.brick_texture = &brick_texture
	game_data.tileset_texture = &tileset_texture
	game_data.power_squares = make([dynamic]PowerSquare, 0)
	game_data.wide_paddle_texture = &wide_paddle_texture
	game_data.life_texture = &life_texture
	game_data.slow_ball_texture = &slow_ball_texture
	defer free(&game_data.power_squares)

	scene: rl.Rectangle
	if !load_current_level(&game_data, &scene) {
		return
	}
	reset_game_data(&game_data, scene)
	load_high_scores(&game_data.high_scores)

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		process_input(&game_data, game_state, scene, dt)
		update_simulation(&game_data, game_state, scene, dt)
		game_state = compute_next_state(game_state, &game_data, &scene)

		rl.BeginDrawing()
		draw_frame(&game_data, game_state, scene)
		rl.EndDrawing()
	}
}
