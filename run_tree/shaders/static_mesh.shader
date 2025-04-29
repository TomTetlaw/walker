[1] # Version number; do not delete!

pipeline_name static_mesh
vertex_input static_mesh
instance_buffer static_mesh
texture_set static_mesh
vert_constants view
frag_constants camera

end_shader_metadata

struct Frag_Input {
	float4 local_position: TEXCOORD0;
	float4 world_position: TEXCOORD1;
	float4 view_position: TEXCOORD2;
	float4 clip_position: SV_Position;
	
	float4 colour: TEXCOORD3;
	float2 tex_coord: TEXCOORD4;
	float3 normal: TEXCOORD5;
	float3 tangent: TEXCOORD6;
};

Frag_Input vert_main(Vertex_Input input, uint instance_id: SV_InstanceId) {
	Instance_Data instance = instance_buffer[instance_id];

	float4x4 local_to_world = instance.transform;
	float4x4 local_to_view = mul(local_to_world, view);
	float4x4 local_to_clip = mul(local_to_view, projection);

	float4 local_position = float4(input.position, 1);
	float4 world_position = mul(float4(input.position, 1), local_to_world);
	float4 view_position = mul(float4(input.position, 1), local_to_view);
	float4 clip_position = mul(float4(input.position, 1), local_to_clip);
	
	float4 colour = instance.colour * float4(input.colour, 1.0);
	float2 tex_coord = input.tex_coord;
	float3 normal = mul(input.normal, adjoint(local_to_world));
	float3 tangent = mul(input.tangent, adjoint(local_to_world));

	Frag_Input output;
	output.local_position = local_position;
	output.world_position = world_position;
	output.view_position = view_position;
	output.clip_position = clip_position;
	output.colour = colour;
	output.tex_coord = tex_coord;
	output.normal = normal;
	output.tangent = tangent;
	return output;
}

float4 frag_main(Frag_Input input): SV_Target {
	return sample_texture(diffuse, input.tex_coord) * input.colour;
}
