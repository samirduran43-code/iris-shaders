#include "ReShade.fxh"

uniform float Separation <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 0.05;
    ui_label = "3D Depth Separation";
> = 0.015;

uniform float Convergence <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Focal Distance";
> = 0.2;

float4 PS_YellowBlue3D(float4 pos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    // 1. Get Depth Buffer value
    float depth = ReShade::GetLinearizedDepth(texcoord);
    
    // 2. Calculate Parallax Shift
    float parallax = (depth - Convergence) * Separation;
    
    // 3. Shift Left Eye (Yellow) and Right Eye (Blue)
    float2 leftTexcoord  = float2(texcoord.x - parallax, texcoord.y);
    float2 rightTexcoord = float2(texcoord.x + parallax, texcoord.y);
    
    // 4. Sample screen textures for each eye
    float3 colorLeft  = tex2D(ReShade::BackBuffer, leftTexcoord).rgb;
    float3 colorRight = tex2D(ReShade::BackBuffer, rightTexcoord).rgb;
    
    // 5. Combine Channels for Yellow (R+G) / Blue (B)
    float3 finalColor;
    finalColor.r  = colorLeft.r;   // Red   --> Left Eye (Yellow Filter)
    finalColor.g  = colorLeft.g;   // Green --> Left Eye (Yellow Filter)
    finalColor.b  = colorRight.b;  // Blue  --> Right Eye (Blue Filter)
    
    return float4(finalColor, 1.0);
}

technique YellowBlue3DEffect
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_YellowBlue3D;
    }
}