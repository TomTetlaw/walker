
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

struct Vert_Output {
	float4 position: SV_Position;
	float4 colour: TEXCOORD0;
};

Vert_Output vert_main(float3 position: POSITION, uint instance_id: SV_InstanceId) {
	Instance_Data instance = instance_buffer[instance_id];

	float4x4 mvp = mul(projection, mul(view, instance.transform));
	float4 clip_position = mul(mvp, float4(position, 1));

	Vert_Output output;
	output.position = clip_position;
	output.colour = instance.colour;
	return output;
}

struct Frag_Output {
	float4 colour: SV_Target;
};

Frag_Output frag_main(Vert_Output input) {
	Frag_Output output;
	output.colour = input.colour;
	return output;
}
