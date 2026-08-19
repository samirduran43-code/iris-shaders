#include "ReShade.fxh"

/*==============================================================================
    UI CONTROLS
==============================================================================*/

uniform int FrameCount < source = "framecount"; >;
uniform float Timer < source = "timer"; >;

uniform int Mode <
    ui_type = "combo";
    ui_label = "Channel Cycling Mode";
    ui_items = "Weighted Ratio Selection\0Interlaced Scanlines (Equal)\0Sequential (Equal)\0";
> = 0;

// --- PICKER RATIO CONTROLS ---
uniform float WeightRed <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 10.0;
    ui_label = "Red Channel Ratio";
    ui_tooltip = "Relative likelihood/weight of picking the Red channel.";
> = 1.0;

uniform float WeightGreen <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 10.0;
    ui_label = "Green Channel Ratio";
    ui_tooltip = "Relative likelihood/weight of picking the Green channel.";
> = 1.0;

uniform float WeightBlue <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 10.0;
    ui_label = "Blue Channel Ratio";
    ui_tooltip = "Relative likelihood/weight of picking the Blue channel.";
> = 1.0;

// --- EFFECT CONTROLS ---
uniform float Dispersion <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 0.05;
    ui_label = "Spatial Dispersion (Aberration)";
    ui_tooltip = "Pulls RGB channels apart radially as speed/distance increases.";
> = 0.015;

uniform bool EnableShutter <
    ui_type = "checker";
    ui_label = "Enable Black Frame Shuttering";
    ui_tooltip = "Inserts a black frame into the pulse sequence to improve motion clarity (strobe effect).";
> = false;

uniform float ShutterWeight <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 10.0;
    ui_label = "Black Shutter Frame Ratio";
    ui_tooltip = "Relative weight of picking a black shutter frame when shuttering is enabled.";
> = 1.0;

uniform float BrightnessBoost <
    ui_type = "slider";
    ui_min = 1.0; ui_max = 4.0;
    ui_label = "Luminance Compensation";
> = 2.0;

uniform float GlitchIntensity <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Analog Glitch Noise";
> = 0.1;

/*==============================================================================
    HELPER FUNCTIONS
==============================================================================*/

float Hash11(float p)
{
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float2 GetRadialOffset(float2 texcoord, float amount)
{
    float2 center = texcoord - 0.5;
    float dist = length(center);
    return center * dist * amount;
}

/*==============================================================================
    PIXEL SHADER
==============================================================================*/

float4 TemporalRGBShutterRatioPS(float4 pos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    // 1. Calculate Radial Channel Offsets
    float2 redUV   = texcoord + GetRadialOffset(texcoord,  Dispersion);
    float2 greenUV = texcoord;
    float2 blueUV  = texcoord + GetRadialOffset(texcoord, -Dispersion);

    // 2. Sample Backbuffer for split channels
    float r = tex2D(ReShade::BackBuffer, redUV).r;
    float g = tex2D(ReShade::BackBuffer, greenUV).g;
    float b = tex2D(ReShade::BackBuffer, blueUV).b;

    int activeState = 0; // 0 = Red, 1 = Green, 2 = Blue, 3 = Black Shutter

    if (Mode == 0) // Weighted Picker Ratio Mode
    {
        // Calculate cumulative threshold boundaries based on picker weights
        float wR = max(0.0, WeightRed);
        float wG = max(0.0, WeightGreen);
        float wB = max(0.0, WeightBlue);
        float wS = EnableShutter ? max(0.0, ShutterWeight) : 0.0;

        float totalWeight = wR + wG + wB + wS;

        if (totalWeight > 0.0)
        {
            // Pseudo-random pick value between 0.0 and totalWeight based on frame
            float rng = Hash11(float(FrameCount) * 17.13) * totalWeight;

            // Map random value against weighted probability buckets
            if (rng < wR)
            {
                activeState = 0; // Red
            }
            else if (rng < (wR + wG))
            {
                activeState = 1; // Green
            }
            else if (rng < (wR + wG + wB))
            {
                activeState = 2; // Blue
            }
            else
            {
                activeState = 3; // Black Shutter Frame
            }
        }
    }
    else if (Mode == 1) // Interlaced Scanlines (Fixed sequence)
    {
        int cycleLength = EnableShutter ? 4 : 3;
        activeState = (int(pos.y) + FrameCount) % cycleLength;
    }
    else // Sequential (Fixed sequence)
    {
        int cycleLength = EnableShutter ? 4 : 3;
        activeState = FrameCount % cycleLength;
    }

    // 3. Analog Noise Generator
    float noise = Hash11(texcoord.x * texcoord.y * Timer) * GlitchIntensity;
    
    // 4. Output Isolated Channel according to picker choice
    float3 finalColor = float3(0.0, 0.0, 0.0);

    if (activeState == 0)
    {
        finalColor = float3(r + noise, 0.0, 0.0);
    }
    else if (activeState == 1)
    {
        finalColor = float3(0.0, g + noise, 0.0);
    }
    else if (activeState == 2)
    {
        finalColor = float3(0.0, 0.0, b + noise);
    }
    else // activeState == 3 (Black Shutter)
    {
        finalColor = float3(0.0, 0.0, 0.0);
    }

    // 5. Apply Luminance Compensation
    finalColor *= BrightnessBoost;

    return float4(finalColor, 1.0);
}

/*==============================================================================
    TECHNIQUE
==============================================================================*/

technique Temporal_RGB_Picker_Ratio
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = TemporalRGBShutterRatioPS;
    }
}
