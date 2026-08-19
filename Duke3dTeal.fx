#include "ReShade.fxh"

/*
    GreenYellowHeterochromia3D.fx
    Proper Stereoscopic 3D Shader for Yellow / Green Filters
*/

uniform float Separation <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 0.05;
    ui_label = "3D Depth Separation";
> = 0.015;

uniform float Convergence <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Convergence (Focal Point)";
> = 0.25;

float4 PS_GreenYellow3D(float4 pos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    // 1. Read depth buffer
    float depth = ReShade::GetLinearizedDepth(texcoord);
    float parallax = (depth - Convergence) * Separation;

    // 2. Calculate coordinates for left and right eye perspectives
    float2 leftTexcoord  = float2(texcoord.x - parallax, texcoord.y);
    float2 rightTexcoord = float2(texcoord.x + parallax, texcoord.y);

    float3 leftColor  = tex2D(ReShade::BackBuffer, leftTexcoord).rgb;
    float3 rightColor = tex2D(ReShade::BackBuffer, rightTexcoord).rgb;

    // 3. Proper Color-Channel Routing for Yellow and Green Filters
    // Yellow filter isolates Red + Green. Green/Teal filter isolates Green + Blue.
    float3 finalColor;
    finalColor.r = leftColor.r;   // Routed to Yellow filter eye
    finalColor.g = (leftColor.g + rightColor.g) * 0.5; // Shared luminance bridge
    finalColor.b = rightColor.b;  // Routed to Green/Teal filter eye

    return float4(finalColor, 1.0);
}

technique GreenYellowHeterochromia3D
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_GreenYellow3D;
    }
}