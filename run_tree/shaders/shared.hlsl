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
	float3 vertex_normal;
	float3 colour;
	
	float3 view_position;
	float3 view_direction;
	
	float4 time;
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

float hash(float2 p) {
    p = frac(p * 0.3183099 + 0.1);
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float noise_2d(float2 p) {
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(
		lerp(hash(i + float2(0,0)), hash(i + float2(1,0)), u.x),
        lerp(hash(i + float2(0,1)), hash(i + float2(1,1)), u.x),
    u.y);
}

float3 hash_gradient(float3 p) {
    float3 h = float3(
        dot(p, float3(127.1, 311.7, 74.7)),
        dot(p, float3(269.5, 183.3, 246.1)),
        dot(p, float3(113.5, 271.9, 124.6))
    );
    return normalize(frac(sin(h) * 43758.5453) * 2.0 - 1.0);
}

float noise_3d(float3 p) {
    float3 i = floor(p);
    float3 f = frac(p);
    
    float3 u = f * f * (3.0 - 2.0 * f);
    
    float3 g000 = hash_gradient(i + float3(0, 0, 0));
    float3 g100 = hash_gradient(i + float3(1, 0, 0));
    float3 g010 = hash_gradient(i + float3(0, 1, 0));
    float3 g110 = hash_gradient(i + float3(1, 1, 0));
    float3 g001 = hash_gradient(i + float3(0, 0, 1));
    float3 g101 = hash_gradient(i + float3(1, 0, 1));
    float3 g011 = hash_gradient(i + float3(0, 1, 1));
    float3 g111 = hash_gradient(i + float3(1, 1, 1));
    
    float3 d000 = f - float3(0, 0, 0);
    float3 d100 = f - float3(1, 0, 0);
    float3 d010 = f - float3(0, 1, 0);
    float3 d110 = f - float3(1, 1, 0);
    float3 d001 = f - float3(0, 0, 1);
    float3 d101 = f - float3(1, 0, 1);
    float3 d011 = f - float3(0, 1, 1);
    float3 d111 = f - float3(1, 1, 1);
    
    float n000 = dot(g000, d000);
    float n100 = dot(g100, d100);
    float n010 = dot(g010, d010);
    float n110 = dot(g110, d110);
    float n001 = dot(g001, d001);
    float n101 = dot(g101, d101);
    float n011 = dot(g011, d011);
    float n111 = dot(g111, d111);
    
    float nx00 = lerp(n000, n100, u.x);
    float nx10 = lerp(n010, n110, u.x);
    float nx01 = lerp(n001, n101, u.x);
    float nx11 = lerp(n011, n111, u.x);
    
    float nxy0 = lerp(nx00, nx10, u.y);
    float nxy1 = lerp(nx01, nx11, u.y);
    
    float nxyz = lerp(nxy0, nxy1, u.z);
    
    return nxyz * .5 + 0.5;
}

float fractal_noise_3d(float3 p, int octaves, float persistence) {
	float total = 0;
	float amplitude = 1;
	float max_value = 0.0;
	
	for (int i = 0; i < octaves; i++) {
		total += amplitude * noise_3d(p * pow(2.0, i));
		max_value += amplitude;
		amplitude *= persistence;
	}
	
	return saturate(total / max_value);
}

float fractal_noise_2d(float2 p, int octaves, float persistence) {
	float total = 0;
	float amplitude = 1;
	float max_value = 0.0;
	
	for (int i = 0; i < octaves; i++) {
		total += amplitude * noise_2d(p * pow(2.0, i));
		max_value += amplitude;
		amplitude *= persistence;
	}
	
	return saturate(total / max_value);
}

void apply_fog(inout Intermediates intermediates, Light light)
{
    float a = 0.001;
    float b = 0.001;
    float height_b = 0.00015;
    const int NUM_SAMPLES = 16;
    
    float distance = length(intermediates.view_position - intermediates.world_position);
    float3 view = normalize(intermediates.view_position - intermediates.world_position);
    
    float eye_height = intermediates.view_position.z;
    float view_z = view.z;
    
    float base_fog_amount = (a / b) * exp(-eye_height * b) * (1.0 - exp(-distance * view_z * b)) / view_z;
    
    float accumulated_density = 0.0;
    float step_size = distance / NUM_SAMPLES;
	float3 ray_start = intermediates.world_position;
	float3 ray_dir = -view;
    float noise_scale = 0.01;

    for (int i = 0; i < NUM_SAMPLES; i++) {
        float t = step_size * (i + 0.5);
        float3 sample_pos = ray_start + ray_dir * t;
		
		float fog_speed = 50;
		sample_pos.xy -= intermediates.time.x * fog_speed *.5;
		sample_pos.z += intermediates.time.x * fog_speed;
		
        float noise_val = noise_3d(sample_pos * noise_scale);
		float min_a = .1;
        float local_density = a * (min_a + noise_val * (1 - min_a));
		
		float height_factor = exp(-max(ray_start.z, 0.0) * height_b);
		accumulated_density *= height_factor;
        
        accumulated_density += local_density * step_size;
    }
    
    float fog_amount = saturate(accumulated_density);
    
    float sun_amount = max(dot(view, light.dir), 0.0);
    float3 fog_colour = lerp(float3(0.7, 0.7, 0.7), light.colour, pow(sun_amount, 8.0));
    
    intermediates.colour = lerp(intermediates.colour, fog_colour, min(fog_amount, .8));
}