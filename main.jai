
#add_context aspect_ratio: float;

game_paused: bool;
game_delta: float;
game_time: float;
real_delta: float;
real_time: float;
frame_num: int;

screen_width :: 320.0;
screen_height :: 240.0;

screen_size :: V2.{screen_width, screen_height};
display_size: V2i;

enable_psx := true;
enable_fog := true;

Entity :: struct {
    position := #run v3(0.0);

    mesh: Model;
    scale := 1.0;

    albedo: Texture2D;
    texture_scale := 1.0;

    shader: Shader;
}

Sound_Player :: struct {
    sounds: [] Sound;
    played: [] bool;
    current: int;
    paused: bool;
}

make_sound_player :: (arena: *Arena, dir: string) -> *Sound_Player {
    files := file_list(dir);

    player := push_struct(arena, Sound_Player);
    using player;

    sounds = push_view(arena, Sound, files.count);
    played = push_view(arena, bool, files.count);

    for files {
        sounds[it_index] = LoadSound(tcs(it));
    }

    return player;
}

sound_player_set_paused :: (player: *Sound_Player, paused: bool) {
    if player.paused != paused {
        if paused {
            PauseSound(player.sounds[player.current]);
        } else {
            ResumeSound(player.sounds[player.current]);
        }

        player.paused = paused;
    }
}

update_sound_player :: (using player: *Sound_Player) {
    if !paused {
        if !IsSoundPlaying(sounds[current]) {
            choices := tarray(u64, sounds.count);

            for played {
                if it continue;
                array_add(*choices, cast(u64) it_index);
            }

            choice: u64 = 0;

            if choices.count == 0 {
                for * played {
                    it.* = false;
                }

                choice = random_get() % cast(u64) sounds.count;
            } else {
                choice = choices[random_get() % cast(u64) choices.count];
            }

            current = xx choice;
            played[choice] = true;
            sound := sounds[choice];
            SetSoundVolume(sound, 0.5 + random_get_zero_to_one() * 0.5);
            SetSoundPitch(sound, 0.8 + random_get_zero_to_one() * 0.2);
            PlaySound(sound);
        }
    }
}

draw_entity :: (using entity: Entity, camera: Camera_Base) {
    SetShaderValue(shader, GetShaderLocation(shader, "screen_size"), *screen_size, cast(s32) ShaderUniformDataType.VEC2);

    psx := ifx enable_psx then 1.0 else 0.0;
    fog := ifx enable_fog then 1.0 else 0.0;
    SetShaderValue(shader, GetShaderLocation(shader, "enable_psx"), *psx, cast(s32) ShaderUniformDataType.FLOAT);
    SetShaderValue(shader, GetShaderLocation(shader, "enable_fog"), *fog, cast(s32) ShaderUniformDataType.FLOAT);

    SetShaderValue(shader, GetShaderLocation(shader, "texture_scale"), *texture_scale, cast(s32) ShaderUniformDataType.FLOAT);

    view_to_clip := camera.projection;
    SetShaderValueMatrix(shader, GetShaderLocation(shader, "view_to_clip"), cast(*Matrix) *view_to_clip);

    world_to_view := camera.view;
    SetShaderValueMatrix(shader, GetShaderLocation(shader, "world_to_view"), cast(*Matrix) *world_to_view);

    local_to_world := mat4_translation(position) * mat4_scale(v3(scale));
    SetShaderValueMatrix(shader, GetShaderLocation(shader, "local_to_world"), cast(*Matrix) *local_to_world);

    DrawModel(mesh, shader, albedo);
}

draw_fullscreen_pass :: (source: Texture, dest: RenderTexture, shader: Shader, clear: bool) {
    source_rect := Rectangle.{0, 0, xx source.width, xx source.height};
    dest_rect := Rectangle.{0, 0, xx dest.texture.width, xx dest.texture.height};

    ortho := mat4_orthographic(0, dest_rect.width, dest_rect.height, 0, 0, 1);
    SetShaderValueMatrix(shader, GetShaderLocation(shader, "ortho"), cast(*Matrix) *ortho);

    BeginTextureMode(dest);
        BeginShaderMode(shader);
            if clear ClearBackground(.{0, 0, 0, 0});
            DrawTexturePro(source, source_rect, dest_rect, .{0, 0}, 0.0, .{1, 1, 1, 1});
        EndShaderMode();
    EndTextureMode();
}

debug_string_position := V2i.{10, 10};

draw_debug_string :: (s: string, colour := Color.{1, 1, 1, 1}) {
    DrawText(tcs(s), debug_string_position.x, debug_string_position.y, 32, colour);
    debug_string_position.y += 32;
}

set_shader_texture :: (shader: Shader, texture: Texture, $name: string, slot: int) {
    rlActiveTextureSlot(xx slot);
    rlEnableTexture(texture.id);

    _slot: s32 = xx slot;
    rlSetUniform(rlGetLocationUniform(shader.id, name), *_slot, cast(s32) ShaderUniformDataType.INT, 1);
}

blur_buffer_0, blur_buffer_1: RenderTexture;
blur_shader, passthrough_shader: Shader;
draw_blur_pass :: (source: Texture, dest: RenderTexture, radius: float) {
    resolution := V2.{xx dest.texture.width, xx dest.texture.height};
    SetShaderValue(blur_shader, GetShaderLocation(blur_shader, "resolution"), *resolution, cast(s32) ShaderUniformDataType.VEC2);
    SetShaderValue(blur_shader, GetShaderLocation(blur_shader, "radius"), *radius, cast(s32) ShaderUniformDataType.FLOAT);

    set_shader_texture(blur_shader, source, "texture0", 0);

    dir := V2.{1, 0};
    SetShaderValue(blur_shader, GetShaderLocation(blur_shader, "dir"), *dir, cast(s32) ShaderUniformDataType.VEC2);
    draw_fullscreen_pass(source, blur_buffer_0, blur_shader, false);

    dir = V2.{0, 1};
    SetShaderValue(blur_shader, GetShaderLocation(blur_shader, "dir"), *dir, cast(s32) ShaderUniformDataType.VEC2);
    draw_fullscreen_pass(blur_buffer_0.texture, blur_buffer_1, blur_shader, false);

    draw_fullscreen_pass(blur_buffer_1.texture, dest, passthrough_shader, false);
}

main :: () {
    // SetConfigFlags(.FLAG_BORDERLESS_WINDOWED_MODE);

    SetTraceLogLevel(cast(s32) TraceLogLevel.WARNING);

    dev_width := 1920 * .8;
    dev_height := 1080 * .8;
    InitWindow(xx dev_width, xx dev_height, "Walker");

    // ToggleBorderlessWindowed();
    // ToggleBorderlessWindowed();

    display_height := GetScreenHeight();
    display_width := (4.0 / 3.0) * display_height;
    display_size = .{xx display_width, xx display_height};
    margin := (GetScreenWidth() - display_width) * .5;

    context.aspect_ratio = cast(float) display_width / display_height;

    DisableCursor();
    SetTargetFPS(144);

    frame_buffer := LoadRenderTexture(xx screen_width, xx screen_height);
    crt_buffer := LoadRenderTexture(xx screen_width, xx screen_height);
    final_buffer := LoadRenderTexture(xx screen_width, xx screen_height);
    crt_bezel_buffer := LoadRenderTexture(xx (screen_width * 2), xx (screen_height * 2));

    blur_shader = LoadShader("shaders/crt.vs", "shaders/blur.fs");
    passthrough_shader = LoadShader("shaders/crt.vs", "shaders/passthrough.fs");
    blur_buffer_0 = LoadRenderTexture(xx (screen_width * 2), xx (screen_height * 2));
    blur_buffer_1 = LoadRenderTexture(xx (screen_width * 2), xx (screen_height * 2));

    crt_shader := LoadShader("shaders/crt.vs", "shaders/crt.fs");

    crt_body_mesh := LoadModel("meshes/crt_body.obj");
    crt_screen_mesh := LoadModel("meshes/crt_screen.obj");
    crt_bezel_mesh := LoadModel("meshes/crt_bezel.obj");
    crt_bezel_mask := LoadTexture("textures/crt_bezel_mask.png");
    crt_mesh_shader := LoadShader("shaders/crt_mesh.vs", "shaders/crt_mesh.fs");

    white_texture := LoadTexture("textures/white.png");

    mesh_shader := LoadShader("shaders/mesh.vs", "shaders/mesh.fs");

    church: Entity;
    church.mesh = LoadModel("meshes/church.obj");
    church.albedo = LoadTexture("textures/church_albedo.png");
    church.shader = mesh_shader;

    terrain: Entity;
    terrain.mesh = LoadModel("meshes/terrain.obj");
    terrain.albedo = LoadTexture("textures/grass_albedo.png");
    terrain.texture_scale = 16.0;
    terrain.shader = mesh_shader;

    bridge: Entity;
    bridge.mesh = LoadModel("meshes/bridge.obj");
    bridge.albedo = LoadTexture("textures/bridge_albedo.png");
    bridge.shader = mesh_shader;

    use_flying_camera := false;
    flying_camera: Flying_Camera;
    player_camera: Player_Camera;

    walkable_surfaces_arena := make_arena();
    walkable_surfaces_bvh := create_bvh_from_models(walkable_surfaces_arena,
        .[terrain.mesh, LoadModel("meshes/walkable_surfaces.obj")]
    );

    InitAudioDevice();

    ambience := LoadMusicStream("sounds/horror_01_drone_02.ogg");
    PlayMusicStream(ambience);

    sounds_arena := make_arena();
    footsteps_player := make_sound_player(sounds_arena, "sounds/footsteps");

    old_time := current_time_monotonic();
    while !WindowShouldClose() {
        UpdateMusicStream(ambience);

        now := current_time_monotonic();
        diff := now - old_time;
        old_time = now;

        delta := cast(float) to_float64_seconds(diff);
        if delta > 0.25 {
            delta = 0.25;
        }

        real_time += delta;
        real_delta = delta;

        if game_paused {
            game_delta = 0.0;
        } else {
            game_time += delta;
            game_delta = delta;
        }

        if IsKeyPressed(cast(s32) KeyboardKey.F1) enable_psx = !enable_psx;
        if IsKeyPressed(cast(s32) KeyboardKey.F2) enable_fog = !enable_fog;

        if IsKeyPressed(cast(s32) KeyboardKey.SPACE) use_flying_camera = !use_flying_camera;

        if use_flying_camera {
            flying_camera_apply_input(*flying_camera);
        } else {
            ray := Ray.{player_camera.position, v3(0, 0, -1)};

            tris := query_bvh(*walkable_surfaces_bvh, ray);
            hit, intersection := ray_intersects_triangles(tris, ray);
            if hit {
                player_camera.ground_pos = intersection.point;
            }

            player_camera_apply_input(*player_camera);
        }

        update_sound_player(footsteps_player);
        sound_player_set_paused(footsteps_player, length(player_camera.velocity) < 0.1);

        BeginDrawing();

            BeginTextureMode(frame_buffer);
                ClearBackground(.{255/2, 255/2, 255/2, 255});
                BeginMode3D(.{});

                    camera := ifx use_flying_camera then flying_camera.base else player_camera.base;

                    draw_entity(church, camera);
                    draw_entity(terrain, camera);
                    draw_entity(bridge, camera);

                EndMode3D();
            EndTextureMode();

            draw_blur_pass(frame_buffer.texture, crt_buffer, 0);

            SetShaderValue(crt_shader, GetShaderLocation(crt_shader, "screen_size"), *display_size, cast(s32) ShaderUniformDataType.VEC2);

            psx := ifx enable_psx then 1.0 else 0.0;
            SetShaderValue(crt_shader, GetShaderLocation(crt_shader, "enable_psx"), *psx, cast(s32) ShaderUniformDataType.FLOAT);

            draw_fullscreen_pass(crt_buffer.texture, final_buffer, crt_shader, false);

            BeginMode2D(.{zoom = 1.0});
                ClearBackground(.{0, 0, 0, 0});

                position_text := tprint("x=%, y=%, z=%",
                    formatFloat(camera.position.x, trailing_width = 1),
                    formatFloat(camera.position.y, trailing_width = 1),
                    formatFloat(camera.position.z, trailing_width = 1)
                );

                draw_debug_string(tprint("FPS=%", GetFPS()), .{0, 1, 0, 1});
                draw_debug_string(position_text);

                debug_string_position = .{10, 10};
            EndMode2D();

            BeginShaderMode(crt_mesh_shader);
                view_to_clip := mat4_projection(0.125, context.aspect_ratio, 0.1, 1000);
                world_to_view := mat4_identity;
                local_to_world := mat4_translation(.{5, 0, -1.6});

                SetShaderValueMatrix(crt_mesh_shader, GetShaderLocation(crt_mesh_shader, "view_to_clip"), cast(*Matrix) *view_to_clip);
                SetShaderValueMatrix(crt_mesh_shader, GetShaderLocation(crt_mesh_shader, "local_to_world"), cast(*Matrix) *local_to_world);

                rlEnableDepthTest();

                enable_lighting := 1.0;
                SetShaderValue(crt_mesh_shader, GetShaderLocation(crt_mesh_shader, "enable_lighting"), *enable_lighting, cast(s32) ShaderUniformDataType.FLOAT);

                DrawModel(crt_body_mesh, crt_mesh_shader, white_texture);

                draw_blur_pass(final_buffer.texture, crt_bezel_buffer, 1.5);

                bezel_glow := 1.0;
                SetShaderValue(crt_mesh_shader, GetShaderLocation(crt_mesh_shader, "bezel_glow"), *bezel_glow, cast(s32) ShaderUniformDataType.FLOAT);
                set_shader_texture(crt_mesh_shader, crt_bezel_mask, "crt_bezel_mask", 1);
                DrawModel(crt_bezel_mesh, crt_mesh_shader, crt_bezel_buffer.texture);
                bezel_glow = 0.0;
                SetShaderValue(crt_mesh_shader, GetShaderLocation(crt_mesh_shader, "bezel_glow"), *bezel_glow, cast(s32) ShaderUniformDataType.FLOAT);

                enable_lighting = 0.0;
                SetShaderValue(crt_mesh_shader, GetShaderLocation(crt_mesh_shader, "enable_lighting"), *enable_lighting, cast(s32) ShaderUniformDataType.FLOAT);

                time := cast(float) GetTime();
                SetShaderValue(crt_mesh_shader, GetShaderLocation(crt_mesh_shader, "time"), *time, cast(s32) ShaderUniformDataType.FLOAT);
                DrawModel(crt_screen_mesh, crt_mesh_shader, final_buffer.texture);
                rlDisableDepthTest();
            EndShaderMode();

        EndDrawing();
    }
}

DrawModel :: (model: Model, shader: Shader, albedo_texture: Texture) {
    rlEnableShader(shader.id);

    set_shader_texture(shader, albedo_texture, "albedo_texture", 0);

    for 0..model.meshCount-1 {
        albedo_colour: V3;
        albedo_colour.x = model.materials[it].maps[0].color.r / 255.0;
        albedo_colour.y = model.materials[it].maps[0].color.g / 255.0;
        albedo_colour.z = model.materials[it].maps[0].color.b / 255.0;

        rlSetUniform(rlGetLocationUniform(shader.id, "albedo_colour"), *albedo_colour, cast(s32) ShaderUniformDataType.VEC3, 1);

        mesh := model.meshes[it];

        rlEnableVertexArray(mesh.vaoId);

        if mesh.indices {
            rlDrawVertexArrayElements(0, mesh.triangleCount * 3, null);
        } else {
            rlDrawVertexArray(0, mesh.vertexCount);
        }

        rlDisableVertexArray();
    }

    rlDisableShader();
}