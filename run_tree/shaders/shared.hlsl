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

/*
void apply_fog(inout Intermediates intermediates, Light light)
{
	float a = 0.00020;
	float b = 0.001;
	
	float distance = length(intermediates.view_position - intermediates.world_position);
	float3 view = normalize(intermediates.view_position - intermediates.world_position);
    
	float world_height = intermediates.world_position.z;
	float eye_height = intermediates.view_position.z;
	float view_z = view.z;
	
	float fog_amount = (a/b) * exp(-eye_height * b) * (1.0 - exp(-distance * view_z * b)) / view_z;
	
	float height_factor = pow(exp(-max(world_height, 0.0) * b), 1.5);
	fog_amount *= height_factor;
	
	float sun_amount = max(dot(view, light.dir), 0.0);
	float3 fog_colour = lerp(float3(0.5, 0.6, 0.7), light.colour, pow(sun_amount, 8.0));
	
	intermediates.colour = lerp(intermediates.colour, fog_colour, saturate(fog_amount));
}
*/

// Simple 3D hash noise (based on common shader techniques)
float hash(float3 p) {
    p = frac(p * 0.3183099 + 0.1);
    return frac(sin(dot(p, float3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(float3 p) {
    float3 i = floor(p);
    float3 f = frac(p);
    float3 u = f * f * (3.0 - 2.0 * f); // Smoothstep
    return lerp(
        lerp(
            lerp(hash(i + float3(0,0,0)), hash(i + float3(1,0,0)), u.x),
            lerp(hash(i + float3(0,1,0)), hash(i + float3(1,1,0)), u.x),
            u.y),
        lerp(
            lerp(hash(i + float3(0,0,1)), hash(i + float3(1,0,1)), u.x),
            lerp(hash(i + float3(0,1,1)), hash(i + float3(1,1,1)), u.x),
            u.y),
        u.z);
}

float fractal_noise(float3 p, int octaves, float persistence) {
	float total = 0;
	float amplitude = 1;
	float max_value = 0.0;
	
	for (int i = 0; i < octaves; i++) {
		total += amplitude * noise(p * pow(2.0, i));
		max_value += amplitude;
		amplitude *= persistence;
	}
	
	return saturate(total / max_value);
}

void apply_fog(inout Intermediates intermediates, Light light)
{
    float a = 0.00025;    // Base fog density
    float b = 0.001;      // Distance decay rate
    float height_b = 0.0005; // Height decay rate
    const int NUM_SAMPLES = 32; // Number of samples along ray (adjust for quality/performance)
    
    // Distance and view direction
    float distance = length(intermediates.view_position - intermediates.world_position);
    float3 view = normalize(intermediates.view_position - intermediates.world_position);
    
    float eye_height = intermediates.view_position.z;
    float view_z = view.z;
    
    // Base uniform fog (for reference, we'll modify this)
    float base_fog_amount = (a / b) * exp(-eye_height * b) * (1.0 - exp(-distance * view_z * b)) / view_z;
    
    // Variable density accumulation
    float accumulated_density = 0.0;
    float step_size = distance / NUM_SAMPLES;
	float3 ray_start = intermediates.world_position;
    float3 ray_end = intermediates.view_position;
	float3 ray_dir = -view;
    float noise_scale = 0.01; // Scale of noise (smaller = finer detail)
    
    for (int i = 0; i < NUM_SAMPLES; i++) {
        float t = step_size * (i + 0.5); // Sample at midpoint of each step
        float3 sample_pos = ray_start + ray_dir * t;
		
        sample_pos.z += intermediates.time.x;
		
        // Noise-based density variation
        float noise_val = fractal_noise(sample_pos * noise_scale, 5, .125);
        float local_density = a * (0.5 + noise_val * 0.5); // Vary density between 0.5a and a
        
        // Reduce density with height
        float height_factor = exp(-max(sample_pos.z, 0.0) * height_b);
        local_density *= height_factor;
        
        // Accumulate density over step
        accumulated_density += local_density * step_size;
    }
    
    // Final fog amount (clamped)
    float fog_amount = saturate(pow(accumulated_density,.5));
    
    // Sun influence and fog color
    float sun_amount = max(dot(view, light.dir), 0.0);
    float3 fog_colour = lerp(float3(0.5, 0.5, 0.5), light.colour, pow(sun_amount, 8.0));
    
    // Apply fog
    intermediates.colour = lerp(intermediates.colour, fog_colour, fog_amount);
	
	intermediates.colour = float3(accumulated_density, accumulated_density, accumulated_density);
}