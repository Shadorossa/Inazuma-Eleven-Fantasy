// tonemap.pfxo: retail tonemap + grade (common.hlsl is pasted before it: `includes`)
float4 main(PSIn i) : SV_Target
{
    float4 c = max(in_texMain.Sample(in_texMainSampler, i.uv), 0.0);
    float chara;
    float3 rgb = RetailTonemap(c.rgb, i.uv, chara);
    return float4(Grade(rgb), c.a);
}
