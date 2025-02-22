
#include "./shared.hlsl"

struct Frag_Input {
	float4 position: SV_Position;
	float3 world_position: TEXCOORD0;
	float4 colour: TEXCOORD1;
	float2 tex_coord: TEXCOORD2;
	float3 normal: TEXCOORD3;
	float3 tangent: TEXCOORD4;
	float4 material_params: TEXCOORD5;
};

struct Instance_Data {
	row_major float4x4 transform;
	float4 colour;
	float4 material_params;
};

StructuredBuffer<Instance_Data> instance_buffer: register(t0, space0);

cbuffer Constant_Buffer : register(b0, space1) {
	row_major float4x4 view;
	row_major float4x4 projection;
};

struct Vertex_Input {
	float3 position: POSITION;
	float4 colour: TEXCOORD0;
	float2 tex_coord: TEXCOORD1;
	float3 normal: TEXCOORD2;
	float3 tangent: TEXCOORD3;
};

Frag_Input vert_main(Vertex_Input input, uint instance_id: SV_InstanceId) {
	Instance_Data instance = instance_buffer[instance_id];

	float4 world_position = mul(instance.transform, float4(input.position, 1));
	
	float4x4 mvp = mul(projection, mul(view, instance.transform));
	float4 cs_position = mul(mvp, float4(input.position, 1));
	
	float3 normal = mul(adjoint(instance.transform), input.normal);
	float3 tangent = mul(adjoint(instance.transform), input.tangent);

	Frag_Input output;
	output.position = cs_position;
	output.world_position = world_position.xyz;
	output.colour = instance.colour * input.colour;
	output.tex_coord = input.tex_coord;
	output.normal = normal;
	output.tangent = tangent;
	output.material_params = instance.material_params;
	return output;
}

// Texture2D shadow_texture: register(t0, space2);
// SamplerState shadow_sampler: register(s0, space2);

Texture2D diffuse_texture: register(t0, space2);
SamplerState diffuse_sampler: register(s0, space2);

Texture2D normal_texture: register(t1, space2);
SamplerState normal_sampler: register(s1, space2);

cbuffer Constant_Buffer : register(b0, space3) {
	float4 camera_position;
	float4 camera_direction;
	float4 light_params;
	float4 directional_light_dir;
	float4 directional_light_colour;
	float4 time;
};

float4 frag_main(Frag_Input input): SV_Target {
	float2 tex_coord = input.tex_coord * input.material_params.xy;
	
	float depth = (input.position.z / input.position.w) +1;
	
	float3 diffuse = input.colour.rgb * fractal_texture_mip(diffuse_texture, diffuse_sampler, tex_coord, depth).rgb;

	float3 tangent = input.tangent;
	
	float3 normal = fractal_texture_mip(normal_texture, normal_sampler, tex_coord, depth).rgb * 2 - 1;
	float3x3 tbn = float3x3(tangent, cross(input.normal, tangent), input.normal);
	normal = normalize(mul(tbn, normal));
	
	// apply mountain peak highlights
    float cosTheta = dot(normalize(normal), float3(0.0, 0.0, 1.0));
    float slope = saturate(1.0 - cosTheta);
	float mask = smoothstep(150, 350, input.world_position.z);
	
	float3 colour = diffuse;
	colour *= 1 - mask;
	colour += (float3(1,1,1) * (1 - slope) * mask);
	colour += diffuse * slope * mask;
	
	Intermediates intermediates;
	intermediates.world_position = input.world_position;
	intermediates.normal = normal;
	intermediates.vertex_normal = input.normal;
	intermediates.colour = colour;
	intermediates.view_position = camera_position.xyz;
	intermediates.view_direction = camera_direction.xyz;
	intermediates.time = time;
	
	Light light;
	light.dir = directional_light_dir.xyz;
	light.colour = directional_light_colour.rgb;
	light.ambient_intensity = light_params.x;
	light.diffuse_intensity = light_params.y;
	light.specular_intensity = light_params.z;
	light.specular_shininess = light_params.w;
	
	apply_lighting_directional(intermediates, light);
	apply_fog(intermediates, light);
    
    return float4(intermediates.colour, input.colour.a);
}
