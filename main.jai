
#add_context window: *SDL_Window;
#add_context device: *SDL_GPUDevice;
#add_context input: Frame_Input;

game_paused: bool;
game_delta: float;
game_time: float;
real_delta: float;
real_time: float;
frame_num: int;

Options :: struct {
    fullscreen := false;
}

main :: () {
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
    } else {
        SDL_SetWindowSize(window, xx window_width, xx window_height);
        SDL_SetWindowPosition(window, xx window_x, xx window_y);
    }

    SDL_SetWindowRelativeMouseMode(window, true);

    SDL_ShowWindow(window);

    context.window = window;

    shader_formats := cast (u32) SDL_GPU_SHADERFORMAT_SPIRV | SDL_GPU_SHADERFORMAT_DXBC | SDL_GPU_SHADERFORMAT_DXIL;
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
    init_pipeline_cache();
    init_shader_system();

    static_mesh_shader := load_shader("static_mesh");

    old_time := current_time_monotonic();
    while main_loop := true {
        events := tarray(SDL_Event);

        event: SDL_Event;
        while SDL_PollEvent(*event) {
            type := cast(SDL_EventType) event.type;
            if type == {
                case .SDL_EVENT_QUIT;
                break main_loop;
            }

            array_add(*events, event);
        }

        context.input = input_process_events(events);
        if key_pressed(context.input, .ESCAPE) break;

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

        frame_num += 1;

        #if PROFILING {
            __Tracy.FrameMark();
        }
    }
}

fatal_error :: (format: string, args: ..Any) {
    builder: String_Builder;
    print_to_builder(*builder, format, ..args,, temp);
    message := builder_to_string(*builder,, temp);
    SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Fatal error", tcs(message), null);
    exit(1);
}