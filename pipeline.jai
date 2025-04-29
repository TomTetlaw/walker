
Pipeline :: struct {
    next, prev: *Pipeline;
    sdl_pipeline: *SDL_GPUGraphicsPipeline;
    out_of_date := true;
    def: Pipeline_Definition;
}

create_pipeline_for_shader :: (shader: *Shader) -> *SDL_GPUGraphicsPipeline {
    key := hash_shader_metadata(shader.meta) % MAX_PIPELINES;
    pipeline := *pipelines[key];

    if pipeline.out_of_date {
        if pipeline.sdl_pipeline {
            SDL_ReleaseGPUGraphicsPipeline(context.device, pipeline.sdl_pipeline);
        }

        props := SDL_CreateProperties();
        SDL_SetStringProperty(props, SDL_PROP_GPU_GRAPHICSPIPELINE_CREATE_NAME_STRING,
            tcs(tprint("pipeline_%", shader.name)));

        def := make_pipeline_definition(shader.meta);
        create_info := make_pipeline_create_info(shader.meta, def);
        create_info.vertex_shader = shader.vertex;
        create_info.fragment_shader = shader.fragment;
        create_info.props = props;

        pipeline.sdl_pipeline = SDL_CreateGPUGraphicsPipeline(context.device, *create_info);
        pipeline.def = def;
    }

    return pipeline.sdl_pipeline;
}

invalidate_pipeline :: (shader: *Shader) {
    key := hash_shader_metadata(shader.meta) % MAX_PIPELINES;
    pipeline := *pipelines[key];
    pipeline.out_of_date = true;
}

init_pipeline_cache :: () {
    pipelines = push_view(*pipelines_arena, Pipeline, MAX_PIPELINES);
    pipelines_hash := push_view(*pipeline_arena, u32, MAX_PIPELINES);
}

#scope_file

MAX_PIPELINES :: 1024;
pipelines: [] Pipeline;
pipelines_arena: Arena;

pipeline_arena: Arena;

Pipeline_Definition :: struct {
    colour_write: bool;
    alpha_blend: bool;

    depth_write: bool;
    depth_test: bool;

    cull_mode: SDL_GPUCullMode;
    fill_mode: SDL_GPUFillMode;

    vertex_attributes: [] SDL_GPUVertexElementFormat;
}

hash_shader_metadata :: (meta: Shader_Metadata) -> u32 {
    hash := get_hash(meta.pipeline);
    hash = get_hash(meta.vertex_input, hash);
    hash = get_hash(meta.instance_buffer, hash);
    hash = get_hash(meta.texture_set, hash);
    return hash;
}

make_pipeline_definition :: (meta: Shader_Metadata) -> Pipeline_Definition {
    def: Pipeline_Definition;

    if meta.pipeline == .STATIC_MESH {
        def.colour_write = true;
        def.alpha_blend = true;
        def.depth_write = true;
        def.depth_test = true;
    } else if meta.pipeline == .FALLBACK {
        def.colour_write = true;
    }

    if equal(meta.vertex_input, "static_mesh") {
        def.vertex_attributes = tview(SDL_GPUVertexElementFormat.[
            .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
            .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
            .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
            .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
            .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3
        ]);
    } else if equal(meta.vertex_input, "position") {
        def.vertex_attributes = tview(SDL_GPUVertexElementFormat.[
            .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3
        ]);
    }

    return def;
}

make_pipeline_create_info :: (meta: Shader_Metadata, def: Pipeline_Definition) -> SDL_GPUGraphicsPipelineCreateInfo {
    info: SDL_GPUGraphicsPipelineCreateInfo;

    if def.colour_write {
        colour_desc := tview(SDL_GPUColorTargetDescription, 1);
        colour_desc[0].format = SDL_GetGPUSwapchainTextureFormat(context.device, context.window);

        if def.alpha_blend {
            colour_desc[0].blend_state.src_color_blendfactor = .SDL_GPU_BLENDFACTOR_SRC_ALPHA;
            colour_desc[0].blend_state.dst_color_blendfactor = .SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
            colour_desc[0].blend_state.color_blend_op = .SDL_GPU_BLENDOP_ADD;
            colour_desc[0].blend_state.src_alpha_blendfactor = .SDL_GPU_BLENDFACTOR_ONE;
            colour_desc[0].blend_state.dst_alpha_blendfactor = .SDL_GPU_BLENDFACTOR_ZERO;
            colour_desc[0].blend_state.alpha_blend_op = .SDL_GPU_BLENDOP_ADD;
            colour_desc[0].blend_state.enable_blend = true;
        }

        info.target_info.color_target_descriptions = colour_desc.data;
        info.target_info.num_color_targets = 1;
    }

    if def.depth_write {
        info.target_info.has_depth_stencil_target = true;
        info.target_info.depth_stencil_format = .SDL_GPU_TEXTUREFORMAT_D24_UNORM;
        info.depth_stencil_state.compare_op = .SDL_GPU_COMPAREOP_LESS;
        info.depth_stencil_state.enable_depth_test = def.depth_test;
        info.depth_stencil_state.enable_depth_write = true;
    }

    info.rasterizer_state.cull_mode = def.cull_mode;
    info.rasterizer_state.fill_mode = def.fill_mode;
    info.rasterizer_state.front_face = .SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;

    sdl_vertex_element_stride :: int.[
        size_of(float),
        size_of(float) * 2,
        size_of(float) * 3,
        size_of(float) * 4,
    ];

    element_count := def.vertex_attributes.count;
    buffers_desc := tview(SDL_GPUVertexBufferDescription, element_count);
    attributes_desc := tview(SDL_GPUVertexAttribute, element_count);
    for def.vertex_attributes {
        buffers_desc[it_index] = .{
            xx it_index,
            xx sdl_vertex_element_stride[it - .SDL_GPU_VERTEXELEMENTFORMAT_FLOAT],
            .SDL_GPU_VERTEXINPUTRATE_VERTEX,
            0
        };

        attributes_desc[it_index] = .{
            xx it_index,
            xx it_index,
            it,
            0
        };
    }

    info.vertex_input_state.vertex_buffer_descriptions = buffers_desc.data;
    info.vertex_input_state.num_vertex_buffers = xx element_count;

    info.vertex_input_state.vertex_attributes = attributes_desc.data;
    info.vertex_input_state.num_vertex_attributes = xx element_count;

    return info;
}