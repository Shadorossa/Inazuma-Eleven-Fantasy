// Utilities' «Estilo visual» (content\shaders\visual_style.toml, VRFW.shader/1; docs/framework/shaders.md), was
// Inazuma Fantasy module `lighting`; research/scripts/lt_shader.py checks it (docs/game/media/lighting.md).
// bloom_composi.pfxo (LAYERS 3) / bloom_composi_l.pfxo (LAYERS 2, low-cost bloom): retail screen-blend of the bloom
// levels, every level intensity (bloomParam*.x, fed from CLightData bloomIntensity) multiplied by BLOOM (the preset's
// define; unset = 1).
#ifndef BLOOM
#define BLOOM 1.0
#endif
#ifndef LAYERS
#define LAYERS 3
#endif
cbuffer CB6 : register(b6)
{
    float2 bloomParam0;   // level 0: intensity, alpha rate
    float2 bloomParam1;   // level 1
    float2 bloomParam2;   // level 2 (unused by the low-cost variant)
};
SamplerState _BloomTex0Sampler : register(s0);
SamplerState _BloomTex1Sampler : register(s1);
Texture2D _BloomTex0 : register(t0);
Texture2D _BloomTex1 : register(t1);
#if LAYERS > 2
SamplerState _BloomTex2Sampler : register(s2);
Texture2D _BloomTex2 : register(t2);
#endif

struct PSIn
{
    float4 pos : SV_Position;
    float2 uv  : TEXCOORD0;
};

void Level(float3 b, float2 prm, inout float3 inv, inout float a)
{
    b = saturate(b * (prm.x * BLOOM));
    inv *= 1.0 - b;
    a *= 1.0 - max(max(b.x, b.y), b.z) * prm.y;
}

float4 main(PSIn i) : SV_Target
{
    float3 inv = 1.0;
    float a = 1.0;
    Level(_BloomTex0.Sample(_BloomTex0Sampler, i.uv).rgb, bloomParam0, inv, a);
    Level(_BloomTex1.Sample(_BloomTex1Sampler, i.uv).rgb, bloomParam1, inv, a);
#if LAYERS > 2
    Level(_BloomTex2.Sample(_BloomTex2Sampler, i.uv).rgb, bloomParam2, inv, a);
#endif
    return 1.0 - float4(inv, a);
}
