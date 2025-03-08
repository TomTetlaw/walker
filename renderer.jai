
debug_draw_bounds :: (box: Bounding_Box, colour := colour_white) {
    command: Mesh_Render_Command;
    command.shader = .DEBUG;
    command.flags = .NO_CAST_SHADOW;
    command.mesh = cube_mesh;
    command.instance.colour = colour;

    mid := (box.min + box.max) * .5;
    span := (box.max - box.min);
    command.instance.transform = mat4_translation(mid) * mat4_scale(span);

    add_mesh_render_command(command);
}

Instance_Data :: struct {
    transform := mat4_identity;
    colour := #run rgba(1.0);
    material_params := Vec4.{1, 1, 0, 0};
}

Mesh_Shader :: enum {
    DEBUG;
    STATIC_MESH;
    TERRAIN;
    SKY;
}

Command_Flags :: enum_flags {
    NO_CAST_SHADOW;
}

Mesh_Render_Command :: struct {
    shader: Mesh_Shader;
    flags: Command_Flags;
    mesh: *Mesh;
    textures: [] *Texture;
    using instance: Instance_Data;
}

add_mesh_render_command :: (command: Mesh_Render_Command) {
    if mesh_batcher.total_instance_count >= MAX_INSTANCES {
        return;
    }

    pipeline: *Pipeline;
    if #complete command.shader == {
        case .DEBUG;
        pipeline = debug_pipeline;
        case .STATIC_MESH;
        pipeline = mesh_pipeline;
        case .TERRAIN;
        pipeline = terrain_pipeline;
        case .SKY;
        pipeline = sky_pipeline;
    }

    hash := get_hash(pipeline.name);
    hash = get_hash(command.shader, hash);
    hash = get_hash(command.flags, hash);
    hash = get_hash(command.mesh.name, hash);
    for command.textures {
        hash = get_hash(it.name, hash);
    }

    index := mesh_batcher.hash_map[hash % MAX_BATCHES];
    if index == -1 {
        if mesh_batcher.batches.count + 1 >= MAX_BATCHES {
            return;
        }

        batch: Mesh_Batch;
        batch.instances = make_arena_array(context.temp_arena, Instance_Data);

        batch.pipeline = pipeline;
        batch.flags = command.flags;

        if pipeline == debug_pipeline {
            batch.vertex_buffers = push_view(context.temp_arena, SDL_GPUBufferBinding, 1);
            batch.vertex_buffers[0] = .{command.mesh.position_buffer, 0};
        } else {
            batch.vertex_buffers = push_view(context.temp_arena, SDL_GPUBufferBinding, 5);
            batch.vertex_buffers[0] = .{command.mesh.position_buffer, 0};
            batch.vertex_buffers[1] = .{command.mesh.colour_buffer, 0};
            batch.vertex_buffers[2] = .{command.mesh.tex_coord_buffer, 0};
            batch.vertex_buffers[3] = .{command.mesh.normal_buffer, 0};
            batch.vertex_buffers[4] = .{command.mesh.tangent_buffer, 0};
        }

        batch.index_buffer = .{command.mesh.index_buffer, 0};

        batch.textures = push_view(context.temp_arena, SDL_GPUTextureSamplerBinding, mesh_pipeline.needed_textures);
        fallback_texture := load_texture("missing");
        for * batch.textures {
            it.* = .{fallback_texture.texture_object, default_sampler};
        }
        for command.textures {
            batch.textures[it_index] = .{it.texture_object, default_sampler};
        }

        batch.num_indices = command.mesh.num_indices;

        index = mesh_batcher.batches.count;
        array_add(*mesh_batcher.batches, batch);
        mesh_batcher.hash_map[hash % MAX_BATCHES] = index;
    }

    batch := *mesh_batcher.batches[index];

    if batch.instances.count + 1 >= MAX_INSTANCES {
        return;
    }

    mesh_batcher.total_instance_count += 1;

    array_add(*batch.instances, command.instance);
}

Mesh_Vertex_Constants :: struct {
    view := mat4_identity;
    projection := mat4_identity;
}

Mesh_Fragment_Constants :: struct {
    camera_position: Vec4;
    camera_direction: Vec4;

    light_params: Vec4;
    directional_light_dir: Vec4;
    directional_light_colour: Linear_Colour;

    time: Vec4;

    cascades: [shadow_cascade_count] float;
    light_matrices: [shadow_cascade_count] Mat4;
}

Shadow_Vertex_Constants :: struct {
    light_matrices: [shadow_cascade_count] Mat4;
}

Directional_Light :: struct {
    // x = ambient lighting
    // y = diffuse intensity
    // z = specular intensity
    // w = specular shininess
    params := Vec4.{0.3, 1.0, 1.0, 2.0};

    direction := Vec3.{0, 0, -1};
    colour := colour_white;
}

Render_Scene :: struct {
    sun: Directional_Light;
    camera: Camera_Base;

    mesh_batcher: Mesh_Batcher;

    cascades: [shadow_cascade_count] float;
    light_matrices: [shadow_cascade_count] Mat4;
}

render_debug_pass :: (scene: Render_Scene, batches: [] Mesh_Batch, swap_texture: *SDL_GPUTexture, command_buffer: *SDL_GPUCommandBuffer, opts := Opaque_Render_Target_Options.{}) {
    colour_target := SDL_GPUColorTargetInfo.{
        texture = swap_texture,
        clear_color = .{0.2, 0.5, 0.8, 1},
        load_op = .SDL_GPU_LOADOP_LOAD,
        store_op = .SDL_GPU_STOREOP_STORE,
    };

    render_pass := SDL_BeginGPURenderPass(command_buffer, *colour_target, 1, null);
    if !render_pass {
        report_sdl_error("SDL_BeginGPURenderPass", "render_debug_pass");
    }

    vert_constants: Mesh_Vertex_Constants;
    vert_constants.view = scene.camera.view;
    vert_constants.projection = scene.camera.projection;

    SDL_PushGPUVertexUniformData(command_buffer, 0, *vert_constants, size_of(Mesh_Vertex_Constants));

    base_instance := 0;
    for batch: batches {
        defer base_instance += batch.instances.count;
        if batch.pipeline != debug_pipeline continue;

        SDL_BindGPUGraphicsPipeline(render_pass, batch.pipeline.pipeline_object);

        SDL_BindGPUVertexStorageBuffers(render_pass, 0, *instance_buffer, 1);
        SDL_BindGPUVertexBuffers(render_pass, 0, batch.vertex_buffers.data, xx batch.vertex_buffers.count);
        SDL_BindGPUIndexBuffer(render_pass, *batch.index_buffer, .SDL_GPU_INDEXELEMENTSIZE_32BIT);

        SDL_DrawGPUIndexedPrimitives(render_pass, xx batch.num_indices, xx batch.instances.count, 0, 0, xx base_instance);
    }

    SDL_EndGPURenderPass(render_pass);
}

render_shadow_pass :: (scene: *Render_Scene, batches: [] Mesh_Batch, command_buffer: *SDL_GPUCommandBuffer) {
    far_planes: [shadow_cascade_count] float;

    near_plane := scene.camera.near_plane;
    far_plane := scene.camera.far_plane;
    range := scene.camera.far_plane - scene.camera.near_plane;

    for 0..shadow_cascade_count-1 {
        far := (it + 1.0) / shadow_cascade_count;
        log_distance := near_plane * pow(far_plane / near_plane, far);
        uniform_distance := near_plane + (far_plane - near_plane) * far;
        far_planes[it] = lerp(uniform_distance, log_distance, 0.5);
    }

    scene.cascades = far_planes;

    for 0..shadow_cascade_count-1 {
        n := near_plane;
        if it > 0 n = far_planes[it - 1];

        f := far_planes[it];

        scene.light_matrices[it] = calculate_light_space_matrix(scene.sun, *scene.camera, n, f);
    }

    for 0..shadow_cascade_count-1 {
        colour_target := SDL_GPUColorTargetInfo.{
            texture = shadow_texture_array,
            clear_color = .{1, 1, 1, 1},
            load_op = .SDL_GPU_LOADOP_CLEAR,
            store_op = .SDL_GPU_STOREOP_STORE,
            layer_or_depth_plane = xx it,
        };

        render_pass := SDL_BeginGPURenderPass(command_buffer, *colour_target, 1, null);
        if !render_pass {
            report_sdl_error("SDL_BeginGPURenderPass", "render_shadow_pass");
        }

        base_instance := 0;
        for batch: batches {
            if batch.flags & .NO_CAST_SHADOW continue;

            SDL_PushGPUVertexUniformData(command_buffer, 0, *scene.light_matrices[it], size_of(Mat4));

            SDL_BindGPUGraphicsPipeline(render_pass, shadow_pipeline.pipeline_object);

            viewport := SDL_GPUViewport.{0, 0, SHADOW_MAP_SIZE, SHADOW_MAP_SIZE, 0, 1};
            SDL_SetGPUViewport(render_pass, *viewport);

            SDL_BindGPUVertexStorageBuffers(render_pass, 0, *instance_buffer, 1);

            SDL_BindGPUVertexBuffers(render_pass, 0, batch.vertex_buffers.data, xx batch.vertex_buffers.count);
            SDL_BindGPUIndexBuffer(render_pass, *batch.index_buffer, .SDL_GPU_INDEXELEMENTSIZE_32BIT);
            SDL_DrawGPUIndexedPrimitives(render_pass, xx batch.num_indices, xx batch.instances.count, 0, 0, xx base_instance);
            base_instance += batch.instances.count;
        }

        SDL_EndGPURenderPass(render_pass);
    }
}

Opaque_Render_Target_Options :: struct {
    clear_colour := true;
    clear_depth := true;
}

render_opaque_pass :: (scene: Render_Scene, batches: [] Mesh_Batch, swap_texture: *SDL_GPUTexture, command_buffer: *SDL_GPUCommandBuffer, opts := Opaque_Render_Target_Options.{}) {
    colour_target := SDL_GPUColorTargetInfo.{
        texture = swap_texture,
        clear_color = .{0.2, 0.5, 0.8, 1},
        load_op = ifx opts.clear_colour then .SDL_GPU_LOADOP_CLEAR else .SDL_GPU_LOADOP_LOAD,
        store_op = .SDL_GPU_STOREOP_STORE,
    };

    depth_target := SDL_GPUDepthStencilTargetInfo.{
        texture = mesh_depth_texture,
        clear_depth = 1,
        load_op = ifx opts.clear_depth then .SDL_GPU_LOADOP_CLEAR else .SDL_GPU_LOADOP_LOAD,
        store_op = .SDL_GPU_STOREOP_STORE,
    };

    render_pass := SDL_BeginGPURenderPass(command_buffer, *colour_target, 1, *depth_target);
    if !render_pass {
        report_sdl_error("SDL_BeginGPURenderPass", "render_opaque_pass");
    }

    shadow_binding := SDL_GPUTextureSamplerBinding.{shadow_texture_array, shadow_sampler};

    vert_constants: Mesh_Vertex_Constants;
    vert_constants.view = scene.camera.view;
    vert_constants.projection = scene.camera.projection;

    frag_constants: Mesh_Fragment_Constants;
    frag_constants.camera_position = v4(scene.camera.position, 0.0);
    frag_constants.camera_direction = v4(scene.camera.view[3].xyz, 0.0);
    frag_constants.light_params = scene.sun.params;
    frag_constants.directional_light_dir = v4(normalize(scene.sun.direction), 0);
    frag_constants.directional_light_colour = scene.sun.colour;
    frag_constants.time = .{real_time, sin(real_time), game_time, sin(game_time)};
    frag_constants.cascades = scene.cascades;
    frag_constants.light_matrices = scene.light_matrices;

    SDL_PushGPUVertexUniformData(command_buffer, 0, *vert_constants, size_of(Mesh_Vertex_Constants));
    SDL_PushGPUFragmentUniformData(command_buffer, 0, *frag_constants, size_of(Mesh_Fragment_Constants));

    base_instance := 0;
    for batch: batches {
        defer base_instance += batch.instances.count;
        if batch.pipeline == debug_pipeline continue;

        SDL_BindGPUGraphicsPipeline(render_pass, batch.pipeline.pipeline_object);

        SDL_BindGPUVertexStorageBuffers(render_pass, 0, *instance_buffer, 1);
        SDL_BindGPUVertexBuffers(render_pass, 0, batch.vertex_buffers.data, xx batch.vertex_buffers.count);
        SDL_BindGPUIndexBuffer(render_pass, *batch.index_buffer, .SDL_GPU_INDEXELEMENTSIZE_32BIT);

        textures := tarray(SDL_GPUTextureSamplerBinding, batch.textures.count + 1);
        array_add(*textures, shadow_binding);
        for batch.textures {
            array_add(*textures, it);
        }

        SDL_BindGPUFragmentSamplers(render_pass, 0, textures.data, xx textures.count);
        SDL_DrawGPUIndexedPrimitives(render_pass, xx batch.num_indices, xx batch.instances.count, 0, 0, xx base_instance);
    }

    SDL_EndGPURenderPass(render_pass);
}

renderer_begin_frame :: () {
    init_mesh_batcher(*mesh_batcher);
}

report_sdl_error :: (function: string, tag := "") {
    err := SDL_GetError();
    if err[0] {
        print("sdl error in function %() tag [%]: %\n", function, tag, to_string(err));
        SDL_ClearError();
    }
}

render_scene :: (scene: Render_Scene) {
    command_buffer := SDL_AcquireGPUCommandBuffer(context.device);
    if !command_buffer {
        report_sdl_error("SDL_AcquireGPUCommandBuffer");
    }

    swap_texture: *SDL_GPUTexture;
    if !SDL_AcquireGPUSwapchainTexture(command_buffer, context.window, *swap_texture, null, null) {
        report_sdl_error("SDL_AcquireGPUSwapchainTexture");
    }

    if swap_texture {
        if mesh_batcher.batches.count > 0 {
            mapping := cast(*Instance_Data) SDL_MapGPUTransferBuffer(context.device, instance_transfer_buffer, false);
            if !mapping {
                report_sdl_error("SDL_MapGPUTransferBuffer", "instance_transfer_buffer");
            }

            cursor := 0;
            for batch: mesh_batcher.batches {
                memcpy(mapping + cursor, batch.instances.data, size_of(Instance_Data) * batch.instances.count);
                cursor += batch.instances.count;
            }

            SDL_UnmapGPUTransferBuffer(context.device, instance_transfer_buffer);

            location: SDL_GPUTransferBufferLocation;
            location.transfer_buffer = instance_transfer_buffer;
            location.offset = 0;

            region: SDL_GPUBufferRegion;
            region.buffer = instance_buffer;
            region.size = xx (cursor * size_of(Instance_Data));
            region.offset = 0;
            copy_pass := SDL_BeginGPUCopyPass(command_buffer);
            if !copy_pass {
                report_sdl_error("SDL_BeginGPUCopyPass", "instance_transfer_buffer");
            }

            SDL_UploadToGPUBuffer(copy_pass, *location, *region, false);

            SDL_EndGPUCopyPass(copy_pass);

            render_shadow_pass(*scene, mesh_batcher.batches, command_buffer);
            render_opaque_pass(scene, mesh_batcher.batches, swap_texture, command_buffer);
            render_debug_pass(scene, mesh_batcher.batches, swap_texture, command_buffer);
        }

        if !SDL_SubmitGPUCommandBuffer(command_buffer) {
            report_sdl_error("SDL_SubmitGPUCommandBuffer", "render_frame");
        }
    } else {
        if !SDL_CancelGPUCommandBuffer(command_buffer) {
            report_sdl_error("SDL_CancelGPUCommandBuffer", "render_frame");
        }
    }
}

init_renderer :: () {
    renderer_arena = make_arena();

    mesh_pipeline_options := Pipeline_Create_Options.{
        has_colour_target = true,
        has_depth_target = true,
        enable_depth_test = true,
        enable_depth_write = true,
        enable_alpha_blending = true,
        cull_mode = .SDL_GPU_CULLMODE_BACK,
        shader_options = .{"static_mesh", "static_mesh", shader_feature_flags_static_mesh},
        needed_textures = 2
    };

    mesh_pipeline = create_pipeline("mesh_render_pipeline", mesh_pipeline_options, .MESH);

    terrain_pipeline_options := mesh_pipeline_options;
    terrain_pipeline_options.shader_options = .{"static_mesh", "terrain", shader_feature_flags_static_mesh};

    terrain_pipeline = create_pipeline("terrain_render_pipeline", terrain_pipeline_options, .MESH);

    sky_pipeline_options := mesh_pipeline_options;
    sky_pipeline_options.shader_options = .{"static_mesh", "sky", shader_feature_flags_none};

    sky_pipeline = create_pipeline("sky_render_pipeline", sky_pipeline_options, .MESH);

    shadow_pipeline_options := Pipeline_Create_Options.{
        has_colour_target = true,
        uses_swap_texture = false,
        cull_mode = .SDL_GPU_CULLMODE_FRONT,
        shader_options = .{"shadow", "", shader_feature_flags_none}
    };

    shadow_pipeline = create_pipeline("shadow_render_pipeline", shadow_pipeline_options, .SHADOW);

    debug_pipeline_options := Pipeline_Create_Options.{
        has_colour_target = true,
        cull_mode = .SDL_GPU_CULLMODE_NONE,
        fill_mode = .SDL_GPU_FILLMODE_LINE,
        shader_options = .{"debug", "", shader_feature_flags_none}
    };

    debug_pipeline = create_pipeline("debug_render_pipeline", debug_pipeline_options, .DEBUG);

    mesh_depth_create_info := SDL_GPUTextureCreateInfo.{
        type = .SDL_GPU_TEXTURETYPE_2D,
        format = .SDL_GPU_TEXTUREFORMAT_D24_UNORM,
        width = xx context.viewport.x,
        height = xx context.viewport.y,
        layer_count_or_depth = 1,
        num_levels = 1,
        usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET
    };

    mesh_depth_texture = SDL_CreateGPUTexture(context.device, *mesh_depth_create_info);
    if !mesh_depth_texture {
        report_sdl_error("SDL_CreateGPUTexture", "mesh_depth_texture");
    }

    SDL_SetGPUTextureName(context.device, mesh_depth_texture, "mesh_depth_texture");

    shadow_create_info := SDL_GPUTextureCreateInfo.{
        type = .SDL_GPU_TEXTURETYPE_2D_ARRAY,
        format = .SDL_GPU_TEXTUREFORMAT_R32_FLOAT,
        width = xx SHADOW_MAP_SIZE,
        height = xx SHADOW_MAP_SIZE,
        layer_count_or_depth = shadow_cascade_count,
        num_levels = 1,
        usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_COLOR_TARGET
    };

    shadow_texture_array = SDL_CreateGPUTexture(context.device, *shadow_create_info);
    if !shadow_texture_array {
        report_sdl_error("SDL_CreateGPUTexture", "shadow_texture_array");
    }

    SDL_SetGPUTextureName(context.device, shadow_texture_array, "shadow_texture_array");

    default_sampler_info: SDL_GPUSamplerCreateInfo;
    default_sampler_info.min_lod = 0;
    default_sampler_info.max_lod = 99;
    default_sampler_info.min_filter = .SDL_GPU_FILTER_LINEAR;
    default_sampler_info.mag_filter = .SDL_GPU_FILTER_LINEAR;
    default_sampler_info.mipmap_mode = .SDL_GPU_SAMPLERMIPMAPMODE_LINEAR;
    default_sampler_info.address_mode_u = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
    default_sampler_info.address_mode_v = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
    default_sampler_info.address_mode_w = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
    default_sampler = SDL_CreateGPUSampler(context.device, *default_sampler_info);
    if !default_sampler {
        report_sdl_error("SDL_CreateGPUSampler", "default_sampler");
    }

    shadow_sampler_info: SDL_GPUSamplerCreateInfo;
    shadow_sampler_info.min_lod = 0;
    shadow_sampler_info.max_lod = 0;
    shadow_sampler_info.min_filter = .SDL_GPU_FILTER_LINEAR;
    shadow_sampler_info.mag_filter = .SDL_GPU_FILTER_LINEAR;
    shadow_sampler_info.address_mode_u = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
    shadow_sampler_info.address_mode_v = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
    shadow_sampler_info.address_mode_w = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
    shadow_sampler = SDL_CreateGPUSampler(context.device, *shadow_sampler_info);
    if !shadow_sampler {
        report_sdl_error("SDL_CreateGPUSampler", "shadow_sampler");
    }

    default_texture = create_default_texture();

    instance_buffer = create_storage_buffer("instance_buffer", size_of(Instance_Data) * MAX_INSTANCES);
    instance_transfer_buffer = create_transfer_buffer(size_of(Instance_Data) * MAX_INSTANCES);
}

Pipeline :: struct {
    next, prev: *Pipeline;

    name: string;
    shader: *Shader;

    create_info: SDL_GPUGraphicsPipelineCreateInfo;
    pipeline_object: *SDL_GPUGraphicsPipeline;

    needed_textures: int;
}

recreate_pipeline :: (pipeline: *Pipeline) {
    pipeline.create_info.vertex_shader = pipeline.shader.vertex;
    pipeline.create_info.fragment_shader = pipeline.shader.fragment;
    pipeline.pipeline_object = SDL_CreateGPUGraphicsPipeline(context.device, *pipeline.create_info);
}

#scope_file

create_default_texture :: () -> *Texture {
    size := 128;
    half_size := size/2;
    pixels := push_view(context.temp_arena, u8, size * size * 4);
    for y: 0..half_size-1 for x: 0..half_size-1 {
        pixels[(x+y*size)*4 + 0] = xx 0xff;
        pixels[(x+y*size)*4 + 1] = xx 0;
        pixels[(x+y*size)*4 + 2] = xx 0xff;
        pixels[(x+y*size)*4 + 3] = xx 0xff;
    }

    for y: half_size..size-1 for x: half_size..size-1 {
        pixels[(x+y*size)*4 + 0] = xx 0xff;
        pixels[(x+y*size)*4 + 1] = xx 0;
        pixels[(x+y*size)*4 + 2] = xx 0xff;
        pixels[(x+y*size)*4 + 3] = xx 0xff;
    }

    return create_texture("missing", .{pixels, size, size, .RGBA8_UNORM});
}

mesh_batcher: Mesh_Batcher;

SHADOW_MAP_SIZE :: 1024;

renderer_arena: *Arena;

pipelines: Bucket_Array(Pipeline);
mesh_pipeline: *Pipeline;
terrain_pipeline: *Pipeline;
shadow_pipeline: *Pipeline;
sky_pipeline: *Pipeline;
debug_pipeline: *Pipeline;

default_texture: *Texture;

shadow_cascade_count :: 4; // SHADOW_CASCADE_COUNT in shared.hlsl
shadow_texture_array: *SDL_GPUTexture;
shadow_sampler: *SDL_GPUSampler;

mesh_depth_texture: *SDL_GPUTexture;
default_sampler: *SDL_GPUSampler;

MAX_BATCHES :: 1024;
MAX_INSTANCES :: 100000;
instance_buffer: *SDL_GPUBuffer;
instance_transfer_buffer: *SDL_GPUTransferBuffer;

Pipeline_Create_Options :: struct {
    has_colour_target: bool;
    colour_target_count := 1;
    uses_swap_texture := true;
    has_depth_target: bool;
    enable_depth_test: bool;
    enable_depth_write: bool;
    enable_alpha_blending: bool;
    cull_mode := SDL_GPUCullMode.SDL_GPU_CULLMODE_BACK;
    fill_mode := SDL_GPUFillMode.SDL_GPU_FILLMODE_FILL;
    shader_options: Shader_Options;
    needed_textures: int;
}

Pipeline_Type :: enum {
    DEBUG;
    SHADOW;
    MESH;
}

create_pipeline :: (name: string, opts: Pipeline_Create_Options, type: Pipeline_Type) -> *Pipeline {
    create_info: SDL_GPUGraphicsPipelineCreateInfo;

    if opts.has_colour_target {
        colour_desc := push_view(renderer_arena, SDL_GPUColorTargetDescription, opts.colour_target_count);
        for * colour_desc {
            if opts.uses_swap_texture {
                it.format = SDL_GetGPUSwapchainTextureFormat(context.device, context.window);
            } else {
                it.format = .SDL_GPU_TEXTUREFORMAT_R32_FLOAT;
            }

            if opts.enable_alpha_blending {
                it.blend_state.src_color_blendfactor = .SDL_GPU_BLENDFACTOR_SRC_ALPHA;
                it.blend_state.dst_color_blendfactor = .SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
                it.blend_state.color_blend_op = .SDL_GPU_BLENDOP_ADD;
                it.blend_state.src_alpha_blendfactor = .SDL_GPU_BLENDFACTOR_ONE;
                it.blend_state.dst_alpha_blendfactor = .SDL_GPU_BLENDFACTOR_ZERO;
                it.blend_state.alpha_blend_op = .SDL_GPU_BLENDOP_ADD;
                it.blend_state.enable_blend = true;
            }
        }

        create_info.target_info.color_target_descriptions = colour_desc.data;
        create_info.target_info.num_color_targets = xx opts.colour_target_count;
    }

    if opts.has_depth_target {
        create_info.target_info.has_depth_stencil_target = true;
        create_info.target_info.depth_stencil_format = .SDL_GPU_TEXTUREFORMAT_D24_UNORM;

        create_info.depth_stencil_state.compare_op = .SDL_GPU_COMPAREOP_LESS;
        create_info.depth_stencil_state.enable_depth_test = opts.enable_depth_test;
        create_info.depth_stencil_state.enable_depth_write = opts.enable_depth_write;
    }

    create_info.rasterizer_state.cull_mode = opts.cull_mode;
    create_info.rasterizer_state.fill_mode = opts.fill_mode;
    create_info.rasterizer_state.front_face = .SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;

    buffers_desc: [] SDL_GPUVertexBufferDescription;
    attributes_desc: [] SDL_GPUVertexAttribute;

    if #complete type == {
        case .DEBUG; #through;
        case .SHADOW;
            buffers_desc = push_view(renderer_arena, SDL_GPUVertexBufferDescription, 1);
            buffers_desc[0] = .{0, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            create_info.vertex_input_state.vertex_buffer_descriptions = buffers_desc.data;
            create_info.vertex_input_state.num_vertex_buffers = 1;

            attributes_desc = push_view(renderer_arena, SDL_GPUVertexAttribute, 1);
            attributes_desc[0] = .{0, 0, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
            create_info.vertex_input_state.vertex_attributes = attributes_desc.data;
            create_info.vertex_input_state.num_vertex_attributes = 1;
        case .MESH;
            buffers_desc = push_view(renderer_arena, SDL_GPUVertexBufferDescription, 5);
            buffers_desc[0] = .{0, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            buffers_desc[1] = .{1, size_of(Linear_Colour), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            buffers_desc[2] = .{2, size_of(Vec2), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            buffers_desc[3] = .{3, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            buffers_desc[4] = .{4, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            create_info.vertex_input_state.vertex_buffer_descriptions = buffers_desc.data;
            create_info.vertex_input_state.num_vertex_buffers = 5;

            attributes_desc = push_view(renderer_arena, SDL_GPUVertexAttribute, 5);
            attributes_desc[0] = .{0, 0, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
            attributes_desc[1] = .{1, 1, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, 0};
            attributes_desc[2] = .{2, 2, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, 0};
            attributes_desc[3] = .{3, 3, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
            attributes_desc[4] = .{4, 4, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
            create_info.vertex_input_state.vertex_attributes = attributes_desc.data;
            create_info.vertex_input_state.num_vertex_attributes = 5;
    }

    shader := load_shader(opts.shader_options);
    create_info.vertex_shader = shader.vertex;
    create_info.fragment_shader = shader.fragment;

    pipeline_object := SDL_CreateGPUGraphicsPipeline(context.device, *create_info);
    if !pipeline_object {
        report_sdl_error("SDL_CreateGPUGraphicsPipeline", tprint("%", name));
    }

    pipeline := bucket_array_add(*pipelines, .{});
    pipeline.name = copy_string_global(name);
    pipeline.create_info = create_info;
    pipeline.shader = shader;
    pipeline.pipeline_object = pipeline_object;
    pipeline.needed_textures = opts.needed_textures;

    array_add(*shader.pipelines, pipeline);

    return pipeline;
}

Mesh_Batch :: struct {
    instances: [..] Instance_Data;

    vertex_buffers: [] SDL_GPUBufferBinding;
    index_buffer: SDL_GPUBufferBinding;

    textures: [] SDL_GPUTextureSamplerBinding;

    pipeline: *Pipeline;

    flags: Command_Flags;

    num_indices: int;
}

Mesh_Batcher :: struct {
    hash_map: [] int;
    batches: [..] Mesh_Batch;
    total_instance_count: int;
    initialized: bool;
}

init_mesh_batcher :: (batcher: *Mesh_Batcher) {
    zero(batcher);

    batcher.hash_map = push_view(context.temp_arena, int, MAX_BATCHES);
    for * batcher.hash_map it.* = -1;

    batcher.batches = make_arena_array(context.temp_arena, Mesh_Batch);
}

calculate_light_space_matrix :: (sun: Directional_Light, camera: *Camera_Base, near_plane: float, far_plane: float) -> Mat4 {
    projection := mat4_projection(camera.fov, context.aspect_ratio, near_plane, far_plane);
    inverse := mat4_inverse(projection * camera.view);

    corners: [8] Vec4;
    corners[0] = inverse * Vec4.{-1, -1, -1, 1};
    corners[1] = inverse * Vec4.{-1, -1,  1, 1};
    corners[2] = inverse * Vec4.{-1,  1, -1, 1};
    corners[3] = inverse * Vec4.{-1,  1,  1, 1};
    corners[4] = inverse * Vec4.{ 1, -1, -1, 1};
    corners[5] = inverse * Vec4.{ 1, -1,  1, 1};
    corners[6] = inverse * Vec4.{ 1,  1, -1, 1};
    corners[7] = inverse * Vec4.{ 1,  1,  1, 1};

    for * corners {
        it.* /= v4(it.w);
    }

    center: Vec3;
    min_corner := v3(FLOAT32_MAX);
    max_corner := v3(-FLOAT32_MAX);
    for corners {
        center += it.xyz;
        min_corner = min(min_corner, it.xyz);
        max_corner = max(max_corner, it.xyz);
    }
    center /= v3(8.0);
    radius := distance(max_corner, min_corner) * .5;

    texel_size := SHADOW_MAP_SIZE / (radius * 2.0);
    light_view := mat4_scale(v3(texel_size))
        * mat4_look_at(v3(0.0), -sun.direction);

    center = (light_view * v4(center, 1.0)).xyz;
    center = v3(center.x, floor(center.yz));
    center = (mat4_inverse(light_view) * v4(center, 1.0)).xyz;

    eye := center - (sun.direction * radius * 2.0);
    light_view = mat4_look_at(eye, center);

    light_projection := mat4_ortho(-radius, radius, -radius, radius, -radius * 6.0, radius * 6.0);
    light_matrix := light_projection * light_view;
    return light_matrix;
}
