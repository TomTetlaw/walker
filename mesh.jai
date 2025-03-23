
Mesh :: struct {
    next, prev: *Mesh;

    name: string;
    bounds: Bounding_Box;
    positions: [] Vec3;
    indices: [] u32;
    num_indices: int;

    position_buffer: *SDL_GPUBuffer;
    colour_buffer: *SDL_GPUBuffer;
    tex_coord_buffer: *SDL_GPUBuffer;
    normal_buffer: *SDL_GPUBuffer;
    tangent_buffer: *SDL_GPUBuffer;
    index_buffer: *SDL_GPUBuffer;
}

Mesh_Data :: struct {
    positions: [] Vec3;
    colours: [] Linear_Colour;
    tex_coords: [] Vec2;
    normals: [] Vec3;
    tangents: [] Vec3;
    indices: [] u32;
}

Mesh_Header :: struct {
    name: string;
    num_vertices: int;
    num_indices: int;
}

load_mesh :: (name: string) -> *Mesh {
    for * meshes {
        if equal(it.name, name) return it;
    }

    path := tprint("meshes/%.mesh", name);
    file, ok := file_open(path);
    if ok {
        mesh_name := file_read_string(*file);
        num_vertices, num_indices: int;
        file_read(*file, *num_vertices, size_of(int));
        file_read(*file, *num_indices, size_of(int));

        data: Mesh_Data;

        data.positions = tview(Vec3, num_vertices);
        file_read(*file, data.positions.data, size_of(Vec3) * num_vertices);

        data.colours = tview(Linear_Colour, num_vertices);
        file_read(*file, data.colours.data, size_of(Linear_Colour) * num_vertices);

        data.tex_coords = tview(Vec2, num_vertices);
        file_read(*file, data.tex_coords.data, size_of(Vec2) * num_vertices);

        data.normals = tview(Vec3, num_vertices);
        file_read(*file, data.normals.data, size_of(Vec3) * num_vertices);

        data.tangents = tview(Vec3, num_vertices);
        file_read(*file, data.tangents.data, size_of(Vec3) * num_vertices);

        data.indices = tview(u32, num_indices);
        file_read(*file, data.indices.data, size_of(u32) * num_indices);

        file_close(*file);

        return create_mesh(mesh_arena, name, data);
    }

    return fallback_mesh;
}

create_mesh :: (arena: *Arena, name: string, data: Mesh_Data) -> *Mesh {
    if data.positions.count <= 0 return fallback_mesh;

    mesh: Mesh;
    mesh.name = copy_string_global(name);
    mesh.positions = push_view(arena, data.positions);

    if data.indices.count > 0 {
        mesh.num_indices = data.indices.count;
    } else {
        mesh.num_indices = data.positions.count;
    }

    bounds: Bounding_Box;
    bounds.min = v3(FLOAT32_MAX);
    bounds.max = v3(-FLOAT32_MAX);
    for data.positions {
        bounds.min = min(bounds.min, it);
        bounds.max = max(bounds.max, it);
    }

    mesh.bounds = bounds;

    create_buffers(*mesh, data);

    return bucket_array_add(*meshes, mesh, fallback_mesh);
}

init_mesh_system :: () {
    mesh_arena = make_arena();

    fallback_data: Mesh_Data;
    fallback_data.positions = push_view(context.temp_arena, Vec3.[
        .{0, -0.5, 0}, .{0, -0.5, 0}, .{0, 0, 0.5}
    ]);
    fallback_data.colours = push_view(context.temp_arena, Linear_Colour.[
        colour_black, colour_black, colour_black
    ]);
    fallback_mesh = create_mesh(mesh_arena, "fallback", fallback_data);
    if !fallback_mesh fatal_error("Failed to create fallback mesh");

    cube_mesh = generate_cube_mesh(mesh_arena, "unit_cube");
}

generate_cube_mesh :: (arena: *Arena, name: string) -> *Mesh {
    data: Mesh_Data;
    data.positions = push_view(context.temp_arena, Vec3.[
        .{-0.5, -0.5,  0.5}, .{ 0.5, -0.5,  0.5}, .{ 0.5,  0.5,  0.5},
        .{ 0.5,  0.5,  0.5}, .{-0.5,  0.5,  0.5}, .{-0.5, -0.5,  0.5},

        .{ 0.5, -0.5,  0.5}, .{ 0.5, -0.5, -0.5}, .{ 0.5,  0.5, -0.5},
        .{ 0.5,  0.5, -0.5}, .{ 0.5,  0.5,  0.5}, .{ 0.5, -0.5,  0.5},

        .{ 0.5, -0.5, -0.5}, .{-0.5, -0.5, -0.5}, .{-0.5,  0.5, -0.5},
        .{-0.5,  0.5, -0.5}, .{ 0.5,  0.5, -0.5}, .{ 0.5, -0.5, -0.5},

        .{-0.5, -0.5, -0.5}, .{-0.5, -0.5,  0.5}, .{-0.5,  0.5,  0.5},
        .{-0.5,  0.5,  0.5}, .{-0.5,  0.5, -0.5}, .{-0.5, -0.5, -0.5},

        .{-0.5,  0.5,  0.5}, .{ 0.5,  0.5,  0.5}, .{ 0.5,  0.5, -0.5},
        .{ 0.5,  0.5, -0.5}, .{-0.5,  0.5, -0.5}, .{-0.5,  0.5,  0.5},

        .{-0.5, -0.5, -0.5}, .{ 0.5, -0.5, -0.5}, .{ 0.5, -0.5,  0.5},
        .{ 0.5, -0.5,  0.5}, .{-0.5, -0.5,  0.5}, .{-0.5, -0.5, -0.5}
    ]);

    data.colours = push_view(context.temp_arena, Linear_Colour.[
        colour_white, colour_white, colour_white,
        colour_white, colour_white, colour_white,

        colour_white, colour_white, colour_white,
        colour_white, colour_white, colour_white,

        colour_white, colour_white, colour_white,
        colour_white, colour_white, colour_white,

        colour_white, colour_white, colour_white,
        colour_white, colour_white, colour_white,

        colour_white, colour_white, colour_white,
        colour_white, colour_white, colour_white,

        colour_white, colour_white, colour_white,
        colour_white, colour_white, colour_white
    ]);

    data.tex_coords = push_view(context.temp_arena, Vec2.[
        .{0.0, 0.0}, .{1.0, 0.0}, .{1.0, 1.0},
        .{1.0, 1.0}, .{0.0, 1.0}, .{0.0, 0.0},

        .{0.0, 0.0}, .{1.0, 0.0}, .{1.0, 1.0},
        .{1.0, 1.0}, .{1.0, 0.0}, .{0.0, 0.0},

        .{0.0, 0.0}, .{1.0, 0.0}, .{1.0, 1.0},
        .{1.0, 1.0}, .{0.0, 1.0}, .{0.0, 0.0},

        .{0.0, 0.0}, .{1.0, 0.0}, .{1.0, 1.0},
        .{1.0, 1.0}, .{0.0, 1.0}, .{0.0, 0.0},

        .{0.0, 0.0}, .{1.0, 0.0}, .{1.0, 1.0},
        .{1.0, 1.0}, .{0.0, 1.0}, .{0.0, 0.0},

        .{0.0, 0.0}, .{1.0, 0.0}, .{1.0, 1.0},
        .{1.0, 1.0}, .{0.0, 1.0}, .{0.0, 0.0}
    ]);

    data.normals = push_view(context.temp_arena, Vec3.[
        .{ 0.0,  0.0,  1.0}, .{ 0.0,  0.0,  1.0}, .{ 0.0,  0.0,  1.0},
        .{ 0.0,  0.0,  1.0}, .{ 0.0,  0.0,  1.0}, .{ 0.0,  0.0,  1.0},

        .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0},
        .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0},

        .{ 0.0,  0.0, -1.0}, .{ 0.0,  0.0, -1.0}, .{ 0.0,  0.0, -1.0},
        .{ 0.0,  0.0, -1.0}, .{ 0.0,  0.0, -1.0}, .{ 0.0,  0.0, -1.0},

        .{-1.0,  0.0,  0.0}, .{-1.0,  0.0,  0.0}, .{-1.0,  0.0,  0.0},
        .{-1.0,  0.0,  0.0}, .{-1.0,  0.0,  0.0}, .{-1.0,  0.0,  0.0},

        .{ 0.0,  1.0,  0.0}, .{ 0.0,  1.0,  0.0}, .{ 0.0,  1.0,  0.0},
        .{ 0.0,  1.0,  0.0}, .{ 0.0,  1.0,  0.0}, .{ 0.0,  1.0,  0.0},

        .{ 0.0, -1.0,  0.0}, .{ 0.0, -1.0,  0.0}, .{ 0.0, -1.0,  0.0},
        .{ 0.0, -1.0,  0.0}, .{ 0.0, -1.0,  0.0}, .{ 0.0, -1.0,  0.0}
    ]);

    data.tangents = push_view(context.temp_arena, Vec3.[
        .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0},
        .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0},

        .{ 0.0,  0.0, -1.0}, .{ 0.0,  0.0, -1.0}, .{ 0.0,  0.0, -1.0},
        .{ 0.0,  0.0, -1.0}, .{ 0.0,  0.0, -1.0}, .{ 0.0,  0.0, -1.0},

        .{-1.0,  0.0,  0.0}, .{-1.0,  0.0,  0.0}, .{-1.0,  0.0,  0.0},
        .{-1.0,  0.0,  0.0}, .{-1.0,  0.0,  0.0}, .{-1.0,  0.0,  0.0},

        .{ 0.0,  0.0,  1.0}, .{ 0.0,  0.0,  1.0}, .{ 0.0,  0.0,  1.0},
        .{ 0.0,  0.0,  1.0}, .{ 0.0,  0.0,  1.0}, .{ 0.0,  0.0,  1.0},

        .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0},
        .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0},

        .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0},
        .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0}, .{ 1.0,  0.0,  0.0}
    ]);

    data.indices = push_view(context.temp_arena, u32, 36);
    for 0..35 data.indices[it] = xx it;

    return create_mesh(arena, name, data);
}

generate_sphere_mesh :: (arena: *Arena, name: string, radius: float, segments: int) -> *Mesh {
    vert_count := (segments + 1) * (segments + 1);
    positions := push_view(context.temp_arena, Vec3, vert_count);

    for lat: 0..segments {
        theta := cast(float) lat / segments;
        sin_theta := sin_turns(theta);
        cos_theta := cos_turns(theta);

        for lon: 0..segments {
            phi := cast(float) (lon * 2) / segments;
            sin_phi := sin_turns(phi);
            cos_phi := cos_turns(phi);

            index := lat + lon*(segments + 1);

            positions[index].x = radius * sin_theta * cos_phi;
            positions[index].y = radius * cos_theta;
            positions[index].z = radius * sin_theta * sin_phi;
        }
    }

    tri_count := segments * segments * 2;
    indices := push_view(context.temp_arena, u32, tri_count * 3);

    cursor := 0;
    for lat: 0..segments-1 for lon: 0..segments-1 {
        top_left := lat * (segments + 1) + lon;
        top_right := top_left + 1;
        bottom_left := (lat + 1) * (segments + 1) + lon;
        bottom_right := bottom_left + 1;

        indices[cursor + 0] = cast(u32) top_left;
        indices[cursor + 1] = cast(u32) bottom_left;
        indices[cursor + 2] = cast(u32) top_right;

        indices[cursor + 3] = cast(u32) top_right;
        indices[cursor + 4] = cast(u32) bottom_left;
        indices[cursor + 5] = cast(u32) bottom_right;

        cursor += 6;
    }

    data: Mesh_Data;
    data.positions = positions;
    data.indices = indices;
    return create_mesh(arena, name, data);
}

recreate_mesh :: (mesh: *Mesh, data: Mesh_Data) {
	SDL_ReleaseGPUBuffer(context.device, mesh.position_buffer);
	SDL_ReleaseGPUBuffer(context.device, mesh.colour_buffer);
	SDL_ReleaseGPUBuffer(context.device, mesh.tex_coord_buffer);
	SDL_ReleaseGPUBuffer(context.device, mesh.normal_buffer);
	SDL_ReleaseGPUBuffer(context.device, mesh.tangent_buffer);

	create_buffers(mesh, data);
}

cube_mesh: *Mesh;
mesh_arena: *Arena;

#scope_file

fallback_mesh: *Mesh;

meshes: Bucket_Array(Mesh);

create_buffers :: (mesh: *Mesh, data: Mesh_Data) {
    generate_normals := true;
    generate_tangents := true;

    if data.indices.count > 0 {
        if data.indices.count % 3 != 0 {
            generate_normals = false;
            generate_tangents = false;
        }
    } else {
        if data.positions.count % 3 != 0 {
            generate_normals = false;
            generate_tangents = false;
        }
    }

    mesh.position_buffer = create_vertex_buffer(tprint("%_positions", mesh.name), data.positions);

    colours: [] Linear_Colour;
    tex_coords: [] Vec2;
    normals: [] Vec3;
    tangents: [] Vec3;
    indices: [] u32;

    if data.colours.count > 0 {
        colours = data.colours;
    } else {
        colours = push_view(context.temp_arena, Linear_Colour, data.positions.count);
        for * colours it.* = rgba(1.0);
    }

    if data.tex_coords.count > 0 {
        tex_coords = data.tex_coords;
    } else {
        tex_coords = push_view(context.temp_arena, Vec2, data.positions.count);
    }

    use_indices := data.indices.count > 0;

    if data.normals.count > 0 {
        normals = data.normals;
    } else {
        normals = push_view(context.temp_arena, Vec3, data.positions.count);

        if generate_normals {
            tri_count := 0;
            if use_indices {
                tri_count = data.indices.count / 3;
            } else {
                tri_count = data.positions.count / 3;
            }

            if use_indices {
                for 0..tri_count-1 {
                    i0 := data.indices[it*3 + 0];
                    i1 := data.indices[it*3 + 1];
                    i2 := data.indices[it*3 + 2];

                    p0 := data.positions[i0];
                    p1 := data.positions[i1];
                    p2 := data.positions[i2];

                    e1 := p1 - p0;
                    e2 := p2 - p0;

                    n := cross_product(e1, e2);
                    normals[i0] = n;
                    normals[i1] = n;
                    normals[i2] = n;
                }
            } else {
                for 0..tri_count-1 {
                    i0 := it*3 + 0;
                    i1 := it*3 + 1;
                    i2 := it*3 + 2;

                    p0 := data.positions[i0];
                    p1 := data.positions[i1];
                    p2 := data.positions[i2];

                    e1 := p1 - p0;
                    e2 := p2 - p0;

                    n := cross_product(e1, e2);
                    normals[i0] = n;
                    normals[i1] = n;
                    normals[i2] = n;
                }
            }
        } else {
            for * normals it.* = .{0, 0, 1};
        }

        for * normals it.* = normalize(it.*);
    }

    if data.tangents.count > 0 {
        tangents = data.tangents;
    } else {
        tangents = push_view(context.temp_arena, Vec3, data.positions.count);

        if generate_tangents {
            tri_count := 0;
            if use_indices {
                tri_count = data.indices.count / 3;
            } else {
                tri_count = data.positions.count / 3;
            }

            if use_indices {
                for 0..tri_count-1 {
                    i0 := data.indices[it*3 + 0];
                    i1 := data.indices[it*3 + 1];
                    i2 := data.indices[it*3 + 2];

                    p0 := data.positions[i0];
                    p1 := data.positions[i1];
                    p2 := data.positions[i2];

                    e1 := p1 - p0;
                    e2 := p2 - p0;

                    n0 := normals[i0];
                    n1 := normals[i1];
                    n2 := normals[i2];

                    t0 := cross_product(n0, e1);
                    t1 := cross_product(n1, e1);
                    t2 := cross_product(n2, e1);

                    tangents[i0] = t0;
                    tangents[i1] = t1;
                    tangents[i2] = t2;
                }
            } else {
                for 0..tri_count-1 {
                    i0 := it*3 + 0;
                    i1 := it*3 + 1;
                    i2 := it*3 + 2;

                    p0 := data.positions[i0];
                    p1 := data.positions[i1];
                    p2 := data.positions[i2];

                    e1 := p1 - p0;
                    e2 := p2 - p0;

                    n0 := normals[i0];
                    n1 := normals[i1];
                    n2 := normals[i2];

                    t0 := cross_product(n0, e1);
                    t1 := cross_product(n1, e1);
                    t2 := cross_product(n2, e1);

                    tangents[i0] = t0;
                    tangents[i1] = t1;
                    tangents[i2] = t2;
                }
            }
        } else {
            for * tangents it.* = .{1, 0, 0};
        }

        for * tangents it.* = normalize(it.*);
    }

    if data.indices.count > 0 {
        indices = data.indices;
    } else {
        indices = push_view(context.temp_arena, u32, data.positions.count);
        for * indices it.* = xx it_index;
    }

    mesh.indices = push_view(mesh_arena, indices);

    mesh.colour_buffer = create_vertex_buffer(tprint("%_colours", mesh.name), colours);
    mesh.tex_coord_buffer = create_vertex_buffer(tprint("%_tex_coords", mesh.name), tex_coords);
    mesh.normal_buffer = create_vertex_buffer(tprint("%_normals", mesh.name), normals);
    mesh.tangent_buffer = create_vertex_buffer(tprint("%_tangents", mesh.name), tangents);
    mesh.index_buffer = create_index_buffer(tprint("%_indices", mesh.name), indices);
}
