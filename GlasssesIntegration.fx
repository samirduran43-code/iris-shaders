#include "ReShade.fxh"

uniform int GlassesMode <
    ui_type = "combo";
    ui_label = "Glasses Mode";
    ui_items = "1. HD Dark Glasses\0"
               "2. -0.5 Anti-Radiation\0"
               "3. Transparent Frame Blue-Green\0"
               "4. Bone-Color Frame Blue-Green\0"
               "5. Yellow Filter Sport\0";
    ui_default = 0;
>;

uniform float Intensity <
    ui_type = "slider";
    ui_label = "Enhancement Intensity";
    ui_min = 0.5; ui_max = 2.0;
    ui_default = 1.0;
>;

// Built-in fullscreen vertex shader (no external dependencies)
void VS_PostProcess(in uint id : SV_VertexID, out float4 vpos : SV_POSITION, out float2 coord : TEXCOORD)
{
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float3 PS_Enhance(float4 vpos : VPOS, float2 coord : TEXCOORD) : COLOR
{
    float3 col = tex2D(ReShade::BackBuffer, coord).rgb;

    if (GlassesMode == 0) // HD Dark
    {
        col *= (1.3 * Intensity);
        col = pow(col, 0.85);
    }
    else if (GlassesMode == 1) // Anti-Radiation
    {
        col *= (1.05 * Intensity);
    }
    else if (GlassesMode == 2) // Transparent Blue-Green
    {
        col.r *= (1.2 * Intensity);
        col.b *= 0.9;
    }
    else if (GlassesMode == 3) // Bone-Color Blue-Green
    {
        col.r *= (1.15 * Intensity);
        col.b *= 0.95;
    }
    else if (GlassesMode == 4) // Yellow Sport
    {
        col.b *= (1.3 * Intensity);
        col.r *= 0.95;
    }

    return saturate(col);
}

technique GlassesEnhancer
{
    pass
    {
        VertexShader = VS_PostProcess;
        PixelShader = PS_Enhance;
    }
}