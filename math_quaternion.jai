
Quaternion :: struct {
    x, y, z:  float;
    w := 1.0;

#place x;
    xyz: V3;
}

dot :: (a: Quaternion, b: Quaternion) -> float {
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
    d := clamp(dot(a, b), -1.0, 1.0);
    theta := acos(d) * t;
    return (a * cos(theta)) + (normalize(b - a * d) * sin(theta));
}

quat_to_forward :: (q: Quaternion) -> V3 {
    return mat4_inverse(mat4_rotation(q))[0].xyz;
}

rotate :: (v: V3, q: Quaternion) -> V3 {
    t := cross(q.xyz, v) * 2.0;
    return v + t * q.w + cross(q.xyz, t);
}

quat_from_axis_angle :: (axis: V3, turns: float) -> Quaternion {
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
    r.w = a.w * b.w - dot(v, av);

    rv := cross(v, av);

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