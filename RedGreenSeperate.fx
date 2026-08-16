#include "ReShade.fxh"

/*
    =========================================================================
    GRIP: Combat Racing - Blue Controlled R/G Separation
    =========================================================================

    - Blue channel controls the amount of R/G separation
    - Red and Green use independent gamma curves
    - Blue remains centered/preserved
    - Optional contrast and saturation
    - Optional subtle sharpening
    - No custom sampler required
*/


// ============================================================================
// COLOR / GAMMA
// ============================================================================

uniform float RedGamma <
    ui_type = "slider";
    ui_label = "Red Gamma";
    ui_tooltip = "Gamma applied to the separated red channel.";
    ui_min = 0.50;
    ui_max = 1.50;
    ui_step = 0.01;
> = 0.90;


uniform float GreenGamma <
    ui_type = "slider";
    ui_label = "Green Gamma";
    ui_tooltip = "Gamma applied to the separated green channel.";
    ui_min = 0.50;
    ui_max = 1.50;
    ui_step = 0.01;
> = 1.10;


uniform float BlueGamma <
    ui_type = "slider";
    ui_label = "Blue Gamma";
    ui_tooltip = "Gamma applied to the blue channel.";
    ui_min = 0.50;
    ui_max = 1.50;
    ui_step = 0.01;
> = 0.95;


// ============================================================================
// R/G SEPARATION
// ============================================================================

uniform float BlueSeparation <
    ui_type = "slider";
    ui_label = "Blue -> R/G Separation";
    ui_tooltip = "Blue brightness controls how strongly red and green separate.";
    ui_min = 0.00;
    ui_max = 3.00;
    ui_step = 0.01;
> = 1.00;


uniform float Separation <
    ui_type = "slider";
    ui_label = "R/G Separation";
    ui_tooltip = "Physical screen-space distance between red and green.";
    ui_min = 0.00;
    ui_max = 5.00;
    ui_step = 0.01;
> = 0.65;


uniform float SeparationAngle <
    ui_type = "slider";
    ui_label = "Separation Angle";
    ui_tooltip = "Direction of the red/green separation.";
    ui_min = 0.00;
    ui_max = 6.28318;
    ui_step = 0.01;
> = 0.0;


// ============================================================================
// BLUE CONTROL
// ============================================================================

uniform float BlueControlLow <
    ui_type = "slider";
    ui_label = "Blue Control Low";
    ui_tooltip = "Blue level where the separation starts.";
    ui_min = 0.00;
    ui_max = 1.00;
    ui_step = 0.01;
> = 0.05;


uniform float BlueControlHigh <
    ui_type = "slider";
    ui_label = "Blue Control High";
    ui_tooltip = "Blue level where separation reaches maximum strength.";
    ui_min = 0.00;
    ui_max = 1.00;
    ui_step = 0.01;
> = 0.95;


uniform float BluePreservation <
    ui_type = "slider";
    ui_label = "Blue Preservation";
    ui_tooltip = "Keeps the original blue channel from being altered too much.";
    ui_min = 0.00;
    ui_max = 1.00;
    ui_step = 0.01;
> = 0.85;


// ============================================================================
// FINAL COLOR
// ============================================================================

uniform float Saturation <
    ui_type = "slider";
    ui_label = "Saturation";
    ui_min = 0.00;
    ui_max = 2.00;
    ui_step = 0.01;
> = 1.05;


uniform float Contrast <
    ui_type = "slider";
    ui_label = "Contrast";
    ui_min = 0.50;
    ui_max = 1.50;
    ui_step = 0.01;
> = 1.05;


uniform float Sharpen <
    ui_type = "slider";
    ui_label = "Sharpen";
    ui_min = 0.00;
    ui_max = 2.00;
    ui_step = 0.01;
> = 0.20;


// ============================================================================
// FUNCTIONS
// ============================================================================

float GetLuma(float3 color)
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


float GammaCorrect(float value, float gamma)
{
    return pow(
        max(value, 0.00001),
        gamma
    );
}


float3 SaturateColor(float3 color, float amount)
{
    float luma = GetLuma(color);

    return lerp(
        float3(luma, luma, luma),
        color,
        amount
    );
}


float3 ContrastColor(float3 color, float amount)
{
    return (color - 0.5) * amount + 0.5;
}


// ============================================================================
// PIXEL SHADER
// ============================================================================

float4 GRIP_BlueRG_PS(
    float4 position : SV_Position,
    float2 uv : TEXCOORD
) : SV_Target
{
    // ------------------------------------------------------------------------
    // Pixel size
    // ------------------------------------------------------------------------

    float2 pixel = ReShade::PixelSize;


    // ------------------------------------------------------------------------
    // Original image
    // ------------------------------------------------------------------------

    float3 original = tex2D(
        ReShade::BackBuffer,
        uv
    ).rgb;


    // ------------------------------------------------------------------------
    // BLUE CONTROL SIGNAL
    //
    // This is the important part.
    //
    // Blue is not simply boosted.
    // Blue determines how much the R/G channels are separated.
    // ------------------------------------------------------------------------

    float blueControl = saturate(
        smoothstep(
            BlueControlLow,
            BlueControlHigh,
            original.b
        )
    );

    blueControl *= BlueSeparation;

    blueControl = saturate(blueControl);


    // ------------------------------------------------------------------------
    // SEPARATION VECTOR
    // ------------------------------------------------------------------------

    float2 direction = float2(
        cos(SeparationAngle),
        sin(SeparationAngle)
    );

    float2 separationVector =
        direction *
        pixel *
        Separation *
        blueControl;


    // ------------------------------------------------------------------------
    // RED SAMPLE
    //
    // Red moves in one direction.
    // ------------------------------------------------------------------------

    float3 redSample = tex2D(
        ReShade::BackBuffer,
        uv + separationVector
    ).rgb;


    // ------------------------------------------------------------------------
    // GREEN SAMPLE
    //
    // Green moves in the opposite direction.
    // ------------------------------------------------------------------------

    float3 greenSample = tex2D(
        ReShade::BackBuffer,
        uv - separationVector
    ).rgb;


    // ------------------------------------------------------------------------
    // BLUE SAMPLE
    //
    // Blue stays centered.
    // ------------------------------------------------------------------------

    float blueSample = tex2D(
        ReShade::BackBuffer,
        uv
    ).b;


    // ------------------------------------------------------------------------
    // EXTRACT CHANNELS
    // ------------------------------------------------------------------------

    float red = redSample.r;
    float green = greenSample.g;


    // ------------------------------------------------------------------------
    // BLUE-DEPENDENT GAMMA
    //
    // At blueControl = 0:
    //      gamma = 1.0
    //
    // At blueControl = 1:
    //      gamma = user setting
    //
    // This prevents the entire image from being gamma shifted.
    // ------------------------------------------------------------------------

    float effectiveRedGamma = lerp(
        1.0,
        RedGamma,
        blueControl
    );

    float effectiveGreenGamma = lerp(
        1.0,
        GreenGamma,
        blueControl
    );


    red = GammaCorrect(
        red,
        effectiveRedGamma
    );

    green = GammaCorrect(
        green,
        effectiveGreenGamma
    );


    // ------------------------------------------------------------------------
    // BLUE GAMMA
    // ------------------------------------------------------------------------

    float blueCorrected = GammaCorrect(
        blueSample,
        BlueGamma
    );


    // ------------------------------------------------------------------------
    // BLUE PRESERVATION
    // ------------------------------------------------------------------------

    float blue = lerp(
        blueCorrected,
        original.b,
        BluePreservation
    );


    // ------------------------------------------------------------------------
    // RECONSTRUCT IMAGE
    // ------------------------------------------------------------------------

    float3 color = float3(
        red,
        green,
        blue
    );


    // ------------------------------------------------------------------------
    // BLUE-DRIVEN R/G CROSS-TALK
    //
    // Gives the effect more of a color-separation character instead of
    // looking like ordinary chromatic aberration.
    // ------------------------------------------------------------------------

    float blueDifferenceR =
        original.b - original.r;

    float blueDifferenceG =
        original.b - original.g;

    float crossTalk =
        blueControl * 0.08;


    color.r +=
        blueDifferenceR *
        crossTalk;


    color.g -=
        blueDifferenceG *
        crossTalk;


    // ------------------------------------------------------------------------
    // SATURATION
    // ------------------------------------------------------------------------

    color = SaturateColor(
        color,
        Saturation
    );


    // ------------------------------------------------------------------------
    // CONTRAST
    // ------------------------------------------------------------------------

    color = ContrastColor(
        color,
        Contrast
    );


    // ------------------------------------------------------------------------
    // SHARPEN
    // ------------------------------------------------------------------------

    if (Sharpen > 0.001)
    {
        float3 north = tex2D(
            ReShade::BackBuffer,
            uv + float2(0.0, -pixel.y)
        ).rgb;

        float3 south = tex2D(
            ReShade::BackBuffer,
            uv + float2(0.0, pixel.y)
        ).rgb;

        float3 east = tex2D(
            ReShade::BackBuffer,
            uv + float2(pixel.x, 0.0)
        ).rgb;

        float3 west = tex2D(
            ReShade::BackBuffer,
            uv + float2(-pixel.x, 0.0)
        ).rgb;


        float3 average =
            (north +
             south +
             east +
             west) * 0.25;


        float3 detail =
            color - average;


        color +=
            detail *
            Sharpen;
    }


    // ------------------------------------------------------------------------
    // FINAL CLAMP
    // ------------------------------------------------------------------------

    color = saturate(color);


    return float4(
        color,
        1.0
    );
}


// ============================================================================
// TECHNIQUE
// ============================================================================

technique GRIP_BlueRG_Separation
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = GRIP_BlueRG_PS;
    }
}
