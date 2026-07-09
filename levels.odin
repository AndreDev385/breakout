package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

MAX_BRICKS :: 1000

LEVELS := []string{"./assets/level_01.json", "./assets/level_02.json", "./assets/level_03.json"}

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
