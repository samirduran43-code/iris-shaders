/*------------------------------------------------------------------------------
    Channel Separator Pro FX (with Presets)
    Compatible with ReShade 3.8+ / 4.x / 5.x / 6.x
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

/*------------------------------------------------------------------------------
    UI Controls & Parameters
------------------------------------------------------------------------------*/

// --- Preset Profiles ---
uniform int PresetMode <
    ui_type = "combo";
    ui_label = "Predefined Preset Profile";
    ui_tooltip = "Select a predefined profile or set to Custom to use manual settings below.";
    ui_items = "Custom (Manual)\0Classic Lens\0VHS Glitch\0Anamorphic Edge\0Rotational Prism\03D Anaglyph\0Subtle Film\0";
> = 0;

// --- General Settings ---
uniform int Mode <
    ui_type = "combo";
    ui_label = "Separation Mode";
    ui_tooltip = "Linear: Uniform offset across screen.\nRadial: Lens-style distortion from center.\nRotational: Swirl-style angular rotation from center.";
    ui_items = "Linear Shift\0Radial (Lens Aberration)\0Rotational Shift\0";
> = 0;

uniform bool CorrectAspect <
    ui_label = "Correct Aspect Ratio";
    ui_tooltip = "Ensures equal offset distances on both X and Y axes regardless of resolution.";
> = true;

uniform bool LinearColorSpace <
    ui_label = "Process in Linear Color Space";
    ui_tooltip = "Converts to linear gamma before blending to prevent dark borders between split channels.";
> = true;

// --- Channel Offset & Direction Settings ---
uniform float MasterDistance <
    ui_type = "drag";
    ui_label = "Master Offset Distance";
    ui_min = -0.1; ui_max = 0.1; ui_step = 0.001;
> = 0.005;

uniform float RedAngle <
    ui_type = "drag";
    ui_label = "Red Direction (Angle / Multiplier)";
    ui_min = -360.0; ui_max = 360.0; ui_step = 1.0;
> = 0.0;

uniform float GreenAngle <
    ui_type = "drag";
    ui_label = "Green Direction (Angle / Multiplier)";
    ui_min = -360.0; ui_max = 360.0; ui_step = 1.0;
> = 120.0;

uniform float BlueAngle <
    ui_type = "drag";
    ui_label = "Blue Direction (Angle / Multiplier)";
    ui_min = -360.0; ui_max = 360.0; ui_step = 1.0;
> = 240.0;

uniform float3 ChannelDistanceMult <
    ui_type = "drag";
    ui_label = "Per-Channel Distance Multipliers (RGB)";
    ui_min = -3.0; ui_max = 3.0; ui_step = 0.05;
> = float3(1.0, 1.0, 1.0);

// --- Center Masking ---
uniform bool EnableCenterMask <
    ui_label = "Enable Center Mask";
    ui_tooltip = "Keeps the center of the screen clear for crosshairs or main subjects.";
> = false;

uniform float CenterMaskRadius <
    ui_type = "drag";
    ui_label = "Center Mask Radius";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.25;

uniform float CenterMaskSmoothness <
    ui_type = "drag";
    ui_label = "Center Mask Falloff Smoothness";
    ui_min = 0.01; ui_max = 1.0; ui_step = 0.01;
> = 0.5;

// --- Post-Processing & Grading ---
uniform float3 ChannelScale <
    ui_type = "color";
    ui_label = "Channel Intensity Scaling";
> = float3(1.0, 1.0, 1.0);

uniform float SubPixelBlur <
    ui_type = "drag";
    ui_label = "Sub-Pixel Smoothness";
    ui_min = 0.0; ui_max = 3.0; ui_step = 0.1;
> = 0.0;

uniform float Brightness <
    ui_type = "drag";
    ui_label = "Master Brightness";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.02;
> = 1.0;

uniform float Contrast <
    ui_type = "drag";
    ui_label = "Master Contrast";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.02;
> = 1.0;

/*------------------------------------------------------------------------------
    Helper Functions
------------------------------------------------------------------------------*/

float3 GammaToLinear(float3 color)
{
    return pow(max(color, 0.0), 2.2);
}

float3 LinearToGamma(float3 color)
{
    return pow(max(color, 0.0), 1.0 / 2.2);
}

float2 RotateVec(float2 vec, float angleRad)
{
    float s = sin(angleRad);
    float c = cos(angleRad);
    return float2(vec.x * c - vec.y * s, vec.x * s + vec.y * c);
}

/*------------------------------------------------------------------------------
    Pixel Shader Logic
------------------------------------------------------------------------------*/

float4 PS_ChannelSeparatorPro(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // Apply Preset Override logic if PresetMode != 0 (Custom)
    int effMode = Mode;
    float effDistance = MasterDistance;
    float effRedAngle = RedAngle;
    float effGreenAngle = GreenAngle;
    float effBlueAngle = BlueAngle;
    float3 effMult = ChannelDistanceMult;
    bool effCenterMask = EnableCenterMask;

    if (PresetMode == 1) // Classic Lens
    {
        effMode = 1; // Radial
        effDistance = 0.008;
        effRedAngle = 100.0;
        effGreenAngle = 0.0;
        effBlueAngle = -100.0;
        effMult = float3(1.0, 0.0, 1.0);
    }
    else if (PresetMode == 2) // VHS Glitch
    {
        effMode = 0; // Linear
        effDistance = 0.012;
        effRedAngle = 0.0;   // Shift right
        effGreenAngle = 180.0; // Small nudge left
        effBlueAngle = 180.0; // Shift left
        effMult = float3(1.5, 0.2, 1.2);
    }
    else if (PresetMode == 3) // Anamorphic Edge
    {
        effMode = 0; // Linear
        effDistance = 0.015;
        effRedAngle = 0.0;
        effGreenAngle = 0.0;
        effBlueAngle = 180.0;
        effMult = float3(2.0, 0.0, 2.0);
        effCenterMask = true;
    }
    else if (PresetMode == 4) // Rotational Prism
    {
        effMode = 2; // Rotational
        effDistance = 0.02;
        effRedAngle = 45.0;
        effGreenAngle = 0.0;
        effBlueAngle = -45.0;
        effMult = float3(1.0, 0.5, 1.0);
    }
    else if (PresetMode == 5) // 3D Anaglyph
    {
        effMode = 0; // Linear
        effDistance = 0.006;
        effRedAngle = 0.0;
        effGreenAngle = 180.0;
        effBlueAngle = 180.0;
        effMult = float3(1.0, 1.0, 1.0);
    }
    else if (PresetMode == 6) // Subtle Film
    {
        effMode = 1; // Radial
        effDistance = 0.003;
        effRedAngle = 50.0;
        effGreenAngle = 0.0;
        effBlueAngle = -50.0;
        effMult = float3(0.8, 0.0, 0.8);
        effCenterMask = true;
    }

    float2 aspect = CorrectAspect ? float2(1.0, BUFFER_WIDTH * BUFFER_RCP_HEIGHT) : float2(1.0, 1.0);
    float2 redOffset = 0.0;
    float2 greenOffset = 0.0;
    float2 blueOffset = 0.0;

    // Calculate Mask Strength
    float maskFactor = 1.0;
    if (effCenterMask)
    {
        float2 distFromCenter = (texcoord - 0.5) * aspect;
        float dist = length(distFromCenter);
        maskFactor = smoothstep(CenterMaskRadius, CenterMaskRadius + CenterMaskSmoothness, dist);
    }

    float finalDist = effDistance * maskFactor;

    if (effMode == 0) // Linear Shift
    {
        redOffset   = float2(cos(radians(effRedAngle)),   sin(radians(effRedAngle)))   * finalDist * effMult.r * aspect;
        greenOffset = float2(cos(radians(effGreenAngle)), sin(radians(effGreenAngle))) * finalDist * effMult.g * aspect;
        blueOffset  = float2(cos(radians(effBlueAngle)),  sin(radians(effBlueAngle)))  * finalDist * effMult.b * aspect;
    }
    else if (effMode == 1) // Radial / Lens Shift
    {
        float2 centerDist = (texcoord - 0.5);
        redOffset   = centerDist * finalDist * (effRedAngle / 100.0)   * effMult.r;
        greenOffset = centerDist * finalDist * (effGreenAngle / 100.0) * effMult.g;
        blueOffset  = centerDist * finalDist * (effBlueAngle / 100.0)  * effMult.b;
    }
    else // Rotational Shift
    {
        float2 centerDist = (texcoord - 0.5) * aspect;
        redOffset   = RotateVec(centerDist, radians(effRedAngle * finalDist * effMult.r)) - centerDist;
        greenOffset = RotateVec(centerDist, radians(effGreenAngle * finalDist * effMult.g)) - centerDist;
        blueOffset  = RotateVec(centerDist, radians(effBlueAngle * finalDist * effMult.b)) - centerDist;
    }

    // Sample Channels
    float2 redUV   = texcoord + redOffset;
    float2 greenUV = texcoord + greenOffset;
    float2 blueUV  = texcoord + blueOffset;

    float r = tex2D(ReShade::BackBuffer, redUV).r;
    float g = tex2D(ReShade::BackBuffer, greenUV).g;
    float b = tex2D(ReShade::BackBuffer, blueUV).b;

    if (SubPixelBlur > 0.0)
    {
        float2 blurTexel = BUFFER_PIXEL_SIZE * SubPixelBlur;

        r = (r + tex2D(ReShade::BackBuffer, redUV + blurTexel).r + tex2D(ReShade::BackBuffer, redUV - blurTexel).r) / 3.0;
        g = (g + tex2D(ReShade::BackBuffer, greenUV + blurTexel).g + tex2D(ReShade::BackBuffer, greenUV - blurTexel).g) / 3.0;
        b = (b + tex2D(ReShade::BackBuffer, blueUV + blurTexel).b + tex2D(ReShade::BackBuffer, blueUV - blurTexel).b) / 3.0;
    }

    float3 color = float3(r, g, b) * ChannelScale;

    if (LinearColorSpace)
    {
        color = GammaToLinear(color);
    }

    color = (color - 0.5) * Contrast + 0.5;
    color *= Brightness;

    if (LinearColorSpace)
    {
        color = LinearToGamma(color);
    }

    return float4(saturate(color), 1.0);
}

/*------------------------------------------------------------------------------
    Technique Pass
------------------------------------------------------------------------------*/

technique ChannelSeparatorPro
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_ChannelSeparatorPro;
    }
}