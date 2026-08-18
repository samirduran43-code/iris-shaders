/*------------------------------------------------------------------------------
    Full Visible Spectrum Remapper / Channel Wavelength Engine
    Compatible with ReShade 3.8+ (ReShade FX)
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

// -----------------------------------------------------------------------------
// UI CONTROLS - SPECTRUM MAPPER
// -----------------------------------------------------------------------------

uniform float GlobalShift <
    ui_type = "drag";
    ui_label = "Global Wavelength Shift";
    ui_tooltip = "Shifts the entire light spectrum continuously across all frequencies (0 to 360 deg).";
    ui_min = -180.0; ui_max = 180.0; ui_step = 1.0;
> = 0.0;

uniform float Red_Shift <
    ui_type = "drag"; ui_category = "Frequency Band Re-Mapping";
    ui_label = "Red Band Remap (0°)";
    ui_min = -180.0; ui_max = 180.0; ui_step = 1.0;
> = 0.0;

uniform float Yellow_Shift <
    ui_type = "drag"; ui_category = "Frequency Band Re-Mapping";
    ui_label = "Yellow Band Remap (60°)";
    ui_min = -180.0; ui_max = 180.0; ui_step = 1.0;
> = 0.0;

uniform float Green_Shift <
    ui_type = "drag"; ui_category = "Frequency Band Re-Mapping";
    ui_label = "Green Band Remap (120°)";
    ui_min = -180.0; ui_max = 180.0; ui_step = 1.0;
> = 0.0;

uniform float Cyan_Shift <
    ui_type = "drag"; ui_category = "Frequency Band Re-Mapping";
    ui_label = "Cyan Band Remap (180°)";
    ui_min = -180.0; ui_max = 180.0; ui_step = 1.0;
> = 0.0;

uniform float Blue_Shift <
    ui_type = "drag"; ui_category = "Frequency Band Re-Mapping";
    ui_label = "Blue Band Remap (240°)";
    ui_min = -180.0; ui_max = 180.0; ui_step = 1.0;
> = 0.0;

uniform float Magenta_Shift <
    ui_type = "drag"; ui_category = "Frequency Band Re-Mapping";
    ui_label = "Magenta Band Remap (300°)";
    ui_min = -180.0; ui_max = 180.0; ui_step = 1.0;
> = 0.0;

uniform float SpectrumCompression <
    ui_type = "drag"; ui_category = "Global Spectral Tuning";
    ui_label = "Spectral Band Width / Compression";
    ui_tooltip = "Squeezes or expands color transitions between adjacent spectral bands.";
    ui_min = 0.2; ui_max = 3.0; ui_step = 0.05;
> = 1.0;

uniform float SaturationBoost <
    ui_type = "drag"; ui_category = "Global Spectral Tuning";
    ui_label = "Remapped Spectrum Saturation";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.05;
> = 1.0;

// -----------------------------------------------------------------------------
// HELPER FUNCTIONS (SPECTRAL MATH)
// -----------------------------------------------------------------------------

// RGB to HSL conversion helpers
float3 RGBtoHSL(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Reconstructs pure spectral wavelengths using cosine spectral curves
float3 HueToRGB(float hue)
{
    float h = frac(hue);
    float r = abs(h * 6.0 - 3.0) - 1.0;
    float g = 2.0 - abs(h * 6.0 - 2.0);
    float b = 2.0 - abs(h * 6.0 - 4.0);
    return saturate(float3(r, g, b));
}

// -----------------------------------------------------------------------------
// PIXEL SHADER
// -----------------------------------------------------------------------------

float4 PS_SpectrumRemapper(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 originalColor = tex2D(ReShade::BackBuffer, texcoord).rgb;
    
    // 1. Deconstruct incoming light into Spectral Hue, Saturation, and Luminance
    float3 hsl = RGBtoHSL(originalColor);
    float currentHue = hsl.x; // 0.0 to 1.0 spectrum position
    float sat = hsl.y;
    float luma = hsl.z;

    // Fast-path bypass for un-saturated grays
    if (sat < 0.01)
        return float4(originalColor, 1.0);

    // 2. Calculate Distance Weightings to 6 Primary Wavelength Anchor Points
    // Hue Anchor Points: Red(0.0), Yellow(0.166), Green(0.333), Cyan(0.5), Blue(0.666), Magenta(0.833)
    float hDegrees = currentHue * 360.0;

    // Cosine-based smooth spectral weighting masks (bell curves around each anchor)
    float weightR = saturate(cos((hDegrees - 0.0)   * 0.0174533 * 3.0));
    float weightY = saturate(cos((hDegrees - 60.0)  * 0.0174533 * 3.0));
    float weightG = saturate(cos((hDegrees - 120.0) * 0.0174533 * 3.0));
    float weightC = saturate(cos((hDegrees - 180.0) * 0.0174533 * 3.0));
    float weightB = saturate(cos((hDegrees - 240.0) * 0.0174533 * 3.0));
    float weightM = saturate(cos((hDegrees - 300.0) * 0.0174533 * 3.0));

    // Handles red wraparound at 360 deg
    if (hDegrees > 300.0) weightR = saturate(cos((hDegrees - 360.0) * 0.0174533 * 3.0));

    // 3. Compute Interpolated Target Wavelength Shift
    float bandOffset = (weightR * Red_Shift) +
                       (weightY * Yellow_Shift) +
                       (weightG * Green_Shift) +
                       (weightC * Cyan_Shift) +
                       (weightB * Blue_Shift) +
                       (weightM * Magenta_Shift);

    // Combine global shift and band-specific shift
    float totalDegreesShift = GlobalShift + (bandOffset * SpectrumCompression);
    
    // Convert back to normalized spectral range [0.0, 1.0]
    float newHue = frac((hDegrees + totalDegreesShift) / 360.0);
    if (newHue < 0.0) newHue += 1.0;

    // 4. Synthesize New Spectrum back into RGB space
    float3 remappedRGB = HueToRGB(newHue);

    // Re-apply original lightness and adjusted saturation
    float3 finalColor = lerp(float3(luma, luma, luma), remappedRGB, sat * SaturationBoost);

    // Maintain contrast/luminance curve of original image
    finalColor = finalColor * (luma / (dot(finalColor, float3(0.299, 0.587, 0.114)) + 1e-5));

    return float4(saturate(finalColor), 1.0);
}

// -----------------------------------------------------------------------------
// TECHNIQUE DEFINITION
// -----------------------------------------------------------------------------

technique SpectrumRemapper
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_SpectrumRemapper;
    }
}