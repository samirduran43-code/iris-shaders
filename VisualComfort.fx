/*
    VisualComfort.fx
    ReShade 3.8.x

    Goal:
      Reduce extreme luminance changes and improve perceived visibility
      while retaining the game's original appearance as much as possible.

    Features:
      - Approximate scene luminance analysis
      - Automatic exposure compensation
      - Highlight compression
      - Shadow lifting
      - Contrast control
      - Optional blue-light reduction
      - Saturation control
      - Adjustable overall strength

    NOTE:
      This does not directly control the human pupil or iris.
      It changes the displayed image to reduce extreme visual adaptation.
*/


#include "ReShade.fxh"


// ============================================================================
// USER SETTINGS
// ============================================================================

uniform float EffectStrength <
    ui_type = "slider";
    ui_label = "Overall Strength";
    ui_tooltip = "Overall strength of the visual-comfort processing.";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.65;


uniform float TargetBrightness <
    ui_type = "slider";
    ui_label = "Target Brightness";
    ui_tooltip = "Preferred average screen brightness.";
    ui_min = 0.10;
    ui_max = 0.80;
    ui_step = 0.01;
> = 0.45;


uniform float ExposureLimit <
    ui_type = "slider";
    ui_label = "Exposure Correction";
    ui_tooltip = "Maximum amount of automatic exposure correction.";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.35;


uniform float HighlightCompression <
    ui_type = "slider";
    ui_label = "Highlight Compression";
    ui_tooltip = "Compresses extremely bright portions of the image.";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.60;


uniform float ShadowLift <
    ui_type = "slider";
    ui_label = "Shadow Lift";
    ui_tooltip = "Raises very dark areas so details remain visible.";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.20;


uniform float ContrastAmount <
    ui_type = "slider";
    ui_label = "Contrast";
    ui_tooltip = "Controls final image contrast.";
    ui_min = 0.70;
    ui_max = 1.20;
    ui_step = 0.01;
> = 0.95;


uniform float SaturationAmount <
    ui_type = "slider";
    ui_label = "Saturation";
    ui_tooltip = "Controls color saturation.";
    ui_min = 0.70;
    ui_max = 1.20;
    ui_step = 0.01;
> = 0.98;


uniform float BlueReduction <
    ui_type = "slider";
    ui_label = "Blue Reduction";
    ui_tooltip = "Slightly reduces blue-channel intensity.";
    ui_min = 0.0;
    ui_max = 0.30;
    ui_step = 0.005;
> = 0.00;


uniform float DarkThreshold <
    ui_type = "slider";
    ui_label = "Shadow Threshold";
    ui_tooltip = "Brightness below which shadow lifting begins.";
    ui_min = 0.01;
    ui_max = 0.40;
    ui_step = 0.01;
> = 0.15;


uniform float BrightThreshold <
    ui_type = "slider";
    ui_label = "Highlight Threshold";
    ui_tooltip = "Brightness above which highlight compression begins.";
    ui_min = 0.50;
    ui_max = 1.00;
    ui_step = 0.01;
> = 0.75;


uniform bool PreserveBlack <
    ui_type = "checkbox";
    ui_label = "Preserve True Blacks";
> = true;


// ============================================================================
// BASIC FUNCTIONS
// ============================================================================

float Luminance(float3 color)
{
    return dot(
        color,
        float3(
            0.2126,
            0.7152,
            0.0722
        )
    );
}


float3 ApplySaturation(float3 color, float amount)
{
    float lum = Luminance(color);

    return lerp(
        float3(lum, lum, lum),
        color,
        amount
    );
}


// ============================================================================
// APPROXIMATE SCREEN LUMINANCE
//
// ReShade 3.8 does not provide a direct scene-average luminance value.
// We approximate brightness using several samples around the current pixel.
//
// This is deliberately inexpensive.
// ============================================================================

float EstimateSceneLuminance(float2 uv)
{
    float total = 0.0;

    float2 px = ReShade::PixelSize;


    // Center
    total += Luminance(
        tex2D(
            ReShade::BackBuffer,
            uv
        ).rgb
    );


    // Cross
    total += Luminance(
        tex2D(
            ReShade::BackBuffer,
            uv + float2(px.x * 20.0, 0.0)
        ).rgb
    );

    total += Luminance(
        tex2D(
            ReShade::BackBuffer,
            uv - float2(px.x * 20.0, 0.0)
        ).rgb
    );

    total += Luminance(
        tex2D(
            ReShade::BackBuffer,
            uv + float2(0.0, px.y * 20.0)
        ).rgb
    );

    total += Luminance(
        tex2D(
            ReShade::BackBuffer,
            uv - float2(0.0, px.y * 20.0)
        ).rgb
    );


    // Larger-radius samples
    total += Luminance(
        tex2D(
            ReShade::BackBuffer,
            uv + float2(
                px.x * 60.0,
                px.y * 40.0
            )
        ).rgb
    );

    total += Luminance(
        tex2D(
            ReShade::BackBuffer,
            uv + float2(
                -px.x * 60.0,
                px.y * 40.0
            )
        ).rgb
    );

    total += Luminance(
        tex2D(
            ReShade::BackBuffer,
            uv + float2(
                px.x * 60.0,
                -px.y * 40.0
            )
        ).rgb
    );

    total += Luminance(
        tex2D(
            ReShade::BackBuffer,
            uv + float2(
                -px.x * 60.0,
                -px.y * 40.0
            )
        ).rgb
    );


    return total / 9.0;
}


// ============================================================================
// ADAPTIVE EXPOSURE
// ============================================================================

float3 ApplyAdaptiveExposure(
    float3 color,
    float sceneLum
)
{
    float safeLum = max(
        sceneLum,
        0.001
    );


    float desiredExposure =
        TargetBrightness / safeLum;


    float exposure =
        lerp(
            1.0,
            desiredExposure,
            ExposureLimit
        );


    // Prevent extreme automatic correction.
    exposure = clamp(
        exposure,
        0.75,
        1.30
    );


    return color * exposure;
}


// ============================================================================
// HIGHLIGHT COMPRESSION
// ============================================================================

float3 ApplyHighlightCompression(float3 color)
{
    float lum = Luminance(color);


    float mask = smoothstep(
        BrightThreshold,
        1.0,
        lum
    );


    /*
        Soft highlight compression.

        The higher the luminance, the more aggressively the highlight
        is brought toward a compressed value.
    */

    float compression =
        1.0 + HighlightCompression * 3.0;


    float compressedLum =
        1.0 - exp(
            -lum * compression
        );


    float ratio =
        compressedLum /
        max(lum, 0.0001);


    float3 compressed =
        color * ratio;


    return lerp(
        color,
        compressed,
        mask * HighlightCompression
    );
}


// ============================================================================
// SHADOW LIFT
// ============================================================================

float3 ApplyShadowLift(float3 color)
{
    float lum = Luminance(color);


    float mask =
        1.0 -
        smoothstep(
            0.0,
            DarkThreshold,
            lum
        );


    float lift =
        ShadowLift *
        mask *
        0.08;


    /*
        Preserve true black pixels when requested.
    */

    if (PreserveBlack)
    {
        lift *= smoothstep(
            0.005,
            DarkThreshold,
            lum
        );
    }


    return color + lift;
}


// ============================================================================
// BLUE REDUCTION
//
// This is intentionally conservative.
//
// Reducing blue does not inherently make a display safer,
// but some users prefer a warmer image for comfort.
// ============================================================================

float3 ApplyBlueReduction(float3 color)
{
    float3 result = color;


    result.b *=
        1.0 -
        BlueReduction;


    /*
        Small red/green compensation prevents the image
        from becoming excessively desaturated.
    */

    result.r *=
        1.0 +
        BlueReduction * 0.08;


    result.g *=
        1.0 +
        BlueReduction * 0.03;


    return result;
}


// ============================================================================
// CONTRAST
// ============================================================================

float3 ApplyContrast(float3 color)
{
    return (
        (color - 0.5) *
        ContrastAmount
    ) + 0.5;
}


// ============================================================================
// MAIN PIXEL SHADER
//
// IMPORTANT:
// : SV_Target is required here.
// Without it, ReShade/HLSL can report:
//
// "function return value is missing semantics"
// ============================================================================

float4 PS_VisualComfort(
    float4 position : SV_Position,
    float2 texcoord : TEXCOORD0
) : SV_Target
{
    float3 original =
        tex2D(
            ReShade::BackBuffer,
            texcoord
        ).rgb;


    float3 color =
        original;


    // ------------------------------------------------------------
    // 1. Estimate current scene brightness
    // ------------------------------------------------------------

    float sceneLum =
        EstimateSceneLuminance(
            texcoord
        );


    // ------------------------------------------------------------
    // 2. Adaptive exposure
    // ------------------------------------------------------------

    color =
        ApplyAdaptiveExposure(
            color,
            sceneLum
        );


    // ------------------------------------------------------------
    // 3. Compress very bright areas
    // ------------------------------------------------------------

    color =
        ApplyHighlightCompression(
            color
        );


    // ------------------------------------------------------------
    // 4. Lift crushed shadows
    // ------------------------------------------------------------

    color =
        ApplyShadowLift(
            color
        );


    // ------------------------------------------------------------
    // 5. Contrast
    // ------------------------------------------------------------

    color =
        ApplyContrast(
            color
        );


    // ------------------------------------------------------------
    // 6. Saturation
    // ------------------------------------------------------------

    color =
        ApplySaturation(
            color,
            SaturationAmount
        );


    // ------------------------------------------------------------
    // 7. Optional blue reduction
    // ------------------------------------------------------------

    color =
        ApplyBlueReduction(
            color
        );


    // ------------------------------------------------------------
    // 8. Prevent negative values
    // ------------------------------------------------------------

    color =
        max(
            color,
            0.0
        );


    // ------------------------------------------------------------
    // 9. Overall effect strength
    // ------------------------------------------------------------

    color =
        lerp(
            original,
            color,
            EffectStrength
        );


    // ------------------------------------------------------------
    // 10. Final output
    // ------------------------------------------------------------

    return float4(
        saturate(color),
        1.0
    );
}


// ============================================================================
// TECHNIQUE
// ============================================================================

technique VisualComfort
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_VisualComfort;
    }
}
