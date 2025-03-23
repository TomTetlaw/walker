
#add_context viewport: Vec2;
#add_context aspect_ratio: float;

#add_context temp_arena: *Arena;
#add_context input: Frame_Input;

#add_context window: *SDL_Window;
#add_context device: *SDL_GPUDevice;

#add_context terrain: Terrain;

game_paused: bool;
game_delta: float;
game_time: float;
real_delta: float;
real_time: float;
frame_num: int;

Options :: struct {
    fullscreen := false;
}

Player :: struct {
    using #as base: Entity;
    next, prev: *Player;

    base.flags = .POSITION_ABOVE_GROUND;

    base.view_model_distance = .2;
    base.view_model_offset = .{0, -.5, 0};

    walk_speed :: 4.7;
    run_speed :: 9.6;
    crouch_speed :: 2.5;
    stand_height :: 6.0;
    crouch_height :: 3.0;

    camera: Player_Camera;
}

Traveller :: struct {
    using #as base: Entity;
    next, prev: *Traveller;

    base.flags = .POSITION_ABOVE_GROUND;
    base.height_above_ground = 1.0;

    base.default_mesh_name = "unit_cube";
    base.default_texture_names[0] = "uv_check";
    base.default_texture_names[1] = "grass_normal";

    base.scale = #run v3(1);

    range: float;
    last_goal_time: float;
    goal_position: Vec2;
}

main :: () {
    context.temp_arena = make_arena();

    args, args_set := parse_arguments(Options,, temp);

    SDL_WINDOW_HIDDEN :: 0x0000000000000008;
    window := SDL_CreateWindow("walker", 1, 1, SDL_WINDOW_HIDDEN);
    if !window fatal_error("Failed to create window: %", get_sdl_error());

    SDL_SetWindowResizable(window, false);

    display_id := SDL_GetDisplays(null)[0];
    mode := SDL_GetCurrentDisplayMode(display_id);

    window_width := mode.w * 0.8;
    window_height := mode.h * 0.8;
    window_x := (mode.w * .5) - (window_width * .5);
    window_y := (mode.h * .5) - (window_height * .5);

    if args_set.fullscreen {
        SDL_SetWindowSize(window, mode.w, mode.h);
        SDL_SetWindowPosition(window, 0, 0);
        SDL_SetWindowFullscreenMode(window, null);

        context.viewport = .{xx mode.w, xx mode.h};
    } else {
        SDL_SetWindowSize(window, xx window_width, xx window_height);
        SDL_SetWindowPosition(window, xx window_x, xx window_y);

        context.viewport = .{window_width, window_height};
    }

    context.aspect_ratio = context.viewport.x / context.viewport.y;

    SDL_SetWindowRelativeMouseMode(window, true);

    SDL_ShowWindow(window);

    context.window = window;

    shader_formats := cast (u32) SDL_GPU_SHADERFORMAT_SPIRV;
    device := SDL_CreateGPUDevice(shader_formats, true, "vulkan");
    if !device fatal_error("Failed to create sdl_gpu device");

    if !SDL_ClaimWindowForGPUDevice(device, window) fatal_error("Failed to claim window for sdl_gpu device");

    if SDL_WindowSupportsGPUPresentMode(device, window, .SDL_GPU_PRESENTMODE_MAILBOX) {
        SDL_SetGPUSwapchainParameters(device, window, .SDL_GPU_SWAPCHAINCOMPOSITION_SDR, .SDL_GPU_PRESENTMODE_MAILBOX);
    } else {
        SDL_SetGPUSwapchainParameters(device, window, .SDL_GPU_SWAPCHAINCOMPOSITION_SDR, .SDL_GPU_PRESENTMODE_VSYNC);
    }

    context.device = device;

    init_input_system();
    init_shader_system();
    init_texture_system();
    init_renderer();
    init_mesh_system();
    init_entity_system();
    init_terrain_system();

    camera: Flying_Camera;

    use_flying_camera := true;

    terrain_options: Terrain_Options;
    terrain_options.subdivisions = 8;
    terrain_options.size = v2(10000.0);

    context.terrain = create_terrain(terrain_options);

    player := make_entity(Player);
    player.view_model = load_mesh("sword");

    for 0..999 {
        traveller := make_entity(Traveller);
        traveller.range = random_float(50, 500);
    }

    old_time := current_time_monotonic();
    while main_loop := true {
        event_mark := arena_push_mark(context.temp_arena);

        event: SDL_Event;
        while SDL_PollEvent(*event) {
            type := cast(SDL_EventType) event.type;
            if type == {
                case .SDL_EVENT_QUIT;
                break main_loop;
            }

            push_struct(context.temp_arena, event);
        }

        //~ gather input

        events := arena_to_view(context.temp_arena, SDL_Event, event_mark);
        context.input = input_process_events(events);
        if key_pressed(context.input, .ESCAPE) break;

        //~ update time

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

        //~ check for hotloads

        check_shaders_modified();

        //~ simulate

        if key_pressed(context.input, .F1) use_flying_camera = !use_flying_camera;
        if use_flying_camera {
            flying_camera_apply_input(*camera, context.input);
        } else {
            for * _Player {
                player_camera_apply_input(*it.camera, context.input);

                move_speed := Player.walk_speed;
                eye_height := Player.stand_height;

                if key_state(context.input, .LCTRL) {
                    move_speed = Player.crouch_speed;
                    eye_height = player.crouch_height;
                } else {
                    if key_state(context.input, .LSHIFT) move_speed = Player.run_speed;
                }

                move_input: Vec2;
                move_input.x = key_state(context.input, .W) - key_state(context.input, .S);
                move_input.y = key_state(context.input, .A) - key_state(context.input, .D);
                move_input = normalize(move_input);
                move_input = rotate(move_input, player.camera.yaw);

                goal_velocity := v3(move_input * move_speed, 0.0);
                it.velocity = approach(it.velocity, goal_velocity, 0.5, game_delta);

                it.height_above_ground = approach(it.height_above_ground, eye_height, 0.5, game_delta);
            }
        }

        for * _Traveller {
            if game_time - it.last_goal_time > 2.0 {
                it.goal_position = random_unit_vec2() * it.range;
                it.last_goal_time = game_time;
            }

            dir := normalize(it.goal_position, it.position.xy);
            it.velocity = v3(dir * 50, 0.0);
        }

        update_entities();

        // @HACK
        player.camera.position = player.visual_position;
        player.rotation = player.camera.rotation;

        //~ render

        renderer_begin_frame();

        render_entities();

        scene: Render_Scene;
        if use_flying_camera {
            scene.camera = camera;
        } else {
            scene.camera = player.camera;
        }

        render_terrain(context.terrain, .[], *scene.camera);

        scene.sun = .{
            direction = normalize(Vec3.{1,1,1} - .{5,5,5}),
            params = .{0.3, 1.0, 1.0, 2.0},
            colour = .{1.0, 0.9, 0.7, 1.0}
        };

        render_scene(scene);

        //~ reset for next frame

        reset_arena(context.temp_arena);
        reset_temporary_storage();

        frame_num += 1;

        #if PROFILING {
            __Tracy.FrameMark();
        }

        report_sdl_error("main");
    }
}

fatal_error :: (format: string, args: ..Any) {
    builder: String_Builder;
    print_to_builder(*builder, format, ..args,, temp);
    message := builder_to_string(*builder,, temp);
    SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Fatal error", tcs(message), null);
    exit(1);
}