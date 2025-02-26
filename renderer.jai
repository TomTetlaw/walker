
Instance_Data :: struct {
    transform := mat4_identity;
    colour := #run rgba(1.0);
    material_params := Vec4.{1, 1, 0, 0};
}

Render_Batch :: struct {
    next, prev: *Render_Batch;

    instances: [..] Instance_Data;

    vertex_buffers: [] SDL_GPUBufferBinding;
    index_buffer: SDL_GPUBufferBinding;

    textures: [] SDL_GPUTextureSamplerBinding;

    pipeline: *Pipeline;

    flags: Command_Flags;

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

init_render_batcher :: (batcher: *Render_Batcher) {
    batcher.batch_arena = make_arena();
    batcher.data_arena = make_arena();
    batcher.hash_map = push_view(batcher.data_arena, *Render_Batch, MAX_BATCHES);
}

free_render_batcher :: (batcher: *Render_Batcher) {
    free_arena(batcher.batch_arena);
    free_arena(batcher.data_arena);
}

make_batches :: (batcher: Render_Batcher) -> [] Render_Batch {
    batches := arena_to_view(batcher.batch_arena, Render_Batch);
    return batches;
}

Mesh_Shader :: enum {
    STATIC_MESH;
    TERRAIN;
    SKY;
}

Command_Flags :: enum_flags {
    WIREFRAME;
    NO_CAST_SHADOW;
}

Render_Command :: struct {
    shader: Mesh_Shader;
    mesh: *Mesh;
    textures: [] *Texture;
    flags: Command_Flags;
    using instance: Instance_Data;
}

add_render_command :: (batcher: *Render_Batcher, command: Render_Command) {
    if batcher.instance_count >= MAX_INSTANCES return;

    pipeline: *Pipeline;
    if command.shader == {
        case .STATIC_MESH;
        pipeline = mesh_pipeline;
        case .TERRAIN;
        pipeline = terrain_pipeline;
        case .SKY;
        pipeline = sky_pipeline;
    }

    hash := get_hash(pipeline.name);
    hash = get_hash(command.flags, hash);
    hash = get_hash(command.mesh.name, hash);
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

        batch.pipeline = pipeline;
        batch.flags = command.flags;

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

    mesh_batcher: Render_Batcher;

    cascades: [shadow_cascade_count] float;
    light_matrices: [shadow_cascade_count] Mat4;
}

render_shadow_pass :: (scene: *Render_Scene, batches: [] Render_Batch, command_buffer: *SDL_GPUCommandBuffer) {
    near_planes: [shadow_cascade_count] float;
    far_planes: [shadow_cascade_count] float;

    n := scene.camera.near_plane;
    f := scene.camera.far_plane;
    range := scene.camera.far_plane - scene.camera.near_plane;

    near_planes[0] = n;
    far_planes[0] = n + range * .125;

    near_planes[1] = far_planes[0];
    far_planes[1] = n + range * .4;

    near_planes[2] = far_planes[1];
    far_planes[2] = n + range * .75;

    near_planes[3] = far_planes[2];
    far_planes[3] = f;

    /*depth_increment := (scene.camera.far_plane - scene.camera.near_plane) / shadow_cascade_count;
    for 0..shadow_cascade_count-1 {
        near_planes[it] = scene.camera.near_plane + (it * depth_increment);
        far_planes[it] = scene.camera.near_plane + ((it+1) * depth_increment);
    }*/

    for 0..shadow_cascade_count-1 {
        scene.light_matrices[it] = calculate_light_space_matrix(scene.sun, *scene.camera,
            near_planes[it], far_planes[it]);
    }

    scene.cascades = far_planes;

    for 0..shadow_cascade_count-1 {
        colour_target := SDL_GPUColorTargetInfo.{
            texture = shadow_texture_array,
            clear_color = .{1, 1, 1, 1},
            load_op = .SDL_GPU_LOADOP_CLEAR,
            store_op = .SDL_GPU_STOREOP_STORE,
            layer_or_depth_plane = xx it,
        };

        render_pass := SDL_BeginGPURenderPass(command_buffer, *colour_target, 1, null);

        base_instance := 0;
        for batch: batches {
            if batch.flags & .NO_CAST_SHADOW continue;

            SDL_PushGPUVertexUniformData(command_buffer, 0, *scene.light_matrices[it], size_of(Mat4));

            SDL_BindGPUGraphicsPipeline(render_pass, shadow_pipeline.filled);

            viewport := SDL_GPUViewport.{0, 0, SHADOW_MAP_SIZE, SHADOW_MAP_SIZE, 0, 1};
            SDL_SetGPUViewport(render_pass, *viewport);

            SDL_BindGPUVertexStorageBuffers(render_pass, 0, *instance_buffer, 1);

            SDL_BindGPUVertexBuffers(render_pass, 0, batch.vertex_buffers.data, xx batch.vertex_buffers.count);
            SDL_BindGPUIndexBuffer(render_pass, *batch.index_buffer, .SDL_GPU_INDEXELEMENTSIZE_32BIT);
            SDL_DrawGPUIndexedPrimitives(render_pass, xx batch.num_indices, xx batch.num_instances, 0, 0, xx base_instance);
            base_instance += batch.num_instances;
        }

        SDL_EndGPURenderPass(render_pass);
    }
}

render_opaque_pass :: (scene: Render_Scene, batches: [] Render_Batch, swap_texture: *SDL_GPUTexture, command_buffer: *SDL_GPUCommandBuffer) {
    colour_target := SDL_GPUColorTargetInfo.{
        texture = swap_texture,
        clear_color = .{0.2, 0.5, 0.8, 1},
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
        if batch.flags & .WIREFRAME {
            SDL_BindGPUGraphicsPipeline(render_pass, batch.pipeline.wireframe);
        } else {
            SDL_BindGPUGraphicsPipeline(render_pass, batch.pipeline.filled);
        }

        SDL_BindGPUVertexStorageBuffers(render_pass, 0, *instance_buffer, 1);
        SDL_BindGPUVertexBuffers(render_pass, 0, batch.vertex_buffers.data, xx batch.vertex_buffers.count);
        SDL_BindGPUIndexBuffer(render_pass, *batch.index_buffer, .SDL_GPU_INDEXELEMENTSIZE_32BIT);

        textures := tarray(SDL_GPUTextureSamplerBinding, batch.textures.count + 1);
        array_add(*textures, shadow_binding);
        for batch.textures {
            array_add(*textures, it);
        }

        SDL_BindGPUFragmentSamplers(render_pass, 0, textures.data, xx textures.count);
        SDL_DrawGPUIndexedPrimitives(render_pass, xx batch.num_indices, xx batch.num_instances, 0, 0, xx base_instance);
        base_instance += batch.num_instances;
    }

    SDL_EndGPURenderPass(render_pass);
}

render_scene :: (scene: Render_Scene) {
    batches := make_batches(scene.mesh_batcher);
    defer free_render_batcher(*scene.mesh_batcher);

    command_buffer := SDL_AcquireGPUCommandBuffer(context.device);

    swap_texture: *SDL_GPUTexture;
    SDL_AcquireGPUSwapchainTexture(command_buffer, context.window, *swap_texture, null, null);
    if !swap_texture {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return;
    }

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

    render_shadow_pass(*scene, batches, command_buffer);
    render_opaque_pass(scene, batches, swap_texture, command_buffer);

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
        shader_name = "static_mesh",
        needed_textures = 2
    };

    mesh_pipeline = create_pipeline("mesh_render_pipeline", mesh_pipeline_options, .MESH);

    terrain_pipeline_options := mesh_pipeline_options;
    terrain_pipeline_options.shader_name = "terrain";

    terrain_pipeline = create_pipeline("terrain_render_pipeline", terrain_pipeline_options, .MESH);

    sky_pipeline_options := mesh_pipeline_options;
    sky_pipeline_options.shader_name = "sky";

    sky_pipeline = create_pipeline("sky_render_pipeline", sky_pipeline_options, .MESH);

    shadow_pipeline_options := Pipeline_Create_Options.{
        has_colour_target = true,
        colour_target_count = 1,
        uses_swap_texture = false,
        cull_mode = .SDL_GPU_CULLMODE_FRONT,
        shader_name = "shadow",
    };

    shadow_pipeline = create_pipeline("shadow_render_pipeline", shadow_pipeline_options, .SHADOW);

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

    shadow_sampler_info: SDL_GPUSamplerCreateInfo;
    default_sampler_info.min_lod = 0;
    default_sampler_info.max_lod = 0;
    default_sampler_info.min_filter = .SDL_GPU_FILTER_NEAREST;
    default_sampler_info.mag_filter = .SDL_GPU_FILTER_NEAREST;
    default_sampler_info.mipmap_mode = .SDL_GPU_SAMPLERMIPMAPMODE_NEAREST;
    default_sampler_info.address_mode_u = .SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
    default_sampler_info.address_mode_v = .SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
    default_sampler_info.address_mode_w = .SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
    shadow_sampler = SDL_CreateGPUSampler(context.device, *shadow_sampler_info);

    default_texture = create_default_texture();

    instance_buffer = create_storage_buffer("instance_buffer", size_of(Instance_Data) * MAX_INSTANCES);
    instance_transfer_buffer = create_transfer_buffer(size_of(Instance_Data) * MAX_INSTANCES);
}

Pipeline :: struct {
    next, prev: *Pipeline;

    name: string;
    shader: *Shader;

    filled_info: SDL_GPUGraphicsPipelineCreateInfo;
    filled: *SDL_GPUGraphicsPipeline;

    wireframe_info: SDL_GPUGraphicsPipelineCreateInfo;
    wireframe: *SDL_GPUGraphicsPipeline;

    needed_textures: int;
}

recreate_pipeline :: (pipeline: *Pipeline) {
    pipeline.filled_info.vertex_shader = pipeline.shader.vertex;
    pipeline.filled_info.fragment_shader = pipeline.shader.fragment;
    pipeline.filled = SDL_CreateGPUGraphicsPipeline(context.device, *pipeline.filled_info);

    pipeline.wireframe_info.vertex_shader = pipeline.shader.vertex;
    pipeline.wireframe_info.fragment_shader = pipeline.shader.fragment;
    pipeline.wireframe = SDL_CreateGPUGraphicsPipeline(context.device, *pipeline.wireframe_info);

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

SHADOW_MAP_SIZE :: 2048;

renderer_arena: *Arena;

pipelines: Bucket_Array(Pipeline);
mesh_pipeline: *Pipeline;
terrain_pipeline: *Pipeline;
shadow_pipeline: *Pipeline;
sky_pipeline: *Pipeline;

default_texture: *Texture;

shadow_cascade_count :: 4; // SHADOW_CASCADE_COUNT in shared.hlsl
shadow_texture_array: *SDL_GPUTexture;
shadow_sampler: *SDL_GPUSampler;

mesh_depth_texture: *SDL_GPUTexture;
default_sampler: *SDL_GPUSampler;

MAX_INSTANCES :: 4096;
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
    shader_name: string;
    needed_textures: int;
}

Pipeline_Type :: enum {
    SHADOW;
    MESH;
}

create_pipeline :: (name: string, opts: Pipeline_Create_Options, type: Pipeline_Type) -> *Pipeline {
    filled_info: SDL_GPUGraphicsPipelineCreateInfo;

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

        filled_info.target_info.color_target_descriptions = colour_desc.data;
        filled_info.target_info.num_color_targets = xx opts.colour_target_count;
    }

    if opts.has_depth_target {
        filled_info.target_info.has_depth_stencil_target = true;
        filled_info.target_info.depth_stencil_format = .SDL_GPU_TEXTUREFORMAT_D24_UNORM;

        filled_info.depth_stencil_state.compare_op = .SDL_GPU_COMPAREOP_LESS;
        filled_info.depth_stencil_state.enable_depth_test = opts.enable_depth_test;
        filled_info.depth_stencil_state.enable_depth_write = opts.enable_depth_write;
    }

    filled_info.rasterizer_state.cull_mode = opts.cull_mode;
    filled_info.rasterizer_state.fill_mode = .SDL_GPU_FILLMODE_FILL;
    filled_info.rasterizer_state.front_face = .SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;

    buffers_desc: [] SDL_GPUVertexBufferDescription;
    attributes_desc: [] SDL_GPUVertexAttribute;

    if #complete type == {
        case .SHADOW;
            buffers_desc = push_view(renderer_arena, SDL_GPUVertexBufferDescription, 1);
            buffers_desc[0] = .{0, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            filled_info.vertex_input_state.vertex_buffer_descriptions = buffers_desc.data;
            filled_info.vertex_input_state.num_vertex_buffers = 1;

            attributes_desc = push_view(renderer_arena, SDL_GPUVertexAttribute, 1);
            attributes_desc[0] = .{0, 0, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
            filled_info.vertex_input_state.vertex_attributes = attributes_desc.data;
            filled_info.vertex_input_state.num_vertex_attributes = 1;
        case .MESH;
            buffers_desc = push_view(renderer_arena, SDL_GPUVertexBufferDescription, 5);
            buffers_desc[0] = .{0, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            buffers_desc[1] = .{1, size_of(Linear_Colour), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            buffers_desc[2] = .{2, size_of(Vec2), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            buffers_desc[3] = .{3, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            buffers_desc[4] = .{4, size_of(Vec3), .SDL_GPU_VERTEXINPUTRATE_VERTEX, 0};
            filled_info.vertex_input_state.vertex_buffer_descriptions = buffers_desc.data;
            filled_info.vertex_input_state.num_vertex_buffers = 5;

            attributes_desc = push_view(renderer_arena, SDL_GPUVertexAttribute, 5);
            attributes_desc[0] = .{0, 0, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
            attributes_desc[1] = .{1, 1, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, 0};
            attributes_desc[2] = .{2, 2, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, 0};
            attributes_desc[3] = .{3, 3, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
            attributes_desc[4] = .{4, 4, .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, 0};
            filled_info.vertex_input_state.vertex_attributes = attributes_desc.data;
            filled_info.vertex_input_state.num_vertex_attributes = 5;
    }

    shader := load_shader(opts.shader_name);
    filled_info.vertex_shader = shader.vertex;
    filled_info.fragment_shader = shader.fragment;

    filled := SDL_CreateGPUGraphicsPipeline(context.device, *filled_info);

    wireframe_info := filled_info;
    wireframe_info.rasterizer_state.fill_mode = .SDL_GPU_FILLMODE_LINE;
    wireframe := SDL_CreateGPUGraphicsPipeline(context.device, *wireframe_info);

    pipeline := bucket_array_add(*pipelines, .{});
    pipeline.name = name;
    pipeline.filled_info = filled_info;
    pipeline.wireframe_info = wireframe_info;
    pipeline.shader = shader;
    pipeline.filled = filled;
    pipeline.wireframe = wireframe;
    pipeline.needed_textures = opts.needed_textures;

    array_add(*shader.pipelines, pipeline);

    return pipeline;
}

calculate_light_space_matrix :: (sun: Directional_Light, camera: *Camera_Base, near_plane: float, far_plane: float) -> Mat4 {
    projection := mat4_projection(0.125, context.aspect_ratio, near_plane, far_plane);
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
    for corners {
        center += it.xyz;
    }
    center /= v3(8.0);

    light_view := mat4_look_at(center - sun.direction, center);

    right, top, far := -FLOAT32_MAX;
    left, bottom, near := FLOAT32_MAX;

    for corners {
        corner := (light_view * it).xyz;

        left = min(left, corner.x);
        right = max(right, corner.x);

        bottom = min(bottom, corner.y);
        top = max(top, corner.y);

        near = min(near, corner.z);
        far = max(far, corner.z);
    }

    texel_size := (right - left) / SHADOW_MAP_SIZE;
    light_center := (light_view * v4(center, 1)).xy;
    snapped_x := floor(light_center.x / texel_size) * texel_size;
    snapped_y := floor(light_center.y / texel_size) * texel_size;
    offset_x := snapped_x - light_center.x;
    offset_y := snapped_y - light_center.y;

    left += offset_x;
    right += offset_x;
    bottom += offset_y;
    top += offset_y;

    z_mult :: 25.0;
    if near < 0 near *= z_mult;
    else near /= z_mult;
    if far < 0 far /= z_mult;
    else far *= z_mult;

    light_projection := mat4_ortho(left, right, bottom, top, -near, -far);

    return light_projection * light_view;
}
