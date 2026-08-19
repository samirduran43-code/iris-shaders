/*
    ===================================================================
    Shader: SmartNeuromorphic3D_v2.fx (ReShade 3.8 Compatible)
    Description: Advanced Neuromorphic Depth Engine featuring 3-band 
                 spectral dispersion, depth edge micro-occlusion, 
                 anamorphic radial shifts, and depth-isolated bokeh.
    ===================================================================
*/

#include "ReShade.fxh"

// --- Configuration UI ---

uniform float ChromaticDispersion <
    ui_type = "drag";
    ui_min = 0.001; ui_max = 0.025; ui_step = 0.001;
    ui_label = "1. Spectral Dispersion";
    ui_tooltip = "Intensity of chromatic refraction separation.";
> = 0.008;

uniform float FocalDepth <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
    ui_label = "2. Focal Plane (Convergence Point)";
    ui_tooltip = "Objects at this depth stay neutral. Lower = foreground pops; Higher = scene sinks back.";
> = 0.25;

uniform float EdgePopStrength <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.05;
    ui_label = "3. Depth Edge Micro-Occlusion";
    ui_tooltip = "Emphasizes object outlines based on depth transitions to visually detach foreground objects.";
> = 0.80;

uniform float AnamorphicAspect <
    ui_type = "drag";
    ui_min = 0.1; ui_max = 1.0; ui_step = 0.05;
    ui_label = "4. Horizontal Parallax Bias";
    ui_tooltip = "Biases parallax horizontally to mirror human binocular IPD (Interpupillary Distance).";
> = 0.30;

uniform float PeripheralMicroBlur <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.05;
    ui_label = "5. Out-of-Focus Depth Softening";
    ui_tooltip = "Smooths background/foreground transitions to eliminate double-vision ghosting.";
> = 0.75;

uniform bool InvertDepth <
    ui_label = "Invert Game Depth Map";
    ui_tooltip = "Toggle if depth is inverted (black/white swap).";
> = false;

// --- Helper Functions ---

float GetDepth(float2 texcoord)
{
    float d = ReShade::GetLinearizedDepth(texcoord);
    return InvertDepth ? (1.0 - d) : d;
}

// --- Pixel Shader ---

float4 PS_Smart3D_v2(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // 1. Depth Sampling & Edge Detection (Sobel-like depth delta)
    float centerDepth = GetDepth(texcoord);
    float depthDelta  = centerDepth - FocalDepth;

    float depthLeft  = GetDepth(texcoord - float2(ReShade::PixelSize.x * 2.0, 0.0));
    float depthRight = GetDepth(texcoord + float2(ReShade::PixelSize.x * 2.0, 0.0));
    float depthUp    = GetDepth(texcoord - float2(0.0, ReShade::PixelSize.y * 2.0));
    float depthDown  = GetDepth(texcoord + float2(0.0, ReShade::PixelSize.y * 2.0));

    // Calculate depth gradient for edge pop
    float depthEdge = sqrt(pow(depthRight - depthLeft, 2.0) + pow(depthDown - depthUp, 2.0));

    // 2. Anamorphic Elliptical Vector (Simulates human IPD horizontal bias)
    float2 centerVec = texcoord - float2(0.5, 0.5);
    centerVec.y *= AnamorphicAspect; // Squash vertical displacement
    
    float shiftScale = depthDelta * ChromaticDispersion;
    float2 offset = normalize(centerVec + float2(0.0001, 0.0001)) * shiftScale * length(centerVec);

    // 3. Multi-Sample Bokeh Micro-Blur (Prevents harsh edge separation)
    float blurRadius = abs(depthDelta) * PeripheralMicroBlur * 0.004;
    float2 blurOffset1 = float2(blurRadius, blurRadius * 0.5);
    float2 blurOffset2 = float2(-blurRadius * 0.5, blurRadius);

    // Sample channels across tri-band spectral positions
    float red   = (tex2D(ReShade::BackBuffer, texcoord + offset + blurOffset1).r + 
                   tex2D(ReShade::BackBuffer, texcoord + offset - blurOffset2).r) * 0.5;
                   
    float green = (tex2D(ReShade::BackBuffer, texcoord + (blurOffset1 * 0.2)).g + 
                   tex2D(ReShade::BackBuffer, texcoord - (blurOffset2 * 0.2)).g) * 0.5;
                   
    float blue  = (tex2D(ReShade::BackBuffer, texcoord - offset - blurOffset1).b + 
                   tex2D(ReShade::BackBuffer, texcoord - offset + blurOffset2).b) * 0.5;

    float3 color = float3(red, green, blue);

    // 4. Edge Micro-Occlusion (Applies dark shading behind pop-out edges)
    if (depthDelta < 0.0)
    {
        // Foreground edges get a subtle brightness boost to detach from background
        color += depthEdge * EdgePopStrength * 0.4;
    }
    else
    {
        // Background edges behind foreground objects drop in intensity (micro-shadow)
        color -= depthEdge * EdgePopStrength * 0.3;
    }

    // 5. Atmospheric Luminance Shift
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    if (depthDelta > 0.0)
    {
        // Distant background loses saturation & darkens slightly
        color = lerp(color, float3(luminance, luminance, luminance), saturate(depthDelta * 0.3));
        color *= (1.0 - saturate(depthDelta * 0.15));
    }

    return float4(saturate(color), 1.0);
}

// --- Technique Pass ---

technique SmartNeuromorphic3D_v2
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Smart3D_v2;
    }
}