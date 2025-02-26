
#add_context viewport: Vec2;
#add_context aspect_ratio: float;

#add_context temp_arena: *Arena;
#add_context input: Frame_Input;

#add_context window: *SDL_Window;
#add_context device: *SDL_GPUDevice;

game_paused: bool;
game_delta: float;
game_time: float;
real_delta: float;
real_time: float;
frame_num: int;

Options :: struct {
    fullscreen := false;
}

Test_Entity :: struct {
    using #as base: Entity;
    next, prev: *Test_Entity;

    default_texture_names[0] = "uv_check";
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

    for y: -5..5 for x: -5..5 {
        e := make_entity(Test_Entity);
        e.p = .{cast(float) x * 100, cast(float) y * 100, 35};
        e.scale = v3(15);
        e.mesh = cube_mesh;
        spawn_entity(e);
    }

    opts: Terrain_Options;
    opts.subdivisions = 8;
    opts.size = v2(10000.0);
    opts.height_scale = 1000.0;

    opts.noise_seed = to_milliseconds(current_time_monotonic());
    opts.noise_octaves = 10;
    opts.noise_persistence = .5;
    opts.noise_scale = .005;
    opts.noise_power = 6.0;

    terrain := create_terrain(opts);

    // sky_sphere_mesh := generate_sphere_mesh(mesh_arena, "sky_sphere", 32.0, 16);

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

        flying_camera_apply_input(*camera, context.input);

        update_entities();

        yaw := quat_from_axis_angle(.{0, 0, 1}, game_delta*0.02);
        pitch := quat_from_axis_angle(.{1, 0, 0}, game_delta*0.02);
        rotation := yaw * pitch;

        for * :active_entities _Test_Entity {
            it.rotation *= rotation;
        }

        //~ render

        mesh_batcher: Render_Batcher;
        init_render_batcher(*mesh_batcher);

        render_entities(*mesh_batcher);
        render_terrain(*mesh_batcher, terrain, .[]);

        scene: Render_Scene;
        scene.mesh_batcher = mesh_batcher;
        scene.camera = camera;

        scene.sun = .{
            direction = .{0.0, -0.94, -0.30},
            params = .{0.3, 1.0, 1.0, 2.0},
            colour = .{1.0, 0.9, 0.7, 1.0}
        };

        render_scene(scene);

        //~ reset for next frame

        reset_arena(context.temp_arena);
        reset_temporary_storage();

        frame_num += 1;
    }
}

fatal_error :: (format: string, args: ..Any) {
    builder: String_Builder;
    print_to_builder(*builder, format, ..args,, temp);
    message := builder_to_string(*builder,, temp);
    SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Fatal error", tcs(message), null);
    exit(1);
}