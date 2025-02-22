
noise_fbm_gen_values :: (arena: *Arena, seed: int, origin: Vec2, scale: float,
    w: int, h: int, octaves: int, persistence: float) -> [] float, float, float {
    random_seed(cast(u64) seed);

    for 0..255 {
        rand := random_get();
        perlin_lookup[it] = rand % 256;
        perlin_lookup[it + 256] = rand % 256;
    }

    values := push_view(arena, float, w*h);

    min_value := FLOAT32_MAX;
    max_value := -FLOAT32_MAX;

    for y: 0..h-1 for x: 0..w-1 {
        pos := origin + Vec2.{cast(float) x, cast(float) y} * scale;
        value := noise_fbm_perlin(pos.x, pos.y, octaves, persistence);
        min_value = min(min_value, value);
        max_value = max(max_value, value);
        values[x+y*w] = value;
    }

    return values, min_value, max_value;
}

noise_perlin_2d :: (p: Vec2) -> float {
    xi := (cast(u64) p.x) & 255;
    yi := (cast(u64) p.y) & 255;

    xf := frac(p.x);
    yf := frac(p.y);

    u := xf*xf*(3.0 - 2.0*xf);
    v := yf*yf*(3.0 - 2.0*yf);

    aa := perlin_lookup[perlin_lookup[xi]+yi];
    ab := perlin_lookup[perlin_lookup[xi]+yi+1];
    ba := perlin_lookup[perlin_lookup[xi+1]+yi];
    bb := perlin_lookup[perlin_lookup[xi+1]+yi+1];

    return lerp(lerp(grad(aa, xf, yf), grad(ba, xf - 1.0, yf), u),
        lerp(grad(ab, xf, yf - 1.0), grad(bb, xf - 1.0, yf - 1.), u), v);
}

noise_fbm_perlin :: (x: float, y: float, octaves: int, persistence: float) -> float {
    total := 0.0;
    amplitude := 1.0;
    max_value := 0.0;

    for 0..octaves-1 {
        total += amplitude * noise_perlin_2d(.{
            x * pow(2.0, cast(float) it),
            y * pow(2.0, cast(float) it)
        });
        max_value += amplitude;
        amplitude *= persistence;
    }

    return total / max_value;
}

#scope_file

perlin_lookup: [512] u64;

grad :: (hash: u64, x: float, y: float) -> float {
    h := hash & 15;
    u := ifx h < 8 then x else y;
    v := ifx h < 4 then y else ifx h == 12 || h == 14 then x else 0;
    return (ifx h & 1 == 0 then u else -u) + (ifx h & 2 == 0 then v else -v);
}
