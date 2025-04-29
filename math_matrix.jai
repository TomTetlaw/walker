
Mat4 :: struct {
    _11, _12, _13, _14: float;
    _21, _22, _23, _24: float;
    _31, _32, _33, _34: float;
    _41, _42, _43, _44: float;

#place _11;
    rows: [4] V4;
#place _11;
    coef: [4][4] float;
#place _11;
    floats: [16] float;
}

operator *[] :: (m: *Mat4, index: int) -> *V4 {
    return *m.rows[index];
}

operator * :: (a: Mat4, b: Mat4) -> Mat4 {
    result: Mat4 = ---;

    result._11 = a._11*b._11 + a._12*b._21 + a._13*b._31 + a._14*b._41;
    result._21 = a._21*b._11 + a._22*b._21 + a._23*b._31 + a._24*b._41;
    result._31 = a._31*b._11 + a._32*b._21 + a._33*b._31 + a._34*b._41;
    result._41 = a._41*b._11 + a._42*b._21 + a._43*b._31 + a._44*b._41;

    result._12 = a._11*b._12 + a._12*b._22 + a._13*b._32 + a._14*b._42;
    result._22 = a._21*b._12 + a._22*b._22 + a._23*b._32 + a._24*b._42;
    result._32 = a._31*b._12 + a._32*b._22 + a._33*b._32 + a._34*b._42;
    result._42 = a._41*b._12 + a._42*b._22 + a._43*b._32 + a._44*b._42;

    result._13 = a._11*b._13 + a._12*b._23 + a._13*b._33 + a._14*b._43;
    result._23 = a._21*b._13 + a._22*b._23 + a._23*b._33 + a._24*b._43;
    result._33 = a._31*b._13 + a._32*b._23 + a._33*b._33 + a._34*b._43;
    result._43 = a._41*b._13 + a._42*b._23 + a._43*b._33 + a._44*b._43;

    result._14 = a._11*b._14 + a._12*b._24 + a._13*b._34 + a._14*b._44;
    result._24 = a._21*b._14 + a._22*b._24 + a._23*b._34 + a._24*b._44;
    result._34 = a._31*b._14 + a._32*b._24 + a._33*b._34 + a._34*b._44;
    result._44 = a._41*b._14 + a._42*b._24 + a._43*b._34 + a._44*b._44;

    return result;
}

operator * :: (m: Mat4, b: V4) -> V4 {
    result: V4;

    result.x = b.x * m._11 + b.y * m._12 + b.z * m._13 + b.w * m._14;
    result.y = b.x * m._21 + b.y * m._22 + b.z * m._23 + b.w * m._24;
    result.z = b.x * m._31 + b.y * m._32 + b.z * m._33 + b.w * m._34;
    result.w = b.x * m._41 + b.y * m._42 + b.z * m._43 + b.w * m._44;

    return result;
}

mat4_identity :: Mat4.{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
};

mat4_translation :: (t: V3) -> Mat4 {
    result := mat4_identity;

    result._14 = t.x;
    result._24 = t.y;
    result._34 = t.z;

    return result;
}

mat4_rotation :: (q: Quaternion) -> Mat4 {
    m := mat4_identity;
    s :: 2.0;

    xs := q.x * s;
    ys := q.y * s;
    zs := q.z * s;

    wx := q.w * xs;
    wy := q.w * ys;
    wz := q.w * zs;

    _xx := q.x * xs;
    xy := q.x * ys;
    xz := q.x * zs;

    yy := q.y * ys;
    yz := q.y * zs;
    zz := q.z * zs;

    m._11 = 1.0 - (yy + zz);
    m._12 = xy - wz;
    m._13 = xz + wy;

    m._21 = xy + wz;
    m._22 = 1.0 - (_xx + zz);
    m._23 = yz - wx;

    m._31 = xz - wy;
    m._32 = yz + wx;
    m._33 = 1.0 - (_xx + yy);

    return m;
}

mat4_scale :: (s: V3) -> Mat4 {
    result: Mat4;

    result._11 = s.x;
    result._22 = s.y;
    result._33 = s.z;
    result._44 = 1.0;

    return result;
}

mat4_projection :: (fov_turns: float, aspect: float, near: float, far: float) -> Mat4 {
    result := mat4_identity;

    tan_theta := tan_turns(fov_turns * 0.5);
    cot_theta := 1.0 / tan_theta;

    n := near;
    f := far;
    d := 1.0 / (f - n);

    result._11 = cot_theta / aspect;
    result._22 = cot_theta;
    result._33 = -f * d;
    result._34 = -f * n * d;
    result._43 = -1.0;
    result._44 = 0;

    return result * vulkan_projection_coord_conversion();
}

mat4_ortho :: (left: float, right: float, bottom: float, top: float, near: float, far: float) -> Mat4 {
    result: Mat4;

    result._11 = 1.0 / (far - near);
    result._14 = -near / (far - near);

    result._22 = 2.0 / (right - left);
    result._24 = -(right + left) / (right - left);

    result._33 = 2.0 / (top - bottom);
    result._34 = -(top + bottom) / (top - bottom);

    result._44 = 1.0;

    return result;
}

mat4_look_at :: (position: V3, target: V3, up_dir := V3.{0, 0, 1}) -> Mat4 {
    forward := normalize(target - position);
    left := normalize(cross(up_dir, forward));
    up := normalize(cross(forward, left));

    result: Mat4;
    result.rows[0] = v4(forward, -dot(forward, position));
    result.rows[1] = v4(left, -dot(left, position));
    result.rows[2] = v4(up, -dot(up, position));
    result.rows[3] = .{0, 0, 0, 1};
    return result;
}

mat4_transpose :: (m: Mat4) -> Mat4 {
    r: Mat4 = ---;

    for i: 0..3 for j: 0..3 {
        r.coef[i][j] = m.coef[j][i];
    }

    return r;
}

mat4_inverse :: (m: Mat4) -> Mat4, bool {
    a := V3.{m._11, m._21, m._31};
    b := V3.{m._12, m._22, m._32};
    c := V3.{m._13, m._23, m._33};
    d := V3.{m._14, m._24, m._34};

    x := m._41;
    y := m._42;
    z := m._43;
    w := m._44;

    s := cross(a, b);
    t := cross(c, d);
    u := a * y - b * x;
    v := c * w - d * z;

    det := dot(s, v) + dot(t, u);
    inv_det := 1.0 / det;
    s *= inv_det;
    t *= inv_det;
    u *= inv_det;
    v *= inv_det;

    r0 := cross(b, v) + t * y;
    r1 := cross(v, a) - t * x;
    r2 := cross(d, u) + s * w;
    r3 := cross(u, c) - s * z;

    result := Mat4.{
        r0.x, r0.y, r0.z, -dot(b, t),
        r1.x, r1.y, r1.z,  dot(a, t),
        r2.x, r2.y, r2.z, -dot(d, s),
        r3.x, r3.y, r3.z,  dot(c, s)
    };

    epsilon := 0.0001;
    return result, abs(det) < epsilon;
}

#scope_file

// thanks to this article!
// https://johannesugb.github.io/gpu-programming/setting-up-a-proper-vulkan-Projection-matrix/
vulkan_projection_coord_conversion :: () -> Mat4 {
    result: Mat4;

    result._12 = -1.0;
    result._23 = 1.0;
    result._31 = -1.0;
    result._44 = 1.0;

    return result;
}
