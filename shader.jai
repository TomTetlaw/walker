
Shader :: struct {
    next, prev: *Shader;

    using opts: Shader_Options;
    vertex, fragment: *SDL_GPUShader;

    pipelines: [..] *Pipeline;
}

init_shader_system :: () {
    fallback_shader = load_shader(.{"empty", "", shader_feature_flags_none});
    if !fallback_shader fatal_error("Failed to compile fallback shader");

    init(*shader_watcher, shader_hotload_callback, null, .MODIFIED);
    add_directories(*shader_watcher, "shaders");
}

check_shaders_modified :: () {
    process_changes(*shader_watcher);
}

Shader_Feature_Flags :: enum_flags u32 {
    RECIEVE_LIGHTING;
    RECIEVE_FOG;
}

shader_feature_flags_none :: cast(Shader_Feature_Flags) 0x00000000;
shader_feature_flags_all :: cast(Shader_Feature_Flags) 0xffffffff;
shader_feature_flags_static_mesh :: Shader_Feature_Flags.RECIEVE_LIGHTING | .RECIEVE_FOG;

Shader_Options :: struct {
    shader_name: string;
    material_name: string;
    feature_flags: Shader_Feature_Flags;
}

operator == :: (a: Shader_Options, b: Shader_Options) -> bool {
    return equal(a.shader_name, b.shader_name) &&
        equal(a.material_name, b.material_name) &&
        a.feature_flags == b.feature_flags;
}

load_shader :: (opts: Shader_Options, $force_recompile := true) -> *Shader {
    shader: *Shader;

    for * shaders {
        if opts == it.opts {
            shader = it;
            break;
        }
    }

    if !shader {
        shader = bucket_array_add(*shaders, .{}, fallback_shader);
        shader.opts = opts;
    }

    recreate := false;
    if force_recompile || shader_needs_recompile(opts) {
        ok := compile_shader(opts);

        if !ok {
            return fallback_shader;
        } else {
            recreate = true;
        }
    }

    compiled, ok := read_compiled_shader(opts);
    if !ok {
        return fallback_shader;
    }

    if recreate && shader.vertex {
        SDL_ReleaseGPUShader(context.device, shader.vertex);
        SDL_ReleaseGPUShader(context.device, shader.fragment);
        shader.vertex = null;
        shader.fragment = null;
    }

    if !shader.vertex || recreate {
        vert_info: SDL_GPUShaderCreateInfo;
        vert_info.num_samplers = compiled.vertex_meta.num_samplers;
        vert_info.num_storage_textures = compiled.vertex_meta.num_storage_textures;
        vert_info.num_storage_buffers = compiled.vertex_meta.num_storage_buffers;
        vert_info.num_uniform_buffers = compiled.vertex_meta.num_uniform_buffers;
        vert_info.code = compiled.vertex_spirv;
        vert_info.code_size = xx compiled.vertex_size;
        vert_info.format = SDL_GPU_SHADERFORMAT_SPIRV;
        vert_info.entrypoint = "vert_main";
        vert_info.stage = .VERTEX;

        frag_info: SDL_GPUShaderCreateInfo;
        frag_info.num_samplers = compiled.fragment_meta.num_samplers;
        frag_info.num_storage_textures = compiled.fragment_meta.num_storage_textures;
        frag_info.num_storage_buffers = compiled.fragment_meta.num_storage_buffers;
        frag_info.num_uniform_buffers = compiled.fragment_meta.num_uniform_buffers;
        frag_info.code = compiled.fragment_spirv;
        frag_info.code_size = xx compiled.fragment_size;
        frag_info.format = SDL_GPU_SHADERFORMAT_SPIRV;
        frag_info.entrypoint = "frag_main";
        frag_info.stage = .FRAGMENT;

        vert := SDL_CreateGPUShader(context.device, *vert_info);
        frag := SDL_CreateGPUShader(context.device, *frag_info);

        shader.vertex = vert;
        shader.fragment = frag;
    }

    return shader;
}

#scope_file

shaders: Bucket_Array(Shader);

fallback_shader: *Shader;

Shader_Header :: struct {
    hash: u32;
    vertex_size: int;
    fragment_size: int;
    vertex_meta: SDL_ShaderCross_GraphicsShaderMetadata;
    fragment_meta: SDL_ShaderCross_GraphicsShaderMetadata;
}

Compiled_Shader :: struct {
    using header: Shader_Header;

    vertex_spirv: *u8;
    fragment_spirv: *u8;
}

read_compiled_shader :: (opts: Shader_Options) -> Compiled_Shader, bool {
    path := get_compiled_shader_path(opts);
    data, ok := read_entire_file(path,, temp);
    if !ok return .{}, false;

    compiled: Compiled_Shader;
    compiled.header = cast(*Shader_Header) data.data;
    compiled.vertex_spirv = data.data + size_of(Shader_Header);
    compiled.fragment_spirv = compiled.vertex_spirv + compiled.vertex_size;

    return compiled, true;
}

shader_needs_recompile :: (opts: Shader_Options) -> bool {
    compiled_path := get_compiled_shader_path(opts);
    if !file_exists(compiled_path) return true;

    compiled_hash: u32;
    compiled := file_open(compiled_path);
    file_read(*compiled, *compiled_hash, size_of(u32));
    file_close(*compiled);

    path := get_shader_path(opts);
    code, ok := read_entire_file(path,, temp);
    if !ok return false;

    if get_hash(code) == compiled_hash return false;

    return true;
}

make_feature_flags_defines :: (flags: Shader_Feature_Flags) -> string {
    new_context := context;
    new_context.allocator = temp;
    push_context new_context {
        defines: [..] string;

        names := enum_names(Shader_Feature_Flags);
        values := enum_values_as_enum(Shader_Feature_Flags);

        for values {
            if flags & it {
                array_add(*defines, names[it_index]);
            }
        }

        builder: String_Builder;
        for names {
            defined := 0;
            if flags & values[it_index] {
                defined = 1;
            }

            print_to_builder(*builder, "#define % %\n", it, defined);
        }

        return builder_to_string(*builder);
    }
}

make_feature_flags_name_list :: (flags: Shader_Feature_Flags) -> [] string {
    new_context := context;
    new_context.allocator = temp;
    push_context new_context {
        features: [..] string;

        names := enum_names(Shader_Feature_Flags);
        values := enum_values_as_enum(Shader_Feature_Flags);

        for values {
            if flags & it {
                array_add(*features, names[it_index]);
            }
        }

        return features;
    }
}

get_source_code :: (opts: Shader_Options) -> string, bool {
    new_context := context;
    new_context.allocator = temp;
    push_context new_context {
        builder: String_Builder;

        defines := make_feature_flags_defines(opts.feature_flags);
        append(*builder, defines);

        shared_source, ok := read_entire_file("shaders/shared.hlsl");
        if ok {
            append(*builder, shared_source);
        }

        shader_path := get_shader_path(opts);
        shader_source:, ok = read_entire_file(shader_path);
        if ok {
            if opts.material_name.count > 0 {
                material_path := get_material_path(opts);
                material_source:, ok = read_entire_file(material_path);
                if ok {
                shader_source = replace(shader_source, "// INSERT_MATERIAL_HERE", material_source);
                }
            }

            append(*builder, shader_source);
        }

        full_source := builder_to_string(*builder);

        name := get_shader_name(opts);
        write_entire_file(tprint("shaders/%.debug_dump", name), full_source);

        return full_source, true;
    }
}

compile_shader :: (opts: Shader_Options) -> bool {
    source_code, ok := get_source_code(opts);
    if !ok return false;

    base_path :: "shaders/";

    name := get_shader_name(opts);

    vert_info: SDL_ShaderCross_HLSL_Info;
    vert_info.source = tcs(source_code);
    vert_info.entrypoint = "vert_main";
    vert_info.shader_stage = .SDL_SHADERCROSS_SHADERSTAGE_VERTEX;
    vert_info.name = tcs(tprint("%_vertex", name));
    vert_info.include_dir = tcs(base_path);

    vert_size: u64;
    vert_meta: SDL_ShaderCross_GraphicsShaderMetadata;
    vert := SDL_ShaderCross_CompileSPIRVFromHLSL(*vert_info, *vert_size);
    defer SDL_free(vert);

    if !vert_size {
        vert = null;
        return false;
    }

    SDL_ShaderCross_ReflectGraphicsSPIRV(vert, vert_size, *vert_meta);

    frag_info: SDL_ShaderCross_HLSL_Info;
    frag_info.source = tcs(source_code);
    frag_info.entrypoint = "frag_main";
    frag_info.shader_stage = .SDL_SHADERCROSS_SHADERSTAGE_FRAGMENT;
    frag_info.name = tcs(tprint("%_fragment", name));
    frag_info.include_dir = tcs(base_path);

    frag_size: u64;
    frag_meta: SDL_ShaderCross_GraphicsShaderMetadata;
    frag := SDL_ShaderCross_CompileSPIRVFromHLSL(*frag_info, *frag_size);
    defer SDL_free(frag);

    if !frag_size {
        frag = null;
        return false;
    }

    SDL_ShaderCross_ReflectGraphicsSPIRV(frag, frag_size, *frag_meta);

    compiled: Compiled_Shader;
    compiled.hash = get_hash(source_code);
    compiled.vertex_size = xx vert_size;
    compiled.fragment_size = xx frag_size;
    compiled.vertex_meta = vert_meta;
    compiled.fragment_meta = frag_meta;
    compiled.vertex_spirv = vert;
    compiled.fragment_spirv = frag;

    dest := get_compiled_shader_path(opts);
    compiled_file := file_open(dest, true);
    file_write(*compiled_file, *compiled.header, size_of(Shader_Header));
    file_write(*compiled_file, vert, cast (int) vert_size);
    file_write(*compiled_file, frag, cast (int) frag_size);
    file_close(*compiled_file);

    return true;
}

get_shader_name :: (opts: Shader_Options) -> string {
    flags := cast(u32) opts.feature_flags;
    return tprint("%_%_%", opts.shader_name, opts.material_name, flags);
}

get_compiled_shader_path :: (opts: Shader_Options) -> string {
    return tprint("shaders/%.compiled_shader", opts.shader_name);
}

get_material_path :: (opts: Shader_Options) -> string {
    return tprint("shaders/%.material", opts.material_name);
}

get_shader_path :: (opts: Shader_Options) -> string {
    return tprint("shaders/%.shader", opts.shader_name);
}

shader_watcher: File_Watcher();

reload_shader :: (shader: *Shader) {
    SDL_ReleaseGPUShader(context.device, shader.vertex);
    SDL_ReleaseGPUShader(context.device, shader.fragment);
    shader.vertex = null;
    shader.fragment = null;

    reloaded := load_shader(shader.opts, true);

    for shader.pipelines {
        it.shader = reloaded; // incase load_shader returns a stub
        recreate_pipeline(it);
    }

    features := make_feature_flags_name_list(shader.feature_flags);
    print("Hotloaded shader % % %\n", shader.shader_name, shader.material_name, features);
}

shader_hotload_callback :: (watcher: *File_Watcher(), change: *File_Change, user_data: *void) {
    path, base, ext := path_decomp(change.full_path);

    if equal(ext, "shader") || equal(ext, "material") || equal(ext, "hlsl") {
        for * shaders {
            reload_shader(it);
        }
    }
}
