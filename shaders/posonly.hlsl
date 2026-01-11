// file : posonly.hlsl

struct Input {
    float3 pos : TEXCOORD0;
    float2 tex : TEXCOORD1;
    float3 nor : TEXCOORD2;
    uint index : SV_VertexID;
};

struct Output {
    float2 tex : TEXCOORD0;
    float3 nor : TEXCOORD1;
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
    op.nor = mul(model, float4(ip.nor, 0.0)).xyz;

    return op;
}

Texture2D    my_texture : register(t0, space2);
SamplerState my_sampler : register(s0, space2);

float4 pmain (float2 tex : TEXCOORD0, float3 nor : TEXCOORD1) : SV_Target0 {
    float3 lightDir = normalize(float3(1.0, 1.0, 1.0)); // Toujours normaliser la direction
    float3 normal   = normalize(nor); // La normale peut perdre sa longueur après interpolation
    
    // Calcul du facteur de lumière diffuse
    float diffuse = dot(normal, lightDir);
    
    // Ajout d'une constante ambiante (ex: 0.2)
    // On utilise max(0, ...) pour éviter les valeurs négatives, 
    // puis on ajoute l'ambiant.
    float lightFactor = max(0.2, diffuse); 

    return my_texture.Sample(my_sampler, tex) * lightFactor;
}