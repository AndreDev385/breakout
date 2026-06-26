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
	Ready,
	Playing,
	GameOver,
	GameWon,
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

	game_state := GameState.Ready

	paddle_y: f32 = scene_height - 40
	paddle_width: f32 = 100
	paddle_height: f32 = 20
	paddle_speed: f32 = 450
	paddle := rl.Rectangle {
		x      = (scene.x + (scene_width / 2)) - (paddle_width / 2),
		y      = paddle_y,
		width  = paddle_width,
		height = paddle_height,
	}

	ball_radius: f32 = 10.0
	ball_speed: f32 = 400

	ball_initial_pos := rl.Vector2 {
		f32(scene.x + (scene.width / 2)),
		f32(paddle_y - ball_radius) - 1,
	}
	ball_initial_vel := rl.Vector2{ball_speed, -ball_speed}

	ball_pos := ball_initial_pos
	ball_velocity := ball_initial_vel

	bricks: [MAX_BRICKS]Brick
	bricks_count := 0
	bricks_width: f32 = 40
	bricks_height: f32 = 20
	init_bricks(
		&bricks,
		&bricks_count,
		scene.x + 90,
		scene.y + 100,
		bricks_width,
		bricks_height,
		4,
		10,
		2,
	)

	lives := 3

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		// INPUT ===================
		if rl.IsKeyPressed(.SPACE) && game_state == .Ready {
			ball_pos = ball_initial_pos
			ball_velocity = ball_initial_vel
			game_state = .Playing
		}

		if game_state == .Playing {
			if rl.IsKeyDown(.D) {
				paddle.x += (paddle_speed * dt)
				if paddle.x + paddle.width > scene.x + scene.width {
					paddle.x = (scene.x + scene.width) - paddle.width
				}
			}

			if rl.IsKeyDown(.A) {
				paddle.x -= (paddle_speed * dt)
				if paddle.x < scene.x {
					paddle.x = scene.x
				}
			}
		}

		// UPDATE ==================
		if game_state == .Playing {
			ball_pos += ball_velocity * dt
		}

		// ball collisions
		if ball_pos.x - ball_radius <= scene.x {
			ball_velocity.x = -ball_velocity.x
		}

		if ball_pos.y - ball_radius <= scene.y {
			ball_velocity.y = -ball_velocity.y
		}

		if ball_pos.x + ball_radius >= scene.x + scene_width {
			ball_velocity.x = -ball_velocity.x
		}

		if game_state == .Playing && ball_pos.y >= scene.y + scene.height {
			lives -= 1
			game_state = .Ready
		}

		// ball + paddle collision
		nearest_x := math.clamp(ball_pos.x, paddle.x, paddle.x + paddle_width)
		nearest_y := math.clamp(ball_pos.y, paddle.y, paddle.y + paddle_height)

		dx := ball_pos.x - nearest_x
		dy := ball_pos.y - nearest_y

		distance := math.sqrt_f32(dx * dx + dy * dy)

		if distance <= ball_radius {
			ball_pos.y = nearest_y - ball_radius
			hit_factor := (ball_pos.x - (paddle.x + paddle_width / 2)) / (paddle_width / 2)
			angle := hit_factor * MAX_ANGLE
			ball_velocity.x = ball_speed * math.sin_f32(angle)
			ball_velocity.y = -ball_speed * math.cos_f32(angle)
		}

		for &brick in bricks[:bricks_count] {
			nearest_x := math.clamp(ball_pos.x, brick.x, brick.x + bricks_width)
			nearest_y := math.clamp(ball_pos.y, brick.y, brick.y + bricks_height)

			dx := ball_pos.x - nearest_x
			dy := ball_pos.y - nearest_y

			distance := math.sqrt_f32(dx * dx + dy * dy)

			if distance <= ball_radius {
				left := ball_pos.x + ball_radius - brick.x
				right := brick.x + bricks_width - ball_pos.x - ball_radius
				up := ball_pos.y + ball_radius - brick.y
				bottom := brick.y + bricks_height - ball_pos.y - ball_radius

				min_overlap_x := min(left, right)
				min_overlap_y := min(up, bottom)

				if min_overlap_x < min_overlap_y {
					ball_velocity.x = -ball_velocity.x
				} else {
					ball_velocity.y = -ball_velocity.y
				}

				brick.lives -= 1
			}
		}

		// Move dead breaks to the end
		j := 0
		for i in 0 ..< bricks_count {
			if bricks[i].lives > 0 {
				bricks[j] = bricks[i]
				j += 1
			}
		}
		bricks_count = j

		if bricks_count == 0 {
			game_state = .GameWon
		}

		// DRAW ====================
		rl.BeginDrawing()
		rl.ClearBackground({30, 30, 30, 255})
		defer rl.EndDrawing()

		lives_text := fmt.ctprintf("Lives %d", lives)
		rl.DrawText(lives_text, i32(scene.x), 50, 20, rl.WHITE)

		bricks_text := fmt.ctprintf("Bricks left %d", bricks_count)
		text_width := rl.MeasureText(bricks_text, 20)
		rl.DrawText(bricks_text, i32(scene.x + scene.width) - text_width, 50, 20, rl.WHITE)

		// Draw playable scene
		rl.DrawRectangleRec(scene, rl.BLACK)

		rl.DrawRectangleRec(paddle, rl.WHITE)
		rl.DrawCircleV(ball_pos, ball_radius, rl.WHITE)

		switch game_state {
		case .Ready:
			text: cstring = "Press SPACE to start"
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

		for i in 0 ..< bricks_count {
			rl.DrawRectangleRec(bricks[i], rl.WHITE)
		}
	}
}
