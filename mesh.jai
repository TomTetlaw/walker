
Mesh :: struct {
    next, prev: *Mesh;

    name: string;
    bounds: Bounding_Box;
    positions: [] Vec3;
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

load_mesh :: (name: string) -> *Mesh {
    for * meshes {
        if equal(it.name, name) return it;
    }

    return fallback_mesh;
}

create_mesh :: (name: string, data: Mesh_Data) -> *Mesh {
    if data.positions.count <= 0 return fallback_mesh;

    mesh: Mesh;
    mesh.name = push_string(mesh_arena, name);
    mesh.positions = push_view(mesh_arena, data.positions);

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
    fallback_data.positions = push_view(mesh_arena, Vec3.[
        .{0, -0.5, 0}, .{0, -0.5, 0}, .{0, 0, 0.5}
    ]);
    fallback_data.colours = push_view(mesh_arena, Linear_Colour.[
        colour_black, colour_black, colour_black
    ]);
    fallback_mesh = create_mesh("fallback", fallback_data);
    if !fallback_mesh fatal_error("Failed to create fallback mesh");

    cube_data: Mesh_Data;
    cube_data.positions = push_view(mesh_arena, Vec3.[
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

    cube_data.colours = push_view(mesh_arena, Linear_Colour.[
        colour_red, colour_red, colour_red,
        colour_red, colour_red, colour_red,

        colour_yellow, colour_yellow, colour_yellow,
        colour_yellow, colour_yellow, colour_yellow,

        colour_green, colour_green, colour_green,
        colour_green, colour_green, colour_green,

        colour_pink, colour_pink, colour_pink,
        colour_pink, colour_pink, colour_pink,

        colour_blue, colour_blue, colour_blue,
        colour_blue, colour_blue, colour_blue,

        colour_cyan, colour_cyan, colour_cyan,
        colour_cyan, colour_cyan, colour_cyan,
    ]);

    cube_data.tex_coords = push_view(mesh_arena, Vec2.[
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

    cube_data.normals = push_view(mesh_arena, Vec3.[
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

    cube_data.tangents = push_view(mesh_arena, Vec3.[
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

    cube_data.indices = push_view(mesh_arena, u32, 36);
    for 0..35 cube_data.indices[it] = xx it;

    cube_mesh = create_mesh("cube", cube_data);
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

#scope_file

mesh_arena: *Arena;

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

            for 0..tri_count-1 {
                i0 := it*3 + 0;
                i1 := it*3 + 1;
                i2 := it*3 + 2;

                if use_indices {
                    i0 = data.indices[i0];
                    i1 = data.indices[i1];
                    i2 = data.indices[i2];
                }

                p0 := data.positions[i0];
                p1 := data.positions[i1];
                p2 := data.positions[i2];

                e1 := p1 - p0;
                e2 := p2 - p0;

                n := normalize(cross_product(e1, e2));
                normals[i0] = n;
                normals[i1] = n;
                normals[i2] = n;
            }
        } else {
            for * normals it.* = .{0, 0, 1};
        }
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

            for 0..tri_count-1 {
                i0 := it*3 + 0;
                i1 := it*3 + 1;
                i2 := it*3 + 2;

                if use_indices {
                    i0 = data.indices[i0];
                    i1 = data.indices[i1];
                    i2 = data.indices[i2];
                }

                p0 := data.positions[i0];
                p1 := data.positions[i1];
                p2 := data.positions[i2];

                e1 := p1 - p0;
                e2 := p2 - p0;

                n0 := normals[i0];
                n1 := normals[i1];
                n2 := normals[i2];

                t0 := normalize(cross_product(n0, e1));
                t1 := normalize(cross_product(n1, e1));
                t2 := normalize(cross_product(n2, e1));

                tangents[i0] = t0;
                tangents[i1] = t1;
                tangents[i2] = t2;
            }
        } else {
            for * tangents it.* = .{1, 0, 0};
        }
    }

    if data.indices.count > 0 {
        indices = data.indices;
    } else {
        indices = push_view(context.temp_arena, u32, data.positions.count);
        for * indices it.* = xx it_index;
    }

    mesh.colour_buffer = create_vertex_buffer(tprint("%_colours", mesh.name), colours);
    mesh.tex_coord_buffer = create_vertex_buffer(tprint("%_tex_coords", mesh.name), tex_coords);
    mesh.normal_buffer = create_vertex_buffer(tprint("%_normals", mesh.name), normals);
    mesh.tangent_buffer = create_vertex_buffer(tprint("%_tangents", mesh.name), tangents);
    mesh.index_buffer = create_index_buffer(tprint("%_indices", mesh.name), indices);
}
