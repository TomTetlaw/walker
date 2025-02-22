float3x3 adjoint(float4x4 m) {
    return float3x3(cross(m[1].xyz, m[2].xyz), cross(m[2].xyz, m[0].xyz), cross(m[0].xyz, m[1].xyz));
}

float4 fractal_texture(Texture2D map, SamplerState sampler, float2 tex_coord, float depth) {
    float LOD = log(depth);
    float LOD_floor = floor(LOD);
    float LOD_fract = LOD - LOD_floor;
    
    float4 tex0 = map.Sample(sampler, tex_coord / exp(LOD_floor - 1.0));
    float4 tex1 = map.Sample(sampler, tex_coord / exp(LOD_floor + 0.0));
    float4 tex2 = map.Sample(sampler, tex_coord / exp(LOD_floor + 1.0));
    
    return (tex1 + lerp(tex0, tex2, LOD_fract)) * 0.5;
}

float4 fractal_texture_mip(Texture2D map, SamplerState sampler, float2 tex_coord, float depth) {
    float LOD = log(depth);
    float LOD_floor = floor(LOD);
    float LOD_fract = LOD - LOD_floor;
    
    float2 t0 = tex_coord / exp(LOD_floor - 1.0);
    float2 t1 = tex_coord / exp(LOD_floor + 0.0);
    float2 t2 = tex_coord / exp(LOD_floor + 1.0);
    
    float2 dx = ddx(tex_coord) / depth * exp(1.0);
    float2 dy = ddy(tex_coord) / depth * exp(1.0);
    
    float4 tex0 = map.SampleGrad(sampler, t0, dx, dy);
    float4 tex1 = map.SampleGrad(sampler, t1, dx, dy);
    float4 tex2 = map.SampleGrad(sampler, t2, dx, dy);
    
    return (tex1 + lerp(tex0, tex2, LOD_fract)) * 0.5;
}

struct Intermediates {
	float3 world_position;
	float3 normal;
	float3 colour;
	
	float3 view_position;
	float3 view_direction;
};

struct Light {
	float3 dir;
	float3 colour;
	float ambient_intensity;
	float diffuse_intensity;
	float specular_intensity;
	float specular_shininess;
};

void apply_lighting_directional(inout Intermediates intermediates, Light light) {
	float3 L = normalize(-light.dir);
	float3 V = normalize(intermediates.view_position - intermediates.world_position);
		 
	float diffuse_lighting = max(dot(intermediates.normal, L), 0) * light.diffuse_intensity;
	
	float3 half_dir = normalize(L + V);
	float specular_lighting = pow(max(dot(intermediates.normal, half_dir), 0.0), light.specular_shininess) * light.specular_intensity;
	
	float lighting = light.ambient_intensity + diffuse_lighting + specular_lighting;
	intermediates.colour = intermediates.colour * light.colour * lighting;
}

void apply_fog(inout Intermediates intermediates, Light light)
{
	float a = 0.00025;
	float b = 0.001;
	
	float distance = length(intermediates.view_position - intermediates.world_position);
	float3 view = normalize(intermediates.view_position - intermediates.world_position);
    
	float eye_height = intermediates.view_position.z;
	float view_z = view.z;
	
	float fog_amount = (a/b) * exp(-eye_height * b) * (1.0 - exp(-distance * view_z * b)) / view_z;
	
	float sun_amount = max(dot(view, light.dir), 0.0);
	float3 fog_colour = lerp(float3(0.5, 0.5, 0.5), light.colour, pow(sun_amount, 8.0));
	
	intermediates.colour = lerp(intermediates.colour, fog_colour, saturate(fog_amount));
}