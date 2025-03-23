
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
    view_model: *Mesh;

    textures: [] *Texture;

    position: Vec3;
    velocity: Vec3;

    forward: Vec3;

    scale := #run v3(1.0);
    rotation: Quaternion;

    visual_position: Vec3;

    view_model_position: Vec3;
    view_model_distance: float;
    view_model_offset: Vec3;
}

get_entity_bounds :: (entity: *Entity) -> Bounding_Box {
    bounds: Bounding_Box;
    bounds.min = (entity.position - entity.mesh.bounds.min) * entity.scale;
    bounds.max = (entity.position + entity.mesh.bounds.max) * entity.scale;
    return bounds;
}

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

    return entity;
}

remove_entity :: (entity: *Entity) {
    entity.marked_for_removal = true;
}

init_entity_system :: () {
    entity_arena = make_arena();
    entity_shader = load_shader(.{
        get_pipeline_domain_options(.MESH),
        shader_feature_flags_static_mesh,
        "static_mesh",
        "static_mesh"
    });

    view_model_shader = load_shader(.{
        get_pipeline_domain_options(.MESH),
        shader_feature_flags_static_mesh,
        "static_mesh",
        "static_mesh",
    });
}

update_entities :: () {
    for_all_entities(remove_marked_entity);

    entity_list = tarray(*Entity);
    for_all_entities(add_to_entity_list);

    for entity_list {
        if frame_num > it.frame_spawned {
            it.spawned_this_frame = false;
        }

        if !(it.flags & .NO_PHYSICS) {
            it.position += it.velocity * game_delta;
        }

        if !(it.flags & .USE_DRAW_POSITION_OVERRIDE) {
            it.visual_position = it.position;

            if it.flags & .POSITION_ABOVE_GROUND {
                hit, height := get_ground_height(context.terrain, it.visual_position.xy);
                it.visual_position = v3(it.visual_position.xy, height + it.height_above_ground);
            }

            it.forward = quat_to_forward(it.rotation);

            it.view_model_position =
                it.visual_position +
                it.view_model_offset +
                it.forward * it.view_model_distance;
        }
    }
}


render_entities :: () {
    for entity_list {
        command: Mesh_Render_Command;
        command.shader = entity_shader;
        command.mesh = it.mesh;
        command.textures = it.textures;
        command.transform = mat4_translation(it.visual_position) * mat4_scale(it.scale) * mat4_rotation(it.rotation);
        add_mesh_render_command(command);

        command.shader = view_model_shader;
        command.mesh = it.view_model;
        command.textures = .[];
        command.transform = mat4_translation(it.view_model_position);
        add_mesh_render_command(command);
    }
}

entity_arena: *Arena;

entity_list: [..] *Entity;

#scope_file

add_to_entity_list :: ($T: Type, array: *Bucket_Array(T), entity: *Entity) {
    array_add(*entity_list, entity);
}

remove_marked_entity :: ($T: Type, array: *Bucket_Array(T), entity: *Entity) {
    if entity.marked_for_removal {
        bucket_array_remove(array, cast(*T) entity);
    }
}

entity_shader: *Shader;
view_model_shader: *Shader;

total_entity_count: int;
next_entity_id: int;