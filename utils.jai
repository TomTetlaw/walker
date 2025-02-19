
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

#scope_file

stub_c_string :: u8.[0];