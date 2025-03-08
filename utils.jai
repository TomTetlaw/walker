
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

print_memberwise_compare_code :: ($T: Type) #compile_time  {
    builder: String_Builder;

    info := type_info(T);

    if info.type != .STRUCT {
        print("print_memberwise_compare_code: % is not a struct.\n", T);
    }

    struct_info := cast(*Type_Info_Struct) info;
    for struct_info.members {
        print_to_builder(*builder, "if a.%1 != b.%1 return false;\n", it.name);
    }

    print(builder_to_string(*builder));
}

#scope_file

global_string_arena: *Arena;

stub_c_string :: u8.[0];