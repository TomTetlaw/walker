
Any_Float_Vector :: struct {
	x, y: float;
}

Any_Integer_Vector :: struct {
	x, y: s32;
}

V2i :: struct {
    x, y: s32;

    #place x;
    components: [COMPONENTS] s32;
    COMPONENTS :: 2;
}

V3i :: struct {
    x, y, z: s32;

    #place x;
    components: [COMPONENTS] s32;
    COMPONENTS :: 3;
}

V4i :: struct {
    x, y, z, w: s32;

    #place x;
    components: [COMPONENTS] s32;
    COMPONENTS :: 4;
}

V2 :: struct {
    x, y: float;

    #place x;
    components: [COMPONENTS] float;
    COMPONENTS :: 2;
}

V3 :: struct {
    x, y, z: float;

    #place x;
    components: [COMPONENTS] float;
    COMPONENTS :: 3;
}

V4 :: struct {
    x, y, z, w: float;

    #place x;
    components: [COMPONENTS] float;
    COMPONENTS :: 4;
}

is_vector_type :: (T: Type) -> bool #compile_time {
	is_scalar_vector := T == V2 || T == V3 || T == V4;
	is_integer_vector := T == V2i || T == V3i || T == V4i;
	return is_scalar_vector || is_integer_vector;
}

min_vector :: (a: $T, b: T) -> T #modify { return is_vector_type(T); } {
	result: T;
	for 0..T.COMPONENTS-1 {
		result[it] = min(a.components[it], b.components[it]);
	}
	return result;
}

max_vector :: (a: $T, b: T) -> T #modify { return is_vector_type(T); } {
	result: T;
	for 0..T.COMPONENTS-1 {
		result[it] = max(a.components[it], b.components[it]);
	}
	return result;
}

length_squared :: inline (v: V2) -> float { return v.x*v.x + v.y*v.y; }
length_squared :: inline (v: V3) -> float { return v.x*v.x + v.y*v.y + v.z*v.z; }
length_squared :: inline (v: V4) -> float { return v.x*v.x + v.y*v.y + v.z*v.z + v.w*v.w; }
length :: inline (v: V2) -> float { return sqrt(v.x*v.x + v.y*v.y); }
length :: inline (v: V3) -> float { return sqrt(v.x*v.x + v.y*v.y + v.z*v.z); }
length :: inline (v: V4) -> float { return sqrt(v.x*v.x + v.y*v.y + v.z*v.z + v.w*v.w); }

normalize :: (v: V2, fallback := V2.{}) -> V2 {
    len := length(v);
    if len == 0.0 return fallback;
    inv_length := 1.0 / len;
    return .{v.x * inv_length, v.y * inv_length};
}

normalize :: (v: V3, fallback := V3.{0, 0, 1}) -> V3 {
    len := length(v);
    if len == 0.0 return fallback;
    inv_length := 1.0 / len;
    return .{v.x * inv_length, v.y * inv_length, v.z * inv_length};
}

normalize :: (v: V4, fallback := V4.{}) -> V4 {
    len := length(v);
    if len == 0.0 return fallback;
    inv_length := 1.0 / len;
    return .{v.x * inv_length, v.y * inv_length, v.z * inv_length, v.w * inv_length};
}

dot :: inline (a: V2, b: V2) -> float { return a.x*b.x + a.y*b.y; }
dot :: inline (a: V3, b: V3) -> float { return a.x*b.x + a.y*b.y + a.z*b.z; }
dot :: inline (a: V4, b: V4) -> float { return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w; }

cross :: inline (a: V3, b: V3) -> V3 {
    return .{
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    };
}

v2i :: inline (xy: s32) -> V2i { return .{xy, xy}; }
v3i :: inline (x: s32, y: s32, z: s32) -> V3i { return .{x, y, z}; }
v3i :: inline (xy: V2i, z: s32) -> V3i { return .{xy.x, xy.y, z}; }
v3i :: inline (x: s32, yz: V2i) -> V3i { return .{x, yz.x, yz.y}; }
v3i :: inline (xyz: s32) -> V3i { return .{xyz, xyz, xyz}; }
v4i :: inline (x: s32, y: s32, z: s32, w: s32) -> V4i { return .{x, y, z, w}; }
v4i :: inline (xy: V2i, z: s32, w: s32) -> V4i { return .{xy.x, xy.y, z, w}; }
v4i :: inline (x: s32, yz: V2i, w: s32) -> V4i { return .{x, yz.x, yz.y, w}; }
v4i :: inline (x: s32, y: s32, zw: V2i) -> V4i { return .{x, y, zw.x, zw.y}; }
v4i :: inline (xy: V2i, zw: V2i) -> V4i { return .{xy.x, xy.y, zw.x, zw.y}; }
v4i :: inline (x: s32, yzw: V3i) -> V4i { return .{x, yzw.x, yzw.y, yzw.z}; }
v4i :: inline (xyz: V3i, w: s32) -> V4i { return .{xyz.x, xyz.y, xyz.z, w}; }
v4i :: inline (xyzw: s32) -> V4i { return .{xyzw, xyzw, xyzw, xyzw}; }

v2 :: inline (xy: float) -> V2 { return .{xy, xy}; }
v3 :: inline (x: float, y: float, z: float) -> V3 { return .{x, y, z}; }
v3 :: inline (xy: V2, z: float) -> V3 { return .{xy.x, xy.y, z}; }
v3 :: inline (x: float, yz: V2) -> V3 { return .{x, yz.x, yz.y}; }
v3 :: inline (xyz: float) -> V3 { return .{xyz, xyz, xyz}; }
v4 :: inline (x: float, y: float, z: float, w: float) -> V4 { return .{x, y, z, w}; }
v4 :: inline (xy: V2, z: float, w: float) -> V4 { return .{xy.x, xy.y, z, w}; }
v4 :: inline (x: float, yz: V2, w: float) -> V4 { return .{x, yz.x, yz.y, w}; }
v4 :: inline (x: float, y: float, zw: V2) -> V4 { return .{x, y, zw.x, zw.y}; }
v4 :: inline (xy: V2, zw: V2) -> V4 { return .{xy.x, xy.y, zw.x, zw.y}; }
v4 :: inline (x: float, yzw: V3) -> V4 { return .{x, yzw.x, yzw.y, yzw.z}; }
v4 :: inline (xyz: V3, w: float) -> V4 { return .{xyz.x, xyz.y, xyz.z, w}; }
v4 :: inline (xyzw: float) -> V4 { return .{xyzw, xyzw, xyzw, xyzw}; }

v2i :: inline (v: V2) -> V2i { return .{cast(s32) v.x, cast(s32) v.y}; }
v2 :: inline (v: V2i) -> V2 { return .{cast(float) v.x, cast(float) v.y}; }
v3i :: inline (v: V3) -> V3i { return .{cast(s32) v.x, cast(s32) v.y, cast(s32) v.z}; }
v3 :: inline (v: V3i) -> V3 { return .{cast(float) v.x, cast(float) v.y, cast(float) v.z}; }
v4i :: inline (v: V4) -> V4i { return .{cast(s32) v.x, cast(s32) v.y, cast(s32) v.z, cast(s32) v.w}; }
v4 :: inline (v: V4i) -> V4 { return .{cast(float) v.x, cast(float) v.y, cast(float) v.z, cast(float) v.w}; }

operator + :: inline (a: V2i, b: V2i) -> V2i #symmetric {
	result: V2i;
	result.x = a.x + b.x;
	result.y = a.y + b.y;
	return result;
}

operator - :: inline (a: V2i, b: V2i) -> V2i #symmetric {
	result: V2i;
	result.x = a.x - b.x;
	result.y = a.y - b.y;
	return result;
}

operator * :: inline (a: V2i, b: V2i) -> V2i #symmetric {
	result: V2i;
	result.x = a.x * b.x;
	result.y = a.y * b.y;
	return result;
}

operator / :: inline (a: V2i, b: V2i) -> V2i #symmetric {
	result: V2i;
	result.x = a.x / b.x;
	result.y = a.y / b.y;
	return result;
}

operator + :: inline (a: V2i, b: s32) -> V2i #symmetric {
	result: V2i;
	result.x = a.x + b;
	result.y = a.y + b;
	return result;
}

operator - :: inline (a: V2i, b: s32) -> V2i #symmetric {
	result: V2i;
	result.x = a.x - b;
	result.y = a.y - b;
	return result;
}

operator * :: inline (a: V2i, b: s32) -> V2i #symmetric {
	result: V2i;
	result.x = a.x * b;
	result.y = a.y * b;
	return result;
}

operator / :: inline (a: V2i, b: s32) -> V2i #symmetric {
	result: V2i;
	result.x = a.x / b;
	result.y = a.y / b;
	return result;
}

operator *[] :: inline (v: V2i, index: int) -> *s32 {
	return *v.components[index];
}

operator + :: inline (a: V3i, b: V3i) -> V3i #symmetric {
	result: V3i;
	result.x = a.x + b.x;
	result.y = a.y + b.y;
	result.z = a.z + b.z;
	return result;
}

operator - :: inline (a: V3i, b: V3i) -> V3i #symmetric {
	result: V3i;
	result.x = a.x - b.x;
	result.y = a.y - b.y;
	result.z = a.z - b.z;
	return result;
}

operator * :: inline (a: V3i, b: V3i) -> V3i #symmetric {
	result: V3i;
	result.x = a.x * b.x;
	result.y = a.y * b.y;
	result.z = a.z * b.z;
	return result;
}

operator / :: inline (a: V3i, b: V3i) -> V3i #symmetric {
	result: V3i;
	result.x = a.x / b.x;
	result.y = a.y / b.y;
	result.z = a.z / b.z;
	return result;
}

operator + :: inline (a: V3i, b: s32) -> V3i #symmetric {
	result: V3i;
	result.x = a.x + b;
	result.y = a.y + b;
	result.z = a.z + b;
	return result;
}

operator - :: inline (a: V3i, b: s32) -> V3i #symmetric {
	result: V3i;
	result.x = a.x - b;
	result.y = a.y - b;
	result.z = a.z - b;
	return result;
}

operator * :: inline (a: V3i, b: s32) -> V3i #symmetric {
	result: V3i;
	result.x = a.x * b;
	result.y = a.y * b;
	result.z = a.z * b;
	return result;
}

operator / :: inline (a: V3i, b: s32) -> V3i #symmetric {
	result: V3i;
	result.x = a.x / b;
	result.y = a.y / b;
	result.z = a.z / b;
	return result;
}

operator *[] :: inline (v: V3i, index: int) -> *s32 {
	return *v.components[index];
}

operator + :: inline (a: V4i, b: V4i) -> V4i #symmetric {
	result: V4i;
	result.x = a.x + b.x;
	result.y = a.y + b.y;
	result.z = a.z + b.z;
	result.w = a.w + b.w;
	return result;
}

operator - :: inline (a: V4i, b: V4i) -> V4i #symmetric {
	result: V4i;
	result.x = a.x - b.x;
	result.y = a.y - b.y;
	result.z = a.z - b.z;
	result.w = a.w - b.w;
	return result;
}

operator * :: inline (a: V4i, b: V4i) -> V4i #symmetric {
	result: V4i;
	result.x = a.x * b.x;
	result.y = a.y * b.y;
	result.z = a.z * b.z;
	result.w = a.w * b.w;
	return result;
}

operator / :: inline (a: V4i, b: V4i) -> V4i #symmetric {
	result: V4i;
	result.x = a.x / b.x;
	result.y = a.y / b.y;
	result.z = a.z / b.z;
	result.w = a.w / b.w;
	return result;
}

operator + :: inline (a: V4i, b: s32) -> V4i #symmetric {
	result: V4i;
	result.x = a.x + b;
	result.y = a.y + b;
	result.z = a.z + b;
	result.w = a.w + b;
	return result;
}

operator - :: inline (a: V4i, b: s32) -> V4i #symmetric {
	result: V4i;
	result.x = a.x - b;
	result.y = a.y - b;
	result.z = a.z - b;
	result.w = a.w - b;
	return result;
}

operator * :: inline (a: V4i, b: s32) -> V4i #symmetric {
	result: V4i;
	result.x = a.x * b;
	result.y = a.y * b;
	result.z = a.z * b;
	result.w = a.w * b;
	return result;
}

operator / :: inline (a: V4i, b: s32) -> V4i #symmetric {
	result: V4i;
	result.x = a.x / b;
	result.y = a.y / b;
	result.z = a.z / b;
	result.w = a.w / b;
	return result;
}

operator *[] :: inline (v: V4i, index: int) -> *s32 {
	return *v.components[index];
}

operator + :: inline (a: V2, b: V2) -> V2 #symmetric {
	result: V2;
	result.x = a.x + b.x;
	result.y = a.y + b.y;
	return result;
}

operator - :: inline (a: V2, b: V2) -> V2 #symmetric {
	result: V2;
	result.x = a.x - b.x;
	result.y = a.y - b.y;
	return result;
}

operator * :: inline (a: V2, b: V2) -> V2 #symmetric {
	result: V2;
	result.x = a.x * b.x;
	result.y = a.y * b.y;
	return result;
}

operator / :: inline (a: V2, b: V2) -> V2 #symmetric {
	result: V2;
	result.x = a.x / b.x;
	result.y = a.y / b.y;
	return result;
}

operator + :: inline (a: V2, b: float) -> V2 #symmetric {
	result: V2;
	result.x = a.x + b;
	result.y = a.y + b;
	return result;
}

operator - :: inline (a: V2, b: float) -> V2 #symmetric {
	result: V2;
	result.x = a.x - b;
	result.y = a.y - b;
	return result;
}

operator * :: inline (a: V2, b: float) -> V2 #symmetric {
	result: V2;
	result.x = a.x * b;
	result.y = a.y * b;
	return result;
}

operator / :: inline (a: V2, b: float) -> V2 #symmetric {
	result: V2;
	result.x = a.x / b;
	result.y = a.y / b;
	return result;
}

operator *[] :: inline (v: V2, index: int) -> *float {
	return *v.components[index];
}

operator + :: inline (a: V3, b: V3) -> V3 #symmetric {
	result: V3;
	result.x = a.x + b.x;
	result.y = a.y + b.y;
	result.z = a.z + b.z;
	return result;
}

operator - :: inline (a: V3, b: V3) -> V3 #symmetric {
	result: V3;
	result.x = a.x - b.x;
	result.y = a.y - b.y;
	result.z = a.z - b.z;
	return result;
}

operator * :: inline (a: V3, b: V3) -> V3 #symmetric {
	result: V3;
	result.x = a.x * b.x;
	result.y = a.y * b.y;
	result.z = a.z * b.z;
	return result;
}

operator / :: inline (a: V3, b: V3) -> V3 #symmetric {
	result: V3;
	result.x = a.x / b.x;
	result.y = a.y / b.y;
	result.z = a.z / b.z;
	return result;
}

operator + :: inline (a: V3, b: float) -> V3 #symmetric {
	result: V3;
	result.x = a.x + b;
	result.y = a.y + b;
	result.z = a.z + b;
	return result;
}

operator - :: inline (a: V3, b: float) -> V3 #symmetric {
	result: V3;
	result.x = a.x - b;
	result.y = a.y - b;
	result.z = a.z - b;
	return result;
}

operator * :: inline (a: V3, b: float) -> V3 #symmetric {
	result: V3;
	result.x = a.x * b;
	result.y = a.y * b;
	result.z = a.z * b;
	return result;
}

operator / :: inline (a: V3, b: float) -> V3 #symmetric {
	result: V3;
	result.x = a.x / b;
	result.y = a.y / b;
	result.z = a.z / b;
	return result;
}

operator *[] :: inline (v: V3, index: int) -> *float {
	return *v.components[index];
}

operator + :: inline (a: V4, b: V4) -> V4 #symmetric {
	result: V4;
	result.x = a.x + b.x;
	result.y = a.y + b.y;
	result.z = a.z + b.z;
	result.w = a.w + b.w;
	return result;
}

operator - :: inline (a: V4, b: V4) -> V4 #symmetric {
	result: V4;
	result.x = a.x - b.x;
	result.y = a.y - b.y;
	result.z = a.z - b.z;
	result.w = a.w - b.w;
	return result;
}

operator * :: inline (a: V4, b: V4) -> V4 #symmetric {
	result: V4;
	result.x = a.x * b.x;
	result.y = a.y * b.y;
	result.z = a.z * b.z;
	result.w = a.w * b.w;
	return result;
}

operator / :: inline (a: V4, b: V4) -> V4 #symmetric {
	result: V4;
	result.x = a.x / b.x;
	result.y = a.y / b.y;
	result.z = a.z / b.z;
	result.w = a.w / b.w;
	return result;
}

operator + :: inline (a: V4, b: float) -> V4 #symmetric {
	result: V4;
	result.x = a.x + b;
	result.y = a.y + b;
	result.z = a.z + b;
	result.w = a.w + b;
	return result;
}

operator - :: inline (a: V4, b: float) -> V4 #symmetric {
	result: V4;
	result.x = a.x - b;
	result.y = a.y - b;
	result.z = a.z - b;
	result.w = a.w - b;
	return result;
}

operator * :: inline (a: V4, b: float) -> V4 #symmetric {
	result: V4;
	result.x = a.x * b;
	result.y = a.y * b;
	result.z = a.z * b;
	result.w = a.w * b;
	return result;
}

operator / :: inline (a: V4, b: float) -> V4 #symmetric {
	result: V4;
	result.x = a.x / b;
	result.y = a.y / b;
	result.z = a.z / b;
	result.w = a.w / b;
	return result;
}

operator *[] :: inline (v: V4, index: int) -> *float {
	return *v.components[index];
}
