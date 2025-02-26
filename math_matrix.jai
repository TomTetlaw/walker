
Mat4 :: struct {
    _11, _12, _13, _14: float;
    _21, _22, _23, _24: float;
    _31, _32, _33, _34: float;
    _41, _42, _43, _44: float;

#place _11;
    rows: [4] Vec4 = ---;
#place _11;
    coef: [4][4] float = ---;
#place _11;
    floats: [16] float = ---;
}

operator *[] :: (m: *Mat4, index: int) -> *Vec4 {
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

operator * :: (m: Mat4, b: Vec4) -> Vec4 {
    result: Vec4;

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

mat4_translation :: (t: Vec3) -> Mat4 {
    result := mat4_identity;

    result._14 = t.x;
    result._24 = t.y;
    result._34 = t.z;

    return result;
}

mat4_translate :: (m: Mat4, v: Vec3) -> Mat4 {
    result := m;

    result.coef[0][3] += result.coef[0][0]*v.x + result.coef[0][1]*v.y + result.coef[0][2]*v.z;
    result.coef[1][3] += result.coef[1][0]*v.x + result.coef[1][1]*v.y + result.coef[1][2]*v.z;
    result.coef[2][3] += result.coef[2][0]*v.x + result.coef[2][1]*v.y + result.coef[2][2]*v.z;
    result.coef[3][3] += result.coef[3][0]*v.x + result.coef[3][1]*v.y + result.coef[3][2]*v.z;

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

mat4_scale :: (s: Vec3) -> Mat4 {
    result: Mat4 = ---;

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

    return result * view_coords_to_projection_coords();
}

mat4_ortho :: (left: float, right: float, bottom: float, top: float, near: float, far: float) -> Mat4 {
    result: Mat4;

    result._11 = 2.0 / (right - left);
    result._14 = -(right + left) / (right - left);

    result._22 = 2.0 / (top - bottom);
    result._24 = -(top + bottom) / (top - bottom);

    result._33 = -2 / (far - near);
    result._34 = -(far + near) / (far - near);

    result._44 = 1.0;

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
    a := Vec3.{m._11, m._21, m._31};
    b := Vec3.{m._12, m._22, m._32};
    c := Vec3.{m._13, m._23, m._33};
    d := Vec3.{m._14, m._24, m._34};

    x := m._41;
    y := m._42;
    z := m._43;
    w := m._44;

    s := cross_product(a, b);
    t := cross_product(c, d);
    u := a * y - b * x;
    v := c * w - d * z;

    det := dot_product(s, v) + dot_product(t, u);
    inv_det := 1.0 / det;
    s *= inv_det;
    t *= inv_det;
    u *= inv_det;
    v *= inv_det;

    r0 := cross_product(b, v) + t * y;
    r1 := cross_product(v, a) - t * x;
    r2 := cross_product(d, u) + s * w;
    r3 := cross_product(u, c) - s * z;

    result := Mat4.{
        r0.x, r0.y, r0.z, -dot_product(b, t),
        r1.x, r1.y, r1.z,  dot_product(a, t),
        r2.x, r2.y, r2.z, -dot_product(d, s),
        r3.x, r3.y, r3.z,  dot_product(c, s)
    };

    epsilon := 0.0001;
    return result, abs(det) < epsilon;
}

mat4_look_at :: (position: Vec3, target: Vec3) -> Mat4 {
    forward := normalize(target - position);
    left := normalize(cross_product(.{0, 0, 1}, forward));
    up := normalize(cross_product(forward, left));

    rotation := mat4_from_rows(left * -1, up, forward * -1);
    result := mat4_translate(rotation, -position);

    return result;
}

mat4_from_rows :: (x: Vec3, y: Vec3, z: Vec3) -> Mat4 {
    result: Mat4;

    result._11 = x.x;
    result._12 = x.y;
    result._13 = x.z;

    result._21 = y.x;
    result._22 = y.y;
    result._23 = y.z;

    result._31 = z.x;
    result._32 = z.y;
    result._33 = z.z;

    result._44 = 1;

    return result;
}

#scope_file

// thanks to this article!
// https://johannesugb.github.io/gpu-programming/setting-up-a-proper-vulkan-Projection-matrix/
view_coords_to_projection_coords :: () -> Mat4 {
    result: Mat4;

    result._12 = -1.0;
    result._23 = 1.0;
    result._31 = -1.0;
    result._44 = 1.0;

    return result;
}

view_coords_to_ortho_coords :: () -> Mat4 {
    result: Mat4;

    result._12 = -1.0;
    result._14 = 1.0;

    result._23 = 1.0;
    result._24 = 1.0;

    result._31 = -1.0;
    result._34 = 1.0;

    result._44 = 1.0;

    return result;
}