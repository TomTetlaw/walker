

RAYLIB_DIR :: "source_files/raylib";

generate_bindings :: () -> bool {
    options: Generate_Bindings_Options;

#if OS == .WINDOWS {
        array_add(*options.include_paths, tprint("%/zig-out/include", RAYLIB_DIR));
        array_add(*options.libpaths, tprint("%/zig-out/lib", RAYLIB_DIR));
        array_add(*options.libpaths, tprint("%/zig-out/bin", RAYLIB_DIR));
        array_add(*options.libnames, "raylib.lib");
    } else {
        assert(false);
    }

    array_add(*options.source_files, "raylib.h");
    array_add(*options.source_files, "rlgl.h");

    copy_file(tprint("%/zig-out/bin/raylib.dll", RAYLIB_DIR), tprint("%/zig-out/lib/raylib.dll", RAYLIB_DIR));

    if !generate_bindings(options, "module.jai") return false;

    return true;
}

build :: () {
    if !generate_bindings() compiler_set_workspace_status(.FAILED);
    set_build_options_dc(.{do_output = false});
}

#run build();

#scope_file

#import "Basic";
#import "File_Utilities";
#import "File";
#import "Compiler";
#import "String";
#import "Bindings_Generator";