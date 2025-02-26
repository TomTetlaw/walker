
#include "./shared.hlsl"

struct Frag_Input {
	float4 position: SV_Position;
	float3 world_position: TEXCOORD0;
	float3 view_position: TEXCOORD1;
	float4 colour: TEXCOORD2;
	float2 tex_coord: TEXCOORD3;
	float3 normal: TEXCOORD4;
	float3 tangent: TEXCOORD5;
	float4 material_params: TEXCOORD6;
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
	float4 view_position = mul(mul(view, instance.transform), float4(input.position, 1));
	
	float4x4 mvp = mul(projection, mul(view, instance.transform));
	float4 cs_position = mul(mvp, float4(input.position, 1));
	
	float3 normal = mul(adjoint(instance.transform), input.normal);
	float3 tangent = mul(adjoint(instance.transform), input.tangent);

	Frag_Input output;
	output.position = cs_position;
	output.world_position = world_position.xyz;
	output.view_position = view_position.xyz;
	output.colour = instance.colour * input.colour;
	output.tex_coord = input.tex_coord;
	output.normal = normal;
	output.tangent = tangent;
	output.material_params = instance.material_params;
	return output;
}

Texture2DArray<float> shadow_textures: register(t0, space2);
SamplerState shadow_sampler: register(s0, space2);

Texture2D diffuse_texture: register(t1, space2);
SamplerState diffuse_sampler: register(s1, space2);

Texture2D normal_texture: register(t2, space2);
SamplerState normal_sampler: register(s2, space2);

cbuffer Constant_Buffer : register(b0, space3) {
	float4 camera_position;
	float4 camera_direction;
	float4 light_params;
	float4 light_direction;
	float4 light_colour;
	float4 time;
	float4 cascades;
	row_major float4x4 light_matrices[SHADOW_CASCADE_COUNT];
};

float4 frag_main(Frag_Input input): SV_Target {
	float2 tex_coord = input.tex_coord * input.material_params.xy;
	
	float depth = input.position.z / input.position.w;
	
	float3 diffuse = input.colour.rgb * diffuse_texture.Sample(diffuse_sampler, tex_coord).rgb;

	float3 tangent = input.tangent;
	
	float3 normal = normal_texture.Sample(normal_sampler, tex_coord).rgb * 2 - 1;
	float3x3 tbn = float3x3(tangent, cross(input.normal, tangent), input.normal);
	normal = normalize(mul(tbn, normal));
	
	Intermediates intermediates;
	intermediates.world_position = input.world_position;
	intermediates.view_position = input.view_position;
	intermediates.normal = normal;
	intermediates.vertex_normal = input.normal;
	intermediates.colour = diffuse;
	intermediates.camera_position = camera_position.xyz;
	intermediates.camera_direction = camera_direction.xyz;
	intermediates.time = time;
	
	intermediates.cascades = cascades;
	intermediates.light_matrices = light_matrices;
	intermediates.shadow_textures = shadow_textures;
	intermediates.shadow_sampler = shadow_sampler;
	
	Light light;
	light.direction = light_direction.xyz;
	light.colour = light_colour.rgb;
	light.ambient_intensity = light_params.x;
	light.diffuse_intensity = light_params.y;
	light.specular_intensity = light_params.z;
	light.specular_shininess = light_params.w;
	
	apply_shadow(intermediates, light);
	apply_lighting_directional(intermediates, light);
	apply_fog(intermediates, light);
	
    return float4(intermediates.colour, input.colour.a);
}
