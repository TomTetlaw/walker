
Arena :: struct {
    base: *void;

    reserved: int;
    committed: int;
    used: int;
}

arena_alloc :: (arena: *Arena, size: int, align := 0, $L := #caller_location) -> *void {
    if !ensure_arena_initialized(arena) return null;

    page_size := get_page_size();
    aligned_size := (size + page_size - 1) & ~(page_size - 1);
    if arena.used + aligned_size >= arena.committed {
        virtual_commit(arena.base + arena.committed, aligned_size);
        arena.committed += aligned_size;
    }

    memory := arena.base + arena.used;
    arena.used += size;

    zero(memory, size);

    return memory;
}

push_struct :: (arena: *Arena, value: $T, $L := #caller_location) -> *T {
    result := push_struct(arena, T, L);
    copy(result, *value, size_of(T));
    return result;
}

push_struct :: (arena: *Arena, $T: Type, $L := #caller_location) -> *T {
    value := cast(*T) arena_alloc(arena, size_of(T), 0, L);
    if !value {
        stub :: T.{};
        return *stub;
    }

    ini :: initializer_of(T);
    #if ini ini(value);

    return value;
}

push_view :: (arena: *Arena, $T: Type, count: int, $L := #caller_location) -> [] T {
    data := cast(*T) arena_alloc(arena, size_of(T) * count, 0, L);
    if !data {
        return .[];
    }

    result := [] T.{count, data};

    ini :: initializer_of(T);
    #if ini for * result ini(it);

    return result;
}

push_view :: (arena: *Arena, values: [] $T, $L := #caller_location) -> [] T {
    result := push_view(arena, T, values.count, L);
    memcpy(result.data, values.data, size_of(T) * values.count);
    return result;
}

arena_push_mark :: (arena: Arena) -> int {
    return arena.used;
}

arena_pop_mark :: (arena: *Arena, mark: int) {
    arena.used = mark;
    zero(arena.base + arena.used, mark - arena.used);
}

reset_arena :: (arena: *Arena) {
    zero(arena.base, arena.committed);
    arena.used = 0;
}

make_arena_allocator :: (arena: *Arena) -> Allocator {
    return .{arena_allocator_proc, arena};
}

tview :: ($T: Type, count: int, $L := #caller_location) -> [] T {
    data := talloc(size_of(T) * count);
    result := [] T.{count, data};

    ini :: initializer_of(T);
    #if ini for * result ini(it);

    return result;
}

tview :: (values: [] $T, $L := #caller_location) -> [] T {
    result := tview(T, values.count, L);
    memcpy(result.data, values.data, size_of(T) * values.count);
    return result;
}

tarray :: ($T: Type, reserve := 0) -> [..] T {
    result: [..] T;
    result.allocator = temp;
    array_reserve(*result, reserve);
    return result;
}

#scope_file

arena_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64,
                         old_memory: *void, allocator_data: *void) -> *void {
    arena := cast(*Arena) allocator_data;

    if mode == {
        case .RESIZE;
        result := arena_alloc(arena, requested_size);
        memcpy(result, old_memory, old_size);
        return result;

        case .ALLOCATE;
        return arena_alloc(arena, requested_size);
    }

    return null;
}

ensure_arena_initialized :: (arena: *Arena) -> bool {
    if arena.base return true;

    arena_default_reserve :: 1024 * 1024 * 1024 * 16;
    arena_default_commit :: 1024 * 4;

    arena.base = virtual_reserve(arena_default_reserve);
    if !arena.base return false;

    virtual_commit(arena.base, arena_default_commit);

    arena.reserved = arena_default_reserve;
    arena.committed = arena_default_commit;
    arena.used = 0;

    return true;
}

total_reserved_bytes: int;
total_committed_bytes: int;

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

    get_page_size :: () -> int {
        return xx getpagesize();
    }
}