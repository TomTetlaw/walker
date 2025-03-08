
preallocate_view :: (arena: *Arena, $T: Type, count: int) -> [] T {
    view := push_view(arena, T, count);
    view.count = 0;
    return view;
}

add_to_view :: (view: *[] $T, value: T) -> *T {
    view.count += 1;
    (<<view)[view.count - 1] = value;
    return *(<<view)[view.count - 1];
}


add_to_view :: (view: *[] $T) -> *T {
    view.count += 1;
    return *(<<view)[view.count - 1];
}

zero :: (value: *void, size: int) {
    memset(value, 0, size);
}

zero :: (value: *$T) {
    memset(value, 0, size_of(T));
}

default_initialize :: (value: *$T) {
    ini :: initializer_of(T);
#if ini ini(value);
    else zero(value);
}