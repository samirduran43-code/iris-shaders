/*
    ==============================================================================
    GripHueTint.fx - ReShade 3.8+ Targeted Color Tint Shader
    Replaces specific RGB color bands in-game using Hue/Saturation Isolation.
    ==============================================================================
*/

#include "ReShade.fxh"

// ===============================================================================
// UI CONTROLS
// ===============================================================================

// --- TARGET 1: RED / WARM TONES ---
uniform bool EnableTargetR <
    ui_category = "1. Red / Warm Hue Target";
    ui_label = "Enable Red-Hue Retint";
> = true;

uniform float3 ReplacementColorR <
    ui_category = "1. Red / Warm Hue Target";
    ui_label = "New Color for Reds";
    ui_type = "color";
> = float3(0.0, 0.8, 1.0); // Default Cyan

uniform float TargetHueR <
    ui_category = "1. Red / Warm Hue Target";
    ui_label = "Target Hue Center";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.0; // 0.0 = Red

uniform float HueToleranceR <
    ui_category = "1. Red / Warm Hue Target";
    ui_label = "Detection Range";
    ui_type = "slider";
    ui_min = 0.01; ui_max = 0.3;
> = 0.08;

// --- TARGET 2: GREEN TONES ---
uniform bool EnableTargetG <
    ui_category = "2. Green Hue Target";
    ui_label = "Enable Green-Hue Retint";
> = true;

uniform float3 ReplacementColorG <
    ui_category = "2. Green Hue Target";
    ui_label = "New Color for Greens";
    ui_type = "color";
> = float3(1.0, 0.2, 0.0); // Default Orange

uniform float TargetHueG <
    ui_category = "2. Green Hue Target";
    ui_label = "Target Hue Center";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.33; // 0.33 = Green

uniform float HueToleranceG <
    ui_category = "2. Green Hue Target";
    ui_label = "Detection Range";
    ui_type = "slider";
    ui_min = 0.01; ui_max = 0.3;
> = 0.08;

// --- TARGET 3: BLUE TONES ---
uniform bool EnableTargetB <
    ui_category = "3. Blue Hue Target";
    ui_label = "Enable Blue-Hue Retint";
> = true;

uniform float3 ReplacementColorB <
    ui_category = "3. Blue Hue Target";
    ui_label = "New Color for Blues";
    ui_type = "color";
> = float3(1.0, 0.0, 0.8); // Default Magenta

uniform float TargetHueB <
    ui_category = "3. Blue Hue Target";
    ui_label = "Target Hue Center";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.66; // 0.66 = Blue

uniform float HueToleranceB <
    ui_category = "3. Blue Hue Target";
    ui_label = "Detection Range";
    ui_type = "slider";
    ui_min = 0.01; ui_max = 0.3;
> = 0.08;

// --- GLOBAL CONTROLS ---
uniform float SaturationThreshold <
    ui_category = "Global Settings";
    ui_label = "Minimum Saturation";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 0.5;
    ui_tooltip = "Ignores whites, grays, and blacks so they aren't accidentally tinted.";
> = 0.15;

uniform bool ShowDebugMask <
    ui_category = "Global Settings";
    ui_label = "Debug Color Mask";
> = false;

// ===============================================================================
// COLOR SPACE CONVERSIONS
// ===============================================================================

float3 RGBtoHCV(float3 rgb) {
    float4 p = (rgb.g < rgb.b) ? float4(rgb.bg, -1.0, 2.0/3.0) : float4(rgb.gb, 0.0, -1.0/3.0);
    float4 q = (rgb.r < p.x)   ? float4(p.xyw, rgb.r)            : float4(rgb.r, p.yzx);
    float c = q.x - min(q.w, q.y);
    float h = abs((q.w - q.y) / (6.0 * c + 1e-10) + q.z);
    return float3(h, c, q.x);
}

float3 RGBtoHSL(float3 rgb) {
    float3 hcv = RGBtoHCV(rgb);
    float l = hcv.z - hcv.y * 0.5;
    float s = hcv.y / (1.0 - abs(l * 2.0 - 1.0) + 1e-10);
    return float3(hcv.x, s, l);
}

// ===============================================================================
// PIXEL SHADER
// ===============================================================================

float4 PS_GripHueTint(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    float4 baseColor = tex2D(ReShade::BackBuffer, texcoord);
    float3 hsl       = RGBtoHSL(baseColor.rgb);
    float3 finalRGB  = baseColor.rgb;

    float maskTotal = 0.0;

    // Only retint pixels with enough saturation (skip asphalt, metals, dark shadows)
    if (hsl.y >= SaturationThreshold) {

        // --- TARGET 1 (Reds) ---
        if (EnableTargetR) {
            float distR = abs(hsl.x - TargetHueR);
            distR = min(distR, 1.0 - distR); // Handle wraparound on wheel
            float weightR = smoothstep(HueToleranceR, 0.0, distR);
            
            float3 newColorR = ReplacementColorR * hsl.z * 1.5; // Preserve original brightness
            finalRGB = lerp(finalRGB, newColorR, weightR);
            maskTotal += weightR;
        }

        // --- TARGET 2 (Greens) ---
        if (EnableTargetG) {
            float distG = abs(hsl.x - TargetHueG);
            distG = min(distG, 1.0 - distG);
            float weightG = smoothstep(HueToleranceG, 0.0, distG);
            
            float3 newColorG = ReplacementColorG * hsl.z * 1.5;
            finalRGB = lerp(finalRGB, newColorG, weightG);
            maskTotal += weightG;
        }

        // --- TARGET 3 (Blues) ---
        if (EnableTargetB) {
            float distB = abs(hsl.x - TargetHueB);
            distB = min(distB, 1.0 - distB);
            float weightB = smoothstep(HueToleranceB, 0.0, distB);
            
            float3 newColorB = ReplacementColorB * hsl.z * 1.5;
            finalRGB = lerp(finalRGB, newColorB, weightB);
            maskTotal += weightB;
        }
    }

    if (ShowDebugMask) {
        return float4(float3(saturate(maskTotal), 0.0, 0.0), baseColor.a);
    }

    return float4(finalRGB, baseColor.a);
}

// ===============================================================================
// PASS DEFINITION
// ===============================================================================

technique GripHueTint {
    pass MainPass {
        VertexShader = PostProcessVS;
        PixelShader  = PS_GripHueTint;
    }
}