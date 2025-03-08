tile_type_count :: 6;

Tile :: struct {
    collapsed: bool;
    options: [] int;
    type: int;
}

Map :: struct {
    width, height := 80;
    tiles: [] Tile;
    adjacency_map: [] int;
}

tile_types :: u8.[
        #char "T", // Trees
        #char "G", // Grass
        #char "S", // Sand
        #char "M", // Mountain
        #char "W", // Water
        #char "L", // Lake
    ];

weights :: float.[
        1,1,1,1,1,1
    ];

gen_test :: () -> *Texture {
    random_seed(cast(u64) current_time_monotonic().low);

    _adjacency_map := [] int.[
        int.[1, 1, 0, 1, 1, 1], // Trees
        int.[1, 1, 1, 0, 1, 1], // Grass
        int.[0, 1, 1, 0, 1, 1], // Sand
        int.[1, 1, 0, 0, 1, 1], // Mountain
        int.[0, 0, 1, 0, 1, 0], // Water
        int.[1, 1, 0, 1, 0, 1], // Lake
    ];

    adjacency_map := tview(int, tile_type_count*tile_type_count);

    for i:0..tile_type_count-1 for j:0..tile_type_count-1 {
        value := _adjacency_map[i][j];
        adjacency_map[i+j*tile_type_count] = value;
        if value {
            adjacency_map[j+i*tile_type_count] = 1;
        }
    }

    for i:0..tile_type_count-1 {
        for j:0..tile_type_count-1 {
            value := adjacency_map[i+j*tile_type_count];
            print("% ", value);
        }
        print("\n");
    }

    map: Map;
    map.tiles = NewArray(map.width*map.height, Tile);
    map.adjacency_map = adjacency_map;

    initialize_map :: (map: *Map) {
        for * map.tiles {
            it.options = NewArray(tile_type_count, int);
            for * it.options {
                it.* = 1;
            }
            it.collapsed = false;
            it.type = 0;
        }
    }

    get_lowest_entropy :: (map: *Map) -> bool, int, int {
        min_options := 99999;
        lowest_x, lowest_y := 0;
        found := false;

        for y: 0..map.height-1 for x: 0..map.width-1 {
            tile := *map.tiles[x+y*map.width];
            if !tile.collapsed {
                option_count := 0;
                for * tile.options {
                    if it.* option_count += 1;
                }
                if option_count < min_options {
                    min_options = option_count;
                    lowest_x = x;
                    lowest_y = y;
                    found = true;
                }
            }
        }

        return found, lowest_x, lowest_y;
    }

    propagate :: (map: *Map, first_x: int, first_y: int) {
        stack := tarray([2] int);
        array_add(*stack, .[first_x, first_y]);

        while stack.count > 0 {
            pos := stack[stack.count-1];
            stack.count -= 1;

            x := pos[0];
            y := pos[1];

            dirs := [] int.[
                .[0, 1], .[1, 0], .[0, -1], .[-1, 0], .[-1, -1], .[1, 1]
            ];

            for dir: dirs {
                new_x := x + dir[0];
                new_y := y + dir[1];

                if new_x < 0 || new_x >= map.width continue;
                if new_y < 0 || new_y >= map.height continue;

                tile := *map.tiles[x + y*map.width];
                adj_tile := *map.tiles[new_x + new_y*map.width];
                if adj_tile.collapsed continue;

                changed := false;
                new_options: [tile_type_count] int;

                for i: 0..tile_type_count-1 {
                    if tile.options[i] {
                        for j: 0..tile_type_count-1 {
                            if adj_tile.options[j] && map.adjacency_map[i+j*tile_type_count] {
                                new_options[j] = 1;
                            }
                        }
                    }
                }

                for i: 0..tile_type_count-1 {
                    if adj_tile.options[i] && !new_options[i] {
                        adj_tile.options[i] = 0;
                        changed = true;
                    }
                }

                if changed {
                    array_add(*stack, .[new_x, new_y]);
                }
            }
        }
    }

    collapse_tile :: (map: *Map, x: int, y: int) -> bool {
        tile := *map.tiles[x + y*map.width];
        available := NewArray(tile_type_count, int);
        available.count = 0;

        for i: 0..tile_type_count-1 {
            if tile.options[i] {
                available.count += 1;
                available[available.count-1] = i; // Store index instead of 1
            }
        }

        if available.count == 0 return false; // Contradiction detected

        choice := -1;
        while find_loop := true {
            for 0..tile_type_count-1 {
                index := random_get() % xx available.count;
                candidate := available[index];
                if random_get_zero_to_one() < weights[candidate] {
                    choice = candidate;
                    break find_loop;
                }
            }
        }

        for i: 0..tile_type_count-1 {
            tile.options[i] = ifx i == xx choice then 1 else 0;
        }

        tile.collapsed = true;
        tile.type = xx choice;

        propagate(map, x, y);
        return true;
    }

    // Main generation with backtracking
    max_attempts := 100;
    attempt := 0;
    success := false;

    while attempt < max_attempts && !success {
        initialize_map(*map);
        success = true;

        while true {
            found, x, y := get_lowest_entropy(*map);
            if !found break;

            // Backup tile state
            tile := *map.tiles[x + y*map.width];
            backup_options := NewArray(tile_type_count, int);
            for i: 0..tile_type_count-1 {
                backup_options[i] = tile.options[i];
            }
            backup_collapsed := tile.collapsed;
            backup_type := tile.type;

            if !collapse_tile(*map, x, y) {
                success = false;
                break; // Contradiction, try again
            }

            // Check for contradictions in remaining tiles
            contradiction := false;
            for ty: 0..map.height-1 for tx: 0..map.width-1 {
                t := *map.tiles[tx + ty*map.width];
                if !t.collapsed {
                    option_count := 0;
                    for * t.options if it.* option_count += 1;
                    if option_count == 0 {
                        contradiction = true;
                        break;
                    }
                }
            }

            if contradiction {
                // Restore backup and mark failure
                tile := *map.tiles[x + y*map.width];
                for i: 0..tile_type_count-1 {
                    tile.options[i] = backup_options[i];
                }
                tile.collapsed = backup_collapsed;
                tile.type = backup_type;
                success = false;
                break;
            }
        }

        attempt += 1;
    }

    if success {
        width := map.width;
        height := map.height;
        pixels := tview(u8, map.width*map.height*4);

        print("Generated map (attempts: %):\n", attempt);
        for y: 0..map.height-1 {
            for x: 0..map.width-1 {
                tile := *map.tiles[x + y*map.width];

                if tile_types[tile.type] == {
                    case #char "T"; set_pixel(pixels, x, y, width, 18, 61, 6);
                    case #char "G"; set_pixel(pixels, x, y, width, 57, 191, 19);
                    case #char "S"; set_pixel(pixels, x, y, width, 191, 174, 19);
                    case #char "M"; set_pixel(pixels, x, y, width, 168, 168, 168);
                    case #char "W"; set_pixel(pixels, x, y, width, 0, 4, 120);
                    case #char "L"; set_pixel(pixels, x, y, width, 0, 98, 255);
                }
            }
        }

        return create_texture("gen_test", .{pixels, width, height, .RGBA8_UNORM});
    } else {
        print("Failed to generate map after % attempts\n", max_attempts);
    }

    return fallback_texture;
}