// tonemap_colorgrading.pfxo: retail tonemap + LUT colour grading + grade (common.hlsl is pasted before it: `includes`)
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

float4 main(PSIn i) : SV_Target
{
    float d = in_texDepth.Sample(in_texDepthSampler, i.uv).x;
    float z = (-d * u_eyeMtxVP[3].w + u_eyeMtxVP[2].w) / (d * u_eyeMtxVP[3].z - u_eyeMtxVP[2].z);
    float f = saturate((-z - u_param0.z) * u_param1.x);
    f = 1.0 - f * f;
    f = 1.0 - f * f;
    float4 c = max(in_texMain.Sample(in_texMainSampler, i.uv), 0.0);
    float chara;
    float3 rgb = RetailTonemap(c.rgb, i.uv, chara);
    float rate = saturate((1.0 - chara) * (u_param0.y - chara * u_param0.x) + chara * u_param0.x);
    f = f * rate * u_param1.y;
    float3 lut = in_LUT.Sample(in_LUTSampler, rgb).rgb;
    rgb = f * (lut - rgb) + rgb;
    return float4(Grade(rgb), c.a);
}
