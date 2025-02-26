#include "./shared.hlsl"

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

	Vert_Output output;
	output.position = mul(mvp, float4(position, 1));
	return output;
}

struct Frag_Output {
	float depth: SV_Target;
};

Frag_Output frag_main(Vert_Output input) {
	Frag_Output output;
	output.depth = input.position.z/input.position.w;//*.5+.5;
	return output;
}
