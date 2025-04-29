
Vertex_Input_Position :: struct @hlsl_struct @no_pad {
    position: V3; @semantic @POSITION
}

Vertex_Input_Position_Colour_Texcoord :: struct @hlsl_struct @no_pad {
    position: V3; @semantic @POSITION
    colour: V3; @semantic @TEXCOORD0
    tex_coord: V2; @semantic @TEXCOORD1
}

Vertex_Input_Static_Mesh :: struct @hlsl_struct @no_pad {
    position: V3; @semantic @POSITION
    colour: V3; @semantic @TEXCOORD0
    tex_coord: V2; @semantic @TEXCOORD1
    normal: V3; @semantic @TEXCOORD2
    tangent: V3; @semantic @TEXCOORD3
}

Instance_Buffer_Transform :: struct @hlsl_struct {
    transform: Mat4;
}

Instance_Buffer_Static_Mesh :: struct @hlsl_struct {
    transform: Mat4;
    colour: V4;
}

Constant_Buffer_View :: struct @hlsl_struct {
    view: Mat4;
    projection: Mat4;
}

Constant_Buffer_Camera :: struct @hlsl_struct {
    camera_position: V3;
    camera_forward: V3;
}

Texture_Set_Static_Mesh :: struct @hlsl_struct {
    diffuse: int; @texture
    normal: int; @texture
    rmaoh: int; @texture
}

Generated_Shader_Struct :: struct {
    name: string;
    members: string;
}

find_generated_struct_members :: (prefix: string, name: string) -> string {
    for generated_hlsl_structs {
        if equal_nocase(tprint("%_%", prefix, name), it.name) return it.members;
    }

    return "";
}

Render_Command :: struct {
    storage_buffers: [] *SDL_GPUBuffer;
    vertex_buffers: [] SDL_GPUBufferBinding;
    index_buffer: SDL_GPUBufferBinding;
    textures: [] SDL_GPUTextureSamplerBinding;
    index_count: int;
    instance_count: int;
    base_instance: int;
}

Render_Pass :: struct {
    pipeline: *SDL_GPUGraphicsPipeline;
    vertex_constants: Any;
    fragment_constants: Any;
    storage_buffers: [] *SDL_GPUBuffer;
    textures: [] SDL_GPUTextureSamplerBinding;
    colour_targets: [] SDL_GPUColorTargetInfo;
    depth_target: *SDL_GPUDepthStencilTargetInfo;
}

run_render_pass :: (command_buffer: *SDL_GPUCommandBuffer, pass: *Render_Pass, commands: [] Render_Command) {
    render_pass := SDL_BeginGPURenderPass(command_buffer, pass.colour_targets.data, xx pass.colour_targets.count, pass.depth_target);

    SDL_BindGPUGraphicsPipeline(render_pass, pass.pipeline);

    SDL_PushGPUVertexUniformData(command_buffer, 0, pass.vertex_constants.value_pointer, xx pass.vertex_constants.type.runtime_size);
    SDL_PushGPUFragmentUniformData(command_buffer, 0, pass.fragment_constants.value_pointer, xx pass.fragment_constants.type.runtime_size);

    for command: commands {
        textures := tarray(SDL_GPUTextureSamplerBinding, pass.textures.count + command.textures.count);
        for pass.textures array_add(*textures, it);
        for command.textures array_add(*textures, it);

        storage_buffers := tarray(*SDL_GPUBuffer, pass.storage_buffers.count + command.storage_buffers.count);
        for pass.storage_buffers array_add(*storage_buffers, it);
        for command.storage_buffers array_add(*storage_buffers, it);

        SDL_BindGPUVertexStorageBuffers(render_pass, 0, storage_buffers.data, xx storage_buffers.count);
        SDL_BindGPUVertexBuffers(render_pass, 0, command.vertex_buffers.data, xx command.vertex_buffers.count);
        SDL_BindGPUIndexBuffer(render_pass, *command.index_buffer, .SDL_GPU_INDEXELEMENTSIZE_32BIT);
        SDL_BindGPUFragmentSamplers(render_pass, 0, textures.data, xx textures.count);
        SDL_DrawGPUIndexedPrimitives(render_pass, xx command.index_count, xx command.instance_count, 0, 0, xx command.base_instance);
    }

    SDL_EndGPURenderPass(render_pass);
}