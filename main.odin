package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 800

MAX_ANGLE :: math.PI / 3

MAX_BRICKS :: 1000

PADDLE_WIDTH :: 100
PADDLE_HEIGHT :: 20
PADDLE_SPEED :: 450

BALL_SPEED :: 400
BALL_RADIUS :: 10.0

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
}

Ball :: struct {
	radius:      f32,
	speed:       f32,
	vel:         rl.Vector2,
	pos:         rl.Vector2,
	initial_vel: rl.Vector2,
	initial_pos: rl.Vector2,
}

GameData :: struct {
	score:        int,
	lives:        int,
	ball:         Ball,
	paddle:       Paddle,
	bricks:       [MAX_BRICKS]Brick,
	bricks_count: int,
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
				lives  = 1,
			}
		}
	}

	data.bricks_count = rows * cols
}

reset_game_data :: proc(data: ^GameData, scene: rl.Rectangle) {
	data.lives = 3
	data.score = 0
    reset_ball_and_paddle(&data.ball, &data.paddle, scene)
}

reset_ball_and_paddle :: proc(ball: ^Ball, paddle: ^Paddle, scene: rl.Rectangle) {
	paddle^ = {
		rec = {
			x = (scene.x + (scene.width / 2)) - (PADDLE_WIDTH / 2),
			y = scene.height - 40,
			width = PADDLE_WIDTH,
			height = PADDLE_HEIGHT,
		},
		speed = PADDLE_SPEED,
	}
	ball^ = {
		speed       = BALL_SPEED,
		radius      = BALL_RADIUS,
		vel         = {BALL_SPEED, -BALL_SPEED},
		pos         = {f32(scene.x + (scene.width / 2)), f32(scene.height - 41 - BALL_RADIUS)},
		initial_vel = {BALL_SPEED, -BALL_SPEED},
		initial_pos = {f32(scene.x + (scene.width / 2)), f32(scene.height - 41 - BALL_RADIUS)},
	}
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

update_simulation :: proc(data: ^GameData, state: GameState, scene: rl.Rectangle, dt: f32) {
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
			}
		}

		// Move dead breaks to the end
		j := 0
		for i in 0 ..< data.bricks_count {
			if data.bricks[i].lives > 0 {
				data.bricks[j] = data.bricks[i]
				j += 1
			}
		}
		data.bricks_count = j

	}
}

compute_next_state :: proc(state: GameState, data: ^GameData, scene: rl.Rectangle) -> GameState {
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

draw_frame :: proc(data: GameData, state: GameState, scene: rl.Rectangle) {
	// DRAW ====================
	rl.ClearBackground({30, 30, 30, 255})

	lives_text := fmt.ctprintf("Lives %d", data.lives)
	rl.DrawText(lives_text, i32(scene.x), 50, 20, rl.WHITE)

	bricks_text := fmt.ctprintf("Bricks left %d", data.bricks_count)
	text_width := rl.MeasureText(bricks_text, 20)
	rl.DrawText(bricks_text, i32(scene.x + scene.width) - text_width, 50, 20, rl.WHITE)

	// Draw playable scene
	rl.DrawRectangleRec(scene, rl.BLACK)

	rl.DrawRectangleRec(data.paddle, rl.WHITE)
	rl.DrawCircleV(data.ball.pos, data.ball.radius, rl.WHITE)

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

	for i in 0 ..< data.bricks_count {
		rl.DrawRectangleRec(data.bricks[i], rl.WHITE)
	}
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Breakout")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	scene_width: f32 = 600.0
	scene_height: f32 = 700.0
	scene := rl.Rectangle {
		x      = (SCREEN_WIDTH / 2) - (scene_width / 2),
		y      = SCREEN_HEIGHT - scene_height,
		width  = scene_width,
		height = scene_height,
	}

	game_state := GameState.StartScreen
	game_data: GameData
	reset_game_data(&game_data, scene)

	init_bricks(&game_data, scene.x + 90, scene.y + 100, 40, 20, 4, 10, 2)

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
