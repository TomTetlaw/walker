
Entity_Handle :: struct {
    id: int;
    type: Type;
    entity: *Entity;
}

Entity :: struct {
    using handle: Entity_Handle;

    active: bool;
    marked_for_removal: bool;

    frame_spawned: int;
    spawn_time: float;
    spawned_this_frame: bool;

    default_mesh_name: string;
    default_texture_names: [8] string;

    mesh: *Mesh;
    textures: [] *Texture;

    p, p0: Vec3;
    dp, ddp: Vec3;

    scale := #run v3(1.0);
    rotation: Quaternion;

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

    return entity;
}

spawn_entity :: (entity: *Entity) {
    entity.active = true;
    entity.spawned_this_frame = true;
    entity.spawn_time = game_time;
    entity.frame_spawned = frame_num;
    entity.p0 = entity.p;
}

remove_entity :: (entity: *Entity) {
    entity.marked_for_removal = true;
}

init_entity_system :: () {
    entity_arena = make_arena();
}

update_entities :: () {
    mark := arena_push_mark(context.temp_arena);
    build_entity_list(context.temp_arena, true);
    all_entities := arena_to_view(context.temp_arena, *Entity, mark);

    for all_entities {
        if it.marked_for_removal {
            remove_entity_by_type(it);
        }
    }

    mark = arena_push_mark(context.temp_arena);
    build_entity_list(context.temp_arena);
    view := arena_to_view(context.temp_arena, *Entity, mark);
    entity_list = view;

    for entity_list {
        if frame_num > it.frame_spawned {
            it.spawned_this_frame = false;
        }
    }

    simulate_physics();
}

render_entities :: () {
    for entity_list {
        command: Mesh_Render_Command;
        command.shader = .STATIC_MESH;
        command.mesh = it.mesh;
        command.textures = it.textures;
        command.transform = mat4_translation(it.draw_p) * mat4_scale(it.scale) * mat4_rotation(it.rotation);
        add_mesh_render_command(command);
    }
}

active_entities :: (array: Bucket_Array($T), body: Code, flags: For_Flags) #expand {
    R :: cast(bool) (flags & .REVERSE);
    P :: cast(bool) (flags & .POINTER);
    for *=P <=R`it, `it_index: array.occupied {
        if !it.active continue;
        if it.marked_for_removal continue;
#insert body;
    }
}

entity_arena: *Arena;

#scope_file

total_entity_count: int;
next_entity_id: int;