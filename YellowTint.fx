/*
    GRIP: Combat Racing - Yellow Tint
    ReShade 3.8 compatible

    Put this file in:
    ReShade-Shaders\Shaders\GRIP_YellowTint.fx

    Then reload ReShade and enable "GRIP Yellow Tint".
*/

#include "ReShade.fxh"

uniform float3 TintColor <
    ui_type = "color";
    ui_label = "Yellow Tint Color";
> = float3(1.0, 0.8627, 0.3137);

uniform float TintStrength <
    ui_type = "slider";
    ui_label = "Tint Strength";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.10;

uniform float Saturation <
    ui_type = "slider";
    ui_label = "Saturation";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.04;

uniform float Contrast <
    ui_type = "slider";
    ui_label = "Contrast";
    ui_min = 0.5;
    ui_max = 1.5;
    ui_step = 0.01;
> = 1.03;

uniform float Brightness <
    ui_type = "slider";
    ui_label = "Brightness";
    ui_min = 0.5;
    ui_max = 1.5;
    ui_step = 0.01;
> = 1.00;


float3 ApplySaturation(float3 color, float amount)
{
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    return lerp(float3(luminance, luminance, luminance), color, amount);
}


float3 ApplyContrast(float3 color, float amount)
{
    return (color - 0.5) * amount + 0.5;
}


float4 PS_YellowTint(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float4 original = tex2D(ReShade::BackBuffer, texcoord);

    float3 color = original.rgb;

    // Brightness
    color *= Brightness;

    // Contrast
    color = ApplyContrast(color, Contrast);

    // Saturation
    color = ApplySaturation(color, Saturation);

    // Yellow/golden tint
    color = lerp(color, color * TintColor, TintStrength);

    // Keep values in valid range
    color = saturate(color);

    return float4(color, original.a);
}


technique GRIP_YellowTint
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_YellowTint;
    }
}
