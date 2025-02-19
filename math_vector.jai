
Vec2 :: struct {
    x, y: float;
}

Vec3 :: struct {
    x, y, z: float;

#place x;
    xy: Vec2;

#place y;
    yz: Vec2;
}

Vec4 :: struct {
    x, y, z, w: float;

#place x;
    xy: Vec2;

#place y;
    yz: Vec2;

#place z;
    zw: Vec2;

#place x;
    xyz: Vec3;

#place y;
    yzw: Vec3;
}

v2 :: (xy: float) -> Vec2 { return .{xy, xy}; }
v3 :: (xyz: float) -> Vec3 { return .{xyz, xyz, xyz}; }
v4 :: (xyzw: float) -> Vec4 { return .{xyzw, xyzw, xyzw, xyzw}; }
v4 :: (xyz: Vec3, w: float) -> Vec4 { return .{xyz.x, xyz.y, xyz.z, w}; }

operator *[] :: (v: *Vec2, $i: int) -> *float {
#if i == 0 return *v.x;
    else #if i == 1 return *v.y;
    else #assert(false);
}

operator *[] :: (v: *Vec3, $i: int) -> *float {
#if i == 0 return *v.x;
    else #if i == 1 return *v.y;
    else #if i == 2 return *v.z;
    else #assert(false);
}

operator *[] :: (v: *Vec4, $i: int) -> *float {
#if i == 0 return *v.x;
    else #if i == 1 return *v.y;
    else #if i == 2 return *v.z;
    else #if i == 3 return *v.w;
    else #assert(false);
}

operator + :: inline (a: Vec2, b: Vec2) -> Vec2 #symmetric { return .{a.x + b.x, a.y + b.y}; }
operator + :: inline (a: Vec3, b: Vec3) -> Vec3 #symmetric { return .{a.x + b.x, a.y + b.y, a.z + b.z}; }
operator + :: inline (a: Vec4, b: Vec4) -> Vec4 #symmetric { return .{a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w}; }

operator - :: inline (a: Vec2, b: Vec2) -> Vec2 #symmetric { return .{a.x - b.x, a.y - b.y}; }
operator - :: inline (a: Vec3, b: Vec3) -> Vec3 #symmetric { return .{a.x - b.x, a.y - b.y, a.z - b.z}; }
operator - :: inline (a: Vec4, b: Vec4) -> Vec4 #symmetric { return .{a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w}; }
operator - :: inline (v: Vec2) -> Vec2 { return .{-v.x, -v.y}; }
operator - :: inline (v: Vec3) -> Vec3 { return .{-v.x, -v.y, -v.z}; }
operator - :: inline (v: Vec4) -> Vec4 { return .{-v.x, -v.y, -v.z, -v.w}; }

operator * :: inline (a: Vec2, b: Vec2) -> Vec2 #symmetric { return .{a.x * b.x, a.y * b.y}; }
operator * :: inline (a: Vec3, b: Vec3) -> Vec3 #symmetric { return .{a.x * b.x, a.y * b.y, a.z * b.z}; }
operator * :: inline (a: Vec4, b: Vec4) -> Vec4 #symmetric { return .{a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w}; }
operator * :: inline (a: Vec2, b: float) -> Vec2 { return .{a.x * b, a.y * b}; }
operator * :: inline (a: Vec3, b: float) -> Vec3 { return .{a.x * b, a.y * b, a.z * b}; }
operator * :: inline (a: Vec4, b: float) -> Vec4 { return .{a.x * b, a.y * b, a.z * b, a.w * b}; }

operator / :: inline (a: Vec2, b: Vec2) -> Vec2 #symmetric { return .{a.x / b.x, a.y / b.y}; }
operator / :: inline (a: Vec3, b: Vec3) -> Vec3 #symmetric { return .{a.x / b.x, a.y / b.y, a.z / b.z}; }
operator / :: inline (a: Vec4, b: Vec4) -> Vec4 #symmetric { return .{a.x / b.x, a.y / b.y, a.z / b.z, a.w / b.w}; }

length_squared :: inline (v: Vec2) -> float { return v.x*v.x + v.y*v.y; }
length_squared :: inline (v: Vec3) -> float { return v.x*v.x + v.y*v.y + v.z*v.z; }
length_squared :: inline (v: Vec4) -> float { return v.x*v.x + v.y*v.y + v.z*v.z + v.w*v.w; }
length :: inline (v: Vec2) -> float { return sqrt(v.x*v.x + v.y*v.y); }
length :: inline (v: Vec3) -> float { return sqrt(v.x*v.x + v.y*v.y + v.z*v.z); }
length :: inline (v: Vec4) -> float { return sqrt(v.x*v.x + v.y*v.y + v.z*v.z + v.w*v.w); }

normalize :: (v: Vec2, fallback := Vec2.{}) -> Vec2 {
    len := length(v);
    inv_length := 1.0 / len;
    if inv_length == 0.0 return fallback;
    return .{v.x * inv_length, v.y * inv_length};
}

normalize :: (v: Vec3, fallback := Vec3.{}) -> Vec3 {
    len := length(v);
    inv_length := 1.0 / len;
    if inv_length == 0.0 return fallback;
    return .{v.x * inv_length, v.y * inv_length, v.z * inv_length};
}

normalize :: (v: Vec4, fallback := Vec4.{}) -> Vec4 {
    len := length(v);
    inv_length := 1.0 / len;
    if inv_length == 0.0 return fallback;
    return .{v.x * inv_length, v.y * inv_length, v.z * inv_length, v.w * inv_length};
}

dot_product :: inline (a: Vec2, b: Vec2) -> float { return a.x*b.x + a.y*b.y; }
dot_product :: inline (a: Vec3, b: Vec3) -> float { return a.x*b.x + a.y*b.y + a.z*b.z; }
dot_product :: inline (a: Vec4, b: Vec4) -> float { return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w; }

distance_squared :: inline (a: Vec2, b: Vec2) -> float { return length_squared(a - b); }
distance_squared :: inline (a: Vec3, b: Vec3) -> float { return length_squared(a - b); }
distance_squared :: inline (a: Vec4, b: Vec4) -> float { return length_squared(a - b); }
distance :: inline (a: Vec2, b: Vec2) -> float { return length(a - b); }
distance :: inline (a: Vec3, b: Vec3) -> float { return length(a - b); }
distance :: inline (a: Vec4, b: Vec4) -> float { return length(a - b); }

lerp :: inline (a: Vec2, b: Vec2, t: float) -> Vec2 { return a + ((b - a) * t); }
lerp :: inline (a: Vec3, b: Vec3, t: float) -> Vec3 { return a + ((b - a) * t); }
lerp :: inline (a: Vec4, b: Vec4, t: float) -> Vec4 { return a + ((b - a) * t); }

clamp :: inline (v: Vec2, min: Vec2, max: Vec2) -> Vec2 {
    return .{
        clamp(v.x, min.x, max.x),
        clamp(v.y, min.y, max.y)};
}

clamp :: inline (v: Vec3, min: Vec3, max: Vec3) -> Vec3 {
    return .{
        clamp(v.x, min.x, max.x),
        clamp(v.y, min.y, max.y),
        clamp(v.z, min.z, max.z)
    };
}

clamp :: inline (v: Vec4, min: Vec4, max: Vec4) -> Vec4 {
    return .{
        clamp(v.x, min.x, max.x),
        clamp(v.y, min.y, max.y),
        clamp(v.z, min.z, max.z),
        clamp(v.w, min.w, max.w)
    };
}

min :: inline (a: Vec2, b: Vec2) -> Vec2 {
    return .{
        min(a.x, b.x),
        min(a.y, b.y)
    };
}

min :: inline (a: Vec3, b: Vec3) -> Vec3 {
    return .{
        min(a.x, b.x),
        min(a.y, b.y),
        min(a.z, b.z)
    };
}

min :: inline (a: Vec4, b: Vec4) -> Vec4 {
    return .{
        min(a.x, b.x),
        min(a.y, b.y),
        min(a.z, b.z),
        min(a.w, b.w)
    };
}

max :: inline (a: Vec2, b: Vec2) -> Vec2 {
    return .{
        max(a.x, b.x),
        max(a.y, b.y)
    };
}

max :: inline (a: Vec3, b: Vec3) -> Vec3 {
    return .{
        max(a.x, b.x),
        max(a.y, b.y),
        max(a.z, b.z)
    };
}

max :: inline (a: Vec4, b: Vec4) -> Vec4 {
    return .{
        max(a.x, b.x),
        max(a.y, b.y),
        max(a.z, b.z),
        max(a.w, b.w)
    };
}

cross_product :: inline (a: Vec3, b: Vec3) -> Vec3 {
    return .{
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    };
}

angle_between :: (a: Vec2, b: Vec2) -> float {
    length_a := length(a);
    if length_a == 0.0 return 0.0;

    length_b := length(b);
    if length_b == 0.0 return 0.0;

    return acos(dot_product(a, b) / (length_a * length_b)) * rad2turn;
}