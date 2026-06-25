package main

import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH :: 720
SCREEN_HEIGHT :: 640

PADDLE_HEIGHT :: 540

MAX_ANGLE :: math.PI / 3

MAX_BRICKS :: 1000

Brick :: struct {
	using rec: rl.Rectangle,
	lives:     int,
}

BRICK_WIDTH: f32 : 40
BRICK_HEIGHT: f32 : 20

init_bricks :: proc(list: ^[MAX_BRICKS]Brick, count: ^int) {
	gap: f32 = 4

	rows := 6
	cols := 14

	for row in 0 ..< rows {
		for col in 0 ..< cols {
			list[row * cols + col] = {
				x      = f32(40 + (f32(col) * BRICK_WIDTH) + gap * f32(col)),
				y      = f32(128 + (f32(row) * BRICK_HEIGHT) + gap * f32(row)),
				width  = BRICK_WIDTH,
				height = BRICK_HEIGHT,
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

	paddle_width: f32 = 100
	paddle_height: f32 = 20
	paddle_speed: f32 = 450
	paddle := rl.Rectangle {
		x      = f32(SCREEN_WIDTH / 2 - paddle_width / 2),
		y      = PADDLE_HEIGHT,
		width  = paddle_width,
		height = paddle_height,
	}

	ball_radius: f32 = 10.0
	ball_speed: f32 = 400
	ball_pos := rl.Vector2{f32(SCREEN_WIDTH / 2), f32(PADDLE_HEIGHT - ball_radius)}
	ball_velocity := rl.Vector2{ball_speed, -ball_speed}

	bricks: [MAX_BRICKS]Brick
	count := 0

	init_bricks(&bricks, &count)

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		// INPUT ===================
		if rl.IsKeyDown(.D) && (paddle.x + f32(paddle_width)) <= f32(SCREEN_WIDTH) {
			paddle.x += (paddle_speed * dt)
		}

		if rl.IsKeyDown(.A) && paddle.x >= 0 {
			paddle.x -= (paddle_speed * dt)
		}

		// UPDATE ==================
		ball_pos += ball_velocity * dt

		// ball collisions
		if ball_pos.x - ball_radius <= 0 {
			ball_velocity.x = -ball_velocity.x
		}

		if ball_pos.y - ball_radius <= 0 {
			ball_velocity.y = -ball_velocity.y
		}

		if ball_pos.x + ball_radius >= SCREEN_WIDTH {
			ball_velocity.x = -ball_velocity.x
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

		for &brick in bricks[:count] {
			nearest_x := math.clamp(ball_pos.x, brick.x, brick.x + BRICK_WIDTH)
			nearest_y := math.clamp(ball_pos.y, brick.y, brick.y + BRICK_HEIGHT)

			dx := ball_pos.x - nearest_x
			dy := ball_pos.y - nearest_y

			distance := math.sqrt_f32(dx * dx + dy * dy)

			if distance <= ball_radius {
				left := ball_pos.x + ball_radius - brick.x
				right := brick.x + BRICK_WIDTH - ball_pos.x - ball_radius
				up := ball_pos.y + ball_radius - brick.y
				bottom := brick.y + BRICK_HEIGHT - ball_pos.y - ball_radius

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
		for i in 0 ..< count {
			if bricks[i].lives > 0 {
				bricks[j] = bricks[i]
				j += 1
			}
		}
		count = j

		// DRAW ====================
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		defer rl.EndDrawing()

		rl.DrawRectangleRec(paddle, rl.WHITE)
		rl.DrawCircleV(ball_pos, ball_radius, rl.WHITE)

		for i in 0 ..< count {
			rl.DrawRectangleRec(bricks[i], rl.WHITE)
		}
	}
}
