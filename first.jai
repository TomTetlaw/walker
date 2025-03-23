
build :: () {
    profiling :: false;
    release :: true;

    workspace := compiler_create_workspace("Walker");

    imports: [..] string;
    array_add(*imports, "Basic", "String", "File", "sdl3", "stb_image",
        "Command_Line", "File_Utilities", "Hash", "File_Watcher", "System",
        "Random", "Sort", "Print_Vars");

#if OS == .WINDOWS array_add(*imports, "Windows");
    else #if OS == .LINUX array_add(*imports, "POSIX");

    plugin_names: [..] string;

    if profiling {
        array_add(*plugin_names, "jai-tracy");
    }

    options := get_build_options(workspace);
    options.backend = .LLVM;
    options.output_executable_name = "walker";
    options.output_path = "./run_tree";
    options.text_output_flags = 0;
    #if release {
        set_optimization(*options, .VERY_OPTIMIZED);
    }
    set_build_options(options, workspace);

    plugins: [..] *Metaprogram_Plugin;
    init_plugins(plugin_names, *plugins, workspace);

    intercept_flags: Intercept_Flags;
    for plugins if it.before_intercept it.before_intercept(it, *intercept_flags);

    compiler_begin_intercept(workspace);

    add_build_string(tprint("PROFILING :: %;\n", profiling), workspace);

    if profiling {
        add_build_string("#import \"jai-tracy\" (IMPORT_MODE=.CLIENT);\n", workspace);
    }

    for plugins if it.add_source it.add_source(it);

    for imports {
        add_build_string(tprint("#import \"%\";\n", it), workspace);
    }

    add_build_string("using,except(Quaternion,rgba) Math :: #import \"Math\";\n", workspace);

    files := file_list("./");
    for files {
        if contains(it, "first.jai") continue;
        if !contains(it, ".jai") continue;

        add_build_file(it, workspace);
    }

    generated_code := false;
    entity_types: [..] *Type_Info_Struct;
    while true {
        message := compiler_wait_for_message();
        for plugins if it.message it.message(it, message);

        if message.kind == .TYPECHECKED {
            tc := cast (*Message_Typechecked) message;
            for tc.structs {
                exp := it.expression;
                t := exp.defined_type;

                if is_subclass_of(t, "Entity") {
                    array_add(*entity_types, t);
                }
            }
        }

        if message.kind == .PHASE {
            phase := cast (*Message_Phase) message;

            if phase.phase == .TYPECHECKED_ALL_WE_CAN {
                if !generated_code {
                    cg: Code_Gen;
                    cg.entity_types = entity_types;
                    code := generate_code(cg);
                    add_build_string(code, workspace);
                    generated_code = true;
                }

                break;
            }
        }

        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(workspace);

    for plugins if it.finish it.finish(it);
    for plugins if it.shutdown it.shutdown(it);

    set_build_options_dc(.{do_output=false});
}

Code_Gen :: struct {
    entity_types: [] *Type_Info_Struct;
}

generate_code :: (cg: Code_Gen) -> string {
    builder: String_Builder;

    for cg.entity_types {
        print_to_builder(*builder, "_%1: Bucket_Array(%1);\n", it.name);
    }

    append(*builder, "get_entity_array :: ($T: Type) -> *Bucket_Array(T) #expand {\n");
    for cg.entity_types {
        print_to_builder(*builder, "\t#if T == %1 return *_%1;\n", it.name);
    }
    append(*builder, "}\n");

    append(*builder, "for_all_entities :: ($func: ($T: Type, array: *Bucket_Array(T), entity: *Entity)) {\n");
    for cg.entity_types {
        print_to_builder(*builder, "{ array := get_entity_array(%1); for * _%1 inline func(%1, array, it); }\n", it.name);
    }
    append(*builder, "}\n");

    append(*builder, "build_entity_list :: (arena: *Arena) {\n");
    for cg.entity_types {
        print_to_builder(*builder, "\tfor * _%1 push_value(arena, it);\n", it.name);
    }
    append(*builder, "}\n");

    result := builder_to_string(*builder);
    return result;
}

#run build();

#import "Basic";
#import "String";
#import "File_Utilities";
#import "Compiler";
#import "Metaprogram_Plugins";