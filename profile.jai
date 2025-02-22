
profile_scope :: (name: string) #expand {
    start := current_time_monotonic();

    `defer {
        end := current_time_monotonic();
        duration_ticks := end - start;
        duration_seconds := to_float64_seconds(duration_ticks);
        print("% took % seconds.\n", name, duration_seconds);
    }
}