
create_storage_buffer :: (name: string, size: int) -> *SDL_GPUBuffer {
    info := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
        size = xx size
    };

    buffer := SDL_CreateGPUBuffer(context.device, *info);
    if !buffer {
        report_sdl_error("SDL_CreateGPUBuffer", tprint("%.storage", name));
    }

    SDL_SetGPUBufferName(context.device, buffer, tcs(name));

    return buffer;
}

create_vertex_buffer :: (name: string, elements: [] $T) -> *SDL_GPUBuffer {
    info := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_VERTEX,
        size = xx (size_of(T) * elements.count)
    };

    buffer := SDL_CreateGPUBuffer(context.device, *info);
    if !buffer {
        report_sdl_error("SDL_CreateGPUBuffer", tprint("%.vertex", name));
    }

    SDL_SetGPUBufferName(context.device, buffer, tcs(name));

    upload_to_buffer(buffer, elements);

    return buffer;
}

create_index_buffer :: (name: string, elements: [] u32) -> *SDL_GPUBuffer {
    info := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_INDEX,
        size = xx (size_of(u32) * elements.count)
    };

    buffer := SDL_CreateGPUBuffer(context.device, *info);
    if !buffer {
        report_sdl_error("SDL_CreateGPUBuffer", tprint("%.index", name));
    }

    SDL_SetGPUBufferName(context.device, buffer, tcs(name));

    upload_to_buffer(buffer, elements);

    return buffer;
}

upload_to_buffer :: (dest: *SDL_GPUBuffer, elements: [] $T) {
    size := size_of(T) * elements.count;
    transfer_buffer := create_transfer_buffer(size);
    mapping := SDL_MapGPUTransferBuffer(context.device, transfer_buffer, false);
    if !mapping {
        report_sdl_error("SDL_MapGPUTransferBuffer", "upload_to_buffer");
    }

    memcpy(mapping, elements.data, size);
    SDL_UnmapGPUTransferBuffer(context.device, transfer_buffer);

    command_buffer := SDL_AcquireGPUCommandBuffer(context.device);
    if !command_buffer {
        report_sdl_error("SDL_AcquireGPUCommandBuffer", "upload_to_buffer");
    }

    copy_pass := SDL_BeginGPUCopyPass(command_buffer);
    if !copy_pass {
        report_sdl_error("SDL_BeginGPUCopyPass", "upload_to_buffer");
    }

    location: SDL_GPUTransferBufferLocation;
    location.transfer_buffer = transfer_buffer;
    location.offset = 0;

    region: SDL_GPUBufferRegion;
    region.buffer = dest;
    region.size = xx size;
    region.offset = 0;

    SDL_UploadToGPUBuffer(copy_pass, *location, *region, false);

    SDL_EndGPUCopyPass(copy_pass);
    SDL_SubmitGPUCommandBuffer(command_buffer);
    SDL_ReleaseGPUTransferBuffer(context.device, transfer_buffer);
}

create_transfer_buffer :: (size: int) -> *SDL_GPUTransferBuffer {
    create_info: SDL_GPUTransferBufferCreateInfo;
    create_info.usage = .SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
    create_info.size = xx size;
    transfer_buffer := SDL_CreateGPUTransferBuffer(context.device, *create_info);
    return transfer_buffer;
}

create_texture_object :: (name: string, width: int, height: int, format: Texture_Format) -> *SDL_GPUTexture {
    create_info: SDL_GPUTextureCreateInfo;
    create_info.type = .SDL_GPU_TEXTURETYPE_2D;
    create_info.format = sdl_texture_format[format];
    create_info.width = xx width;
    create_info.height = xx height;
    create_info.layer_count_or_depth = 1;
    create_info.num_levels = xx get_mipmap_count(width, height);
    create_info.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
    texture_object := SDL_CreateGPUTexture(context.device, *create_info);
    if !texture_object {
        report_sdl_error("SDL_CreateGPUTexture", "texture_object");
    }

    SDL_SetGPUTextureName(context.device, texture_object, tcs(name));
    return texture_object;
}

upload_texture :: (dest: *SDL_GPUTexture, pixels: *u8, width: int, height: int, format: Texture_Format) {
    size := width * height * texture_pixel_size[format];
    transfer_buffer := create_transfer_buffer(size);

    mapping := SDL_MapGPUTransferBuffer(context.device, transfer_buffer, false);
    if !mapping {
        report_sdl_error("SDL_MapGPUTransferBuffer", "upload_texture");
    }

    memcpy(mapping, pixels, size);
    SDL_UnmapGPUTransferBuffer(context.device, transfer_buffer);

    info: SDL_GPUTextureTransferInfo;
    info.transfer_buffer = transfer_buffer;
    info.offset = 0;
    info.pixels_per_row = xx width;
    info.rows_per_layer = xx height;

    region: SDL_GPUTextureRegion;
    region.texture = dest;
    region.w = xx width;
    region.h = xx height;
    region.d = 1;

    command_buffer := SDL_AcquireGPUCommandBuffer(context.device);
    if !command_buffer {
        report_sdl_error("SDL_AcquireGPUCommandBuffer", "upload_texture");
    }

    copy_pass := SDL_BeginGPUCopyPass(command_buffer);
    if !copy_pass {
        report_sdl_error("SDL_BeginGPUCopyPass", "upload_texture");
    }

    SDL_UploadToGPUTexture(copy_pass, *info, *region, false);
    SDL_EndGPUCopyPass(copy_pass);

    if get_mipmap_count(width, height) > 1 {
        SDL_GenerateMipmapsForGPUTexture(command_buffer, dest);
    }

    SDL_SubmitGPUCommandBuffer(command_buffer);
    SDL_ReleaseGPUTransferBuffer(context.device, transfer_buffer);
}