/*------------------------------------------------------------------------------
    Master Color Tuner & Channel Separator for ReShade
    Designed for custom RGB channel separation, tinting, and chromatic control.
------------------------------------------------------------------------------*/

#include "ReShade.fxh"

// =============================================================================
// UI PARAMETERS
// =============================================================================

// --- Channel Multipliers ---
uniform float RedChannel <
    ui_category = "1. Channel Multipliers";
    ui_label = "Red Channel Intensity";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

uniform float GreenChannel <
    ui_category = "1. Channel Multipliers";
    ui_label = "Green Channel Intensity";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

uniform float BlueChannel <
    ui_category = "1. Channel Multipliers";
    ui_label = "Blue Channel Intensity (Increase for Blue)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

// --- Channel Offsets (Chromatic Aberration) ---
uniform float2 RedOffset <
    ui_category = "2. Channel Spatial Offsets";
    ui_label = "Red Channel Offset (X, Y)";
    ui_type = "slider";
    ui_min = -0.05; ui_max = 0.05; ui_step = 0.001;
> = float2(0.003, 0.0);

uniform float2 GreenOffset <
    ui_category = "2. Channel Spatial Offsets";
    ui_label = "Green Channel Offset (X, Y)";
    ui_type = "slider";
    ui_min = -0.05; ui_max = 0.05; ui_step = 0.001;
> = float2(0.0, 0.0);

uniform float2 BlueOffset <
    ui_category = "2. Channel Spatial Offsets";
    ui_label = "Blue Channel Offset (X, Y)";
    ui_type = "slider";
    ui_min = -0.05; ui_max = 0.05; ui_step = 0.001;
> = float2(-0.003, 0.0);

// --- Master Color Adjustments ---
uniform float Saturation <
    ui_category = "3. Master Color Controls";
    ui_label = "Global Saturation";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

uniform float Contrast <
    ui_category = "3. Master Color Controls";
    ui_label = "Global Contrast";
    ui_type = "slider";
    ui_min = 0.5; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

uniform float Brightness <
    ui_category = "3. Master Color Controls";
    ui_label = "Global Brightness";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

uniform float3 ColorTint <
    ui_category = "3. Master Color Controls";
    ui_label = "Global Tint Color (RGB)";
    ui_type = "color";
> = float3(1.0, 1.0, 1.0);

// =============================================================================
// PIXEL SHADER
// =============================================================================

float4 PS_MasterColorTuner(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // 1. Sample RGB channels individually with spatial offsets
    float r = tex2D(ReShade::BackBuffer, texcoord + RedOffset).r;
    float g = tex2D(ReShade::BackBuffer, texcoord + GreenOffset).g;
    float b = tex2D(ReShade::BackBuffer, texcoord + BlueOffset).b;

    // 2. Apply individual channel intensity multipliers
    r *= RedChannel;
    g *= GreenChannel;
    b *= BlueChannel;

    float3 color = float3(r, g, b);

    // 3. Apply Brightness
    color *= Brightness;

    // 4. Apply Contrast
    color = (color - 0.5) * Contrast + 0.5;

    // 5. Apply Saturation
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    color = lerp(float3(luma, luma, luma), color, Saturation);

    // 6. Apply Global Tint
    color *= ColorTint;

    return float4(clamp(color, 0.0, 1.0), 1.0);
}

// =============================================================================
// TECHNIQUE DEFINITION
// =============================================================================

technique MasterColorTuner
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_MasterColorTuner;
    }
}