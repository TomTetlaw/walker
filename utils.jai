
file_read_string :: (file: *File) -> string {
    length := 0;
    file_read(file, *length, size_of(int));
    data := talloc(length);
    file_read(file, data, length);
    return push_string(.{length, data});
}

eat_until_whitespace :: (s: string) -> string, string {
    cursor := s;

    while cursor {
        if cursor[0] <= 10 break;
        advance(*cursor, 1);
    }

    return .{s.count - cursor.count, s.data}, cursor;
}

enum_find_name :: ($T: Type, name: string) -> T, bool #modify {
    type := cast(*Type_Info) T;
    return type.type == .ENUM;
} {
    names := enum_names(T);
    values := enum_values_as_enum(T);
    for names if equal_nocase(it, name) return values[it_index], true;
    return values[0], false;
}

get_sdl_error :: () -> string {
    return to_string(SDL_GetError());
}

tcs :: (s: string) -> *u8 {
    data := cast(*u8) talloc(s.count + 1);
    copy(data, s.data, s.count);
    data[s.count] = 0;
    return data;
}

copy :: (dest: *void, source: *void, size: int) {
    memcpy(dest, source, size);
}

zero :: (data: *void, size: int) {
    memset(data, 0, size);
}

zero :: (data: *$T) {
    memset(data, 0, size_of(T));
}

push_string :: (s: string) -> string {
    data := arena_alloc(*string_arena, s.count);
    if !data return "";

    copy(data, s.data, s.count);
    return .{s.count, data};
}

#scope_file

string_arena: Arena;