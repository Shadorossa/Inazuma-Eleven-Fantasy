// Utilities' «Estilo visual»: the colour LUT part of tonemap_colorgrading.pfxo / colorgrading.pfxo (pasted after
// common.hlsl, before either program: `includes`). Same cbuffers, registers and names as the retail programs.
cbuffer CBUSE_UB_CAMERA_IDX : register(b5)
{
    float3 u_eyePos;
    float4 u_eyeDir;
    float3 u_eyeUpDir;
    float4 u_eyeNearFarInvAspect;
    row_major float4x4 u_eyeMtxWV;
    row_major float4x4 u_eyeMtxVP;
    row_major float4x4 u_eyeMtxWP;
    row_major float4x4 u_eyeMtxVW;
    row_major float4x4 u_eyeMtxPV;
    row_major float4x4 u_eyeMtxPW;
    row_major float3x4 u_mtxEyeSphere;
    float4 u_shadowSampleParams;
    float4 u_degeneracyParam;
    float4 u_pointLightRWParam;
    float4 u_shadowCascadeMinMax[3];
    float3 u_RayleighColorP20;
    float3 u_RayleighColorP10;
    float3 u_RayleighColorO00;
    float3 u_RayleighColorM10;
    float3 u_RayleighColorM20;
    float3 u_HeightRayleighColor;
    float3 u_MieColorP20;
    float3 u_MieColorO00;
    float3 u_MieColorM20;
    float4 u_fogWorldParam0;
    float4 u_fogWorldParam1;
    float4 u_fogHeightParam0;
    float4 u_fogHeightParam1;
    float4 u_RayleighBandRatio;
};
cbuffer CB1 : register(b1)
{
    float4 u_param0;
    float4 u_param1;
};
SamplerState in_texDepthSampler : register(s3);
SamplerState in_LUTSampler : register(s4);
Texture2D in_texDepth : register(t3);
Texture3D in_LUT : register(t4);

// the retail LUT blend: strength = depth fade (u_param0.z start, u_param1.x scale) * chara / map rate (u_param0.x /
// u_param0.y) * u_param1.y
float3 RetailLut(float3 rgb, float2 uv, float chara)
{
    float d = in_texDepth.Sample(in_texDepthSampler, uv).x;
    float z = (-d * u_eyeMtxVP[3].w + u_eyeMtxVP[2].w) / (d * u_eyeMtxVP[3].z - u_eyeMtxVP[2].z);
    float f = saturate((-z - u_param0.z) * u_param1.x);
    f = 1.0 - f * f;
    f = 1.0 - f * f;
    float rate = saturate((1.0 - chara) * (u_param0.y - chara * u_param0.x) + chara * u_param0.x);
    f = f * rate * u_param1.y;
    float3 lut = in_LUT.Sample(in_LUTSampler, rgb).rgb;
    return f * (lut - rgb) + rgb;
}
