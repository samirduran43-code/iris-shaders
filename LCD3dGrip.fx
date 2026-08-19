/*------------------------------------------------------------------------------
    Depth Cues FX - ReShade 3.8 Shader
    Author: BlueSkyDefender (Adapted for ReShade 3.8 Legacy Support)
    
    Generates depth-based pop-out, local contrast, and pseudo-3D separation
    using the game's linearized z-buffer.
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

// --- UI Controls ---
uniform float Depth_Power <
    ui_type = "drag";
    ui_min = 0.1; ui_max = 5.0; ui_step = 0.05;
    ui_label = "Depth Power";
    ui_tooltip = "Adjusts depth curve intensity. Higher values push far objects back.";
> = 1.0;

uniform float Depth_Pop <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.02;
    ui_label = "3D Pop Strength";
    ui_tooltip = "Controls haloing and depth-edge pop-out contrast.";
> = 0.5;

uniform float Blur_Spread <
    ui_type = "drag";
    ui_min = 0.5; ui_max = 3.0; ui_step = 0.1;
    ui_label = "Edge Spread";
    ui_tooltip = "Radius of the depth-separation mask.";
> = 1.0;

uniform bool Debug_Depth <
    ui_label = "Display Depth Buffer";
    ui_tooltip = "Toggle this to confirm GRIP's depth buffer is reading correctly.";
> = false;

// --- Depth Buffer Sampler ---
float GetDepth(float2 texcoord)
{
    float depth = ReShade::GetLinearizedDepth(texcoord);
    return pow(abs(depth), Depth_Power);
}

// --- Pixel Shader ---
float4 PS_DepthCues(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float4 color = tex2D(ReShade::BackBuffer, texcoord);
    float centerDepth = GetDepth(texcoord);

    if (Debug_Depth)
    {
        return float4(centerDepth.rrr, 1.0);
    }

    // Offset sampling for depth-edge detection
    float2 texel = ReShade::PixelSize * Blur_Spread;
    
    float d1 = GetDepth(texcoord + float2(texel.x, 0.0));
    float d2 = GetDepth(texcoord - float2(texel.x, 0.0));
    float d3 = GetDepth(texcoord + float2(0.0, texel.y));
    float d4 = GetDepth(texcoord - float2(0.0, texel.y));

    // Calculate depth gradient mask
    float depthEdge = (abs(centerDepth - d1) + abs(centerDepth - d2) + 
                       abs(centerDepth - d3) + abs(centerDepth - d4)) * 0.25;

    // Apply depth-edge Pop Shift
    float3 poppedColor = color.rgb + (color.rgb - (d1 + d2 + d3 + d4) * 0.25) * (depthEdge * Depth_Pop * 10.0);

    // Subtle depth shading pop
    poppedColor *= (1.0 + (centerDepth - 0.5) * (Depth_Pop * 0.2));

    return float4(saturate(poppedColor), color.a);
}

// --- Technique ---
technique DepthCues
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_DepthCues;
    }
}