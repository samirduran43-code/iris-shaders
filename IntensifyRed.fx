/*------------------------------------------------------------------------------
    RedIntensityOverdrive.fx - High-Intensity Red Base Channel Processor
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

// UI CONTROL PARAMETERS
uniform float RedGain <
    ui_category = "1. Red Channel Boost";
    ui_label = "Red Channel Saturation Multiplier";
    ui_type = "slider"; ui_min = 1.0; ui_max = 3.0; ui_step = 0.05;
> = 1.5;

uniform float ContrastCurve <
    ui_category = "1. Red Channel Boost";
    ui_label = "Red Contrast Curve";
    ui_type = "slider"; ui_min = 0.5; ui_max = 2.5; ui_step = 0.05;
> = 1.4;

uniform float CyanShadowStrength <
    ui_category = "2. Complementary Contrast";
    ui_label = "Cyan Shadow Injection";
    ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
> = 0.35;

uniform float EdgeOverdrive <
    ui_category = "3. Subpixel Edge Glow";
    ui_label = "Edge Edge Highlight (Yellow/White Peak)";
    ui_type = "slider"; ui_min = 0.0; ui_max = 2.0; ui_step = 0.1;
> = 1.0;

// PIXEL SHADER
float4 PS_RedIntensityOverdrive(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 rawColor = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // 1. Isolate and overdrive Red Channel base
    float redBase = rawColor.r;
    
    // Apply gamma/contrast curve to red
    float redBoosted = pow(saturate(redBase), ContrastCurve) * RedGain;

    // 2. Inject Complementary Cyan (Green+Blue) in low-red shadow areas
    float shadowMask = 1.0 - saturate(redBase);
    float3 cyanTint = float3(0.0, 0.7, 1.0) * shadowMask * CyanShadowStrength;

    // Combine red highlights and cyan shadows
    float3 intensifiedColor = float3(redBoosted, 0.0, 0.0) + cyanTint;

    // 3. Subpixel Edge Overdrive (Sobel Edge Pass on Red Channel)
    float2 texel = BUFFER_PIXEL_SIZE;
    float rLeft  = tex2D(ReShade::BackBuffer, texcoord - float2(texel.x, 0.0)).r;
    float rRight = tex2D(ReShade::BackBuffer, texcoord + float2(texel.x, 0.0)).r;
    float rUp    = tex2D(ReShade::BackBuffer, texcoord - float2(0.0, texel.y)).r;
    float rDown  = tex2D(ReShade::BackBuffer, texcoord + float2(0.0, texel.y)).r;

    float edge = abs(redBase - rLeft) + abs(redBase - rRight) + abs(redBase - rUp) + abs(redBase - rDown);
    
    // Add peak white/yellow subpixel flares along red edge boundaries
    intensifiedColor += float3(1.0, 0.8, 0.2) * edge * EdgeOverdrive;

    return float4(saturate(intensifiedColor), 1.0);
}

technique RedIntensityOverdrive
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_RedIntensityOverdrive;
    }
}