struct Input {
    uint index : SV_VertexID;
};

struct Output {
    float4 col : TEXCOORD0;
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

    static const float3 vertices[36] = 
    {
        // FACE AVANT (Z = -1)
        float3(-1, -1, -1), float3( 1, -1, -1), float3( 1,  1, -1),
        float3(-1, -1, -1), float3( 1,  1, -1), float3(-1,  1, -1),

        // FACE ARRIERE (Z = +1)
        float3( 1, -1,  1), float3(-1, -1,  1), float3(-1,  1,  1),
        float3( 1, -1,  1), float3(-1,  1,  1), float3( 1,  1,  1),

        // FACE GAUCHE (X = -1)
        float3(-1, -1,  1), float3(-1, -1, -1), float3(-1,  1, -1),
        float3(-1, -1,  1), float3(-1,  1, -1), float3(-1,  1,  1),

        // FACE DROITE (X = +1)
        float3( 1, -1, -1), float3( 1, -1,  1), float3( 1,  1,  1),
        float3( 1, -1, -1), float3( 1,  1,  1), float3( 1,  1, -1),

        // FACE HAUT (Y = +1)
        float3(-1,  1, -1), float3( 1,  1, -1), float3( 1,  1,  1),
        float3(-1,  1, -1), float3( 1,  1,  1), float3(-1,  1,  1),

        // FACE BAS (Y = -1)
        float3(-1, -1,  1), float3( 1, -1,  1), float3( 1, -1, -1),
        float3(-1, -1,  1), float3( 1, -1, -1), float3(-1, -1, -1)
    };
    static const float4 faceColors[6] = 
    {
        float4(1.0, 0.0, 0.0, 1.0), // Face 0 (Avant)  - Rouge
        float4(0.0, 1.0, 0.0, 1.0), // Face 1 (Arrière)- Vert
        float4(0.0, 0.0, 1.0, 1.0), // Face 2 (Gauche) - Bleu
        float4(1.0, 1.0, 0.0, 1.0), // Face 3 (Droite) - Jaune
        float4(0.0, 1.0, 1.0, 1.0), // Face 4 (Haut)   - Cyan
        float4(1.0, 0.0, 1.0, 1.0)  // Face 5 (Bas)    - Magenta
    };

    op.pos = mul(projection, mul(view, mul(model, float4(vertices[ip.index], 1.0))));
    op.col = faceColors[int(ip.index/6)];

    return op;
}

float4 pmain (float4 col : TEXCOORD0) : SV_Target0 {
    return float4(col);
}