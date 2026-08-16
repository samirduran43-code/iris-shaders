/*------------------------------------------------------------------------------
    NeonChannelTuner.fx
    Custom Color Channel Remapper & Threshold Tuner for ReShade
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

// --- PARAMETERS ---

uniform float3 RedChannelBoost <
    ui_type = "drag";
    ui_category = "Red Channel Remap";
    ui_label = "Red Output (R, G, B)";
    ui_min = -2.0; ui_max = 2.0; ui_step = 0.05;
> = float3(1.0, 0.0, 0.0);

uniform float3 GreenChannelBoost <
    ui_type = "drag";
    ui_category = "Green Channel Remap";
    ui_label = "Green Output (R, G, B)";
    ui_min = -2.0; ui_max = 2.0; ui_step = 0.05;
> = float3(0.0, 1.0, 0.0);

uniform float3 BlueChannelBoost <
    ui_type = "drag";
    ui_category = "Blue Channel Remap";
    ui_label = "Blue Output (R, G, B)";
    ui_min = -2.0; ui_max = 2.0; ui_step = 0.05;
> = float3(0.0, 0.0, 1.0);

uniform bool InvertRed < ui_category = "Channel Inversion"; ui_label = "Invert Red Channel"; > = false;
uniform bool InvertGreen < ui_category = "Channel Inversion"; ui_label = "Invert Green Channel"; > = false;
uniform bool InvertBlue < ui_category = "Channel Inversion"; ui_label = "Invert Blue Channel"; > = false;

uniform float ContrastThreshold <
    ui_type = "drag";
    ui_category = "Thresholding & Gamma";
    ui_label = "Posterize Power / Gamma";
    ui_min = 0.1; ui_max = 5.0; ui_step = 0.05;
> = 1.0;

uniform float MasterBrightness <
    ui_type = "drag";
    ui_category = "Thresholding & Gamma";
    ui_label = "Master Brightness";
    ui_min = 0.0; ui_max = 3.0; ui_step = 0.05;
> = 1.0;

// --- SHADER PASS ---

float4 PS_NeonChannelTuner(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // Optional Channel Inversions
    if (InvertRed)   color.r = 1.0 - color.r;
    if (InvertGreen) color.g = 1.0 - color.g;
    if (InvertBlue)  color.b = 1.0 - color.b;

    // Apply Contrast / Gamma curve
    color = pow(abs(color), ContrastThreshold);

    // Matrix Multiply to remap channel destinations
    float3 tunedColor;
    tunedColor.r = dot(color, RedChannelBoost);
    tunedColor.g = dot(color, GreenChannelBoost);
    tunedColor.b = dot(color, BlueChannelBoost);

    // Final Gain Adjustment
    tunedColor *= MasterBrightness;

    return float4(saturate(tunedColor), 1.0);
}

technique NeonChannelTuner
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_NeonChannelTuner;
    }
}