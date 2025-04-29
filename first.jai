
build :: () {
    profiling :: false;
    release :: false;

    workspace := compiler_create_workspace("Walker");

    imports: [..] string;
    array_add(*imports, "Basic", "String", "File", "sdl3", "stb_image",
        "Command_Line", "File_Utilities", "Hash", "File_Watcher", "System",
        "Random", "Sort", "Print_Vars", "Math", "Text_File_Handler");

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

    files := file_list("./");
    for files {
        if contains(it, "first.jai") continue;
        if !contains(it, ".jai") continue;

        add_build_file(it, workspace);
    }

    generated_code := false;
    hlsl_structs: [..] *Type_Info_Struct;
    while true {
        message := compiler_wait_for_message();
        for plugins if it.message it.message(it, message);

        if message.kind == .TYPECHECKED {
            tc := cast (*Message_Typechecked) message;
            for tc.structs {
                exp := it.expression;
                t := exp.defined_type;

                if array_find(t.notes, "hlsl_struct") {
                    array_add(*hlsl_structs, t);
                }
            }
        }

        if message.kind == .PHASE {
            phase := cast (*Message_Phase) message;
            if phase.phase == .TYPECHECKED_ALL_WE_CAN {
                if !generated_code {
                    add_build_string(generate_hlsl_structs(hlsl_structs), workspace);
                    generated_code = true;
                }
            }
        }

        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(workspace);

    for plugins if it.finish it.finish(it);
    for plugins if it.shutdown it.shutdown(it);

    set_build_options_dc(.{do_output=false});
}

generate_hlsl_struct_members :: (type: *Type_Info_Struct, texture_index: *int) -> string {
    builder: String_Builder;
    padding_index := 0;

    pad := !array_find(type.notes, "no_pad");

    for type.members {
        padding_type := "";

        if array_find(it.notes, "texture") {
            print_to_builder(*builder, "Texture2D %_texture: register(t%, space2);\n", it.name, texture_index.*);
            print_to_builder(*builder, "SamplerState %_sampler: register(t%, space2);\n", it.name, texture_index.*);
            texture_index.* += 1;
        } else {
            if it.type.type == .FLOAT {
                print_to_builder(*builder, "float %", it.name);
                padding_type = "float3";
            } else if it.type.type == .STRUCT {
                member_type := cast(*Type_Info_Struct) it.type;
                if equal(member_type.name, "V2") {
                    print_to_builder(*builder, "float2 %", it.name);
                    padding_type = "float2";
                } else if equal(member_type.name, "V3") {
                    print_to_builder(*builder, "float3 %", it.name);
                    padding_type = "float";
                } else if equal(member_type.name, "V4") {
                    print_to_builder(*builder, "float4 %", it.name);
                } else if equal(member_type.name, "Mat4") {
                    print_to_builder(*builder, "float4x4 %", it.name);
                }
            }

            use_semantic, index := array_find(it.notes, "semantic");
            if use_semantic {
                if it.notes.count > index + 1 {
                    semantic := it.notes[index + 1];
                    print_to_builder(*builder, ": %", semantic);
                }
            }

            append(*builder, ";\n");

            if pad && padding_type {
                print_to_builder(*builder, "% pad_%;\n", padding_type, padding_index);
                padding_index += 1;
            }
        }
    }

    return builder_to_string(*builder);
}

generate_hlsl_structs :: (structs: [..] *Type_Info_Struct) -> string {
    texture_index := 0;

    builder: String_Builder;
    for structs {
        print_to_builder(*builder, "%_generated :: #string HERE\n", it.name);
        append(*builder, generate_hlsl_struct_members(it, *texture_index));
        append(*builder, "HERE\n");
    }

    append(*builder, "generated_hlsl_structs :: Generated_Shader_Struct.[\n");
    for structs {
        print_to_builder(*builder, ".{\"%1\", %1_generated},\n", it.name);
    }
    append(*builder, "];\n");

    return builder_to_string(*builder);
}

#run build();

#import "Basic";
#import "String";
#import "File_Utilities";
#import "Compiler";
#import "Metaprogram_Plugins";