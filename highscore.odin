package main

import "core:fmt"
import "core:os"
import "core:strings"

HIGH_SCORE_COUNT :: 5

hs_pathbuf_reserve :: #force_inline proc(buf: ^[1024]u8, parts: ..string) -> string {
	off := 0
	for part in parts {
		for i in 0 ..< len(part) {
			buf[off] = part[i]
			off += 1
		}
	}
	buf[off] = 0
	return string(buf[:off])
}

load_high_scores :: proc(scores: ^[HIGH_SCORE_COUNT]int) {
	xdg_buf: [256]u8
	home_buf: [256]u8
	xdg := os.get_env_buf(xdg_buf[:], "XDG_DATA_HOME")
	home := os.get_env_buf(home_buf[:], "HOME")

	buf: [1024]u8
	dir: string
	if xdg != "" {
		dir = hs_pathbuf_reserve(&buf, xdg, "/breakout")
	} else if home != "" {
		dir = hs_pathbuf_reserve(&buf, home, "/.local/share/breakout")
	} else {
		for i in 0 ..< HIGH_SCORE_COUNT { scores[i] = 0 }
		return
	}
	os.make_directory(dir, os.Permissions_All)

	path := hs_pathbuf_reserve(&buf, dir, "/highscores.txt")

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
	xdg_buf: [256]u8
	home_buf: [256]u8
	xdg := os.get_env_buf(xdg_buf[:], "XDG_DATA_HOME")
	home := os.get_env_buf(home_buf[:], "HOME")

	buf: [1024]u8
	dir: string
	if xdg != "" {
		dir = hs_pathbuf_reserve(&buf, xdg, "/breakout")
	} else if home != "" {
		dir = hs_pathbuf_reserve(&buf, home, "/.local/share/breakout")
	} else { return }
	os.make_directory(dir, os.Permissions_All)

	path := hs_pathbuf_reserve(&buf, dir, "/highscores.txt")

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
