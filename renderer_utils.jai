
create_transfer_buffer :: (size: int, upload := true) -> *SDL_GPUTransferBuffer {
    info: SDL_GPUTransferBufferCreateInfo;
    info.usage = ifx upload then .UPLOAD else .DOWNLOAD;
    info.size = xx size;
    return SDL_CreateGPUTransferBuffer(context.device, *info);
}

Buffer_Usage :: enum {
    VERTEX;
    INDEX;
    INDIRECT;
    GRAPHICS_STORAGE_READ;
    COMPUTE_STORAGE_READ;
    COMPUTE_STORAGE_WRITE;
}

create_buffer :: (name: string, capacity: int, usage: Buffer_Usage) -> *SDL_GPUBuffer {
    sdl_buffer_usage := SDL_GPUBufferUsageFlags.[
        SDL_GPU_BUFFERUSAGE_VERTEX,
        SDL_GPU_BUFFERUSAGE_INDEX,
        SDL_GPU_BUFFERUSAGE_INDIRECT,
        SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
        SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_READ,
        SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
    ];

    info: SDL_GPUBufferCreateInfo;
    info.usage = sdl_buffer_usage[usage];
    info.size = xx capacity;
    buffer := SDL_CreateGPUBuffer(context.device, *info);

    SDL_SetGPUBufferName(context.device, buffer, tcs(name));

    return buffer;
}

create_buffer :: (name: string, data: *void, size: int, usage: Buffer_Usage) -> *SDL_GPUBuffer {
    buffer := create_buffer(name, size, usage);
    queue_buffer_upload(data, size, buffer);
    return buffer;
}

create_vertex_buffer :: (name: string, data: [] $T) -> *SDL_GPUBuffer {
    buffer := create_buffer(name, data.data, size_of(T) * data.count, .VERTEX);
    queue_buffer_upload(data.data, size_of(T) * data.count, buffer);
    return buffer;
}

create_index_buffer :: (name: string, data: [] u32) -> *SDL_GPUBuffer {
    buffer := create_buffer(name, data.data, size_of(u32) * data.count, .INDEX);
    queue_buffer_upload(data.data, size_of(u32) * data.count, buffer);
    return buffer;
}

Texture_Format :: enum {
    R8_UNORM;
    RGBA32_UNORM;

    D24;
    D32;
}

mip_count :: (width: int, height: int) -> int {
    levels := 1;

    while width > 1 || height > 1 {
        width = ifx width > 1 then width/2 else 1;
        height = ifx height > 1 then height/2 else 1;
        levels += 1;
    }

    return levels;
}

create_texture :: (width: int, height: int, format: Texture_Format, layers := 1, needs_mipmaps := true) -> *SDL_GPUTexture {
    sdl_texture_format := SDL_GPUTextureFormat.[
        .R8_UNORM, .R8G8B8A8_UNORM, .D24_UNORM, .D32_FLOAT
    ];

    info: SDL_GPUTextureCreateInfo;
    info.type = .SDL_GPU_TEXTURETYPE_2D;
    info.format = sdl_texture_format[format];
    info.width = xx width;
    info.height = xx height;
    info.layer_count_or_depth = xx layers;
    info.num_levels = xx (ifx needs_mipmaps then mip_count(width, height) else 1);
    info.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER;

    if format == .D24 || format == .D32 {
        info.usage |= SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET;
    }

    return SDL_CreateGPUTexture(context.device, *info);
}

create_texture :: (data: *void, width: int, height: int, format: Texture_Format, layers := 1, needs_mipmaps := true) -> *SDL_GPUTexture {
    texture := create_texture(width, height, format, layers, needs_mipmaps);

    stride := 1;
    if format == {
        case .R8_UNORM; stride = 1;
        case .RGBA32_UNORM; stride = 4;
        case; assert(false);
    }

    queue_texture_upload(data, width, height, stride, texture, 0, needs_mipmaps);

    return texture;
}

queue_buffer_upload :: (data: *void, size: int, dest: *SDL_GPUBuffer, offset := 0) {
    using transfer_queue;

    upload: GPU_Upload;
    upload.type = .BUFFER;
    upload.data = data;
    upload.size = size;
    upload.buffer_dest = dest;
    upload.offset = offset;
    array_add(*queue, upload);

    total_queued_size += size;
}

queue_texture_upload :: (data: *void, width: int, height: int, stride: int, dest: *SDL_GPUTexture, offset := 0, needs_mipmaps := true) {
    using transfer_queue;

    upload: GPU_Upload;
    upload.type = .TEXTURE;
    upload.data = data;
    upload.texture_dest = dest;
    upload.size = width * height * stride;
    upload.width = width;
    upload.height = height;
    upload.stride = stride;
    upload.needs_mipmaps = needs_mipmaps;
    array_add(*queue, upload);

    total_queued_size += width * height * stride;
}

upload_queued_data :: (command_buffer: *SDL_GPUCommandBuffer) {
    using transfer_queue;

    if !transfer_buffer || total_queued_size > buffer_size {
        if transfer_buffer SDL_ReleaseGPUTransferBuffer(context.device, transfer_buffer);

        info: SDL_GPUTransferBufferCreateInfo;
        info.usage = .UPLOAD;
        info.size = xx total_queued_size;

        transfer_buffer = SDL_CreateGPUTransferBuffer(context.device, *info);
        buffer_size = total_queued_size;
    }

    mapping := SDL_MapGPUTransferBuffer(context.device, transfer_buffer, false);

    cursor := 0;
    for queue {
        memcpy(mapping + cursor, it.data, it.size);
    }

    SDL_UnmapGPUTransferBuffer(context.device, transfer_buffer);

    pass := SDL_BeginGPUCopyPass(command_buffer);

    cursor = 0;
    for queue {
        if it.type == {
            case .BUFFER;
            source: SDL_GPUTransferBufferLocation;
            source.transfer_buffer = transfer_buffer;
            source.offset = xx cursor;

            dest: SDL_GPUBufferRegion;
            dest.buffer = it.buffer_dest;
            dest.offset = xx it.offset;
            dest.size = xx it.size;

            SDL_UploadToGPUBuffer(pass, *source, *dest, false);

            case .TEXTURE;
            source: SDL_GPUTextureTransferInfo;
            source.transfer_buffer = transfer_buffer;
            source.offset = xx cursor;
            source.pixels_per_row = xx it.width;
            source.rows_per_layer = xx it.height;

            dest: SDL_GPUTextureRegion;
            dest.texture = it.texture_dest;
            dest.w = xx it.width;
            dest.h = xx it.height;

            SDL_UploadToGPUTexture(pass, *source, *dest, false);
        }
    }

    SDL_EndGPUCopyPass(pass);

    for queue {
        if it.type == .TEXTURE && it.needs_mipmaps {
            SDL_GenerateMipmapsForGPUTexture(command_buffer, it.texture_dest);
        }
    }

    total_queued_size = 0;
    queue.count = 0;
}

#scope_file

init_transfer_queue :: () {
    using transfer_queue;

    queue.allocator = make_arena_allocator(*arena);
}

transfer_queue: Transfer_Queue;

Transfer_Queue :: struct {
    arena: Arena;
    queue: [..] GPU_Upload;
    transfer_buffer: *SDL_GPUTransferBuffer;
    buffer_size: int;

    total_queued_size: int;
}

Upload_Type :: enum {
    BUFFER;
    TEXTURE;
}

GPU_Upload :: struct {
    type: Upload_Type;

    data: *void;
    size: int;

    buffer_dest: *SDL_GPUBuffer;
    offset: int;

    texture_dest: *SDL_GPUTexture;
    width, height, stride: int;

    needs_mipmaps: bool;
}