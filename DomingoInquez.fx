#include "ReShade.fxh"

// ----------------------------------------------------------------------------------
// UI CONTROLS
// ----------------------------------------------------------------------------------

uniform float Hue <
    ui_type = "slider";
    ui_min = -180.0; ui_max = 180.0;
    ui_label = "Hue Shift (Degrees)";
    ui_tooltip = "Rotates all colors around the RGB color wheel.";
> = 0.0;

uniform float Saturation <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
    ui_label = "Saturation";
    ui_tooltip = "0 = Monochromatic / Black & White, 1 = Normal, 2 = Ultra Vibrate";
> = 1.0;

uniform float Contrast <
    ui_type = "slider";
    ui_min = 0.5; ui_max = 2.0;
    ui_label = "Contrast";
> = 1.0;

uniform float Brightness <
    ui_type = "slider";
    ui_min = -0.5; ui_max = 0.5;
    ui_label = "Brightness";
> = 0.0;

uniform float PaletteBlend <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "IQ Cosine Palette Blend";
    ui_tooltip = "Blends an IQ procedural color gradient into the image based on pixel brightness.";
> = 0.0;

// ----------------------------------------------------------------------------------
// COLOR FUNCTIONS
// ----------------------------------------------------------------------------------

// Inigo Quilez Cosine Color Palette
float3 iqPalette(in float t)
{
    float3 a = float3(0.5, 0.5, 0.5);
    float3 b = float3(0.5, 0.5, 0.5);
    float3 c = float3(1.0, 1.0, 1.0);
    float3 d = float3(0.00, 0.33, 0.67);
    return a + b * cos(6.283185 * (c * t + d));
}

// RGB to HSV Conversion
float3 RGBtoHSV(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB Conversion
float3 HSVtoRGB(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ----------------------------------------------------------------------------------
// PIXEL SHADER
// ----------------------------------------------------------------------------------

float4 PS_IQColorAdjust(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // 1. Sample the game screen texture from ReShade
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // 2. Adjust Brightness & Contrast
    color = (color - 0.5) * Contrast + 0.5 + Brightness;

    // 3. Convert to HSV for Hue and Saturation adjustments
    float3 hsv = RGBtoHSV(saturate(color));
    
    // Shift Hue (remap degrees to 0.0 - 1.0 range)
    hsv.x = frac(hsv.x + (Hue / 360.0));
    
    // Scale Saturation
    hsv.y = saturate(hsv.y * Saturation);
    
    color = HSVtoRGB(hsv);

    // 4. Optionally blend in Inigo Quilez's Cosine Palette based on pixel luminance
    if (PaletteBlend > 0.0)
    {
        float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
        float3 paletteColor = iqPalette(luminance);
        color = lerp(color, paletteColor * luminance, PaletteBlend);
    }

    return float4(saturate(color), 1.0);
}

// ----------------------------------------------------------------------------------
// TECHNIQUE DEFINITION
// ----------------------------------------------------------------------------------

technique IQColorAdjust
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_IQColorAdjust;
    }
}