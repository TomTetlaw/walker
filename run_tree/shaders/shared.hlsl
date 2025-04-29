
#define sample_texture(name, tex_coord) name##_texture.Sample(name##_sampler, tex_coord)

float3x3 adjoint(float4x4 m) {
    return float3x3(cross(m[1].xyz, m[2].xyz), cross(m[2].xyz, m[0].xyz), cross(m[0].xyz, m[1].xyz));
}