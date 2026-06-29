package main

import "core:fmt"
import "core:math"
import "core:math/rand"
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
}

PowerSquare :: struct {
	using rec: rl.Rectangle,
	kind:      PowerUpKind,
}

GameData :: struct {
	score:           int,
	lives:           int,
	ball:            Ball,
	paddle:          Paddle,
	bricks:          [MAX_BRICKS]Brick,
	bricks_count:    int,
	bg_texture:      ^rl.Texture2D,
	brick_texture:   ^rl.Texture2D,
	power_ups:       [len(PowerUpKind)]PowerUp,
	power_squares:   [dynamic]PowerSquare,
	power_up_chance: f32, // % of chances of get a power up e very time a brick is hit
}

Scene :: struct {
	using rect: rl.Rectangle,
	texture:    ^rl.Texture2D,
}

init_bricks :: proc(
	data: ^GameData,
	x: f32,
	y: f32,
	width: f32,
	height: f32,
	rows: int,
	cols: int,
	gap: f32,
) {
	for row in 0 ..< rows {
		for col in 0 ..< cols {
			data.bricks[row * cols + col] = {
				x      = f32(x + (f32(col) * width) + gap * f32(col)),
				y      = f32(y + (f32(row) * height) + gap * f32(row)),
				width  = width,
				height = height,
				lives  = int(rand.int32_range(1, 6)),
			}
		}
	}

	data.bricks_count = rows * cols
}

reset_game_data :: proc(data: ^GameData, scene: Scene) {
	data.lives = 3
	data.score = 0
	data.power_up_chance = 70
	data.power_ups = {
		{timer = 0, duration = 5, is_active = false, kind = .WidePaddle},
		{timer = 0, duration = 0, is_active = false, kind = .ExtraLife},
		{timer = 0, duration = 5, is_active = false, kind = .SlowBall},
	}
	clear(&data.power_squares)
	reset_ball_and_paddle(&data.ball, &data.paddle, scene)
}

reset_ball_and_paddle :: proc(ball: ^Ball, paddle: ^Paddle, scene: Scene) {
	paddle.rec = {
		x      = (scene.x + (scene.width / 2)) - (PADDLE_WIDTH / 2),
		y      = scene.height - 10,
		width  = PADDLE_WIDTH,
		height = PADDLE_HEIGHT,
	}
	paddle.speed = PADDLE_SPEED

	ball.speed = BALL_SPEED
	ball.radius = BALL_RADIUS
	ball.vel = {BALL_SPEED / 2, -BALL_SPEED / 2}
	ball.pos = {f32(scene.x + (scene.width / 2)), f32(scene.height - 11 - BALL_RADIUS)}
}

process_input :: proc(data: ^GameData, state: GameState, scene: Scene, dt: f32) {
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

apply_power_up :: proc(data: ^GameData, scene: Scene, kind: PowerUpKind) {
	switch kind {
	case .WidePaddle:
		data.paddle.x -= PADDLE_WIDTH / 2
        data.paddle.width = PADDLE_WIDTH * 2
		if data.paddle.x + data.paddle.width > scene.x + scene.width {
			data.paddle.x = scene.x + scene.width - data.paddle.width
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

update_simulation :: proc(data: ^GameData, state: GameState, scene: Scene, dt: f32) {
	if state == .Playing {
		// move ball
		data.ball.pos += data.ball.vel * dt

		ball_fell := data.ball.pos.y >= scene.y + scene.height

		// ball collisions
		if data.ball.pos.x - data.ball.radius <= scene.x {
			data.ball.vel.x = -data.ball.vel.x
		}

		if data.ball.pos.y - data.ball.radius <= scene.y {
			data.ball.vel.y = -data.ball.vel.y
		}

		if data.ball.pos.x + data.ball.radius >= scene.x + scene.width {
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
				random := rand.float32_range(0, 100)
				if random <= data.power_up_chance {
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

compute_next_state :: proc(state: GameState, data: ^GameData, scene: Scene) -> GameState {
	// CHANGE GAME STATE =======
	ball_fell := data.ball.pos.y >= scene.y + scene.height

	if state == .StartScreen && rl.IsKeyPressed(.SPACE) {
		return .Playing
	} else if state == .Playing && ball_fell {
		return .GameOver if data.lives == 0 else .Serving
	} else if state == .Playing && rl.IsKeyPressed(.P) {
		return .Paused
	} else if state == .Paused && rl.IsKeyPressed(.P) {
		return .Playing
	} else if state == .Playing && data.bricks_count == 0 {
		return .GameWon
	} else if state == .GameOver && rl.IsKeyPressed(.SPACE) {
		reset_game_data(data, scene)
		init_bricks(data, scene.x + 90, scene.y + 100, 40, 20, 4, 10, 2)
		return .StartScreen
	} else if state == .GameWon && rl.IsKeyPressed(.SPACE) {
		reset_game_data(data, scene)
		init_bricks(data, scene.x + 90, scene.y + 100, 40, 20, 4, 10, 2)
		return .StartScreen
	} else if state == .Serving && rl.IsKeyPressed(.SPACE) {
		reset_ball_and_paddle(&data.ball, &data.paddle, scene)
		return .Playing
	}

	return state
}

draw_frame :: proc(data: GameData, state: GameState, scene: Scene) {
	// DRAW ====================
	rl.SetTextureWrap(data.bg_texture^, .REPEAT)
	rl.DrawTexturePro(
		data.bg_texture^,
		{x = 0, y = 0, width = SCREEN_WIDTH * 32 / 64, height = SCREEN_HEIGHT * 32 / 64},
		{x = 0, y = 0, width = SCREEN_WIDTH, height = SCREEN_HEIGHT},
		{0, 0},
		0,
		rl.WHITE,
	)

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
	rl.SetTextureWrap(scene.texture^, .REPEAT)
	rl.DrawTexturePro(
		scene.texture^,
		{x = 0, y = 0, width = scene.width * 32 / 64, height = scene.height * 32 / 64},
		scene,
		{0, 0},
		0,
		rl.WHITE,
	)

	for sq in data.power_squares {
		rl.DrawRectangleRec(sq, rl.WHITE)
	}

	for i in 0 ..< data.bricks_count {
		brick := data.bricks[i]
		rl.DrawTexturePro(
			data.brick_texture^,
			{0, 0, 32, 32},
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
			i32(scene.height / 2),
			32,
			rl.WHITE,
		)
	case .Paused:
		text: cstring = "Press 'P' to resume"
		text_width := rl.MeasureText(text, 32)
		rl.DrawText(
			text,
			i32(scene.x) + i32(scene.width / 2) - (text_width / 2),
			i32(scene.height / 2),
			32,
			rl.WHITE,
		)
	case .GameOver:
		text: cstring = "Game Over"
		text_width := rl.MeasureText(text, 32)
		rl.DrawText(
			text,
			i32(scene.x) + i32(scene.width / 2) - (text_width / 2),
			i32(scene.height / 2),
			32,
			rl.WHITE,
		)
	case .GameWon:
		text: cstring = "Congratulations!"
		text_width := rl.MeasureText(text, 32)
		rl.DrawText(
			text,
			i32(scene.x) + i32(scene.width / 2) - (text_width / 2),
			i32(scene.height / 2),
			32,
			rl.WHITE,
		)
	case .Playing:
	}
}

brick_color :: proc(lives: int) -> rl.Color {
	switch lives {
	case 1:
		return {136, 192, 112, 255}
	case 2:
		return {220, 214, 70, 255}
	case 3:
		return {238, 152, 73, 255}
	case 4:
		return {230, 95, 60, 255}
	case 5:
		return {200, 50, 50, 255}
	case 6:
		return {160, 50, 120, 255}
	case:
		return {160, 50, 120, 255}
	}
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Breakout")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	bg_texture := rl.LoadTexture("./assets/background.png")
	defer rl.UnloadTexture(bg_texture)
	scene_texture := rl.LoadTexture("./assets/scene_background.png")
	defer rl.UnloadTexture(scene_texture)
	ball_texture := rl.LoadTexture("./assets/ball.png")
	defer rl.UnloadTexture(ball_texture)
	paddle_texture := rl.LoadTexture("./assets/paddle.png")
	defer rl.UnloadTexture(paddle_texture)
	brick_texture := rl.LoadTexture("./assets/brick.png")
	defer rl.UnloadTexture(brick_texture)

	scene_width: f32 = 640.0
	scene_height: f32 = 480 * 1.8
	scene: Scene = {
		x       = (SCREEN_WIDTH / 2) - (scene_width / 2),
		y       = SCREEN_HEIGHT - scene_height,
		width   = scene_width,
		height  = scene_height,
		texture = &scene_texture,
	}

	game_state := GameState.StartScreen
	game_data: GameData
	game_data.ball.texture = &ball_texture
	game_data.paddle.texture = &paddle_texture
	game_data.brick_texture = &brick_texture
	game_data.bg_texture = &bg_texture
	game_data.power_squares = make([dynamic]PowerSquare, 0)
	defer free(&game_data.power_squares)
	reset_game_data(&game_data, scene)

	init_bricks(&game_data, scene.x + 64, scene.y + 100, 64, 30, 4, 8, 2)

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		process_input(&game_data, game_state, scene, dt)
		update_simulation(&game_data, game_state, scene, dt)
		game_state = compute_next_state(game_state, &game_data, scene)

		rl.BeginDrawing()
		draw_frame(game_data, game_state, scene)
		rl.EndDrawing()
	}
}
