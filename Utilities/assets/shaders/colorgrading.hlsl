// colorgrading.pfxo: the pass the engine runs instead of the tonemap when a scene has the tonemap off and a colour LUT
// on (events, some maps): retail LUT colour grading + grade (common.hlsl and lut.hlsl are pasted before it: `includes`)
float4 main(PSIn i) : SV_Target
{
    float4 c = max(in_texMain.Sample(in_texMainSampler, i.uv), 0.0);
    float3 rgb = RetailLut(c.rgb, i.uv, CharaBit(i.uv));
    return float4(Grade(rgb), c.a);
}
