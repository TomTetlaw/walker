// Workspace: Walker

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "Basic";

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "String";

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "File";

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "sdl3";

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "stb_image";

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "Command_Line";

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "File_Utilities";

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "Hash";

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "File_Watcher";

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "System";

//
// String added via add_build_string() from F:/walker/first.jai:29.
//
#import "Windows";

//
// String added via add_build_string() from F:/walker/first.jai:32.
//
using,except(Quaternion,rgba) Math :: #import "Math";

//
// #insert text. Generated from C:/jai/modules/Command_Line.jai:64.
//
    fullscreen := false;

//
// String added via add_build_string() from F:/walker/first.jai:67.
//
_Test_Entity: Bucket_Array(Test_Entity);
get_entity_array :: ($T: Type) -> *Bucket_Array(T) #expand {
	#if T == Test_Entity return *_Test_Entity;
}
remove_entity_by_type :: (entity: *Entity) {
	if entity.type == {
		case Test_Entity; bucket_array_remove(*_Test_Entity, cast(*Test_Entity) entity);
	}
}
all_entity_types :: Type.[
	Test_Entity];
build_entity_list :: (arena: *Arena, $include_inactive := false) {
#if include_inactive {
	for * _Test_Entity push_value(arena, it);
} else {
	for * :active_entities _Test_Entity push_value(arena, it);
}
}
