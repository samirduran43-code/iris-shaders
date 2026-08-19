#include "ReShade.fxh"

/*==============================================================================
    UI CONTROLS
==============================================================================*/

uniform int FrameCount < source = "framecount"; >;

uniform float Separation <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 0.05;
    ui_label = "3D Edge Separation Shift";
    ui_tooltip = "Width of the primary anaglyph vector offset on depth boundaries.";
> = 0.01;

uniform float Convergence <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Screen Plane Focus (Convergence)";
> = 0.2;

uniform float EdgeThreshold <
    ui_type = "slider";
    ui_min = 0.0001; ui_max = 0.05;
    ui_label = "Edge Sensitivity Threshold";
> = 0.002;

uniform float EdgeMultiplier <
    ui_type = "slider";
    ui_min = 1.0; ui_max = 100.0;
    ui_label = "Edge Sensitivity Multiplier";
> = 20.0;

uniform bool InvertDepth <
    ui_type = "checker";
    ui_label = "Invert Depth Buffer";
    ui_tooltip = "Toggle this if no depth vectors are detected.";
> = true;

// --- GHOST VECTOR SHUTTER CONTROLS ---

uniform float GhostOffset <
    ui_type = "slider";
    ui_min = -0.05; ui_max = 0.05;
    ui_label = "Ghost Vector Offset X";
    ui_tooltip = "Horizontal spatial offset of the shuttering ghost vector.";
> = 0.015;

uniform float GhostOpacity <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Ghost Vector Opacity";
    ui_tooltip = "Strength of the ghost vector overlay when visible.";
> = 0.8;

uniform int GhostChannel <
    ui_type = "combo";
    ui_label = "Ghost Color Spectrum";
    ui_items = "Cyan Ghost (Right Eye Shift)\0Red Ghost (Left Eye Shift)\0Full RGB Cutout\0";
> = 0;

uniform int DebugView <
    ui_type = "combo";
    ui_label = "Debug View Modes";
    ui_items = "Disabled (Normal Output)\0Show Raw Depth Buffer\0Show Edge Vector Lines\0";
> = 0;

/*==============================================================================
    HELPER: DEPTH SAMPLING
==============================================================================*/

float GetRawDepth(float2 uv)
{
    float rawDepth = tex2D(ReShade::DepthBuffer, uv).r;
    return InvertDepth ? (1.0 - rawDepth) : rawDepth;
}

/*==============================================================================
    PIXEL SHADER
==============================================================================*/

float4 VectorGhostShutterPS(float4 pos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    float currentDepth = GetRawDepth(texcoord);

    // 1. Debug Mode: View raw Z-buffer
    if (DebugView == 1)
    {
        return float4(currentDepth, currentDepth, currentDepth, 1.0);
    }

    // 2. Sobel Depth Vector Edge Detection
    float2 pixelStep = ReShade::PixelSize;

    float dRight = GetRawDepth(texcoord + float2(pixelStep.x, 0.0));
    float dLeft  = GetRawDepth(texcoord - float2(pixelStep.x, 0.0));
    float dUp    = GetRawDepth(texcoord - float2(0.0, pixelStep.y));
    float dDown  = GetRawDepth(texcoord + float2(0.0, pixelStep.y));

    float edgeVector = (abs(dRight - dLeft) + abs(dDown - dUp)) * EdgeMultiplier;
    float isEdgeVector = step(EdgeThreshold, edgeVector);

    // 3. Debug Mode: View detected vector outlines
    if (DebugView == 2)
    {
        return float4(isEdgeVector, 0.0, 0.0, 1.0);
    }

    // 4. Sample Base Frame (Anchored)
    float3 centerColor = tex2D(ReShade::BackBuffer, texcoord).rgb;

    // 5. Compute Primary 3D Parallax Vectors
    float parallax = Separation * (currentDepth - Convergence);

    float2 leftUV  = texcoord + float2(parallax, 0.0);
    float2 rightUV = texcoord - float2(parallax, 0.0);

    float3 leftColor  = tex2D(ReShade::BackBuffer, leftUV).rgb;
    float3 rightColor = tex2D(ReShade::BackBuffer, rightUV).rgb;

    // Apply primary 3D anaglyph lines strictly on geometry edge vectors
    float3 finalColor;
    finalColor.r = lerp(centerColor.r, leftColor.r, isEdgeVector);
    finalColor.g = lerp(centerColor.g, rightColor.g, isEdgeVector);
    finalColor.b = lerp(centerColor.b, rightColor.b, isEdgeVector);

    // 6. Ghost Vector Calculation & Temporal Shuttering
    // Fetch ghost edge vector from spatially offset UV coordinates
    float2 ghostUV = texcoord + float2(GhostOffset, 0.0);
    float ghostDepth = GetRawDepth(ghostUV);
    
    float gRight = GetRawDepth(ghostUV + float2(pixelStep.x, 0.0));
    float gLeft  = GetRawDepth(ghostUV - float2(pixelStep.x, 0.0));
    float gUp    = GetRawDepth(ghostUV - float2(0.0, pixelStep.y));
    float gDown  = GetRawDepth(ghostUV + float2(0.0, pixelStep.y));
    
    float ghostEdge = (abs(gRight - gLeft) + abs(gDown - gUp)) * EdgeMultiplier;
    float isGhostEdge = step(EdgeThreshold, ghostEdge);

    // Shutter state toggles on alternating frames
    bool shutterActive = (FrameCount % 2) == 0;

    if (shutterActive && (isGhostEdge > 0.5))
    {
        float3 ghostSample = tex2D(ReShade::BackBuffer, ghostUV).rgb;

        if (GhostChannel == 0) // Cyan Ghost
        {
            finalColor.gb = lerp(finalColor.gb, ghostSample.gb, GhostOpacity);
        }
        else if (GhostChannel == 1) // Red Ghost
        {
            finalColor.r = lerp(finalColor.r, ghostSample.r, GhostOpacity);
        }
        else // Full RGB Cutout Ghost
        {
            finalColor = lerp(finalColor, float3(0.0, 0.0, 0.0), GhostOpacity);
        }
    }

    return float4(finalColor, 1.0);
}

/*==============================================================================
    TECHNIQUE
==============================================================================*/

technique Anaglyph_Vector_Ghost_Shutter
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = VectorGhostShutterPS;
    }
}
