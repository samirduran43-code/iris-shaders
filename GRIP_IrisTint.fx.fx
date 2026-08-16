/*
    GRIP Combat Racing - Iris Tint / Contrast
    Yellow-green cinematic racing look
*/

#include "ReShade.fxh"

uniform float TintStrength <
    ui_type = "slider";
    ui_label = "Yellow-Green Tint";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
> = 0.18;

uniform float Contrast <
    ui_type = "slider";
    ui_label = "Contrast";
    ui_min = 0.50; ui_max = 2.00;
    ui_step = 0.01;
> = 1.12;

uniform float Saturation <
    ui_type = "slider";
    ui_label = "Saturation";
    ui_min = 0.50; ui_max = 1.50;
    ui_step = 0.01;
> = 1.08;

uniform float GreenBias <
    ui_type = "slider";
    ui_label = "Green Bias";
    ui_min = -0.20; ui_max = 0.30;
    ui_step = 0.01;
> = 0.05;

uniform float LineStrength <
    ui_type = "slider";
    ui_label = "Fine Line Effect";
    ui_min = 0.0; ui_max = 0.15;
    ui_step = 0.005;
> = 0.025;

uniform float LineScale <
    ui_type = "slider";
    ui_label = "Line Density";
    ui_min = 100.0; ui_max = 1200.0;
    ui_step = 10.0;
> = 600.0;

float3 ApplyContrast(float3 c, float contrast)
{
    return saturate((c - 0.5) * contrast + 0.5);
}

float4 PS_IrisTint(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 src = tex2D(ReShade::BackBuffer, uv);
    float3 c = src.rgb;

    // Yellow-green cinematic tint
    float3 irisColor = float3(0.72, 0.90, 0.20);

    float luminance = dot(c, float3(0.2126, 0.7152, 0.0722));

    // Preserve shadows while pushing mids/highlights toward yellow-green
    float tintMask = smoothstep(0.15, 0.85, luminance);

    c = lerp(c, c * irisColor * 1.35, TintStrength * tintMask);

    // Additional green bias
    c.g += GreenBias * tintMask;

    // Saturation
    float gray = dot(c, float3(0.2126, 0.7152, 0.0722));
    c = lerp(float3(gray, gray, gray), c, Saturation);

    // Racing-game contrast
    c = ApplyContrast(c, Contrast);

    // Very subtle horizontal line structure
    float lines = sin(uv.y * LineScale * 6.2831853);
    float lineMask = lines * LineStrength;

    c -= lineMask;

    return float4(saturate(c), src.a);
}

technique GRIP_IrisTint
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_IrisTint;
    }
}
