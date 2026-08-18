/*------------------------------------------------------------------------------
    IntenseColorCRTVision.fx - True-Color Overdrive & CRT Scanline Shader
    Preserves original game colors while maximizing color intensity and contrast.
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

// =============================================================================
// UI PARAMETERS
// =============================================================================

uniform float ColorSaturation <
    ui_category = "1. Color Intensity";
    ui_label = "Vibrance / Saturation Overdrive";
    ui_type = "slider"; ui_min = 1.0; ui_max = 5.0; ui_step = 0.1;
> = 2.5;

uniform float Contrast <
    ui_category = "2. Contrast & Exposure";
    ui_label = "Contrast Expansion";
    ui_type = "slider"; ui_min = 1.0; ui_max = 4.0; ui_step = 0.1;
> = 2.0;

uniform float ShadowCutoff <
    ui_category = "2. Contrast & Exposure";
    ui_label = "Black Shadow Threshold";
    ui_type = "slider"; ui_min = 0.0; ui_max = 0.5; ui_step = 0.01;
> = 0.08;

uniform float ScanlineDensity <
    ui_category = "3. CRT Lines";
    ui_label = "Scanline Frequency";
    ui_type = "slider"; ui_min = 0.5; ui_max = 3.0; ui_step = 0.1;
> = 1.5;

uniform float ScanlineDarkness <
    ui_category = "3. CRT Lines";
    ui_label = "Scanline Depth";
    ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
> = 0.60;

// =============================================================================
// PIXEL SHADER
// =============================================================================

float4 PS_IntenseColorCRTVision(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // 1. Fetch raw game color
    float3 col = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // 2. Calculate luminance
    float luma = dot(col, float3(0.2126, 0.7152, 0.0722));

    // 3. Apply High-Contrast Curve while keeping relative color ratios intact
    float3 contrastColor = (col - ShadowCutoff) * Contrast;
    col = max(contrastColor, float3(0.0, 0.0, 0.0));

    // 4. Intensify Saturation / Vibrance towards original pure hues
    float maxChan = max(col.r, max(col.g, col.b));
    float minChan = min(col.r, min(col.g, col.b));
    float chroma = maxChan - minChan;

    if (chroma > 0.001)
    {
        // Push colors outward toward their dominant channel without shifting hue
        col = lerp(float3(luma, luma, luma), col, ColorSaturation);
    }

    // 5. Heavy CRT Scanline Pattern
    float scanline = sin(texcoord.y * BUFFER_HEIGHT * ScanlineDensity) * 0.5 + 0.5;
    scanline = pow(scanline, 1.5); // Sharpen scanline edges
    col *= 1.0 - (scanline * ScanlineDarkness);

    return float4(saturate(col), 1.0);
}

// =============================================================================
// TECHNIQUE DEFINITION
// =============================================================================

technique IntenseColorCRTVision
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_IntenseColorCRTVision;
    }
}