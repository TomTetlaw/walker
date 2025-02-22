
build :: () {
    workspace := compiler_create_workspace("Walker");

    options := get_build_options(workspace);
    options.output_executable_name = "walker";
    options.output_path = "./run_tree";
    options.text_output_flags = 0;
    set_build_options(options, workspace);

    imports: [..] string;
    array_add(*imports, "Basic");
    array_add(*imports, "String");
    array_add(*imports, "File");
    array_add(*imports, "sdl3");
    array_add(*imports, "stb_image");
    array_add(*imports, "Command_Line");
    array_add(*imports, "File_Utilities");
    array_add(*imports, "Hash");
    array_add(*imports, "File_Watcher");
    array_add(*imports, "System");
    array_add(*imports, "Random");

#if OS == .WINDOWS array_add(*imports, "Windows");
    else #if OS == .LINUX array_add(*imports, "POSIX");

    compiler_begin_intercept(workspace);

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

    append(*builder, "remove_entity_by_type :: (entity: *Entity) {\n");
    append(*builder, "\tif entity.type == {\n");
    for cg.entity_types {
        print_to_builder(*builder, "\t\tcase %1; bucket_array_remove(*_%1, cast(*%1) entity);\n", it.name);
    }
    append(*builder, "\t}\n");
    append(*builder, "}\n");

    append(*builder, "all_entity_types :: Type.[\n");
    for cg.entity_types {
        print_to_builder(*builder, "\t%", it.name);
    }
    append(*builder, "];\n");

    append(*builder, "build_entity_list :: (arena: *Arena, $include_inactive := false) {\n");
    for cg.entity_types {
        append(*builder, "#if include_inactive {\n");
        print_to_builder(*builder, "\tfor * _%1 push_value(arena, it);\n", it.name);
        append(*builder, "} else {\n");
        print_to_builder(*builder, "\tfor * :active_entities _%1 push_value(arena, it);\n", it.name);
        append(*builder, "}\n");
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