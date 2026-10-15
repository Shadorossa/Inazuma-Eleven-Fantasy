// Utilities' «Estilo visual» (content\shaders\visual_style.toml, VRFW.shader/1; docs/framework/shaders.md), was
// Inazuma Fantasy module `lighting`; research/scripts/lt_shader.py checks it (docs/game/media/lighting.md).
// Pasted before tonemap.hlsl / tonemap_colorgrading.hlsl / colorgrading.hlsl (`includes`), compiled as ps_5_0 by the
// VR-Framework. The
// preset's `defines` set GRADE, EXPOSURE, GAMMA, SATURATION, CONTRAST, PIVOT, TINT (unset = the neutral values below).
// The register layout / names equal the retail program (the engine D3DReflects the file).
#ifndef LUMA
#define LUMA float3(0.29891, 0.58661, 0.11448)
#endif
#ifndef GRADE
#define GRADE 0
#endif
#ifndef EXPOSURE
#define EXPOSURE 1.0
#endif
#ifndef GAMMA
#define GAMMA 1.0
#endif
#ifndef SATURATION
#define SATURATION 1.0
#endif
#ifndef CONTRAST
#define CONTRAST 1.0
#endif
#ifndef PIVOT
#define PIVOT 0.5
#endif
#ifndef TINT
#define TINT float3(1.0, 1.0, 1.0)
#endif
cbuffer CB0 : register(b0)
{
    float fLumWhite;
    float fLumGray;
    float fEnableRate;
    float fEnableRateForChara;
    float fScrLumEnable;
    float fScrLum;
};
SamplerState in_texMainSampler : register(s0);
SamplerState in_texMaskSampler : register(s1);
Texture2D in_texMain : register(t0);
Texture2D in_texMask : register(t1);
StructuredBuffer<float> ro_luminance : register(t2);

struct PSIn
{
    float4 pos : SV_Position;
    float4 col : COLOR0;
    float2 uv  : TEXCOORD0;
};

// 1 on character pixels (bit 0 of the mask's z), 0 elsewhere
float CharaBit(float2 uv)
{
    float m = in_texMask.Sample(in_texMaskSampler, uv).z;
    return ((int)(m * 255.0 + 0.5) & 1) ? 1.0 : 0.0;
}

// retail tonemap (extended Reinhard on luma, chara pixels scaled by fEnableRateForChara). The scene rate is read as at
// least 0: the retail pass never runs at a rate of 0 or below, the framework's `tonemap_pass` patch runs it there as
// an identity pass so the grade still applies.
float3 RetailTonemap(float3 c, float2 uv, out float charaBit)
{
    charaBit = CharaBit(uv);
    float rate = (charaBit * (fEnableRateForChara - 1.0) + 1.0) * max(fEnableRate, 0.0);
    float white2 = fLumWhite * fLumWhite;
    float lavg = ro_luminance[0];
    lavg = fScrLumEnable * (fScrLum - lavg) + lavg;
    float L = dot(c, LUMA);
    float Ls = (L * fLumGray) / (lavg + 0.001);
    float Ld = Ls * (Ls / white2 + 1.0) / (Ls + 1.0);
    float3 t = (Ld * c) / (L + 0.0001);
    return rate * (t - c) + c;
}

float3 Grade(float3 c)
{
#if GRADE
    c = max(c * EXPOSURE, 0.0);
    float3 lo = pow(saturate(c), GAMMA);
    c = lo + max(c - 1.0, 0.0);
    float l = dot(c, LUMA);
    c = l + (c - l) * SATURATION;
    c = max((c - PIVOT) * CONTRAST + PIVOT, 0.0);
    c *= TINT;
#endif
    return c;
}
