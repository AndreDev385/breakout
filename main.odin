package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 800

MAX_ANGLE :: math.PI / 3

MAX_BRICKS :: 1000

Brick :: struct {
	using rec: rl.Rectangle,
	lives:     int,
}

GameState :: enum {
	StartScreen,
	Playing,
	Paused,
	GameOver,
	GameWon,
}

Paddle :: struct {
	using rec:   rl.Rectangle,
	speed:       f32,
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
	list: ^[MAX_BRICKS]Brick,
	count: ^int,
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
			list[row * cols + col] = {
				x      = f32(x + (f32(col) * width) + gap * f32(col)),
				y      = f32(y + (f32(row) * height) + gap * f32(row)),
				width  = width,
				height = height,
				lives  = 1,
			}
		}
	}

	count^ = rows * cols
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
	game_data := GameData {
		paddle = {
			rec = {
				x = (scene.x + (scene_width / 2)) - (100 / 2),
				y = scene_height - 40,
				width = 100,
				height = 20,
			},
			speed = 450,
		},
		ball = {
			speed = 400,
			radius = 10.0,
			vel = {400, -400},
			pos = {f32(scene.x + (scene.width / 2)), f32(scene_height - 41 - 10)},
			initial_vel = {400, -400},
			initial_pos = {f32(scene.x + (scene.width / 2)), f32(scene_height - 41 - 10)},
		},
		lives = 3,
		score = 0,
	}

	init_bricks(
		&game_data.bricks,
		&game_data.bricks_count,
		scene.x + 90,
		scene.y + 100,
		40,
		20,
		4,
		10,
		2,
	)

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		ball_fell := game_data.ball.pos.y >= scene.y + scene.height

		// UPDATE ==================
		if rl.IsKeyPressed(.SPACE) && game_state == .StartScreen {
			game_data.ball.pos = game_data.ball.initial_pos
			game_data.ball.vel = game_data.ball.initial_vel
		}

		if game_state == .Playing {
			if rl.IsKeyDown(.D) {
				game_data.paddle.x += (game_data.paddle.speed * dt)
				if game_data.paddle.x + game_data.paddle.width > scene.x + scene.width {
					game_data.paddle.x = (scene.x + scene.width) - game_data.paddle.width
				}
			}

			if rl.IsKeyDown(.A) {
				game_data.paddle.x -= (game_data.paddle.speed * dt)
				if game_data.paddle.x < scene.x {
					game_data.paddle.x = scene.x
				}
			}
		}

		if game_state == .Playing {
			game_data.ball.pos += game_data.ball.vel * dt
		}

		// ball collisions
		if game_data.ball.pos.x - game_data.ball.radius <= scene.x {
			game_data.ball.vel.x = -game_data.ball.vel.x
		}

		if game_data.ball.pos.y - game_data.ball.radius <= scene.y {
			game_data.ball.vel.y = -game_data.ball.vel.y
		}

		if game_data.ball.pos.x + game_data.ball.radius >= scene.x + scene_width {
			game_data.ball.vel.x = -game_data.ball.vel.x
		}

		if game_state == .Playing && ball_fell {
			game_data.lives -= 1
		}

		// ball + paddle collision
		nearest_x := math.clamp(
			game_data.ball.pos.x,
			game_data.paddle.x,
			game_data.paddle.x + game_data.paddle.width,
		)
		nearest_y := math.clamp(
			game_data.ball.pos.y,
			game_data.paddle.y,
			game_data.paddle.y + game_data.paddle.height,
		)

		dx := game_data.ball.pos.x - nearest_x
		dy := game_data.ball.pos.y - nearest_y

		distance := math.sqrt_f32(dx * dx + dy * dy)

		if distance <= game_data.ball.radius {
			game_data.ball.pos.y = nearest_y - game_data.ball.radius
			hit_factor :=
				(game_data.ball.pos.x - (game_data.paddle.x + game_data.paddle.width / 2)) /
				(game_data.paddle.width / 2)
			angle := hit_factor * MAX_ANGLE
			game_data.ball.vel.x = game_data.ball.speed * math.sin_f32(angle)
			game_data.ball.vel.y = -game_data.ball.speed * math.cos_f32(angle)
		}

		for &brick in game_data.bricks[:game_data.bricks_count] {
			nearest_x := math.clamp(game_data.ball.pos.x, brick.x, brick.x + brick.width)
			nearest_y := math.clamp(game_data.ball.pos.y, brick.y, brick.y + brick.height)

			dx := game_data.ball.pos.x - nearest_x
			dy := game_data.ball.pos.y - nearest_y

			distance := math.sqrt_f32(dx * dx + dy * dy)

			if distance <= game_data.ball.radius {
				left := game_data.ball.pos.x + game_data.ball.radius - brick.x
				right := brick.x + brick.width - game_data.ball.pos.x - game_data.ball.radius
				up := game_data.ball.pos.y + game_data.ball.radius - brick.y
				bottom := brick.y + brick.height - game_data.ball.pos.y - game_data.ball.radius

				min_overlap_x := min(left, right)
				min_overlap_y := min(up, bottom)

				if min_overlap_x < min_overlap_y {
					game_data.ball.vel.x = -game_data.ball.vel.x
				} else {
					game_data.ball.vel.y = -game_data.ball.vel.y
				}

				brick.lives -= 1
			}
		}

		// Move dead breaks to the end
		j := 0
		for i in 0 ..< game_data.bricks_count {
			if game_data.bricks[i].lives > 0 {
				game_data.bricks[j] = game_data.bricks[i]
				j += 1
			}
		}
		game_data.bricks_count = j

		// CHANGE GAME STATE =======
		if game_state == .StartScreen && rl.IsKeyPressed(.SPACE) {
			game_state = .Playing
		} else if game_state == .Playing && ball_fell {
			game_state = .GameOver if game_data.lives == 0 else .StartScreen
		} else if game_state == .Playing && rl.IsKeyPressed(.P) {
			game_state = .Paused
		} else if game_state == .Paused && rl.IsKeyPressed(.P) {
			game_state = .Playing
		} else if game_state == .Playing && game_data.bricks_count == 0 {
			game_state = .GameWon
		}

		// DRAW ====================
		rl.BeginDrawing()
		rl.ClearBackground({30, 30, 30, 255})
		defer rl.EndDrawing()

		lives_text := fmt.ctprintf("Lives %d", game_data.lives)
		rl.DrawText(lives_text, i32(scene.x), 50, 20, rl.WHITE)

		bricks_text := fmt.ctprintf("Bricks left %d", game_data.bricks_count)
		text_width := rl.MeasureText(bricks_text, 20)
		rl.DrawText(bricks_text, i32(scene.x + scene.width) - text_width, 50, 20, rl.WHITE)

		// Draw playable scene
		rl.DrawRectangleRec(scene, rl.BLACK)

		rl.DrawRectangleRec(game_data.paddle, rl.WHITE)
		rl.DrawCircleV(game_data.ball.pos, game_data.ball.radius, rl.WHITE)

		switch game_state {
		case .StartScreen:
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
			text: cstring = "Press SPACE to resume"
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

		for i in 0 ..< game_data.bricks_count {
			rl.DrawRectangleRec(game_data.bricks[i], rl.WHITE)
		}
	}
}
