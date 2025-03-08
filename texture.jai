
 Texture_Format :: enum {
    R8_UNORM;
    RGBA8_UNORM;
}

Texture :: struct {
    next, prev: *Texture;

    name: string;
    width, height: int;
    format: Texture_Format;
    texture_object: *SDL_GPUTexture;
}

load_texture :: (name: string, format := Texture_Format.RGBA8_UNORM) -> *Texture {
    texture: *Texture;

    for * textures {
        if equal(it.name, name) {
            if it.texture_object {
                return it;
            } else {
                texture = it;
                break;
            }
        }
    }

    if !texture || !texture.texture_object {
        path := tprint("textures/%.png", name);

        width, height, channels: s32;
        pixels := stbi_load(tcs(path), *width, *height, *channels, xx texture_pixel_size[format]);
        if !pixels return fallback_texture;

        texture_object := create_texture_object(name, width, height, format);
        if !texture_object return fallback_texture;

        upload_texture(texture_object, pixels, width, height, format);

        if !texture {
            texture = bucket_array_add(*textures, .{}, fallback_texture);
        }

        texture.name = copy_string_global(name);
        texture.width = width;
        texture.height = height;
        texture.format = format;
        texture.texture_object = texture_object;
    }

    return texture;
}

Texture_Data :: struct {
    pixels: [] u8;
    width: int;
    height: int;
    format := Texture_Format.RGBA8_UNORM;
}

create_texture :: (name: string, data: Texture_Data) -> *Texture {
    texture_object := create_texture_object(name, data.width, data.height, data.format);
    if !texture_object return fallback_texture;

    upload_texture(texture_object, data.pixels.data, data.width, data.height, data.format);

    texture: Texture;
    texture.name = copy_string_global(name);
    texture.width = data.width;
    texture.height = data.height;
    texture.format = data.format;
    texture.texture_object = texture_object;

    return bucket_array_add(*textures, texture, fallback_texture);
}

get_mipmap_count :: (width: int, height: int) -> int {
    max_dimension := max(width, height);
    return cast(int) log(cast(float) max_dimension) + 1;
}

init_texture_system :: () {
    pixels := u8.[0, 0, 0, 0];
    fallback_texture = create_texture("fallback", .{pixels, 1, 1, .RGBA8_UNORM});
    if !fallback_texture fatal_error("Failed to create fallback texture");

    init(*texture_watcher, texture_hotload_callback, null, .MODIFIED);
    add_directories(*texture_watcher, "textures");
}

sdl_texture_format := SDL_GPUTextureFormat.[
                                            .SDL_GPU_TEXTUREFORMAT_R8_UNORM,
                                            .SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
                                            ];

texture_pixel_size := int.[1, 4];

set_pixel :: (pixels: [] u8, x: int, y: int, width: int, r: u8, g: u8, b: u8, a: u8 = 255) {
    pixels[4 * (x+y*width) + 0] = r;
    pixels[4 * (x+y*width) + 1] = g;
    pixels[4 * (x+y*width) + 2] = b;
    pixels[4 * (x+y*width) + 3] = a;
}

fallback_texture: *Texture;

#scope_file

texture_watcher: File_Watcher();

textures: Bucket_Array(Texture);

reload_texture :: (texture: *Texture) {
    SDL_ReleaseGPUTexture(context.device, texture.texture_object);
    texture.texture_object = null;

    load_texture(texture.name, texture.format);
}

texture_hotload_callback :: (watcher: *File_Watcher(), change: *File_Change, user_data: *void) {
    path, base, ext := path_decomp(change.full_path);
    if !equal(ext, "png") return;

    texture: *Texture;

    for * textures {
        if equal(it.name, base) {
            texture = it;
            break;
        }
    }

    if !texture return;

    reload_texture(texture);
}