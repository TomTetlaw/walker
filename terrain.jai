
Terrain :: struct {
    meshes: [] Terrain_Mesh;
    transform := mat4_identity;
    size: Vec2;

    triangles: [] Triangle;
    bvh: BVH;
}

Terrain_Options :: struct {
    subdivisions: int;
    size: Vec2;
}

create_terrain :: (opts: Terrain_Options) -> Terrain {
    profile_scope("create_terrain");

    terrain: Terrain;
    terrain.size = opts.size;

    mesh := create_terrain_mesh(opts);

    tri_count := mesh.indices.count / 3;
    triangles := push_view(terrain_arena, Triangle, tri_count);
    for 0..tri_count-1 {
        tri: Triangle;
        tri.p0 = mesh.positions[mesh.indices[it*3 + 0]];
        tri.p1 = mesh.positions[mesh.indices[it*3 + 1]];
        tri.p2 = mesh.positions[mesh.indices[it*3 + 2]];
        triangles[it] = tri;
    }

    terrain.triangles = triangles;
    terrain.bvh = build_bvh(terrain_arena, triangles);

    terrain.meshes = push_view(terrain_arena, Terrain_Mesh.[.{mesh, mat4_identity}]);

    return terrain;
}

Terrain_Layer :: struct {
    textures: [8] *Texture;
    tex_coord_scale: Vec2;
}

render_terrain :: (terrain: Terrain, layers: [] Terrain_Layer, camera: *Camera_Base) {
    for terrain.meshes {
        command: Mesh_Render_Command;
        command.shader = .TERRAIN;
        command.flags = .NO_CAST_SHADOW;
        command.mesh = it.mesh;

        command.textures = push_view(context.temp_arena, *Texture.[
            load_texture("grass_diffuse"),
            load_texture("grass_normal")
        ]);
        command.transform = terrain.transform * it.transform;
        command.instance.material_params = v4(terrain.size, 0, 0);
        add_mesh_render_command(command);
    }

    draw_bvh(*terrain.bvh, camera);
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

    print("terrain has % verts\n", vertex_count);

    positions := push_view(context.temp_arena, Vec3, vertex_count);
    tex_coords := push_view(context.temp_arena, Vec2, vertex_count);
    inc := opts.size / v2(cast(float) n);
    start := -opts.size * .5;
    inv_size := v2(1.0) / opts.size;
    for y: 0..n-1 for x: 0..n-1 {
        positions[x+y*n] = v3(start + .{cast(float) x, cast(float) y}*inc, 0.0);
        tex_coords[x+y*n] = (positions[x+y*n].xy - start) * inv_size;
    }

    indices := push_view(context.temp_arena, u32, (n-1) * (n-1) * 6);
    cursor := 0;
    for y: 0..n-2 for x: 0..n-2 {
            top_left := x + y * n;
            top_right := (x + 1) + y * n;
            bottom_left := x + (y + 1) * n;
            bottom_right := (x + 1) + (y + 1) * n;

            indices[cursor + 0] = cast(u32) top_left;
            indices[cursor + 1] = cast(u32) top_right;
            indices[cursor + 2] = cast(u32) bottom_left;
            indices[cursor + 3] = cast(u32) top_right;
            indices[cursor + 4] = cast(u32) bottom_right;
            indices[cursor + 5] = cast(u32) bottom_left;
            cursor += 6;
    }

    apply_terrain_noise(opts, n, positions);

    data: Mesh_Data;
    data.positions = positions;
    data.tex_coords = tex_coords;
    data.indices = indices;

    return create_mesh(terrain_arena, tprint("plane_%x%", n, n), data);
}

apply_terrain_noise :: (opts: Terrain_Options, n: int, positions: [] Vec3) {
    perlin := noise_gen_values(
        context.temp_arena,
        Noise_Gen_Options(noise_value_2d, fbm=true, warp=true, remap=true).{
            origin = .{0, 0},
            scale = .005,
            width = n,
            height = n,
            octaves = 10,
            persistence = .5,
            warp_iterations = 3
        }
    );

    height_scale :: 200.0;

    for y: 0..n-1 for x: 0..n-1 {
        positions[x+y*n].z = pow(6.0, perlin[x+y*n]) * height_scale;
    }
}