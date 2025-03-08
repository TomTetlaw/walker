
struct Instance_Data {
	row_major float4x4 transform;
	float4 colour;
	float4 material_params;
};

StructuredBuffer<Instance_Data> instance_buffer: register(t0, space0);

cbuffer Constant_Buffer : register(b0, space1) {
	row_major float4x4 light_matrix;
};

struct Vert_Output {
	float4 position: SV_Position;
};

Vert_Output vert_main(float3 position: POSITION, uint instance_id: SV_InstanceId) {
	float4x4 mvp = mul(light_matrix, instance_buffer[instance_id].transform);

	float4 lightspace_position = mul(mvp, float4(position, 1));

	Vert_Output output;
	output.position = lightspace_position;
	return output;
}

struct Frag_Output {
	float depth: SV_Target;
};

// INSERT_MATERIAL_HERE

Frag_Output frag_main(Vert_Output input) {
	Frag_Output output;
	output.depth = input.position.x;
	return output;
}
