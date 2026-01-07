struct Input {
    float3 pos : TEXCOORD0;
    float2 tex : TEXCOORD1;
    uint index : SV_VertexID;
};

struct Output {
    float2 tex : TEXCOORD0;
    float4 pos : SV_Position;
};

cbuffer vUniform_cam : register(b0, space1) {
    float4x4 view;
    float4x4 projection;
};

cbuffer vUniform_mdl : register(b1, space1) {
    float4x4 model;
};

Output vmain (Input ip) {
    Output op;

    op.pos = mul(projection, mul(view, mul(model, float4(ip.pos, 1.0))));
    op.tex = float2(ip.tex);

    return op;
}

Texture2D    my_texture : register(t0, space2);
SamplerState my_sampler : register(s0, space2);

float4 pmain (float2 tex : TEXCOORD0) : SV_Target0 {
    return my_texture.Sample(my_sampler, tex);
}