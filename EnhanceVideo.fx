/*
    ==================================================================
    GameEnhancer.fx - Ultra Radical Edition (Monitor Channel Math)
    Features: 
      - Radial Channel Dispersion & Barrel Distortion
      - Matrix Color Transformations (Cyberpunk, Infrared, Neon, Vaporwave)
      - Luma-Keyed Highlight/Shadow Polarization
      - Cross-Channel Color Difference Amplification
      - Channel-Dependent Scan-Glow (Color Bleed)
      - Procedural Sub-Pixel LCD Grid
      - Luma-Weighted Film Grain
    ==================================================================
*/

#include "ReShade.fxh"

// --- Base Image Adjustments ---
uniform float Sharpness <
    ui_type = "slider"; ui_min = 0.0; ui_max = 2.0;
    ui_label = "Sharpen Strength";
> = 0.5;

uniform float Contrast <
    ui_type = "slider"; ui_min = 0.0; ui_max = 1.0;
    ui_label = "S-Curve Contrast";
> = 0.2;

// --- Channel Math Radical FX Controls ---
uniform bool EnableChannelMathFX <
    ui_label = "Enable Radical Channel Math";
    ui_tooltip = "Master toggle for vector math, dispersion, and channel transformations.";
> = true;

uniform int ColorMatrixMode <
    ui_type = "combo";
    ui_items = "Off\0Cyberpunk Cyan/Magenta\0Infrared False-Color\0Neon Cross-Bleed\0Vaporwave Pink/Yellow\0";
    ui_label = "Color Matrix Mode";
> = 1;

uniform float DispersionStrength <
    ui_type = "slider"; ui_min = 0.0; ui_max = 3.0;
    ui_label = "Radial Channel Dispersion";
    ui_tooltip = "Splits R, G, B channels outward from screen center based on vector distance.";
> = 1.2;

uniform float BarrelDistortion <
    ui_type = "slider"; ui_min = -0.5; ui_max = 0.5;
    ui_label = "Radial Barrel Warp";
    ui_tooltip = "Warps UV coordinates in an exponential curve (Fisheye / CRT curvature).";
> = 0.05;

uniform float ChannelDiffBoost <
    ui_type = "slider"; ui_min = 0.0; ui_max = 2.0;
    ui_label = "Cross-Channel Difference Boost";
    ui_tooltip = "Amplifies contrast between color channels for hyper-saturated edge isolation.";
> = 0.8;

uniform float ScanGlow <
    ui_type = "slider"; ui_min = 0.0; ui_max = 2.0;
    ui_label = "Channel Scan-Glow (Bleed)";
    ui_tooltip = "Creates a neon horizontal bleed by pulling high-intensity sub-pixels across columns.";
> = 0.5;

uniform float Polarization <
    ui_type = "slider"; ui_min = 0.0; ui_max = 1.0;
    ui_label = "Shadow/Highlight Polarization";
    ui_tooltip = "Splits shadow and highlight channels into complementary color tones.";
> = 0.35;

// --- Sub-Pixel & Texture Artifacts ---
uniform bool EnableSubpixelGrid <
    ui_label = "Enable Sub-Pixel LCD Grid";
    ui_tooltip = "Simulates physical monitor sub-pixel layouts (RGB triads).";
> = false;

uniform float SubpixelStrength <
    ui_type = "slider"; ui_min = 0.0; ui_max = 1.0;
    ui_label = "LCD Grid Strength";
> = 0.25;

uniform float FilmGrain <
    ui_type = "slider"; ui_min = 0.0; ui_max = 0.5;
    ui_label = "Luma-Weighted Film Grain";
    ui_tooltip = "Adds procedural noise concentrated in dark/shadow areas to fight banding.";
> = 0.08;

uniform float Timer < source = "timer"; >;

// --- Helper Functions ---

float GetLuma(float3 color)
{
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

// 1. Barrel Vector Distortion Math
float2 ApplyBarrelWarp(float2 texcoord, float k)
{
    float2 coord = texcoord - 0.5;
    float r2 = dot(coord, coord);
    return 0.5 + coord * (1.0 + k * r2);
}

// 2. High-Pass Pixel Sharpening
float3 ApplySharpen(float2 texcoord, float strength)
{
    float2 pixelSize = ReShade::PixelSize;
    float3 center = tex2D(ReShade::BackBuffer, texcoord).rgb;
    float3 top    = tex2D(ReShade::BackBuffer, texcoord + float2(0.0, -pixelSize.y)).rgb;
    float3 bottom = tex2D(ReShade::BackBuffer, texcoord + float2(0.0,  pixelSize.y)).rgb;
    float3 left   = tex2D(ReShade::BackBuffer, texcoord + float2(-pixelSize.x, 0.0)).rgb;
    float3 right  = tex2D(ReShade::BackBuffer, texcoord + float2( pixelSize.x, 0.0)).rgb;

    float3 blur = (top + bottom + left + right) * 0.25;
    return saturate(center + (center - blur) * strength);
}

// 3. Matrix Color Manipulations (Linear Algebra Dot Products)
float3 ApplyMatrixTransform(float3 color, int mode)
{
    if (mode == 1) // Cyberpunk Cyan/Magenta Shift
    {
        float3 rRow = float3(0.8,  0.4, -0.2);
        float3 gRow = float3(-0.1, 1.1,  0.2);
        float3 bRow = float3(0.3, -0.3,  1.4);
        return saturate(float3(dot(color, rRow), dot(color, gRow), dot(color, bRow)));
    }
    else if (mode == 2) // Thermal / Infrared False-Color
    {
        float luma = GetLuma(color);
        float3 infrared = float3(
            saturate(luma * 2.0),
            saturate(1.0 - abs(luma - 0.5) * 2.0),
            saturate((1.0 - luma) * 1.5)
        );
        return lerp(color, infrared, 0.75);
    }
    else if (mode == 3) // Neon Cross-Bleed
    {
        float3 rRow = float3(1.2, -0.3,  0.3);
        float3 gRow = float3(0.1,  1.3, -0.2);
        float3 bRow = float3(-0.4, 0.2,  1.5);
        return saturate(float3(dot(color, rRow), dot(color, gRow), dot(color, bRow)));
    }
    else if (mode == 4) // Vaporwave Pink/Yellow
    {
        float3 rRow = float3(1.1,  0.2,  0.3);
        float3 gRow = float3(0.2,  0.7,  0.4);
        float3 bRow = float3(0.5, -0.2,  1.2);
        return saturate(float3(dot(color, rRow), dot(color, gRow), dot(color, bRow)));
    }

    return color;
}

// 4. Radial Chromatic Dispersion
float3 ApplyRadialDispersion(float2 texcoord, float strength)
{
    float2 centerOffset = texcoord - 0.5;
    float dist = length(centerOffset);
    float2 dir = normalize(centerOffset) * (dist * dist) * (strength * 0.015);

    float r = tex2D(ReShade::BackBuffer, texcoord + dir * 1.5).r;
    float g = tex2D(ReShade::BackBuffer, texcoord).g;
    float b = tex2D(ReShade::BackBuffer, texcoord - dir * 1.5).b;

    return float3(r, g, b);
}

// 5. Cross-Channel Difference Amplification
float3 ApplyChannelDifference(float3 color, float boost)
{
    float3 diff = float3(
        color.r - max(color.g, color.b),
        color.g - max(color.r, color.b),
        color.b - max(color.r, color.g)
    );

    return saturate(color + (diff * boost));
}

// 6. Channel Scan-Glow (Horizontal Bleed)
float3 ApplyScanGlow(float2 texcoord, float strength)
{
    float2 px = ReShade::PixelSize;
    float3 glow = 0.0;

    [unroll]
    for(int i = -3; i <= 3; i++)
    {
        float weight = 1.0 - abs(float(i) / 3.0);
        float3 tap = tex2D(ReShade::BackBuffer, texcoord + float2(float(i) * px.x * 2.5, 0.0)).rgb;
        glow += tap * weight;
    }

    return (glow / 3.0) * strength * 0.3;
}

// 7. Highlight/Shadow Polarization
float3 ApplyPolarization(float3 color, float strength)
{
    float luma = GetLuma(color);
    float3 shadowTint = float3(0.0, 0.15, 0.3);  // Deep Cyan/Blue shadows
    float3 highlightTint = float3(0.3, 0.15, 0.0); // Warm Amber highlights

    float3 polarized = lerp(color + shadowTint, color + highlightTint, luma);
    return lerp(color, polarized, strength);
}

// 8. Sub-Pixel LCD Patterning Math (HLSL Integer Modulo Fix)
float3 ApplySubpixelGrid(float3 color, float2 pos, float strength)
{
    int subPixel = int(pos.x) % 3;
    float3 mask = float3(0.5, 0.5, 0.5);

    if (subPixel == 0) mask = float3(1.2, 0.4, 0.4);      // Red Subpixel
    else if (subPixel == 1) mask = float3(0.4, 1.2, 0.4); // Green Subpixel
    else mask = float3(0.4, 0.4, 1.2);                    // Blue Subpixel

    return lerp(color, color * mask, strength);
}

// 9. Dynamic Noise Generator
float PseudoRandom(float2 co)
{
    return frac(sin(dot(co, float2(12.9898, 78.233))) * 43758.5453);
}

// --- Main Pixel Shader Pass ---
float4 PS_GameEnhancer(float4 pos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    // 0. Barrel Distortion Geometry Warp
    float2 uv = texcoord;
    if (EnableChannelMathFX && BarrelDistortion != 0.0)
    {
        uv = ApplyBarrelWarp(texcoord, BarrelDistortion);
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
            return float4(0.0, 0.0, 0.0, 1.0); // Black out of bounds
    }

    // 1. Radial Chromatic Dispersion
    float3 color;
    if (EnableChannelMathFX && DispersionStrength > 0.0)
        color = ApplyRadialDispersion(uv, DispersionStrength);
    else
        color = tex2D(ReShade::BackBuffer, uv).rgb;

    // 2. High-Pass Sharpening
    color = ApplySharpen(uv, Sharpness);

    // 3. Matrix Channel Transformation
    if (EnableChannelMathFX && ColorMatrixMode > 0)
        color = ApplyMatrixTransform(color, ColorMatrixMode);

    // 4. Cross-Channel Math Amplification
    if (EnableChannelMathFX && ChannelDiffBoost > 0.0)
        color = ApplyChannelDifference(color, ChannelDiffBoost);

    // 5. Channel Scan-Glow Bleed
    if (EnableChannelMathFX && ScanGlow > 0.0)
        color += ApplyScanGlow(uv, ScanGlow);

    // 6. Shadow / Highlight Polarization
    if (EnableChannelMathFX && Polarization > 0.0)
        color = ApplyPolarization(color, Polarization);

    // 7. S-Curve Contrast
    color = lerp(color, color * color * (3.0 - 2.0 * color), Contrast);

    // 8. Luma-Weighted Film Grain
    if (FilmGrain > 0.0)
    {
        float noise = PseudoRandom(uv + float2(Timer * 0.001, Timer * 0.001));
        float luma = GetLuma(color);
        float shadowMask = 1.0 - smoothstep(0.0, 0.8, luma); // Concentrate noise in dark areas
        color += (noise - 0.5) * FilmGrain * shadowMask;
    }

    // 9. Sub-Pixel LCD Grid
    if (EnableSubpixelGrid)
        color = ApplySubpixelGrid(color, pos.xy, SubpixelStrength);

    return float4(saturate(color), 1.0);
}

// --- Technique Definition ---
technique GameEnhancer
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_GameEnhancer;
    }
}