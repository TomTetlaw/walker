
SHADERS_DIRECTORY :: "shaders";
SHADERS_DEBUG_DUMP_DIRECTORY :: "shaders/debug_dumps";

Pipeline_Id :: enum {
    FALLBACK;
    STATIC_MESH;
}

Shader_Metadata :: struct {
    pipeline := Pipeline_Id.FALLBACK;
    vertex_input := "position";
    instance_buffer := "transform";
    vert_constants := "view";
    frag_constants := "camera";
    texture_set := "";
}

Shader :: struct {
    next, prev: *Shader;

    name: string;
    id: int;

    meta: Shader_Metadata;

    vertex: *SDL_GPUShader;
    fragment: *SDL_GPUShader;

    pipeline: *SDL_GPUGraphicsPipeline;
}

load_shader :: (name: string, vert_entry_point := "vert_main", frag_entry_point := "frag_main") -> *Shader {
    for * shaders {
        if equal(name, it.name) return it;
    }

    data := read_entire_file(tprint("%/%.shader", SHADERS_DIRECTORY, name));
    meta, code := parse_shader(name, data);

    builder: String_Builder;
    append(*builder, generate_hlsl_inputs(meta));
    append(*builder, "#include \"shared.hlsl\"\n");
    append(*builder, code);
    code = builder_to_string(*builder);

    write_entire_file(tprint("%/%.txt", SHADERS_DEBUG_DUMP_DIRECTORY, name), code);

    vertex := create_sdl_shader(name, code, .VERTEX, vert_entry_point);
    fragment := create_sdl_shader(name, code, .FRAGMENT, frag_entry_point);

    if !vertex || !fragment {
        return fallback_shader;
    }

    shader: Shader;
    shader.name = name;
    shader.meta = meta;
    shader.id = get_hash(name);
    shader.vertex = vertex;
    shader.fragment = fragment;
    shader.pipeline = create_pipeline_for_shader(*shader);

    result := push_struct(*shaders_arena, shader);
    linked_list_add(*shaders, result);
    return result;
}

parse_shader :: (name: string, data: string) -> Shader_Metadata, string {
    handler: Text_File_Handler;

    start_from_memory(*handler, name, name, data);
    if handler.failed {
        return .{}, "";
    }

    meta: Shader_Metadata;
    if handler.version == 1 {
        while true {
            line, found := consume_next_line(*handler);
            if !found {
                print("Failed to find end_shader_metadata in shader % metadata!", name);
                break;
            }

            key, rhs := break_by_spaces(line);
            if !key || equal(key, "end_shader_metadata") {
                break;
            }

            value := break_by_spaces(rhs);

            if equal(key, "pipeline_name") {
                id, found := enum_find_name(Pipeline_Id, value);
                if found meta.pipeline = id;
                else print("Unknown pipeline_name % in shader % metadata!", value, name);
            } else if equal(key, "vertex_input") {
                meta.vertex_input = value;
            } else if equal(key, "instance_buffer") {
                meta.instance_buffer = value;
            } else if equal(key, "texture_set") {
                meta.texture_set = value;
            } else if equal(key, "vert_constants") {
                meta.vert_constants = value;
            } else if equal(key, "frag_constants") {
                meta.frag_constants = value;
            } else {
                print("Unknown metadata key in shader %: %!", name, key);
            }
        }
    }

    return meta, handler.file_data;
}

init_shader_system :: () {
    fallback_code :: #string HERE
        cbuffer Constant_Buffer : register(b0, space1) {
	       float4x4 view;
	       float4x4 projection;
        };

        struct Instance_Data {
	       float4x4 transform;
	    };

        StructuredBuffer<Instance_Data> instance_buffer: register(t0, space0);

        float4 vert_main(float3 position: POSITION, int instance_id: SV_InstanceID): SV_Position {
        	Instance_Data instance = instance_buffer[instance_id];
        	float4x4 local_to_clip = mul(instance.transform, mul(view, projection));
            return mul(float4(position, 1), local_to_clip);
        }

        float4 frag_main(): SV_Target {
            return float4(1, 0, 0, 1);
        }
    HERE;

    fallback_vertex := create_sdl_shader("fallback", fallback_code, .VERTEX, "vert_main");
    fallback_fragment := create_sdl_shader("fallback", fallback_code, .FRAGMENT, "frag_main");

    fallback_shader = push_struct(*shaders_arena, Shader);
    fallback_shader.name = "fallback";
    fallback_shader.meta = .{};
    fallback_shader.id = get_hash(fallback_shader.name);
    fallback_shader.vertex = fallback_vertex;
    fallback_shader.fragment = fallback_fragment;
    fallback_shader.pipeline = create_pipeline_for_shader(fallback_shader);
}

#scope_file

fallback_shader: *Shader;

shaders: Linked_List(Shader);
shaders_arena: Arena;

Shader_Stage :: enum {
    VERTEX;
    FRAGMENT;
}

create_sdl_shader :: (name: string, code: string, stage: Shader_Stage, entry_point: string) -> *SDL_GPUShader {
    sdl_shadercross_stage :: SDL_ShaderCross_ShaderStage.[
        .SDL_SHADERCROSS_SHADERSTAGE_VERTEX,
        .SDL_SHADERCROSS_SHADERSTAGE_FRAGMENT
    ];

    sdl_shader_stage :: SDL_GPUShaderStage.[
        .SDL_GPU_SHADERSTAGE_VERTEX,
        .SDL_GPU_SHADERSTAGE_FRAGMENT
    ];

    shader_name := tcs(tprint("%_%", name, string.["vertex", "fragment"][stage]));

    compile_info: SDL_ShaderCross_HLSL_Info;
    compile_info.source = tcs(code);
    compile_info.entrypoint = tcs(entry_point);
    compile_info.shader_stage = sdl_shadercross_stage[stage];
    compile_info.name = shader_name;
    compile_info.include_dir = "shaders/";

    spirv_size: u64;
    meta: SDL_ShaderCross_GraphicsShaderMetadata;
    spirv := SDL_ShaderCross_CompileSPIRVFromHLSL(*compile_info, *spirv_size);
    if spirv_size > 0 {
        SDL_ShaderCross_ReflectGraphicsSPIRV(spirv, spirv_size, *meta);

        props := SDL_CreateProperties();
        SDL_SetStringProperty(props, SDL_PROP_GPU_SHADER_CREATE_NAME_STRING, shader_name);

        create_info: SDL_GPUShaderCreateInfo;
        create_info.code_size = spirv_size;
        create_info.code = spirv;
        create_info.entrypoint = tcs(entry_point);
        create_info.format = SDL_GPU_SHADERFORMAT_SPIRV;
        create_info.stage = sdl_shader_stage[stage];
        create_info.num_samplers = meta.num_samplers;
        create_info.num_storage_textures = meta.num_storage_textures;
        create_info.num_storage_buffers = meta.num_storage_buffers;
        create_info.num_uniform_buffers = meta.num_uniform_buffers;
        create_info.props = props;

        shader := SDL_CreateGPUShader(context.device, *create_info);
        SDL_free(spirv);
        return shader;
    }

    return null;
}

generate_hlsl_inputs :: (meta: Shader_Metadata) -> string {
    builder: String_Builder;

    append(*builder, "struct Vertex_Input {\n");
    append(*builder, find_generated_struct_members("Vertex_Input", meta.vertex_input));
    append(*builder, "};\n");

    if meta.instance_buffer {
        append(*builder, "struct Instance_Data {\n");
        append(*builder, find_generated_struct_members("Instance_Buffer", meta.instance_buffer));
        append(*builder, "};\n");
        append(*builder, "StructuredBuffer<Instance_Data> instance_buffer: register(t0, space0);\n");
    }

    if meta.vert_constants {
        append(*builder, "cbuffer Constant_Buffer : register(b0, space1) {\n");
        append(*builder, find_generated_struct_members("Constant_Buffer", meta.vert_constants));
        append(*builder, "};\n");
    }

    if meta.frag_constants {
        append(*builder, "cbuffer Constant_Buffer : register(b0, space3) {\n");
        append(*builder, find_generated_struct_members("Constant_Buffer", meta.frag_constants));
        append(*builder, "};\n");
    }

    if meta.texture_set {
        append(*builder, find_generated_struct_members("Texture_Set", meta.texture_set));
    }

    return builder_to_string(*builder);
}