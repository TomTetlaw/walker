
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