
tcs :: (s: string) -> *u8 {
    result := cast (*u8) arena_alloc(context.temp_arena, s.count + 1);
    if result == null return stub_c_string.data;

    memcpy(result, s.data, s.count);
    result[s.count] = 0;
    return result;
}

get_sdl_error :: () -> string {
    return to_string(SDL_GetError());
}

copy_string_global :: (s: string) -> string {
    if !global_string_arena {
        global_string_arena = make_arena();
    }

    return push_string(global_string_arena, s);
}

#scope_file

global_string_arena: *Arena;

stub_c_string :: u8.[0];