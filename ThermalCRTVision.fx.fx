/*------------------------------------------------------------------------------
    ThermalCRTVision.fx - Thermal Heatmap & CRT Scanline Shader
    Recreates high-contrast neon green, yellow, and red thermal exposure.
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

// =============================================================================
// UI PARAMETERS
// =============================================================================

uniform float Contrast <
    ui_category = "1. Exposure & Contrast";
    ui_label = "Luma Contrast Multiplier";
    ui_type = "slider"; ui_min = 1.0; ui_max = 5.0; ui_step = 0.1;
> = 2.8;

uniform float BrightnessThreshold <
    ui_category = "1. Exposure & Contrast";
    ui_label = "Black Cutoff Level";
    ui_type = "slider"; ui_min = 0.0; ui_max = 0.8; ui_step = 0.02;
> = 0.15;

uniform float ScanlineDensity <
    ui_category = "2. CRT Scanlines";
    ui_label = "Scanline Frequency";
    ui_type = "slider"; ui_min = 0.5; ui_max = 3.0; ui_step = 0.1;
> = 1.5;

uniform float ScanlineDarkness <
    ui_category = "2. CRT Scanlines";
    ui_label = "Scanline Depth";
    ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
> = 0.65;

uniform float RedChannelBoost <
    ui_category = "3. Thermal Palette Tuning";
    ui_label = "Red Isolation Bias";
    ui_type = "slider"; ui_min = 0.5; ui_max = 3.0; ui_step = 0.1;
> = 1.8;

// =============================================================================
// PIXEL SHADER
// =============================================================================

float4 PS_ThermalCRTVision(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // 1. Fetch raw game color
    float3 rawColor = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // Calculate luminance
    float luma = dot(rawColor, float3(0.2126, 0.7152, 0.0722));

    // Calculate red intensity dominance (for isolated vehicle highlight)
    float redBias = rawColor.r / (rawColor.g + rawColor.b + 0.001);

    // 2. High-contrast exposure curve
    luma = saturate((luma - BrightnessThreshold) * Contrast);

    // 3. Construct Thermal Gradient Map (Red -> Yellow -> Green -> Black)
    float3 thermalColor = float3(0.0, 0.0, 0.0);

    if (luma < 0.05)
    {
        // Deep shadows -> Black
        thermalColor = float3(0.0, 0.0, 0.0);
    }
    else if (luma < 0.35)
    {
        // Low-midtones -> Saturated Green
        float t = (luma - 0.05) / 0.30;
        thermalColor = lerp(float3(0.0, 0.6, 0.0), float3(0.0, 1.0, 0.0), t);
    }
    else if (luma < 0.75)
    {
        // High-midtones -> Bright Neon Yellow/Green
        float t = (luma - 0.35) / 0.40;
        thermalColor = lerp(float3(0.0, 1.0, 0.0), float3(0.9, 1.0, 0.0), t);
    }
    else
    {
        // Overexposed Highlights -> Pure Electric Yellow
        thermalColor = float3(1.0, 0.95, 0.0);
    }

    // Overdrive Red channel on high-red source pixels (vehicle chassis)
    if (redBias > RedChannelBoost && luma > 0.1)
    {
        float redFactor = saturate((redBias - RedChannelBoost) * 0.8);
        thermalColor = lerp(thermalColor, float3(1.0, 0.05, 0.0), redFactor);
    }

    // 4. Heavy CRT Scanline Pattern
    float scanline = sin(texcoord.y * BUFFER_HEIGHT * ScanlineDensity) * 0.5 + 0.5;
    scanline = pow(scanline, 1.5); // Sharpen lines
    thermalColor *= 1.0 - (scanline * ScanlineDarkness);

    return float4(saturate(thermalColor), 1.0);
}

// =============================================================================
// TECHNIQUE DEFINITION
// =============================================================================

technique ThermalCRTVision
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_ThermalCRTVision;
    }
}