/*------------------------------------------------------------------------------
    Desert & Ice Combat Channel FX
    Compatible with ReShade 3.8+ (ReShade FX)
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

// -----------------------------------------------------------------------------
// UI CONTROLS
// -----------------------------------------------------------------------------

uniform int BiomeMode <
    ui_type = "combo";
    ui_label = "Active Biome Preset";
    ui_tooltip = "Applies custom channel math tailored for specific environments.";
    ui_items = "Off\0Desert Heatwave (R-G Boost & Max Chroma)\0Ice Cave Frost (B-G Split & Cold Tint)\0Combat Overdrive (High Contrast Punch)\0";
> = 1;

uniform float ChannelOffset <
    ui_type = "drag";
    ui_label = "Chromatic Channel Split";
    ui_tooltip = "Offsets Red and Blue channels in opposite directions for high-speed distortion.";
    ui_min = 0.0; ui_max = 0.05;
    ui_step = 0.001;
> = 0.005;

uniform float LowHealthDegradation <
    ui_type = "drag";
    ui_label = "Low Health / Damage Glitch";
    ui_tooltip = "Cross-blends Red channel into Green/Blue and applies luminance-based saturation crush.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.05;
> = 0.0;

uniform float ImpactPulse <
    ui_type = "drag";
    ui_label = "Impact Pulse / Nitro Boost";
    ui_tooltip = "Inverts channel differences (|R - G|) for explosive flash impacts.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.05;
> = 0.0;

// -----------------------------------------------------------------------------
// PIXEL SHADER
// -----------------------------------------------------------------------------

float4 PS_CombatChannelFX(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // 1. Chromatic Aberration / Channel Offset
    float2 offset = float2(ChannelOffset, 0.0);
    float redChannel   = tex2D(ReShade::BackBuffer, texcoord + offset).r;
    float greenChannel = tex2D(ReShade::BackBuffer, texcoord).g;
    float blueChannel  = tex2D(ReShade::BackBuffer, texcoord - offset).b;

    float3 color = float3(redChannel, greenChannel, blueChannel);

    // 2. Biome-Specific Channel Math
    if (BiomeMode == 1) 
    {
        // DESERT HEATWAVE: Push Red-Green differences, soften blue channel, compress shadows
        float desertLuma = dot(color, float3(0.299, 0.587, 0.114));
        color.r = lerp(color.r, max(color.r, color.g * 1.15), 0.5);
        color.b = color.b * 0.85; // Warm desert drop
        color.rgb = lerp(color.rgb, float3(color.r, desertLuma, color.g), 0.15); // Heat distortion blend
    }
    else if (BiomeMode == 2) 
    {
        // ICE CAVE FROST: Maximize Blue/Green contrast, damp red, isolate high-luminance ice highlights
        float minChroma = min(color.r, min(color.g, color.b));
        float maxChroma = max(color.r, max(color.g, color.b));
        float iceMask   = smoothstep(0.4, 0.9, maxChroma - minChroma);

        color.r = color.r * 0.75;
        color.g = min(1.0, color.g * 1.1);
        color.b = min(1.0, color.b * 1.3 + (iceMask * 0.2)); // Blue specular boost
    }
    else if (BiomeMode == 3) 
    {
        // COMBAT OVERDRIVE: High-contrast difference math for intense racing
        float3 diff = abs(color.rgb - color.gbr);
        color.rgb = color.rgb + (diff * 0.4);
    }

    // 3. Impact Pulse Math (|R - G| Inversion)
    if (ImpactPulse > 0.0)
    {
        float channelDiff = abs(color.r - color.g);
        float3 flashColor = float3(1.0 - channelDiff, color.g * 0.5, color.b * 1.2);
        color.rgb = lerp(color.rgb, flashColor, ImpactPulse);
    }

    // 4. Low-Health Channel Degradation
    if (LowHealthDegradation > 0.0)
    {
        // Bleed Red into Green/Blue, collapse contrast down to monochrome red
        float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));
        float3 damagedColor = float3(luma + 0.3, luma * 0.2, luma * 0.1);
        color.rgb = lerp(color.rgb, damagedColor, LowHealthDegradation);
    }

    return float4(color, 1.0);
}

// -----------------------------------------------------------------------------
// TECHNIQUE DEFINITION
// -----------------------------------------------------------------------------

technique CombatChannels
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_CombatChannelFX;
    }
}