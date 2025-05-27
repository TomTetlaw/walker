
build :: () {
    profiling :: false;
    release :: false;

    workspace := compiler_create_workspace("Walker");

    imports: [..] string;
    array_add(*imports, "Basic", "String", "File", "sdl3", "stb_image",
        "Command_Line", "File_Utilities", "Hash", "File_Watcher", "System",
        "Random", "Sort", "Print_Vars");

    options := get_build_options(workspace);
    options.backend = .LLVM;
    options.output_executable_name = "walker";
    options.output_path = "./run_tree";
    options.text_output_flags = 0;
    #if release {
        set_optimization(*options, .VERY_OPTIMIZED);
    }
    set_build_options(options, workspace);

    for imports {
        add_build_string(tprint("#import \"%\";\n", it), workspace);
    }

    add_build_string("using,except(Quaternion,PI,Vector4,Ray,Vector3,Vector2) Raylib :: #import \"raylib\";\n", workspace);
    add_build_string("using,except(Quaternion) Math :: #import \"Math\";\n", workspace);

    files := file_list("./");
    for files {
        if contains(it, "first.jai") continue;
        if !contains(it, ".jai") continue;

        add_build_file(it, workspace);
    }

    set_build_options_dc(.{do_output=false});
}

#run build();

#import "Basic";
#import "String";
#import "File_Utilities";
#import "Compiler";
#import "Metaprogram_Plugins";