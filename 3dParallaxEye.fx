/*
    ===================================================================
    Shader: SmartNeuromorphic3D.fx (ReShade 3.8 Compatible)
    Description: Multi-sensory 3D spatial reconstruction combining
                 wavelength separation, depth-based atmospheric contrast,
                 and subtle micro-blur.
    ===================================================================
*/

#include "ReShade.fxh"

// --- Configuration UI ---

uniform float ChromaticDispersion <
    ui_type = "drag";
    ui_min = 0.001; ui_max = 0.020; ui_step = 0.001;
    ui_label = "1. Refractive Dispersion";
    ui_tooltip = "Simulates cornea light-refraction depth shift for Red vs Blue wavelengths.";
> = 0.006;

uniform float FocalDepth <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
    ui_label = "2. Eye Convergence Point";
    ui_tooltip = "Depth zone where elements pop out or recede.";
> = 0.25;

uniform float ContrastDepthScale <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 0.5; ui_step = 0.02;
    ui_label = "3. Luminance Parallax";
    ui_tooltip = "Enhances depth by dynamically lowering contrast on background elements.";
> = 0.20;

uniform float PeripheralMicroBlur <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.5; ui_step = 0.05;
    ui_label = "4. Spatial Depth Blur";
    ui_tooltip = "Subtly softens off-focus regions to force your brain to isolate foreground 3D depth.";
> = 0.50;

uniform bool InvertDepth <
    ui_label = "Invert Game Depth Map";
    ui_tooltip = "Toggle if depth is inverted (black/white swap).";
> = false;

// --- Pixel Shader ---

float4 PS_Smart3D(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // 1. Get Game Depth Buffer
    float depth = ReShade::GetLinearizedDepth(texcoord);
    if (InvertDepth) depth = 1.0 - depth;

    // Relative depth distance from visual focal plane
    float depthDelta = depth - FocalDepth;

    // 2. Parallax Vector (Shift originates from screen center to emulate lens curvature)
    float2 centerVec = texcoord - float2(0.5, 0.5);
    float shiftScale = depthDelta * ChromaticDispersion;
    float2 offset = normalize(centerVec + 0.0001) * shiftScale * length(centerVec);

    // 3. Multi-Tap Micro-Blur for Spatial Depth Isolation
    float2 blurSize = ReShade::PixelSize * abs(depthDelta) * PeripheralMicroBlur * 3.0;
    
    // Sample color channels separated by chromatic aberration vector + subtle spatial sampling
    float4 centerSample = tex2D(ReShade::BackBuffer, texcoord);
    
    float redChannel  = tex2D(ReShade::BackBuffer, texcoord + offset + blurSize).r;
    float greenChannel= tex2D(ReShade::BackBuffer, texcoord + (blurSize * 0.5)).g;
    float blueChannel = tex2D(ReShade::BackBuffer, texcoord - offset - blurSize).b;

    float3 finalColor = float3(redChannel, greenChannel, blueChannel);

    // 4. Atmospheric Luminance & Contrast Falloff (Pushes background deep into display)
    if (depthDelta > 0.0) // Background objects
    {
        // Reduce saturation slightly for distant objects
        float luminance = dot(finalColor, float3(0.2126, 0.7152, 0.0722));
        finalColor = lerp(finalColor, float3(luminance, luminance, luminance), depthDelta * ContrastDepthScale);
        
        // Darken background slightly to increase foreground pop-out contrast
        finalColor *= (1.0 - (depthDelta * ContrastDepthScale * 0.5));
    }
    else // Foreground objects
    {
        // Slightly sharpen/boost contrast of foreground elements popping out
        finalColor = saturate(lerp(finalColor, finalColor * 1.15, abs(depthDelta) * ContrastDepthScale));
    }

    return float4(finalColor, 1.0);
}

// --- Technique ---

technique SmartNeuromorphic3D
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Smart3D;
    }
}