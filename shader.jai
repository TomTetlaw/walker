
Shader :: struct {
    next, prev: *Shader;

    name: string;
    vertex, fragment: *SDL_GPUShader;

    pipelines: Linked_List(Pipeline);
}

init_shader_system :: () {
    fallback_shader = load_shader("fallback");
    if !fallback_shader fatal_error("Failed to compile fallback shader");

    init(*shader_watcher, shader_hotload_callback, null, .MODIFIED);
    add_directories(*shader_watcher, "shaders");
}

check_shaders_modified :: () {
    process_changes(*shader_watcher);
}

load_shader :: (name: string) -> *Shader {
    shader: *Shader;

    for * shaders {
        if equal(name, it.name) {
            shader = it;
            break;
        }
    }

    if !shader {
        shader = bucket_array_add(*shaders, .{}, fallback_shader);
        shader.name = name;

        print("Tracking shader %\n", name);
    }

    recreate := false;
    if shader_needs_recompile(name) {
        recreate = true;
        ok := compile_shader(name);
        print("Compiled shader %\n", name);
        if !ok return fallback_shader;
    }

    compiled, ok := read_compiled_shader(name);
    if !ok return fallback_shader;

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

reload_shader :: (shader: *Shader) {
    SDL_ReleaseGPUShader(context.device, shader.vertex);
    SDL_ReleaseGPUShader(context.device, shader.fragment);
    shader.vertex = null;
    shader.fragment = null;

    reloaded := load_shader(shader.name);

    for * shader.pipelines {
        it.shader = reloaded;
        recreate_pipeline(it);
    }

    print("Hotloaded shader %\n", shader.name);
}

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

read_compiled_shader :: (name: string) -> Compiled_Shader, bool {
    path := tprint("shaders/%.compiled_shader", name);
    data, ok := read_entire_file(path,, temp);
    if !ok return .{}, false;

    compiled: Compiled_Shader;
    compiled.header = cast(*Shader_Header) data.data;
    compiled.vertex_spirv = data.data + size_of(Shader_Header);
    compiled.fragment_spirv = compiled.vertex_spirv + compiled.vertex_size;

    return compiled, true;
}

shader_needs_recompile :: (name: string) -> bool {
    compiled_path := tprint("shaders/%.compiled_shader", name);
    if !file_exists(compiled_path) return true;

    compiled_hash: u32;
    compiled := file_open(compiled_path);
    file_read(*compiled, *compiled_hash, size_of(u32));
    file_close(*compiled);

    path := tprint("shaders/%.shader", name);
    code, ok := read_entire_file(path,, temp);
    if !ok return false;

    if get_hash(code) == compiled_hash return false;

    return true;
}

compile_shader :: (name: string) -> bool {
    path := tprint("shaders/%.shader", name);
    source_code, ok := read_entire_file(path);
    if !ok return false;

    vert_info: SDL_ShaderCross_HLSL_Info;
    vert_info.source = tcs(source_code);
    vert_info.entrypoint = "vert_main";
    vert_info.shader_stage = .SDL_SHADERCROSS_SHADERSTAGE_VERTEX;
    vert_info.name = tcs(tprint("%_vertex", name));
    vert_info.include_dir = "shaders/";

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
    frag_info.include_dir = "shaders/";

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

    dest := tprint("shaders/%.compiled_shader", name);
    compiled_file := file_open(dest, true);
    file_write(*compiled_file, *compiled.header, size_of(Shader_Header));
    file_write(*compiled_file, vert, cast (int) vert_size);
    file_write(*compiled_file, frag, cast (int) frag_size);
    file_close(*compiled_file);

    return true;
}

shader_watcher: File_Watcher();

shader_hotload_callback :: (watcher: *File_Watcher(), change: *File_Change, user_data: *void) {
    path, base, ext := path_decomp(change.full_path);

    if !equal(ext, "shader") return;

    for * shaders {
        if equal(it.name, base) {
            reload_shader(it);
        }
    }
}