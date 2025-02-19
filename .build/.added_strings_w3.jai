// Workspace: Walker

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "Basic";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "String";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "File";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "sdl3";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "stb_image";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "Command_Line";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "File_Utilities";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "Hash";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "File_Watcher";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "System";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "Random";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "fastnoise_jai";

//
// String added via add_build_string() from F:/walker/first.jai:31.
//
#import "Windows";

//
// String added via add_build_string() from F:/walker/first.jai:34.
//
using,except(Quaternion,rgba) Math :: #import "Math";

//
// #insert text. Generated from C:/jai/modules/Command_Line.jai:64.
//
    fullscreen := false;

//
// #insert text. Generated from F:/walker/modules/fastnoise_jai/module.jai:18.
//
Constant :: 0;
White :: 1;
Checkerboard :: 2;
SineWave :: 3;
PositionOutput :: 4;
DistanceToPoint :: 5;
Value :: 6;
Perlin :: 7;
Simplex :: 8;
OpenSimplex2 :: 9;
CellularValue :: 10;
CellularDistance :: 11;
CellularLookup :: 12;
FractalFBm :: 13;
FractalPingPong :: 14;
FractalRidged :: 15;
DomainWarpGradient :: 16;
DomainWarpFractalProgressive :: 17;
DomainWarpFractalIndependant :: 18;
DomainScale :: 19;
DomainOffset :: 20;
DomainRotate :: 21;
SeedOffset :: 22;
Remap :: 23;
ConvertRGBA8 :: 24;
Add :: 25;
Subtract :: 26;
Multiply :: 27;
Divide :: 28;
Min :: 29;
Max :: 30;
MinSmooth :: 31;
MaxSmooth :: 32;
Fade :: 33;
Terrace :: 34;
PowFloat :: 35;
PowInt :: 36;
DomainAxisScale :: 37;
AddDimension :: 38;
RemoveDimension :: 39;
GeneratorCache :: 40;
OpenSimplex2S :: 41;

//
// String added via add_build_string() from F:/walker/first.jai:69.
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
