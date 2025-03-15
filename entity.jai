
Entity_Handle :: struct {
    id: int;
    type: Type;
    entity: *Entity;
}

Entity_Flags :: enum_flags {
    NO_PHYSICS;
    USE_DRAW_POSITION_OVERRIDE;
    POSITION_ABOVE_GROUND;
}

Entity :: struct {
    using handle: Entity_Handle;

    marked_for_removal: bool;

    frame_spawned: int;
    spawn_time: float;
    spawned_this_frame: bool;

    flags: Entity_Flags;

    height_above_ground: float;

    default_mesh_name: string;
    default_texture_names: [8] string;

    mesh: *Mesh;
    textures: [] *Texture;

    p, p0: Vec3;
    dp: Vec3;

    scale := #run v3(1.0);
    rotation: Quaternion;

    phys_p: Vec3;
    draw_p: Vec3;
}

get_entity_bounds :: (entity: *Entity) -> Bounding_Box {
    bounds: Bounding_Box;
    bounds.min = (entity.p - entity.mesh.bounds.min) * entity.scale;
    bounds.max = (entity.p + entity.mesh.bounds.max) * entity.scale;
    return bounds;
}

entity_list: [] *Entity;

make_entity :: ($T: Type) -> *T {
    array := get_entity_array(T);

    stub :: T.{};
    entity := bucket_array_add(array, T.{}, *stub);

    entity.id = next_entity_id;
    entity.type = T;
    entity.entity = entity;

    entity.mesh = load_mesh(entity.default_mesh_name);

    textures := tarray(*Texture);
    for entity.default_texture_names {
        if it.count > 0 {
            array_add(*textures, load_texture(it));
        }
    }

    entity.textures = push_view(entity_arena, *Texture, textures.count);
    for textures {
        entity.textures[it_index] = it;
    }

    next_entity_id += 1;
    total_entity_count += 1;

    entity.spawned_this_frame = true;
    entity.spawn_time = game_time;
    entity.frame_spawned = frame_num;
    entity.p0 = entity.p;

    return entity;
}

remove_entity :: (entity: *Entity) {
    entity.marked_for_removal = true;
}

init_entity_system :: () {
    entity_arena = make_arena();
    entity_shader = load_shader(.{
        .MESH,
        shader_feature_flags_static_mesh,
        "static_mesh",
        "static_mesh"
    });
}

update_entities :: () {
    for_all_entities(remove_marked_entity);

    mark := arena_push_mark(context.temp_arena);
    build_entity_list(context.temp_arena);
    entity_list = arena_to_view(context.temp_arena, *Entity, mark);

    for entity_list {
        if frame_num > it.frame_spawned {
            it.spawned_this_frame = false;
        }
    }

    simulate_physics();

    for entity_list {
        if !(it.flags & .USE_DRAW_POSITION_OVERRIDE) {
            true_position: Vec3;
            if it.flags & .NO_PHYSICS {
                true_position = it.p;
            } else {
                true_position = it.phys_p;
            }

            it.draw_p = true_position;

            if it.flags & .POSITION_ABOVE_GROUND {
                hit, height := get_ground_height(context.terrain, it.draw_p.xy);
                it.draw_p = v3(it.draw_p.xy, height + it.height_above_ground);
            }
        }
    }
}

render_entities :: () {
    for entity_list {
        command: Mesh_Render_Command;
        command.shader = entity_shader;
        command.mesh = it.mesh;
        command.textures = it.textures;
        command.transform = mat4_translation(it.draw_p) * mat4_scale(it.scale) * mat4_rotation(it.rotation);
        add_mesh_render_command(command);
    }
}

entity_arena: *Arena;

#scope_file

remove_marked_entity :: ($T: Type, array: *Bucket_Array(T), entity: *Entity) {
    if entity.marked_for_removal {
        bucket_array_remove(array, cast(*T) entity);
    }
}

entity_shader: *Shader;

total_entity_count: int;
next_entity_id: int;