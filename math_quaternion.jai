
Quaternion :: struct {
    x, y, z:  float;
    w := 1.0;

#place x;
    xyz: Vec3;
}

operator [] :: (q: Quaternion, $i: int) -> float {
#if i == 0 return q.x;
    else #if i == 1 return q.y;
    else #if i == 2 return q.z;
    else #if i == 3 return q.w;
    else #assert(false);
}

dot_product :: (a: Quaternion, b: Quaternion) -> float {
    return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w;
}

length :: (q: Quaternion) -> float {
    return sqrt(q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w);
}

length_squared :: (q: Quaternion) -> float {
    return q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w;
}

normalize :: (q: Quaternion, fallback := Quaternion.{}) -> Quaternion {
    len := length(q);
    if len == 0.0 return fallback;
    inv_length := 1.0 / len;
    return q * inv_length;
}

lerp :: (a: Quaternion, b: Quaternion, t: float) -> Quaternion {
    result: Quaternion = ---;

    result.x = a.x + t * (b.x - a.x);
    result.y = a.y + t * (b.y - a.y);
    result.z = a.z + t * (b.z - a.z);
    result.w = a.w + t * (b.w - a.w);

    return result;
}

nlerp :: inline (a: Quaternion, b: Quaternion, t: float) -> Quaternion {
    result := normalize(lerp(a, b, t));
    return result;
}

slerp :: (a: Quaternion, b: Quaternion, t: float) -> Quaternion {
    dot := clamp(dot_product(a, b), -1.0, 1.0);
    theta := acos(dot) * t;
    return (a * cos(theta)) + (normalize(b - a * dot) * sin(theta));
}

approach :: (c: float, g: float, time_to_goal: float, delta: float) -> float {
    decay :: 4.6;
    return g + (c - g) * exp(-decay * delta * (1.0 / time_to_goal));
}

rotate :: (v: Vec2, turns: float) -> Vec2 {
    s := sin_turns(turns);
    c := cos_turns(turns);

    return .{
        v.x*c + v.y*s,
        v.x*-s + v.y*c
    };
}

quat_to_forward :: (q: Quaternion) -> Vec3 {
    return mat4_inverse(mat4_rotation(q))[0].xyz;
}

rotate :: (v: Vec3, q: Quaternion) -> Vec3 {
    t := cross_product(q.xyz, v) * 2.0;
    return v + t * q.w + cross_product(q.xyz, t);
}

quat_from_axis_angle :: (axis: Vec3, turns: float) -> Quaternion {
    s := sin_turns(turns * 0.5);
    c := cos_turns(turns * 0.5);

    return .{
        axis.x * s,
        axis.y * s,
        axis.z * s,
        c
    };
}

operator * :: (a: Quaternion, b: Quaternion) -> Quaternion {
    v := a.xyz;
    av := b.xyz;

    r: Quaternion;
    r.w = a.w * b.w - dot_product(v, av);

    rv := cross_product(v, av);

    av *= a.w;
    v  *= b.w;

    rv = rv + av + v;

    r.x = rv.x;
    r.y = rv.y;
    r.z = rv.z;

    return r;
}

operator + :: (a: Quaternion, b: Quaternion) -> Quaternion {
    return .{a.x+b.x, a.y+b.y, a.z+b.z, a.w+b.w};
}

operator * :: (a: Quaternion, b: float) -> Quaternion #symmetric {
    return .{a.x*b, a.y*b, a.z*b, a.w*b};
}

operator - :: (a: Quaternion, b: Quaternion) -> Quaternion {
    return .{a.x-b.x, a.y-b.y, a.z-b.z, a.w-b.w};
}

operator - :: (a: Quaternion) -> Quaternion {
    return .{-a.x, -a.y, -a.z, -a.w};
}