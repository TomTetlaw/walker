
Instance_Data :: struct {
    transform := mat4_identity;
    colour := #run rgba(1.0);
}

Render_Batch :: struct {
    next, prev: *Render_Batch;

    instances: [..] Instance_Data;

    vertex_buffers: [] SDL_GPUBufferBinding;
    index_buffer: SDL_GPUBufferBinding;

    textures: [] SDL_GPUTextureSamplerBinding;

    num_indices: int;
    num_instances: int;
}

Render_Batcher :: struct {
    hash_map: [] *Render_Batch;
    batch_arena: *Arena;
    data_arena: *Arena;
    instance_count: int;
}

MAX_BATCHES :: 1024;

free_render_batcher :: (batcher: *Render_Batcher) {
    free_arena(batcher.batch_arena);
    free_arena(batcher.data_arena);
}

make_batches :: (batcher: Render_Batcher) -> [] Render_Batch {
    if !batcher.batch_arena return .[];
    batches := arena_to_view(batcher.batch_arena, Render_Batch);
    return batches;
}

Render_Command :: struct {
    mesh: *Mesh;
    textures: [] *Texture;
    using instance: Instance_Data;
}

add_render_command :: (batcher: *Render_Batcher, command: Render_Command) {
    if !batcher.batch_arena {
        batcher.batch_arena = make_arena();
        batcher.data_arena = make_arena();
        batcher.hash_map = push_view(batcher.data_arena, *Render_Batch, MAX_BATCHES);
    }

    if batcher.instance_count >= MAX_INSTANCES return;

    hash := get_hash(command.mesh.name);
    for command.textures {
        hash = get_hash(it.name, hash);
    }

    batch := batcher.hash_map[hash % MAX_BATCHES];
    if !batch {
        stub_batch :: Render_Batch.{};
        batch = push_struct(batcher.batch_arena, Render_Batch, *stub_batch);
        if batch == *stub_batch {
            return;
        }

        batch.instances = push_array(batcher.data_arena, Instance_Data, 32);

        batch.vertex_buffers = push_view(batcher.data_arena, SDL_GPUBufferBinding, 5);
        batch.vertex_buffers[0] = .{command.mesh.position_buffer, 0};
        batch.vertex_buffers[1] = .{command.mesh.colour_buffer, 0};
        batch.vertex_buffers[2] = .{command.mesh.tex_coord_buffer, 0};
        batch.vertex_buffers[3] = .{command.mesh.normal_buffer, 0};
        batch.vertex_buffers[4] = .{command.mesh.tangent_buffer, 0};

        batch.index_buffer = .{command.mesh.index_buffer, 0};

        batch.textures = push_view(batcher.data_arena, SDL_GPUTextureSamplerBinding, mesh_pipeline.needed_textures);
        fallback_texture := load_texture("missing");
        for * batch.textures {
            it.* = .{fallback_texture.texture_object, default_sampler};
        }
        for command.textures {
            batch.textures[it_index] = .{it.texture_object, default_sampler};
        }

        batch.num_indices = command.mesh.num_indices;

        batcher.hash_map[hash % MAX_BATCHES] = batch;
    }

    batch.num_instances += 1;
    array_add(*batch.instances, command.instance);
}

Mesh_Vertex_Constants :: struct {
    view, projection := mat4_identity;
}

Mesh_Fragment_Constants :: struct {
    camera_position: Vec4;

    // xy = tex coord scale
    material_params := Vec4.{1, 1, 0, 0};

    // x = ambient lighting
    // y = diffuse intensity
    // z = specular intensity
    // w = specular shininess
    light_params := Vec4.{0.3, 1.0, 1.0, 2.0};

    directional_light_dir := Vec4.{0, 0, -1, 0};
    directional_light_colour := colour_white;
}

Render_Scene :: struct {
    mesh_batcher: Render_Batcher;
    mesh_vert_constants: Mesh_Vertex_Constants;
    mesh_frag_constants: Mesh_Fragment_Constants;
}

render_scene :: (scene: Render_Scene) {
    command_buffer := SDL_AcquireGPUCommandBuffer(context.device);

    swap_texture: *SDL_GPUTexture;
    SDL_AcquireGPUSwapchainTexture(command_buffer, context.window, *swap_texture, null, null);
    if !swap_texture {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return;
    }

    batches := make_batches(scene.mesh_batcher);
    defer free_render_batcher(*scene.mesh_batcher);

    if batches.count > 0 {
        mapping := cast(*Instance_Data) SDL_MapGPUTransferBuffer(context.device, instance_transfer_buffer, false);
        cursor := 0;
        for batch: batches {
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

        SDL_UploadToGPUBuffer(copy_pass, *location, *region, false);
        SDL_EndGPUCopyPass(copy_pass);
    }

    colour_target := SDL_GPUColorTargetInfo.{
        texture = swap_texture,
        clear_color = .{0, 0, 0, 1},
        load_op = .SDL_GPU_LOADOP_CLEAR,
        store_op = .SDL_GPU_STOREOP_STORE,
    };

    depth_target := SDL_GPUDepthStencilTargetInfo.{
        texture = mesh_depth_texture,
        clear_depth = 1,
        load_op = .SDL_GPU_LOADOP_CLEAR,
        store_op = .SDL_GPU_STOREOP_STORE,
    };

    render_pass := SDL_BeginGPURenderPass(command_buffer, *colour_target, 1, *depth_target);

    SDL_BindGPUGraphicsPipeline(render_pass, mesh_pipeline.pipeline_object);

    shadow_binding := SDL_GPUTextureSamplerBinding.{shadow_texture, shadow_sampler};

    SDL_PushGPUVertexUniformData(command_buffer, 0, *scene.mesh_vert_constants, size_of(Mesh_Vertex_Constants));
    SDL_PushGPUFragmentUniformData(command_buffer, 0, *scene.mesh_frag_constants, size_of(Mesh_Fragment_Constants));
    SDL_BindGPUVertexStorageBuffers(render_pass, 0, *instance_buffer, 1);

    base_instance := 0;
    for batch: batches {
        SDL_BindGPUVertexBuffers(render_pass, 0, batch.vertex_buffers.data, xx batch.vertex_buffers.count);
        SDL_BindGPUIndexBuffer(render_pass, *batch.index_buffer, .SDL_GPU_INDEXELEMENTSIZE_32BIT);
        // SDL_BindGPUFragmentSamplers(render_pass, 0, *shadow_binding, 1);
        SDL_BindGPUFragmentSamplers(render_pass, 0, batch.textures.data, xx batch.textures.count);
        SDL_DrawGPUIndexedPrimitives(render_pass, xx batch.num_indices, xx batch.num_instances, 0, 0, xx base_instance);
        base_instance += batch.num_instances;
    }

    SDL_EndGPURenderPass(render_pass);

    SDL_SubmitGPUCommandBuffer(command_buffer);
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
        fill_mode = .SDL_GPU_FILLMODE_FILL,
        shader_name = "static_mesh",
        needed_textures = 1
    };

    mesh_pipeline = create_pipeline("mesh_render_pipeline", mesh_pipeline_options);

    mesh_depth_create_info := SDL_GPUTextureCreateInfo.{
        type = .SDL_GPU_TEXTURETYPE_2D,
        format = .SDL_GPU_TEXTUREFORMAT_D24_UNORM,
        width = xx context.viewport.x,
        height = xx context.viewport.y,
        layer_count_or_depth = 1,
        num_levels = xx get_mipmap_count(xx context.viewport.x, xx context.viewport.y),
        usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET
    };

    mesh_depth_texture = SDL_CreateGPUTexture(context.device, *mesh_depth_create_info);

    shadow_create_info := SDL_GPUTextureCreateInfo.{
        type = .SDL_GPU_TEXTURETYPE_2D,
        format = .SDL_GPU_TEXTUREFORMAT_D24_UNORM,
        width = SHADOW_MAP_SIZE,
        height = SHADOW_MAP_SIZE,
        layer_count_or_depth = 1,
        num_levels = xx get_mipmap_count(SHADOW_MAP_SIZE, SHADOW_MAP_SIZE),
        usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET
    };

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

    shadow_sampler_info: SDL_GPUSamplerCreateInfo;
    shadow_sampler_info.min_lod = 0;
    shadow_sampler_info.max_lod = 0;
    shadow_sampler_info.min_filter = .SDL_GPU_FILTER_NEAREST;
    shadow_sampler_info.mag_filter = .SDL_GPU_FILTER_NEAREST;
    shadow_sampler_info.mipmap_mode = .SDL_GPU_SAMPLERMIPMAPMODE_NEAREST;
    shadow_sampler_info.address_mode_u = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
    shadow_sampler_info.address_mode_v = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
    shadow_sampler_info.address_mode_w = .SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
    shadow_sampler = SDL_CreateGPUSampler(context.device, *shadow_sampler_info);

    shadow_texture = SDL_CreateGPUTexture(context.device, *shadow_create_info);

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
    print("Recreated pipeline %\n", pipeline.name);
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

SHADOW_MAP_SIZE :: 1024;

renderer_arena: *Arena;

pipelines: Bucket_Array(Pipeline);
mesh_pipeline: *Pipeline;

default_texture: *Texture;

shadow_texture: *SDL_GPUTexture;
mesh_depth_texture: *SDL_GPUTexture;
default_sampler: *SDL_GPUSampler;
shadow_sampler: *SDL_GPUSampler;

MAX_INSTANCES :: 4096;
instance_buffer: *SDL_GPUBuffer;
instance_transfer_buffer: *SDL_GPUTransferBuffer;

Pipeline_Create_Options :: struct {
    has_colour_target: bool;
    has_depth_target: bool;
    enable_depth_test: bool;
    enable_depth_write: bool;
    enable_alpha_blending: bool;
    cull_mode := SDL_GPUCullMode.SDL_GPU_CULLMODE_BACK;
    fill_mode := SDL_GPUFillMode.SDL_GPU_FILLMODE_FILL;
    shader_name: string;
    needed_textures: int;
}

create_pipeline :: (name: string, opts: Pipeline_Create_Options) -> *Pipeline {
    info: SDL_GPUGraphicsPipelineCreateInfo;

    colour_desc: SDL_GPUColorTargetDescription;
    colour_desc.format = SDL_GetGPUSwapchainTextureFormat(context.device, context.window);
    if opts.enable_alpha_blending {
        colour_desc.blend_state.src_color_blendfactor = .SDL_GPU_BLENDFACTOR_SRC_ALPHA;
        colour_desc.blend_state.dst_color_blendfactor = .SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
        colour_desc.blend_state.color_blend_op = .SDL_GPU_BLENDOP_ADD;
        colour_desc.blend_state.src_alpha_blendfactor = .SDL_GPU_BLENDFACTOR_ONE;
        colour_desc.blend_state.dst_alpha_blendfactor = .SDL_GPU_BLENDFACTOR_ZERO;
        colour_desc.blend_state.alpha_blend_op = .SDL_GPU_BLENDOP_ADD;
        colour_desc.blend_state.enable_blend = true;
    }

    if opts.has_colour_target {
        info.target_info.color_target_descriptions = push_struct(renderer_arena, colour_desc);
        info.target_info.num_color_targets = 1;
    }

    if opts.has_depth_target {
        info.target_info.has_depth_stencil_target = true;
        info.target_info.depth_stencil_format = .SDL_GPU_TEXTUREFORMAT_D24_UNORM;

        info.depth_stencil_state.compare_op = .SDL_GPU_COMPAREOP_LESS;
        info.depth_stencil_state.enable_depth_test = opts.enable_depth_test;
        info.depth_stencil_state.enable_depth_write = opts.enable_depth_write;
    }

    info.rasterizer_state.cull_mode = opts.cull_mode;
    info.rasterizer_state.fill_mode = opts.fill_mode;
    info.rasterizer_state.front_face = .SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;

    buffers_desc := push_view(renderer_arena, SDL_GPUVertexBufferDescription, 5);
    buffers_desc[0] = .{0, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
    buffers_desc[1] = .{1, size_of(Linear_Colour), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
    buffers_desc[2] = .{2, size_of(Vec2), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
    buffers_desc[3] = .{3, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
    buffers_desc[4] = .{4, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
    info.vertex_input_state.vertex_buffer_descriptions = buffers_desc.data;
    info.vertex_input_state.num_vertex_buffers = 5;

    attributes_desc := push_view(renderer_arena, SDL_GPUVertexAttribute, 5);
    attributes_desc[0] = .{0, 0, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
    attributes_desc[1] = .{1, 1, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, 0};
    attributes_desc[2] = .{2, 2, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, 0};
    attributes_desc[3] = .{3, 3, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
    attributes_desc[4] = .{4, 4, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
    info.vertex_input_state.vertex_attributes = attributes_desc.data;
    info.vertex_input_state.num_vertex_attributes = 5;

    shader := load_shader(opts.shader_name);
    info.vertex_shader = shader.vertex;
    info.fragment_shader = shader.fragment;

    pipeline_object := SDL_CreateGPUGraphicsPipeline(context.device, *info);

    pipeline := bucket_array_add(*pipelines, .{});
    pipeline.name = name;
    pipeline.create_info = info;
    pipeline.shader = shader;
    pipeline.pipeline_object = pipeline_object;
    pipeline.needed_textures = opts.needed_textures;

    linked_list_add(*shader.pipelines, pipeline);

    return pipeline;
}