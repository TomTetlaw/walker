
Terrain :: struct {
    meshes: [] Terrain_Mesh;
    transform := mat4_identity;
    size: Vec2;
}

Terrain_Options :: struct {
    subdivisions: int;
    size: Vec2;

    height_scale: float;

    noise_seed: int;
    noise_origin: Vec2;
    noise_persistence: float;
    noise_octaves: int;
    noise_scale: float;
    noise_power: float;
}

create_terrain :: (opts: Terrain_Options) -> Terrain {
    mesh := create_terrain_mesh(opts);

    terrain: Terrain;
    terrain.size = opts.size;

    terrain.meshes = push_view(terrain_arena, Terrain_Mesh, 1);

    terrain_mesh: Terrain_Mesh;
    terrain_mesh.mesh = mesh;

    terrain.meshes[0] = terrain_mesh;

    return terrain;
}

Terrain_Layer :: struct {
    textures: [8] *Texture;
    tex_coord_scale: Vec2;
}

render_terrain :: (batcher: *Render_Batcher, terrain: Terrain, layers: [] Terrain_Layer) {
    for terrain.meshes {
        command: Render_Command;
        command.shader = .TERRAIN;
        // command.flags = .NO_CAST_SHADOW;
        command.mesh = it.mesh;
        command.textures = push_view(context.temp_arena, *Texture.[
            load_texture("grass_diffuse"),
            load_texture("grass_normal")
        ]);
        command.transform = terrain.transform * it.transform;
        command.instance.material_params = v4(terrain.size, 0, 0);
        add_render_command(batcher, command);
    }
}

init_terrain_system :: () {
    terrain_arena = make_arena();
}

#scope_file

terrain_arena: *Arena;

Terrain_Mesh :: struct {
    mesh: *Mesh;
    transform := mat4_identity;
}

create_terrain_mesh :: (opts: Terrain_Options) -> *Mesh {
    n := (1 << opts.subdivisions) + 1;
    vertex_count := n*n;

    positions := push_view(context.temp_arena, Vec3, vertex_count);
    tex_coords := push_view(context.temp_arena, Vec2, vertex_count);

    inc := opts.size / v2(cast(float) n);
    start := -opts.size * .5;
    for y: 0..n-1 for x: 0..n-1 {
        positions[x+y*n] = v3(start + .{cast(float) x, cast(float) y}*inc, 0.0);
        tex_coords[x+y*n] = (positions[x+y*n].xy - start) / opts.size;
    }

    index_mark := arena_push_mark(context.temp_arena);
    for y: 0..n-2 for x: 0..n-2 {
            top_left := x + y * n;
            top_right := (x + 1) + y * n;
            bottom_left := x + (y + 1) * n;
            bottom_right := (x + 1) + (y + 1) * n;

            push_value(context.temp_arena, cast(u32) top_left);
            push_value(context.temp_arena, cast(u32) top_right);
            push_value(context.temp_arena, cast(u32) bottom_left);

            push_value(context.temp_arena, cast(u32) top_right);
            push_value(context.temp_arena, cast(u32) bottom_right);
            push_value(context.temp_arena, cast(u32) bottom_left);
    }

    indices := arena_to_view(context.temp_arena, u32, index_mark);

    apply_terrain_noise(opts, n, positions);

    data: Mesh_Data;
    data.positions = positions;
    data.tex_coords = tex_coords;
    data.indices = indices;

    return create_mesh(terrain_arena, tprint("plane_%x%", n, n), data);
}

apply_terrain_noise :: (opts: Terrain_Options, n: int, positions: [] Vec3) {
    noise_values, min_value, max_value := noise_fbm_gen_values(
        context.temp_arena, opts.noise_seed, opts.noise_origin,
        opts.noise_scale, n, n, opts.noise_octaves, opts.noise_persistence
    );

    for y: 0..n-1 for x: 0..n-1 {
        value := remap(noise_values[x+y*n], min_value, max_value, 0.0, 1.0);
        value = pow(value, opts.noise_power);

        positions[x+y*n].z = value * opts.height_scale;
    }
}