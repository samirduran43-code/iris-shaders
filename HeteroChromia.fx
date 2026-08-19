#include "ReShade.fxh"

/*
    IrisCentral3D.fx
    A custom stereoscopic depth shader modeled after Central Heterochromia 
    (Inner Gold/Yellow, Outer Green)
*/

// ==========================================
// USER CONTROLS (EXPOSED TO RESHADE UI)
// ==========================================

uniform float Separation <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 0.05;
    ui_label = "3D Separation Strength";
    ui_tooltip = "Adjusts how far objects pop out or sink into the screen.";
> = 0.015;

uniform float Convergence <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Focal Distance (Convergence)";
    ui_tooltip = "The depth level where objects align with the screen surface.";
> = 0.2;

uniform float InnerZoneRadius <
    ui_type = "slider";
    ui_min = 0.1; ui_max = 0.8;
    ui_label = "Inner Iris Radius (Yellow Zone)";
    ui_tooltip = "Controls the size of the central gold/yellow focal region.";
> = 0.35;

uniform float RingSmoothness <
    ui_type = "slider";
    ui_min = 0.01; ui_max = 0.5;
    ui_label = "Ring Blend Smoothness";
    ui_tooltip = "Softens the transition between inner yellow and outer green rings.";
> = 0.15;

// ==========================================
// PIXEL SHADER PASS
// ==========================================

float4 PS_IrisCentral3D(float4 pos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    // 1. Calculate distance from screen center to model the iris geometry
    float2 centerOffset = texcoord - float2(0.5, 0.5);
    float distFromCenter = length(centerOffset);

    // 2. Sample game depth buffer
    float depth = ReShade::GetLinearizedDepth(texcoord);

    // 3. Compute Parallax Shift based on depth relative to focal plane
    float parallax = (depth - Convergence) * Separation;

    // 4. Sample Left and Right stereoscopic views
    float2 leftTexcoord  = float2(texcoord.x - parallax, texcoord.y);
    float2 rightTexcoord = float2(texcoord.x + parallax, texcoord.y);

    float3 leftColor  = tex2D(ReShade::BackBuffer, leftTexcoord).rgb;
    float3 rightColor = tex2D(ReShade::BackBuffer, rightTexcoord).rgb;

    // 5. Define Central Iris Zones:
    // Inner Ring: Yellow/Gold (Red + Green channels weighted toward central eye focal area)
    // Outer Ring: Green (Green channel dominant in peripheral depth)
    
    float innerMask = 1.0 - smoothstep(InnerZoneRadius - RingSmoothness, InnerZoneRadius + RingSmoothness, distFromCenter);

    // Composite stereo outputs using yellow/green luminance weights
    float3 finalColor;

    // Inner Yellow Zone (Uses left-eye offset for vibrant central focal depth)
    float3 yellowComposite = float3(leftColor.r, leftColor.g, rightColor.b * 0.2);

    // Outer Green Zone (Isolates peripheral background depth via green dominance)
    float3 greenComposite  = float3(rightColor.r * 0.15, (leftColor.g + rightColor.g) * 0.5, rightColor.b * 0.1);

    // Seamlessly blend inner yellow ring and outer green ring
    finalColor = lerp(greenComposite, yellowComposite, innerMask);

    return float4(finalColor, 1.0);
}

// ==========================================
// TECHNIQUE DEFINITION
// ==========================================

technique IrisCentral3D
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_IrisCentral3D;
    }
}