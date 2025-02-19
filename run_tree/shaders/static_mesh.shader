struct Frag_Input {
	float4 position: SV_Position;
	float3 world_position: TEXCOORD0;
	float4 colour: TEXCOORD1;
	float2 tex_coord: TEXCOORD2;
	float3 normal: TEXCOORD3;
	float3 tangent: TEXCOORD4;
};

struct Instance_Data {
	row_major float4x4 transform;
	float4 colour;
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

	Frag_Input output;
	output.position = cs_position;
	output.world_position = world_position.xyz;
	output.colour = instance.colour * input.colour;
	output.tex_coord = input.tex_coord;
	output.normal = input.normal;
	output.tangent = input.tangent;
	return output;
}

// Texture2D shadow_texture: register(t0, space2);
// SamplerState shadow_sampler: register(s0, space2);

Texture2D diffuse_texture: register(t0, space2);
SamplerState diffuse_sampler: register(s0, space2);

cbuffer Constant_Buffer : register(b0, space3) {
	float4 camera_position;
	float4 material_params;
	float4 light_params;
	float4 directional_light_dir;
	float4 directional_light_colour;
};

float4 frag_main(Frag_Input input): SV_Target {
	float2 tex_coord = input.tex_coord;
	
	float3 diffuse = input.colour.rgb * diffuse_texture.Sample(diffuse_sampler, tex_coord).rgb;
	
	float3 V = normalize(input.world_position - camera_position.xyz);
	float3 half_dir = normalize(directional_light_dir.xyz + V);	
	
	float diffuse_intensity = light_params.y;
	float specular_intensity = light_params.z;
	float specular_shininess = light_params.w;
	
	float ambient_lighting = light_params.x;
	
	float diffuse_lighting = max(dot(input.normal, -directional_light_dir.xyz), 0);
	
	float specular_lighting = pow(max(dot(input.normal, half_dir), 0.0), specular_shininess);
	
	float3 colour = (diffuse * (ambient_lighting + diffuse_lighting*diffuse_intensity)) + (directional_light_colour.rgb * specular_lighting*specular_intensity);
		
	return float4(colour, input.colour.a);
}