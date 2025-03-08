
Noise_Gen_Options :: struct($noise_func: (p: Vec2) -> float, $fbm := false, $warp := false, $remap := false) {
    origin: Vec2;
    width: int;
    height: int;
    scale := 1.0;
    octaves: int;
    persistence: float;
    warp_iterations := 1;

    // if enabled, default to remapping 0,1 -> -1,1
    min_value := -1.0;
    max_value := 1.0;
}

noise_gen_values :: (arena: *Arena, opts: $N/Noise_Gen_Options) -> [] float, float, float {
    values := push_view(arena, float, opts.width * opts.height);

    min_value := FLOAT32_MAX;
    max_value := -FLOAT32_MAX;

    for y: 0..opts.height-1 {
        for x: 0..opts.width-1 {
            pos := Vec2.{cast(float) x, cast(float) y};
            p := opts.origin + pos*opts.scale;

            #if N.warp {
                for 0..opts.warp_iterations-1 {
                    p.x += noise_fbm(p, opts.octaves, opts.persistence, N.noise_func);
                    p.y += noise_fbm(p, opts.octaves, opts.persistence, N.noise_func);
                }
            }

            #if N.fbm {
                value := noise_fbm(p, opts.octaves, opts.persistence, N.noise_func);
            } else {
                value := N.noise_func(p);
            }

            min_value = min(min_value, value);
            max_value = max(max_value, value);

            values[x+y*opts.width] = value;
        }
    }

    #if N.remap {
        for * values {
            it.* = remap(it.*, min_value, max_value, opts.min_value, opts.max_value);
        }
    }

    return values, min_value, max_value;
}

noise_fbm :: (p: Vec2, octaves: int, persistence: float, $noise_func: (p: Vec2) -> float) -> float {
    total := 0.0;
    amplitude := 1.0;
    max_value := 0.0;

    for 0..octaves-1 {
        total += amplitude * noise_func(.{
            p.x * pow(2.0, cast(float) it),
            p.y * pow(2.0, cast(float) it)
        });
        max_value += amplitude;
        amplitude *= persistence;
    }

    return total / max_value;
}

noise_value_2d :: (p: Vec2) -> float {

    noise_hash :: (p: Vec2) -> float {
        return cast(float)
            frac(sin(dot_product(frac(p * 0.3183099 + v2(0.1)), .{127.1, 311.7})) * 43758.5453);
    }

    i := floor(p);
    f := frac(p);
    u := f * f * (v2(3.0) - f*2.0);
    return lerp(
        lerp(noise_hash(i + .{0, 0}), noise_hash(i + .{1, 0}), u.x),
        lerp(noise_hash(i + .{0, 1}), noise_hash(i + .{1, 1}), u.x),
        u.y
    );
}
