struct vInput {
    float3 pos : TEXCOORD0;
    float3 color : TEXCOORD1;
};

struct vOutput {
    float3 color : TEXCOORD0;
    float4 pos   : SV_Position;
};

struct pInput {
    float3 color : TEXCOORD0;
};

cbuffer vuniform : register(b0, space1) {
    float4x4 mvp;
}

vOutput vs_main(vInput inp) {
    vOutput result;

    result.pos = mul(mvp, float4(inp.pos, 1.0));
    result.color = float3(inp.color);

    return result;
}

float4 ps_main(pInput inp) : SV_Target0 {
    return float4(inp.color, 1.0);
}