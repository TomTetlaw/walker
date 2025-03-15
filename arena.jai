
Arena :: struct {
    used: int;
    committed: int;
    reserved: int;
    base: *void;

    next, prev: *Arena;
    freed: bool;
}

#assert(size_of(Arena) < 4096);

default_reserve_size :: 1024 * 1024 * 1024 * 64;
default_commit_size :: 1024 * 4;

make_arena :: ($L := #caller_location) -> *Arena {
    arena := linked_list_pop(*arena_free_list);
    if arena {
        arena.freed = false;
        arena.used = 0;
        zero(arena.base, arena.committed);
        return arena;
    }

    page_size := get_page_size();

    reserve := (default_reserve_size + page_size - 1) & ~(page_size - 1);

    memory := virtual_reserve(reserve);
    if !memory {
        code, error := get_error_value_and_string();
        reserved_tb := total_reserved_bytes / (1024.0 * 1024.0 * 1024.0 * 1024.0);
        committed_gb := total_committed_bytes / (1024.0 * 1024.0 * 1024.0);
        print("Failed to reserve memory (committed=%gb, reserved=%tb): % (%)\n",
              committed_gb, reserved_tb, error, code);
        return *stub_arena;
    }

    virtual_commit(memory, page_size);

    arena = cast (*Arena) memory;
    arena.base = memory + page_size;
    arena.reserved = reserve;
    arena.used = 0;

    commit := (default_commit_size + page_size - 1) & ~(page_size - 1);
    virtual_commit(arena.base, commit);
    arena.committed = commit;

    return arena;
}

reset_arena :: (arena: *Arena) {
    arena.used = 0;
    zero(arena.base, arena.committed);
}

arena_push_mark :: (arena: *Arena) -> int {
    return arena.used;
}

arena_pop_mark :: (arena: *Arena, mark: int) {
    arena.used = mark;
    zero(arena.base + mark, arena.committed - mark);
}

make_scoped_arena :: () -> *Arena #expand {
    arena := make_arena();

    `defer free_arena(arena);

    return arena;
}

free_arena :: (arena: *Arena) {
    if !arena return;

    arena.freed = true;
    linked_list_add(*arena_free_list, arena);
}

arena_alloc :: (arena: *Arena, size: int, $L := #caller_location) -> *void {
    if arena.freed return null;

    page_size := get_page_size();

    if arena.used + size >= arena.committed {
        aligned_size := (size + page_size - 1) & ~(page_size - 1);
        commit := max(default_commit_size, aligned_size);

        if arena.committed + commit >= arena.reserved {
            return null;
        }

        virtual_commit(arena.base + arena.committed, commit);
        arena.committed += commit;
    }

    result := arena.base + arena.used;
    zero(result, size);
    arena.used += size;

    return result;
}

push_value :: (arena: *Arena, value: $T) {
    result := cast(*T) arena_alloc(arena, size_of(T));
    if !result return;

    memcpy(result, *value, size_of(T));
}

push_string :: (arena: *Arena, value: string) -> string {
    result := cast(*u8) arena_alloc(arena, value.count);
    if !result return "";

    memcpy(result, value.data, value.count);

    s: string;
    s.data = result;
    s.count = value.count;
    return s;
}

push_struct :: (arena: *Arena, $T: Type, stub: *T) -> *T {
    result := cast(*T) arena_alloc(arena, size_of(T));

    if !result return stub;

    ini :: initializer_of(T);
    #if ini ini(result);

    return result;
}

push_struct :: (arena: *Arena, value: $T) -> *T {
    stub :: T.{};
    result := push_struct(arena, T, *stub);
    if result != *stub {
        memcpy(result, *value, size_of(T));
    }

    return result;
}

push_structs :: (arena: *Arena, $T: Type, count: int) -> *T {
    result := arena_alloc(arena, size_of(T) * count);
    if !result return null;

    ini :: initializer_of(T);
    #if ini {
        for 0..count-1 {
            ini(result + it);
        }
    }

    return result;
}

push_view :: (arena: *Arena, $T: Type, count: int) -> [] T {
    data := cast(*T) arena_alloc(arena, size_of(T) * count);
    if !data {
        return .[];
    }

    result: [] T;
    result.data = data;
    result.count = count;

    ini :: initializer_of(T);
    #if ini {
        for * result ini(it);
    }

    return result;
}

push_view :: (arena: *Arena, values: [] $T) -> [] T {
    view := push_view(arena, T, values.count);
    memcpy(view.data, values.data, size_of(T) * values.count);
    return view;
}

arena_to_view :: (arena: *Arena, $T: Type, mark := 0) -> [] T {
    result: [] T;
    result.data = arena.base + mark;
    result.count = arena_count(arena, T, mark);
    return result;
}

arena_count :: inline (arena: *Arena, $T: Type, mark := 0) -> int {
    return (arena.used - mark) / size_of(T);
}

#scope_file

total_reserved_bytes: int;
total_committed_bytes: int;

stub_arena :: Arena.{};

arena_free_list: Linked_List(Arena);

#if OS == .WINDOWS {
    virtual_reserve :: (size: int) -> *void {
        memory := VirtualAlloc(null, xx size, MEM_RESERVE, PAGE_READWRITE);
        total_reserved_bytes += size;
        return memory;
    }

    virtual_commit :: (memory: *void, size: int) {
        total_committed_bytes += size;
        VirtualAlloc(memory, xx size, MEM_COMMIT, PAGE_READWRITE);
    }

    virtual_set_guard :: (memory: *void, size: int) {
        VirtualAlloc(memory, xx size, MEM_COMMIT, PAGE_GUARD);
    }

    get_page_size :: () -> int {
        info: SYSTEM_INFO;
        GetSystemInfo(*info);
        return xx info.dwPageSize;
    }
} else #if OS == .LINUX {
    virtual_reserve :: (size: int) -> *void {
        memory := mmap(null, xx size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, 0, 0);
        total_reserved_bytes += size;
        return memory;
    }

    virtual_commit :: (memory: *void, size: int) {
        total_committed_bytes += size;
        // Linux does this automatically when the memory is written
    }

    virtual_set_guard :: (memory: *void, size: int) {
        mprotect(memory, xx size, PROT_NONE);
    }

    get_page_size :: () -> int {
        return xx getpagesize();
    }
}