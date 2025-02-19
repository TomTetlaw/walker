
Terrain :: struct {
    meshes: [] Terrain_Mesh;
    transform := mat4_identity;
}

create_terrain :: (size: Vec2, subdivisions: int) -> Terrain {
    mesh := create_terrain_mesh(size, subdivisions);

    terrain: Terrain;
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
        command.mesh = it.mesh;
        command.textures = push_view(context.temp_arena, *Texture.[
            load_texture("grass_diffuse"),
            load_texture("grass_normal")
        ]);
        command.transform = terrain.transform * it.transform;
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

create_terrain_mesh :: (size: Vec2, subdivisions: int) -> *Mesh {
    n := (1 << subdivisions) + 1;
    vertex_count := n*n;

    positions := push_view(context.temp_arena, Vec3, vertex_count);
    tex_coords := push_view(context.temp_arena, Vec2, vertex_count);

    inc := size / v2(cast(float) n);
    start := -size * .5;
    for y: 0..n-1 for x: 0..n-1 {
        positions[x+y*n] = v3(start + .{cast(float) x, cast(float) y}*inc, 0.0);
        tex_coords[x+y*n] = (positions[x+y*n].xy - start) / size;
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

    apply_terrain_noise(n, positions);

    data: Mesh_Data;
    data.positions = positions;
    data.tex_coords = tex_coords;
    data.indices = indices;

    return create_mesh(tprint("plane_%x%", n, n, size), data);
}

apply_terrain_noise :: (n: int, positions: [] Vec3) {
    height_scale :: 25.0;

    encoded_tree :: "DQAEAAAAAACAQBAAAACAPwcAAAAAgD8A4XoUPwDNzIw/";

    min_max: [2] float;
    noise_values := push_view(context.temp_arena, float, n*n);

    noise := fnNewFromEncodedNodeTree(encoded_tree, 0);
    fnGenTileable2D(noise, noise_values.data, xx n, xx n, 0.02, 1984, min_max.data);

    for y: 0..n-1 for x: 0..n-1 {
        value := remap(noise_values[x+y*n], min_max[0], min_max[1], -1.0, 1.0);
        positions[x+y*n].z += value * height_scale;
    }

    fnDeleteNodeRef(noise);
}